/* ZipRecover.c -- unpacks a zip by walking its entries from the front
 *
 * See ZipRecover.h for why. The archive is memory-mapped, so a large pack costs address space
 * rather than memory, and Deflate is decoded by the system's zlib, which also reports where each
 * stream ends when the entry's header does not say.
 */

#include "ZipRecover.h"
#include "ArchivePaths.h"

#include <errno.h>
#include <fcntl.h>
#include <stdarg.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/mman.h>
#include <sys/stat.h>
#include <unistd.h>
#include <zlib.h>

/* How much output is decoded per step, and how much is written per call. */
#define kOutputChunk ((size_t)1 << 18)
#define kWriteChunk  ((size_t)1 << 20)

#define kSigLocalHeader    0x04034b50u
#define kSigCentralHeader  0x02014b50u
#define kSigEndOfCentral   0x06054b50u
#define kSigZip64End       0x06064b50u
#define kSigZip64Locator   0x07064b50u
#define kSigDataDescriptor 0x08074b50u

#define kFlagEncrypted      0x0001
#define kFlagDataDescriptor 0x0008
#define kFlagUTF8           0x0800

#define kMethodStored  0
#define kMethodDeflate 8

/* MARK: - State */

typedef struct {
    const uint8_t *data;
    size_t size;
    const char *destination;
    ZipRecoverProgressCallback progress;
    void *context;
    char *detail;
    size_t detailSize;
    ZipRecoverStats *stats;
} Recovery;

typedef struct {
    uint16_t flags;
    uint16_t method;
    uint32_t crc;
    uint64_t compressedSize;
    uint64_t uncompressedSize;
    size_t dataStart;
    int isDirectory;
    char name[ARCHIVE_MAX_PATH];
} LocalEntry;

/* Where one entry's bytes go. `fd` is -1 for a directory or a skipped entry; a skipped entry's data
   is still decoded, because that is how the walk learns where the next entry starts. */
typedef struct {
    int fd;
    uLong crc;
    int skipped;
    char path[ARCHIVE_MAX_PATH];
    char relative[ARCHIVE_MAX_PATH];
} Output;

typedef enum {
    EntryComplete,
    /* The file ends inside the entry. */
    EntryTruncated,
    /* The data does not decompress. */
    EntryDamaged
} EntryEnd;

/* MARK: - Helpers */

static uint16_t readLE16(const uint8_t *p) {
    return (uint16_t)(p[0] | (p[1] << 8));
}

static uint32_t readLE32(const uint8_t *p) {
    return (uint32_t)p[0] | ((uint32_t)p[1] << 8) | ((uint32_t)p[2] << 16) | ((uint32_t)p[3] << 24);
}

static uint64_t readLE64(const uint8_t *p) {
    return (uint64_t)readLE32(p) | ((uint64_t)readLE32(p + 4) << 32);
}

static ZipRecoverStatus fail(Recovery *r, ZipRecoverStatus status, const char *format, ...) {
    if (r->detail && r->detailSize > 0) {
        va_list args;
        va_start(args, format);
        vsnprintf(r->detail, r->detailSize, format, args);
        va_end(args);
    }
    return status;
}

static ZipRecoverStatus reportProgress(Recovery *r, size_t position) {
    if (r->progress && r->progress(r->context, position, r->size) != 0) {
        return fail(r, ZipRecoverStatusCancelled, "cancelled");
    }
    return ZipRecoverStatusOK;
}

static int isSignature(const Recovery *r, size_t position) {
    if (position + 4 > r->size) return 0;
    uint32_t signature = readLE32(r->data + position);
    return signature == kSigLocalHeader || signature == kSigCentralHeader || signature == kSigEndOfCentral
        || signature == kSigZip64End || signature == kSigZip64Locator || signature == kSigDataDescriptor;
}

/* MARK: - Names */

static int isValidUTF8(const uint8_t *text, size_t length) {
    size_t i = 0;
    while (i < length) {
        uint8_t c = text[i];
        size_t extra;
        if (c < 0x80) extra = 0;
        else if ((c & 0xE0) == 0xC0) extra = 1;
        else if ((c & 0xF0) == 0xE0) extra = 2;
        else if ((c & 0xF8) == 0xF0) extra = 3;
        else return 0;

        if (i + extra >= length) return 0;
        for (size_t k = 1; k <= extra; k++) {
            if ((text[i + k] & 0xC0) != 0x80) return 0;
        }
        i += extra + 1;
    }
    return 1;
}

/* The entry name as UTF-8. Names without the UTF-8 flag are CP437 by the letter of the format, but
   in practice they are ASCII or UTF-8 anyway, so only bytes that are not valid UTF-8 are read as
   Latin-1. Leaves an empty name, which is then skipped, when it does not fit. */
static void decodeName(const uint8_t *raw, size_t length, int flaggedUTF8, char *out, size_t outSize) {
    out[0] = 0;
    if (flaggedUTF8 || isValidUTF8(raw, length)) {
        if (length + 1 > outSize) return;
        memcpy(out, raw, length);
        out[length] = 0;
        return;
    }

    size_t o = 0;
    for (size_t i = 0; i < length; i++) {
        uint8_t c = raw[i];
        if (o + 3 > outSize) {
            out[0] = 0;
            return;
        }
        if (c < 0x80) {
            out[o++] = (char)c;
        } else {
            out[o++] = (char)(0xC0 | (c >> 6));
            out[o++] = (char)(0x80 | (c & 0x3F));
        }
    }
    out[o] = 0;
}

/* MARK: - Headers */

/* Zip64 keeps sizes too large for the header in an extra field, in this order. */
static void applyZip64Extra(LocalEntry *entry, const uint8_t *extra, size_t length) {
    size_t position = 0;
    while (position + 4 <= length) {
        uint16_t identifier = readLE16(extra + position);
        uint16_t size = readLE16(extra + position + 2);
        const uint8_t *field = extra + position + 4;
        if (position + 4 + size > length) return;

        if (identifier == 0x0001) {
            size_t offset = 0;
            if (entry->uncompressedSize == 0xFFFFFFFFu && offset + 8 <= size) {
                entry->uncompressedSize = readLE64(field + offset);
                offset += 8;
            }
            if (entry->compressedSize == 0xFFFFFFFFu && offset + 8 <= size) {
                entry->compressedSize = readLE64(field + offset);
            }
            return;
        }
        position += 4 + (size_t)size;
    }
}

/* Reads the local header at `position`. Returns 0 when the file ends inside it. */
static int readLocalHeader(const Recovery *r, size_t position, LocalEntry *entry) {
    if (position + 30 > r->size) return 0;
    const uint8_t *header = r->data + position;

    size_t nameLength = readLE16(header + 26);
    size_t extraLength = readLE16(header + 28);
    if (position + 30 + nameLength + extraLength > r->size) return 0;

    entry->flags = readLE16(header + 6);
    entry->method = readLE16(header + 8);
    entry->crc = readLE32(header + 14);
    entry->compressedSize = readLE32(header + 18);
    entry->uncompressedSize = readLE32(header + 22);
    applyZip64Extra(entry, header + 30 + nameLength, extraLength);
    entry->dataStart = position + 30 + nameLength + extraLength;

    decodeName(header + 30, nameLength, (entry->flags & kFlagUTF8) != 0, entry->name, sizeof entry->name);
    size_t length = strlen(entry->name);
    entry->isDirectory = length > 0 && (entry->name[length - 1] == '/' || entry->name[length - 1] == '\\');
    return 1;
}

/* Steps over the data descriptor after an entry and takes the checksum from it. A descriptor may or
   may not start with a signature, and carries 32- or 64-bit sizes. */
static size_t skipDataDescriptor(const Recovery *r, size_t position, uint32_t *crc, int *hasCrc) {
    *hasCrc = 0;

    if (position + 4 <= r->size && readLE32(r->data + position) == kSigDataDescriptor) {
        if (position + 16 > r->size) return r->size;
        *crc = readLE32(r->data + position + 4);
        *hasCrc = 1;
        if (!isSignature(r, position + 16) && isSignature(r, position + 24)) return position + 24;
        return position + 16;
    }

    if (position + 12 > r->size) return r->size;
    *crc = readLE32(r->data + position);
    *hasCrc = 1;
    if (!isSignature(r, position + 12) && isSignature(r, position + 20)) return position + 20;
    return position + 12;
}

/* A Stored entry that keeps its size only in the descriptor after its data: the size is the one
   whose descriptor records it as its own distance from the start of the data. */
static int findStoredLength(const Recovery *r, size_t start, uint64_t *length) {
    static const uint8_t signature[4] = { 0x50, 0x4B, 0x07, 0x08 };
    size_t position = start;

    while (position + 16 <= r->size) {
        const uint8_t *hit = memmem(r->data + position, r->size - position, signature, sizeof signature);
        if (!hit) return 0;

        size_t offset = (size_t)(hit - r->data);
        if (offset + 16 <= r->size && readLE32(hit + 8) == (uint32_t)(offset - start)) {
            *length = offset - start;
            return 1;
        }
        position = offset + 1;
    }
    return 0;
}

/* MARK: - Output */

static ZipRecoverStatus openOutput(Recovery *r, const LocalEntry *entry, Output *out) {
    out->fd = -1;
    out->crc = crc32(0L, Z_NULL, 0);
    out->skipped = 0;

    int resolved = ArchiveResolveEntryPath(r->destination, entry->name,
                                           out->path, sizeof out->path,
                                           out->relative, sizeof out->relative);
    if (resolved < 0) return fail(r, ZipRecoverStatusIO, "cannot create the folder for %s", entry->name);
    if (resolved == 0) {
        out->skipped = 1;
        out->relative[0] = 0;
        r->stats->entriesSkipped++;
        return ZipRecoverStatusOK;
    }

    if (entry->isDirectory) {
        if (!ArchiveEnsureDirectory(out->path)) return fail(r, ZipRecoverStatusIO, "cannot create %s", out->relative);
        return ZipRecoverStatusOK;
    }

    out->fd = open(out->path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
    if (out->fd < 0) return fail(r, ZipRecoverStatusIO, "cannot create %s: %s", out->relative, strerror(errno));
    return ZipRecoverStatusOK;
}

static ZipRecoverStatus writeOutput(Recovery *r, Output *out, const uint8_t *data, size_t length) {
    if (out->fd < 0) return ZipRecoverStatusOK;

    while (length > 0) {
        size_t step = length < kWriteChunk ? length : kWriteChunk;
        out->crc = crc32(out->crc, data, (uInt)step);

        const uint8_t *cursor = data;
        size_t remaining = step;
        while (remaining > 0) {
            ssize_t written = write(out->fd, cursor, remaining);
            if (written < 0) {
                if (errno == EINTR) continue;
                return fail(r, ZipRecoverStatusIO, "write failed: %s", strerror(errno));
            }
            cursor += written;
            remaining -= (size_t)written;
        }

        data += step;
        length -= step;
    }
    return ZipRecoverStatusOK;
}

static void closeOutput(Output *out) {
    if (out->fd >= 0) {
        close(out->fd);
        out->fd = -1;
    }
}

/* MARK: - Entry Data */

/* Decodes a raw Deflate stream from `start`, reading no further than `limit`. The stream marks its
   own end, which is how an entry that keeps its sizes in a trailing descriptor is measured. `*end`
   is the first byte after what was consumed. */
static ZipRecoverStatus inflateEntry(Recovery *r, Output *out, size_t start, size_t limit,
                                     size_t *end, EntryEnd *result) {
    z_stream stream;
    memset(&stream, 0, sizeof stream);
    if (inflateInit2(&stream, -MAX_WBITS) != Z_OK) return fail(r, ZipRecoverStatusIO, "zlib did not start");

    uint8_t *buffer = malloc(kOutputChunk);
    if (!buffer) {
        inflateEnd(&stream);
        return fail(r, ZipRecoverStatusIO, "output buffer: out of memory");
    }

    ZipRecoverStatus status = ZipRecoverStatusOK;
    size_t position = start;
    *result = EntryTruncated;

    for (;;) {
        size_t available = limit - position;
        uInt feed = available > (size_t)(1u << 30) ? (uInt)(1u << 30) : (uInt)available;

        stream.next_in = (Bytef *)(uintptr_t)(r->data + position);
        stream.avail_in = feed;
        stream.next_out = buffer;
        stream.avail_out = (uInt)kOutputChunk;

        int ret = inflate(&stream, Z_NO_FLUSH);
        size_t used = feed - stream.avail_in;
        size_t produced = kOutputChunk - stream.avail_out;
        position += used;

        if (produced > 0) {
            status = writeOutput(r, out, buffer, produced);
            if (status != ZipRecoverStatusOK) break;
        }
        status = reportProgress(r, position);
        if (status != ZipRecoverStatusOK) break;

        if (ret == Z_STREAM_END) {
            *result = EntryComplete;
            break;
        }
        if (ret == Z_DATA_ERROR || ret == Z_NEED_DICT || ret == Z_MEM_ERROR) {
            *result = EntryDamaged;
            break;
        }
        if (used == 0 && produced == 0) {
            // No input left and no progress: the file ended inside the stream.
            break;
        }
    }

    free(buffer);
    inflateEnd(&stream);
    *end = position;
    return status;
}

/* Copies a Stored entry of `length` bytes, or as much of it as the file still holds. */
static ZipRecoverStatus copyStored(Recovery *r, Output *out, size_t start, uint64_t length,
                                   size_t *end, EntryEnd *result) {
    size_t available = r->size - start;
    size_t take = length < available ? (size_t)length : available;
    size_t copied = 0;

    while (copied < take) {
        size_t step = take - copied < kWriteChunk ? take - copied : kWriteChunk;
        ZipRecoverStatus status = writeOutput(r, out, r->data + start + copied, step);
        if (status != ZipRecoverStatusOK) return status;
        copied += step;
        status = reportProgress(r, start + copied);
        if (status != ZipRecoverStatusOK) return status;
    }

    *end = start + take;
    *result = take == length ? EntryComplete : EntryTruncated;
    return ZipRecoverStatusOK;
}

/* MARK: - Entry Point */

ZipRecoverStatus ZipRecoverExtract(const char *archivePath,
                                   const char *destinationDirectory,
                                   ZipRecoverProgressCallback progress,
                                   void *context,
                                   char *truncatedEntry,
                                   size_t truncatedEntrySize,
                                   char *detail,
                                   size_t detailSize,
                                   ZipRecoverStats *stats) {
    ZipRecoverStats localStats;
    Recovery r;
    memset(&r, 0, sizeof r);
    r.destination = destinationDirectory;
    r.progress = progress;
    r.context = context;
    r.detail = detail;
    r.detailSize = detailSize;
    r.stats = stats ? stats : &localStats;
    memset(r.stats, 0, sizeof *r.stats);
    if (detail && detailSize > 0) detail[0] = 0;
    if (truncatedEntry && truncatedEntrySize > 0) truncatedEntry[0] = 0;

    int fd = open(archivePath, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return fail(&r, ZipRecoverStatusIO, "cannot open archive: %s", strerror(errno));

    struct stat info;
    if (fstat(fd, &info) != 0) {
        close(fd);
        return fail(&r, ZipRecoverStatusIO, "cannot read archive size: %s", strerror(errno));
    }
    if (info.st_size < 4) {
        close(fd);
        return fail(&r, ZipRecoverStatusNotAZip, "file is too short to be a zip");
    }

    r.size = (size_t)info.st_size;
    void *mapped = mmap(NULL, r.size, PROT_READ, MAP_PRIVATE, fd, 0);
    close(fd);
    if (mapped == MAP_FAILED) return fail(&r, ZipRecoverStatusIO, "cannot map archive: %s", strerror(errno));
    r.data = mapped;

    ZipRecoverStatus status = ZipRecoverStatusOK;
    size_t position = 0;

    if (readLE32(r.data) != kSigLocalHeader) {
        status = fail(&r, ZipRecoverStatusNotAZip, "no zip local header at the start");
        goto done;
    }

    while (status == ZipRecoverStatusOK) {
        // The file ends where an entry or the index should start.
        if (position + 4 > r.size) break;

        uint32_t signature = readLE32(r.data + position);
        if (signature == kSigCentralHeader || signature == kSigEndOfCentral
            || signature == kSigZip64End || signature == kSigZip64Locator) {
            r.stats->reachedIndex = 1;
            break;
        }
        if (signature != kSigLocalHeader) {
            fail(&r, ZipRecoverStatusOK, "unexpected data at offset %zu; stopped there", position);
            break;
        }

        LocalEntry entry;
        if (!readLocalHeader(&r, position, &entry)) break;

        if (entry.flags & kFlagEncrypted) {
            status = fail(&r, ZipRecoverStatusEncrypted, "%s is encrypted", entry.name);
            break;
        }
        if (!entry.isDirectory && entry.method != kMethodStored && entry.method != kMethodDeflate) {
            status = fail(&r, ZipRecoverStatusUnsupported, "method %u in %s", (unsigned)entry.method, entry.name);
            break;
        }

        Output out;
        status = openOutput(&r, &entry, &out);
        if (status != ZipRecoverStatusOK) break;

        int hasDescriptor = (entry.flags & kFlagDataDescriptor) != 0;
        size_t end = entry.dataStart;
        EntryEnd result = EntryComplete;

        if (entry.method == kMethodDeflate) {
            size_t limit = r.size;
            if (!hasDescriptor && entry.compressedSize < r.size - entry.dataStart) {
                limit = entry.dataStart + (size_t)entry.compressedSize;
            }
            status = inflateEntry(&r, &out, entry.dataStart, limit, &end, &result);

            // A header that knows the size, and a stream that has not ended within it, is damage
            // rather than a short file.
            if (result == EntryTruncated && !hasDescriptor && limit < r.size) result = EntryDamaged;
        } else if (!entry.isDirectory || entry.compressedSize > 0) {
            uint64_t length = entry.compressedSize;
            if (hasDescriptor && length == 0 && !findStoredLength(&r, entry.dataStart, &length)) {
                // No descriptor anywhere after the data: the file ends inside it.
                length = (uint64_t)(r.size - entry.dataStart) + 1;
            }
            status = copyStored(&r, &out, entry.dataStart, length, &end, &result);
        }

        closeOutput(&out);
        if (status != ZipRecoverStatusOK) break;

        int isFile = !entry.isDirectory && !out.skipped;

        if (result == EntryTruncated) {
            if (isFile && truncatedEntry && truncatedEntrySize > 0) {
                snprintf(truncatedEntry, truncatedEntrySize, "%s", out.relative);
            }
            break;
        }

        uint32_t expectedCrc = entry.crc;
        int hasCrc = !hasDescriptor;

        if (result == EntryDamaged) {
            if (isFile) {
                unlink(out.path);
                r.stats->entriesDamaged++;
            }
            // Only a header that knows the size says where the next entry starts.
            if (hasDescriptor || entry.compressedSize > r.size - entry.dataStart) break;
            end = entry.dataStart + (size_t)entry.compressedSize;
        } else {
            if (hasDescriptor) {
                end = skipDataDescriptor(&r, end, &expectedCrc, &hasCrc);
            } else if (entry.method == kMethodDeflate) {
                end = entry.dataStart + (size_t)entry.compressedSize;
            }

            if (isFile && hasCrc && (uint32_t)out.crc != expectedCrc) {
                unlink(out.path);
                r.stats->entriesDamaged++;
            } else if (isFile) {
                r.stats->entriesWritten++;
            }
        }

        status = reportProgress(&r, end);
        position = end;
    }

    if (status == ZipRecoverStatusOK && r.stats->entriesWritten == 0
        && !(truncatedEntry && truncatedEntrySize > 0 && truncatedEntry[0])) {
        status = fail(&r, ZipRecoverStatusCorrupt, "no entry could be recovered");
    }

done:
    munmap(mapped, r.size);
    return status;
}
