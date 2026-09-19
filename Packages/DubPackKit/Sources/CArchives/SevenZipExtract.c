/* SevenZipExtract.c -- unpacks a .7z archive to a directory
 *
 * Streams the common block types straight to disk; see SevenZipExtract.h for why.
 * Written for Dubloon on top of the LZMA SDK (public domain, Igor Pavlov).
 */

#include "Precomp.h"
#include "SevenZipExtract.h"
#include "ArchivePaths.h"

#include "7z.h"
#include "7zAlloc.h"
#include "7zCrc.h"
#include "7zFile.h"
#include "7zTypes.h"
#include "CpuArch.h"
#include "Lzma2Dec.h"
#include "LzmaDec.h"

#include <bzlib.h>
#include <zlib.h>

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/* How much of the archive is read at a time, and how much output is decoded per step. */
#define kInputBufSize  ((size_t)1 << 18)
#define kOutputChunk   ((size_t)1 << 18)

/* 7z method ids, from the SDK's DOC/Methods.txt. */
#define kMethodCopy    0x00
#define kMethodLZMA2   0x21
#define kMethodLZMA    0x030101
#define kMethodDeflate 0x040108
#define kMethodBZip2   0x040202
#define kMethodAES     0x06F10701

static const ISzAlloc g_Alloc = { SzAlloc, SzFree };

/* MARK: - State */

typedef struct {
    const CSzArEx *db;
    ILookInStreamPtr in;
    const char *destination;
    size_t memoryLimit;
    SevenZipProgressCallback progress;
    void *context;
    char *detail;
    size_t detailSize;

    UInt64 totalSize;
    UInt64 totalWritten;
    UInt32 entriesWritten;
    UInt32 entriesSkipped;

    /* Scratch for entry names. Grown as needed. */
    UInt16 *name16;
    size_t name16Capacity;
    char *name8;
    size_t name8Capacity;
    char path[ARCHIVE_MAX_PATH];
} Extractor;

/* One output file on disk, with the running CRC the archive will be checked against. */
typedef struct {
    int fd;          /* -1 when nothing is open */
    int discard;     /* nonzero: this entry is being skipped, its bytes dropped */
    UInt64 remaining;
    UInt32 crc;
    int hasExpectedCrc;
    UInt32 expectedCrc;
} OutFile;

/* Routes a solid block's decoded bytes into its files, one after another. */
typedef struct {
    Extractor *ex;
    UInt32 folderIndex;
    UInt32 nextFile;   /* next index to consider, scanning forward through the folder */
    UInt32 fileEnd;
    OutFile out;
    UInt64 blockRemaining;
} StreamWriter;

static SevenZipStatus fail(Extractor *ex, SevenZipStatus status, const char *format, ...) {
    if (ex->detail && ex->detailSize > 0) {
        va_list args;
        va_start(args, format);
        vsnprintf(ex->detail, ex->detailSize, format, args);
        va_end(args);
    }
    return status;
}

static SevenZipStatus statusForSRes(Extractor *ex, SRes res, const char *where) {
    switch (res) {
        case SZ_OK: return SevenZipStatusOK;
        case SZ_ERROR_MEM: return fail(ex, SevenZipStatusOutOfMemory, "%s: out of memory", where);
        case SZ_ERROR_UNSUPPORTED: return fail(ex, SevenZipStatusUnsupported, "%s: unsupported method", where);
        case SZ_ERROR_NO_ARCHIVE: return fail(ex, SevenZipStatusNotAnArchive, "%s: not a 7z archive", where);
        case SZ_ERROR_READ:
        case SZ_ERROR_WRITE: return fail(ex, SevenZipStatusIO, "%s: i/o error", where);
        case SZ_ERROR_CRC: return fail(ex, SevenZipStatusCorrupt, "%s: crc mismatch", where);
        case SZ_ERROR_INPUT_EOF: return fail(ex, SevenZipStatusCorrupt, "%s: archive is truncated", where);
        default: return fail(ex, SevenZipStatusCorrupt, "%s: damaged (sdk error %d)", where, res);
    }
}

/* MARK: - Names and paths */

/* UTF-16 to UTF-8, surrogate pairs included. Returns the byte length written, or -1. */
static long utf16ToUtf8(const UInt16 *src, size_t srcLen, char *dst, size_t dstSize) {
    size_t out = 0;
    size_t i = 0;
    while (i < srcLen) {
        UInt32 code = src[i++];
        if (code >= 0xD800 && code < 0xDC00 && i < srcLen && src[i] >= 0xDC00 && src[i] < 0xE000) {
            code = 0x10000 + ((code - 0xD800) << 10) + (src[i++] - 0xDC00);
        } else if (code >= 0xD800 && code < 0xE000) {
            code = 0xFFFD;
        }

        size_t need = code < 0x80 ? 1 : code < 0x800 ? 2 : code < 0x10000 ? 3 : 4;
        if (out + need + 1 > dstSize) return -1;

        if (need == 1) {
            dst[out++] = (char)code;
        } else if (need == 2) {
            dst[out++] = (char)(0xC0 | (code >> 6));
            dst[out++] = (char)(0x80 | (code & 0x3F));
        } else if (need == 3) {
            dst[out++] = (char)(0xE0 | (code >> 12));
            dst[out++] = (char)(0x80 | ((code >> 6) & 0x3F));
            dst[out++] = (char)(0x80 | (code & 0x3F));
        } else {
            dst[out++] = (char)(0xF0 | (code >> 18));
            dst[out++] = (char)(0x80 | ((code >> 12) & 0x3F));
            dst[out++] = (char)(0x80 | ((code >> 6) & 0x3F));
            dst[out++] = (char)(0x80 | (code & 0x3F));
        }
    }
    dst[out] = 0;
    return (long)out;
}

/* The entry's name as UTF-8, in ex->name8. Returns 0 on allocation failure. */
static int entryName(Extractor *ex, UInt32 fileIndex) {
    size_t len = SzArEx_GetFileNameUtf16(ex->db, fileIndex, NULL); /* includes the terminator */
    if (len > ex->name16Capacity) {
        UInt16 *grown = (UInt16 *)realloc(ex->name16, len * sizeof(UInt16));
        if (!grown) return 0;
        ex->name16 = grown;
        ex->name16Capacity = len;
    }
    SzArEx_GetFileNameUtf16(ex->db, fileIndex, ex->name16);

    size_t need = len * 3 + 1;
    if (need > ex->name8Capacity) {
        char *grown = (char *)realloc(ex->name8, need);
        if (!grown) return 0;
        ex->name8 = grown;
        ex->name8Capacity = need;
    }
    return utf16ToUtf8(ex->name16, len > 0 ? len - 1 : 0, ex->name8, ex->name8Capacity) >= 0;
}

/*
 * Resolves entry `fileIndex` to a full path under the destination, in ex->path.
 * Returns 1 for a usable path, 0 for an entry to skip, -1 on failure (detail set).
 */
static int resolvePath(Extractor *ex, UInt32 fileIndex) {
    char relative[ARCHIVE_MAX_PATH];

    if (!entryName(ex, fileIndex)) {
        fail(ex, SevenZipStatusOutOfMemory, "entry name: out of memory");
        return -1;
    }

    int resolved = ArchiveResolveEntryPath(ex->destination, ex->name8, ex->path, sizeof ex->path, relative, sizeof relative);
    if (resolved < 0) fail(ex, SevenZipStatusIO, "cannot create directory for %s", relative);
    return resolved;
}

/* MARK: - Output files */

static void outFileInit(OutFile *f) {
    f->fd = -1;
    f->discard = 0;
    f->remaining = 0;
    f->crc = CRC_INIT_VAL;
    f->hasExpectedCrc = 0;
    f->expectedCrc = 0;
}

static SevenZipStatus outFileOpen(Extractor *ex, OutFile *f, UInt32 fileIndex) {
    outFileInit(f);
    f->remaining = SzArEx_GetFileSize(ex->db, fileIndex);
    if (SzBitWithVals_Check(&ex->db->CRCs, fileIndex)) {
        f->hasExpectedCrc = 1;
        f->expectedCrc = ex->db->CRCs.Vals[fileIndex];
    }

    int resolved = resolvePath(ex, fileIndex);
    if (resolved < 0) return SevenZipStatusIO;
    if (resolved == 0) {
        f->discard = 1;
        ex->entriesSkipped++;
        return SevenZipStatusOK;
    }

    f->fd = open(ex->path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (f->fd < 0) return fail(ex, SevenZipStatusIO, "cannot create %s: %s", ex->path, strerror(errno));
    ex->entriesWritten++;
    return SevenZipStatusOK;
}

static SevenZipStatus outFileWrite(Extractor *ex, OutFile *f, const Byte *data, size_t size) {
    f->crc = CrcUpdate(f->crc, data, size);
    if (f->discard) return SevenZipStatusOK;

    while (size > 0) {
        ssize_t written = write(f->fd, data, size);
        if (written < 0) {
            if (errno == EINTR) continue;
            return fail(ex, SevenZipStatusIO, "write failed: %s", strerror(errno));
        }
        data += (size_t)written;
        size -= (size_t)written;
    }
    return SevenZipStatusOK;
}

/* Closes the file and checks its CRC against the archive's. */
static SevenZipStatus outFileClose(Extractor *ex, OutFile *f) {
    if (f->fd >= 0) {
        close(f->fd);
        f->fd = -1;
    }
    if (f->hasExpectedCrc && !f->discard && CRC_GET_DIGEST(f->crc) != f->expectedCrc) {
        return fail(ex, SevenZipStatusCorrupt, "crc mismatch in %s", ex->path);
    }
    return SevenZipStatusOK;
}

static SevenZipStatus reportProgress(Extractor *ex, UInt64 added) {
    ex->totalWritten += added;
    if (ex->progress && ex->progress(ex->context, ex->totalWritten, ex->totalSize) != 0) {
        return fail(ex, SevenZipStatusCancelled, "cancelled");
    }
    return SevenZipStatusOK;
}

/* MARK: - Streaming writer */

static void streamWriterInit(StreamWriter *w, Extractor *ex, UInt32 folderIndex) {
    w->ex = ex;
    w->folderIndex = folderIndex;
    w->nextFile = ex->db->FolderToFile[folderIndex];
    w->fileEnd = ex->db->FolderToFile[(size_t)folderIndex + 1];
    outFileInit(&w->out);
    w->blockRemaining = SzAr_GetFolderUnpackSize(&ex->db->db, folderIndex);
}

/* Opens the folder's next file with data in it. Returns 0 when the folder has no more. */
static int streamWriterAdvance(StreamWriter *w, SevenZipStatus *status) {
    const CSzArEx *db = w->ex->db;
    while (w->nextFile < w->fileEnd) {
        UInt32 index = w->nextFile++;
        if (db->FileToFolder[index] != w->folderIndex) continue;
        if (SzArEx_IsDir(db, index) || SzArEx_GetFileSize(db, index) == 0) continue;
        *status = outFileOpen(w->ex, &w->out, index);
        return 1;
    }
    return 0;
}

static SevenZipStatus streamWriterPush(StreamWriter *w, const Byte *data, size_t size) {
    SevenZipStatus status;

    if (size > w->blockRemaining) {
        return fail(w->ex, SevenZipStatusCorrupt, "block decoded to more bytes than it declares");
    }

    while (size > 0) {
        if (w->out.remaining == 0) {
            if (!streamWriterAdvance(w, &status)) {
                return fail(w->ex, SevenZipStatusCorrupt, "block has data beyond its last file");
            }
            if (status != SevenZipStatusOK) return status;
        }

        size_t take = size < w->out.remaining ? size : (size_t)w->out.remaining;
        status = outFileWrite(w->ex, &w->out, data, take);
        if (status != SevenZipStatusOK) return status;

        data += take;
        size -= take;
        w->out.remaining -= take;
        w->blockRemaining -= take;

        status = reportProgress(w->ex, take);
        if (status != SevenZipStatusOK) return status;

        if (w->out.remaining == 0) {
            status = outFileClose(w->ex, &w->out);
            if (status != SevenZipStatusOK) return status;
        }
    }
    return SevenZipStatusOK;
}

static SevenZipStatus streamWriterFinish(StreamWriter *w) {
    if (w->out.fd >= 0) outFileClose(w->ex, &w->out);
    if (w->blockRemaining != 0) {
        return fail(w->ex, SevenZipStatusCorrupt, "block ended %llu bytes short",
                    (unsigned long long)w->blockRemaining);
    }
    return SevenZipStatusOK;
}

/* MARK: - Input */

/* Points `buf` at the next run of packed bytes, at most `packRemaining` of them. */
static SevenZipStatus lookInput(Extractor *ex, UInt64 packRemaining, const Byte **buf, size_t *size) {
    size_t want = kInputBufSize;
    if (want > packRemaining) want = (size_t)packRemaining;
    *size = want;
    if (want == 0) {
        *buf = NULL;
        return SevenZipStatusOK;
    }
    SRes res = ILookInStream_Look(ex->in, (const void **)buf, size);
    if (res != SZ_OK) return statusForSRes(ex, res, "read");
    return SevenZipStatusOK;
}

static SevenZipStatus skipInput(Extractor *ex, size_t consumed) {
    if (consumed == 0) return SevenZipStatusOK;
    SRes res = ILookInStream_Skip(ex->in, consumed);
    if (res != SZ_OK) return statusForSRes(ex, res, "read");
    return SevenZipStatusOK;
}

/* MARK: - Block decoders */

typedef struct {
    const Byte *props;
    unsigned propsSize;
    UInt64 packSize;
    UInt64 unpackSize;
} BlockInfo;

static SevenZipStatus decodeCopy(Extractor *ex, const BlockInfo *block, StreamWriter *w) {
    UInt64 packRemaining = block->packSize;
    if (block->packSize != block->unpackSize) {
        return fail(ex, SevenZipStatusCorrupt, "stored block sizes disagree");
    }

    while (packRemaining > 0) {
        const Byte *buf;
        size_t size;
        SevenZipStatus status = lookInput(ex, packRemaining, &buf, &size);
        if (status != SevenZipStatusOK) return status;
        if (size == 0) return fail(ex, SevenZipStatusCorrupt, "archive is truncated");

        status = streamWriterPush(w, buf, size);
        if (status != SevenZipStatusOK) return status;
        status = skipInput(ex, size);
        if (status != SevenZipStatusOK) return status;
        packRemaining -= size;
    }
    return SevenZipStatusOK;
}

/* The smallest LZMA2 dictionary property that still covers `needed` bytes. */
static Byte lzma2PropertyCovering(Byte original, UInt64 needed) {
    for (Byte p = 0; p < original; p++) {
        UInt64 size = (UInt64)(2 | (p & 1)) << (p / 2 + 11);
        if (size >= needed) return p;
    }
    return original;
}

static SevenZipStatus decodeLzmaFamily(Extractor *ex, const BlockInfo *block, StreamWriter *w, int isLzma2) {
    CLzmaDec lzma;
    CLzma2Dec lzma2;
    SRes res;

    /*
     * A dictionary bigger than the block's output is memory for nothing: no match can reach
     * further back than the start of the data. Clamping it keeps a 64 MB "ultra" dictionary
     * from being allocated to unpack a 3 MB pack.
     */
    UInt64 needed = block->unpackSize < 4096 ? 4096 : block->unpackSize;

    if (isLzma2) {
        if (block->propsSize < 1) return fail(ex, SevenZipStatusCorrupt, "lzma2 block has no properties");
        Byte prop = block->props[0];
        if (prop > 40) return fail(ex, SevenZipStatusCorrupt, "lzma2 dictionary property out of range");
        if (prop < 40) {
            UInt64 dictionary = (UInt64)(2 | (prop & 1)) << (prop / 2 + 11);
            if (dictionary > needed) prop = lzma2PropertyCovering(prop, needed);
        } else {
            prop = lzma2PropertyCovering(prop, needed);
        }
        Lzma2Dec_CONSTRUCT(&lzma2)
        res = Lzma2Dec_Allocate(&lzma2, prop, &g_Alloc);
        if (res != SZ_OK) return statusForSRes(ex, res, "lzma2 setup");
        Lzma2Dec_Init(&lzma2);
    } else {
        Byte props[LZMA_PROPS_SIZE];
        if (block->propsSize < LZMA_PROPS_SIZE) return fail(ex, SevenZipStatusCorrupt, "lzma block has short properties");
        memcpy(props, block->props, LZMA_PROPS_SIZE);
        UInt32 dictionary = GetUi32(props + 1);
        if (dictionary > needed) { SetUi32(props + 1, (UInt32)needed) }
        LzmaDec_CONSTRUCT(&lzma)
        res = LzmaDec_Allocate(&lzma, props, LZMA_PROPS_SIZE, &g_Alloc);
        if (res != SZ_OK) return statusForSRes(ex, res, "lzma setup");
        LzmaDec_Init(&lzma);
    }

    Byte *outBuf = (Byte *)malloc(kOutputChunk);
    if (!outBuf) {
        if (isLzma2) Lzma2Dec_Free(&lzma2, &g_Alloc); else LzmaDec_Free(&lzma, &g_Alloc);
        return fail(ex, SevenZipStatusOutOfMemory, "output buffer: out of memory");
    }

    SevenZipStatus status = SevenZipStatusOK;
    UInt64 outRemaining = block->unpackSize;
    UInt64 packRemaining = block->packSize;

    while (outRemaining > 0 && status == SevenZipStatusOK) {
        const Byte *inBuf;
        size_t inSize;
        status = lookInput(ex, packRemaining, &inBuf, &inSize);
        if (status != SevenZipStatusOK) break;

        SizeT srcLen = inSize;
        SizeT destLen = outRemaining < kOutputChunk ? (SizeT)outRemaining : kOutputChunk;
        ELzmaFinishMode finish = destLen == outRemaining ? LZMA_FINISH_END : LZMA_FINISH_ANY;
        ELzmaStatus lzmaStatus;

        if (isLzma2) {
            res = Lzma2Dec_DecodeToBuf(&lzma2, outBuf, &destLen, inBuf, &srcLen, finish, &lzmaStatus);
        } else {
            res = LzmaDec_DecodeToBuf(&lzma, outBuf, &destLen, inBuf, &srcLen, finish, &lzmaStatus);
        }

        status = skipInput(ex, srcLen);
        if (status != SevenZipStatusOK) break;
        packRemaining -= srcLen;

        if (res != SZ_OK) {
            status = fail(ex, SevenZipStatusCorrupt, "%s data is damaged", isLzma2 ? "lzma2" : "lzma");
            break;
        }

        if (destLen > 0) {
            status = streamWriterPush(w, outBuf, destLen);
            if (status != SevenZipStatusOK) break;
            outRemaining -= destLen;
        }

        if (destLen == 0 && srcLen == 0) {
            /* No progress in either direction: the packed stream ran out early. */
            status = fail(ex, SevenZipStatusCorrupt, "%s stream ended %llu bytes early",
                          isLzma2 ? "lzma2" : "lzma", (unsigned long long)outRemaining);
            break;
        }
    }

    free(outBuf);
    if (isLzma2) Lzma2Dec_Free(&lzma2, &g_Alloc); else LzmaDec_Free(&lzma, &g_Alloc);
    return status;
}

static SevenZipStatus decodeDeflate(Extractor *ex, const BlockInfo *block, StreamWriter *w) {
    z_stream z;
    memset(&z, 0, sizeof z);
    /* 7z stores raw deflate: no zlib header, hence the negative window bits. */
    if (inflateInit2(&z, -15) != Z_OK) return fail(ex, SevenZipStatusOutOfMemory, "deflate setup failed");

    Byte *outBuf = (Byte *)malloc(kOutputChunk);
    if (!outBuf) {
        inflateEnd(&z);
        return fail(ex, SevenZipStatusOutOfMemory, "output buffer: out of memory");
    }

    SevenZipStatus status = SevenZipStatusOK;
    UInt64 outRemaining = block->unpackSize;
    UInt64 packRemaining = block->packSize;

    while (outRemaining > 0 && status == SevenZipStatusOK) {
        const Byte *inBuf;
        size_t inSize;
        status = lookInput(ex, packRemaining, &inBuf, &inSize);
        if (status != SevenZipStatusOK) break;

        z.next_in = (Bytef *)inBuf;
        z.avail_in = (uInt)inSize;
        z.next_out = outBuf;
        z.avail_out = (uInt)(outRemaining < kOutputChunk ? outRemaining : kOutputChunk);

        int ret = inflate(&z, Z_NO_FLUSH);
        size_t consumed = inSize - z.avail_in;
        size_t produced = (size_t)(z.next_out - outBuf);

        status = skipInput(ex, consumed);
        if (status != SevenZipStatusOK) break;
        packRemaining -= consumed;

        if (ret != Z_OK && ret != Z_STREAM_END && ret != Z_BUF_ERROR) {
            status = fail(ex, SevenZipStatusCorrupt, "deflate data is damaged (%d)", ret);
            break;
        }

        if (produced > 0) {
            status = streamWriterPush(w, outBuf, produced);
            if (status != SevenZipStatusOK) break;
            outRemaining -= produced;
        }

        if (ret == Z_STREAM_END && outRemaining > 0) {
            status = fail(ex, SevenZipStatusCorrupt, "deflate stream ended %llu bytes early",
                          (unsigned long long)outRemaining);
            break;
        }
        if (produced == 0 && consumed == 0) {
            status = fail(ex, SevenZipStatusCorrupt, "deflate stream is truncated");
            break;
        }
    }

    free(outBuf);
    inflateEnd(&z);
    return status;
}

static SevenZipStatus decodeBZip2(Extractor *ex, const BlockInfo *block, StreamWriter *w) {
    bz_stream bz;
    memset(&bz, 0, sizeof bz);
    if (BZ2_bzDecompressInit(&bz, 0, 0) != BZ_OK) return fail(ex, SevenZipStatusOutOfMemory, "bzip2 setup failed");

    Byte *outBuf = (Byte *)malloc(kOutputChunk);
    if (!outBuf) {
        BZ2_bzDecompressEnd(&bz);
        return fail(ex, SevenZipStatusOutOfMemory, "output buffer: out of memory");
    }

    SevenZipStatus status = SevenZipStatusOK;
    UInt64 outRemaining = block->unpackSize;
    UInt64 packRemaining = block->packSize;

    while (outRemaining > 0 && status == SevenZipStatusOK) {
        const Byte *inBuf;
        size_t inSize;
        status = lookInput(ex, packRemaining, &inBuf, &inSize);
        if (status != SevenZipStatusOK) break;

        bz.next_in = (char *)inBuf;
        bz.avail_in = (unsigned int)inSize;
        bz.next_out = (char *)outBuf;
        bz.avail_out = (unsigned int)(outRemaining < kOutputChunk ? outRemaining : kOutputChunk);

        int ret = BZ2_bzDecompress(&bz);
        size_t consumed = inSize - bz.avail_in;
        size_t produced = (size_t)((Byte *)bz.next_out - outBuf);

        status = skipInput(ex, consumed);
        if (status != SevenZipStatusOK) break;
        packRemaining -= consumed;

        if (ret != BZ_OK && ret != BZ_STREAM_END) {
            status = fail(ex, SevenZipStatusCorrupt, "bzip2 data is damaged (%d)", ret);
            break;
        }

        if (produced > 0) {
            status = streamWriterPush(w, outBuf, produced);
            if (status != SevenZipStatusOK) break;
            outRemaining -= produced;
        }

        if (ret == BZ_STREAM_END && outRemaining > 0) {
            /* A block written as several concatenated bzip2 streams. Start the next one. */
            if (packRemaining == 0 && bz.avail_in == 0) {
                status = fail(ex, SevenZipStatusCorrupt, "bzip2 stream ended %llu bytes early",
                              (unsigned long long)outRemaining);
                break;
            }
            BZ2_bzDecompressEnd(&bz);
            memset(&bz, 0, sizeof bz);
            if (BZ2_bzDecompressInit(&bz, 0, 0) != BZ_OK) {
                status = fail(ex, SevenZipStatusOutOfMemory, "bzip2 setup failed");
                break;
            }
            continue;
        }
        if (produced == 0 && consumed == 0) {
            status = fail(ex, SevenZipStatusCorrupt, "bzip2 stream is truncated");
            break;
        }
    }

    free(outBuf);
    BZ2_bzDecompressEnd(&bz);
    return status;
}

/* MARK: - Folders */

/* Reads folder `index`'s coder chain. Returns 0 if the header is malformed. */
static int readFolder(const CSzArEx *db, UInt32 index, CSzFolder *folder, const Byte **propsData) {
    const CSzAr *ar = &db->db;
    const Byte *data = ar->CodersData + ar->FoCodersOffsets[index];
    CSzData sd;
    sd.Data = data;
    sd.Size = ar->FoCodersOffsets[(size_t)index + 1] - ar->FoCodersOffsets[index];
    if (SzGetNextFolderItem(folder, &sd) != SZ_OK || sd.Size != 0) return 0;
    *propsData = data;
    return 1;
}

/* Whether the folder is one plain coder this file can stream. */
static int isStreamable(const CSzFolder *folder) {
    if (folder->NumCoders != 1 || folder->NumPackStreams != 1 || folder->Coders[0].NumStreams != 1) return 0;
    switch (folder->Coders[0].MethodID) {
        case kMethodCopy:
        case kMethodLZMA:
        case kMethodLZMA2:
        case kMethodDeflate:
        case kMethodBZip2:
            return 1;
        default:
            return 0;
    }
}

static SevenZipStatus streamFolder(Extractor *ex, UInt32 folderIndex, const CSzFolder *folder, const Byte *propsData) {
    const CSzAr *ar = &ex->db->db;
    const CSzCoderInfo *coder = &folder->Coders[0];
    UInt32 packIndex = ar->FoStartPackStreamIndex[folderIndex];

    BlockInfo block;
    block.props = propsData + coder->PropsOffset;
    block.propsSize = coder->PropsSize;
    block.packSize = ar->PackPositions[(size_t)packIndex + 1] - ar->PackPositions[packIndex];
    block.unpackSize = SzAr_GetFolderUnpackSize(ar, folderIndex);

    SRes res = LookInStream_SeekTo(ex->in, ex->db->dataPos + ar->PackPositions[packIndex]);
    if (res != SZ_OK) return statusForSRes(ex, res, "seek");

    StreamWriter writer;
    streamWriterInit(&writer, ex, folderIndex);

    SevenZipStatus status;
    switch (coder->MethodID) {
        case kMethodCopy:    status = decodeCopy(ex, &block, &writer); break;
        case kMethodLZMA:    status = decodeLzmaFamily(ex, &block, &writer, 0); break;
        case kMethodLZMA2:   status = decodeLzmaFamily(ex, &block, &writer, 1); break;
        case kMethodDeflate: status = decodeDeflate(ex, &block, &writer); break;
        case kMethodBZip2:   status = decodeBZip2(ex, &block, &writer); break;
        default:             status = fail(ex, SevenZipStatusUnsupported, "method %#x", (unsigned)coder->MethodID); break;
    }

    if (status != SevenZipStatusOK) {
        if (writer.out.fd >= 0) close(writer.out.fd);
        return status;
    }
    return streamWriterFinish(&writer);
}

/*
 * The SDK's own path: the whole solid block into memory, then each file copied out of it.
 * Used for anything `streamFolder` does not handle.
 */
typedef struct {
    UInt32 blockIndex;
    Byte *buffer;
    size_t bufferSize;
} MemoryCache;

static SevenZipStatus extractInMemory(Extractor *ex, UInt32 fileIndex, MemoryCache *cache) {
    UInt32 folderIndex = ex->db->FileToFolder[fileIndex];
    UInt64 blockSize = SzAr_GetFolderUnpackSize(&ex->db->db, folderIndex);

    if (ex->memoryLimit > 0 && blockSize > ex->memoryLimit && (!cache->buffer || cache->blockIndex != folderIndex)) {
        return fail(ex, SevenZipStatusTooLarge, "a %llu MB block cannot be decoded in memory",
                    (unsigned long long)(blockSize >> 20));
    }

    size_t offset = 0;
    size_t size = 0;
    SRes res = SzArEx_Extract(ex->db, ex->in, fileIndex, &cache->blockIndex, &cache->buffer,
                              &cache->bufferSize, &offset, &size, &g_Alloc, &g_Alloc);
    if (res != SZ_OK) return statusForSRes(ex, res, "decode");

    OutFile out;
    SevenZipStatus status = outFileOpen(ex, &out, fileIndex);
    if (status != SevenZipStatusOK) return status;

    status = outFileWrite(ex, &out, cache->buffer + offset, size);
    if (status == SevenZipStatusOK) status = reportProgress(ex, size);
    if (out.fd >= 0) { close(out.fd); out.fd = -1; }
    return status;
}

/* MARK: - Entry point */

int SevenZipLooksLikeArchive(const char *path) {
    Byte head[k7zSignatureSize];
    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 0;
    ssize_t got = read(fd, head, sizeof head);
    close(fd);
    return got == (ssize_t)sizeof head && memcmp(head, k7zSignature, sizeof head) == 0;
}

SevenZipStatus SevenZipExtract(const char *archivePath,
                               const char *destinationDirectory,
                               size_t memoryLimit,
                               SevenZipProgressCallback progress,
                               void *context,
                               char *detail,
                               size_t detailSize,
                               SevenZipExtractStats *stats) {
    Extractor ex;
    memset(&ex, 0, sizeof ex);
    ex.destination = destinationDirectory;
    ex.memoryLimit = memoryLimit;
    ex.progress = progress;
    ex.context = context;
    ex.detail = detail;
    ex.detailSize = detailSize;
    if (detail && detailSize > 0) detail[0] = 0;
    if (stats) {
        stats->entriesWritten = 0;
        stats->entriesSkipped = 0;
    }

    if (!SevenZipLooksLikeArchive(archivePath)) {
        return fail(&ex, SevenZipStatusNotAnArchive, "no 7z signature");
    }

    CrcGenerateTable();

    CFileInStream archiveStream;
    if (InFile_Open(&archiveStream.file, archivePath) != 0) {
        return fail(&ex, SevenZipStatusIO, "cannot open archive: %s", strerror(errno));
    }
    FileInStream_CreateVTable(&archiveStream);
    archiveStream.wres = 0;

    CLookToRead2 lookStream;
    LookToRead2_CreateVTable(&lookStream, False);
    lookStream.buf = (Byte *)ISzAlloc_Alloc(&g_Alloc, kInputBufSize);
    if (!lookStream.buf) {
        File_Close(&archiveStream.file);
        return fail(&ex, SevenZipStatusOutOfMemory, "input buffer: out of memory");
    }
    lookStream.bufSize = kInputBufSize;
    lookStream.realStream = &archiveStream.vt;
    LookToRead2_INIT(&lookStream)
    ex.in = &lookStream.vt;

    CSzArEx db;
    SzArEx_Init(&db);
    ex.db = &db;

    SevenZipStatus status;
    MemoryCache cache = { 0xFFFFFFFF, NULL, 0 };
    Byte *folderDone = NULL;

    SRes res = SzArEx_Open(&db, &lookStream.vt, &g_Alloc, &g_Alloc);
    if (res != SZ_OK) {
        status = statusForSRes(&ex, res, "open");
        if (res == SZ_ERROR_UNSUPPORTED) {
            fail(&ex, SevenZipStatusUnsupported, "open: unsupported header method, or the headers are encrypted");
        }
        goto done;
    }

    /* Refuse an encrypted archive up front, by name, rather than as a mystery method. */
    for (UInt32 f = 0; f < db.db.NumFolders; f++) {
        CSzFolder folder;
        const Byte *propsData;
        if (!readFolder(&db, f, &folder, &propsData)) {
            status = fail(&ex, SevenZipStatusCorrupt, "folder %u header is damaged", (unsigned)f);
            goto done;
        }
        for (UInt32 c = 0; c < folder.NumCoders; c++) {
            if (folder.Coders[c].MethodID == kMethodAES) {
                status = fail(&ex, SevenZipStatusEncrypted, "archive is password protected");
                goto done;
            }
        }
    }

    for (UInt32 i = 0; i < db.NumFiles; i++) {
        if (!SzArEx_IsDir(&db, i)) ex.totalSize += SzArEx_GetFileSize(&db, i);
    }

    folderDone = (Byte *)calloc(db.db.NumFolders + 1, 1);
    if (!folderDone) {
        status = fail(&ex, SevenZipStatusOutOfMemory, "folder table: out of memory");
        goto done;
    }

    status = SevenZipStatusOK;

    for (UInt32 i = 0; i < db.NumFiles && status == SevenZipStatusOK; i++) {
        int isDir = SzArEx_IsDir(&db, i);
        UInt32 folderIndex = db.FileToFolder[i];

        if (isDir || folderIndex == (UInt32)-1) {
            /* A directory or an empty file: nothing to decode, but it should still exist. */
            int resolved = resolvePath(&ex, i);
            if (resolved < 0) { status = SevenZipStatusIO; break; }
            if (resolved == 0) { ex.entriesSkipped++; continue; }
            if (isDir) {
                if (!ArchiveEnsureDirectory(ex.path)) status = fail(&ex, SevenZipStatusIO, "cannot create %s", ex.path);
                else ex.entriesWritten++;
            } else {
                int fd = open(ex.path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
                if (fd < 0) status = fail(&ex, SevenZipStatusIO, "cannot create %s: %s", ex.path, strerror(errno));
                else { close(fd); ex.entriesWritten++; }
            }
            continue;
        }

        if (folderDone[folderIndex]) continue;

        CSzFolder folder;
        const Byte *propsData;
        if (!readFolder(&db, folderIndex, &folder, &propsData)) {
            status = fail(&ex, SevenZipStatusCorrupt, "folder %u header is damaged", (unsigned)folderIndex);
            break;
        }

        if (isStreamable(&folder)) {
            status = streamFolder(&ex, folderIndex, &folder, propsData);
            folderDone[folderIndex] = 1;
        } else {
            status = extractInMemory(&ex, i, &cache);
        }
    }

done:
    if (stats) {
        stats->entriesWritten = ex.entriesWritten;
        stats->entriesSkipped = ex.entriesSkipped;
    }
    free(folderDone);
    ISzAlloc_Free(&g_Alloc, cache.buffer);
    SzArEx_Free(&db, &g_Alloc);
    ISzAlloc_Free(&g_Alloc, lookStream.buf);
    File_Close(&archiveStream.file);
    free(ex.name16);
    free(ex.name8);
    return status;
}
