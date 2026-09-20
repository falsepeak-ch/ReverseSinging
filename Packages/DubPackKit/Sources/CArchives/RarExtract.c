/* RarExtract.c -- see RarExtract.h */

#include "RarExtract.h"
#include "ArchivePaths.h"

#include "libarchive/archive.h"
#include "libarchive/archive_entry.h"

#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>
#include <unistd.h>

/* How much of the archive libarchive reads at a time. */
#define RAR_READ_BLOCK (128 * 1024)

static void SetDetail(char *detail, size_t size, const char *message) {
    if (detail == NULL || size == 0) return;
    snprintf(detail, size, "%s", message != NULL ? message : "unknown");
}

int RarLooksLikeArchive(const char *path) {
    static const unsigned char rar4[7] = { 'R', 'a', 'r', '!', 0x1A, 0x07, 0x00 };
    static const unsigned char rar5[8] = { 'R', 'a', 'r', '!', 0x1A, 0x07, 0x01, 0x00 };
    unsigned char head[8] = { 0 };

    int fd = open(path, O_RDONLY | O_CLOEXEC);
    if (fd < 0) return 0;
    ssize_t got = read(fd, head, sizeof head);
    close(fd);

    if (got >= (ssize_t)sizeof rar5 && memcmp(head, rar5, sizeof rar5) == 0) return 1;
    return got >= (ssize_t)sizeof rar4 && memcmp(head, rar4, sizeof rar4) == 0;
}

/* libarchive reports nearly everything as ARCHIVE_FATAL with a message. The message is the only
 * way to tell a password from a bad checksum, so it is what gets read. */
static RarStatus ClassifyFailure(struct archive *archive) {
    const char *message = archive_error_string(archive);
    int code = archive_errno(archive);

    if (code == ENOMEM) return RarStatusOutOfMemory;
    if (message != NULL) {
        if (strstr(message, "ncrypt") != NULL || strstr(message, "assphrase") != NULL) return RarStatusEncrypted;
        if (strstr(message, "ulti") != NULL && strstr(message, "olume") != NULL) return RarStatusUnsupported;
        if (strstr(message, "nsupported") != NULL || strstr(message, "not supported") != NULL) return RarStatusUnsupported;
    }
    return RarStatusCorrupt;
}

static int WriteAll(int fd, const void *buffer, size_t size) {
    const unsigned char *bytes = buffer;
    while (size > 0) {
        ssize_t wrote = write(fd, bytes, size);
        if (wrote < 0) {
            if (errno == EINTR) continue;
            return 0;
        }
        bytes += wrote;
        size -= (size_t)wrote;
    }
    return 1;
}

RarStatus RarExtract(const char *archivePath,
                     const char *destinationDirectory,
                     RarProgressCallback progress,
                     void *context,
                     char *detail,
                     size_t detailSize,
                     char *damagedEntry,
                     size_t damagedEntrySize,
                     RarExtractStats *stats) {
    RarExtractStats local = { 0, 0, 0, 0 };
    RarStatus status = RarStatusOK;
    struct archive *archive = NULL;
    int outputFd = -1;

    if (detail != NULL && detailSize > 0) detail[0] = '\0';
    if (damagedEntry != NULL && damagedEntrySize > 0) damagedEntry[0] = '\0';

    if (!RarLooksLikeArchive(archivePath)) {
        status = RarStatusNotAnArchive;
        goto done;
    }

    struct stat archiveStat;
    uint64_t archiveSize = stat(archivePath, &archiveStat) == 0 ? (uint64_t)archiveStat.st_size : 0;

    archive = archive_read_new();
    if (archive == NULL) {
        status = RarStatusOutOfMemory;
        goto done;
    }
    archive_read_support_format_rar(archive);
    archive_read_support_format_rar5(archive);

    if (archive_read_open_filename(archive, archivePath, RAR_READ_BLOCK) != ARCHIVE_OK) {
        SetDetail(detail, detailSize, archive_error_string(archive));
        /* The signature was checked above, so a file libarchive will not open is one it could
         * not read, or one whose headers are damaged past the signature. */
        int code = archive_errno(archive);
        status = code > 0 && code != EILSEQ && code != EFTYPE ? RarStatusIO : RarStatusCorrupt;
        goto done;
    }

    for (;;) {
        struct archive_entry *entry = NULL;
        int header = archive_read_next_header(archive, &entry);
        if (header == ARCHIVE_EOF) break;
        if (header < ARCHIVE_WARN) {
            SetDetail(detail, detailSize, archive_error_string(archive));
            status = ClassifyFailure(archive);
            /* A header that will not read is where a cut-off download ends. Everything
             * before it came out whole, and is kept. */
            if (status == RarStatusCorrupt) {
                local.truncated = 1;
                break;
            }
            goto done;
        }

        if (archive_entry_is_encrypted(entry)) {
            SetDetail(detail, detailSize, "encrypted entry");
            status = RarStatusEncrypted;
            goto done;
        }

        /* Directories come into being with the files inside them; links and devices have no
         * business in a pack. An entry that does not say what it is (archives written on
         * Windows carry DOS attributes, not a Unix mode) is a file. */
        __LA_MODE_T type = archive_entry_filetype(entry);
        if (type != AE_IFREG && type != 0) continue;

        const char *name = archive_entry_pathname_utf8(entry);
        if (name == NULL) name = archive_entry_pathname(entry);
        if (name == NULL) {
            local.entriesSkipped++;
            continue;
        }

        char path[ARCHIVE_MAX_PATH];
        char relative[ARCHIVE_MAX_PATH];
        int resolved = ArchiveResolveEntryPath(destinationDirectory, name, path, sizeof path, relative, sizeof relative);
        if (resolved == 0) {
            local.entriesSkipped++;
            continue;
        }
        if (resolved < 0) {
            SetDetail(detail, detailSize, "could not create a folder");
            status = RarStatusIO;
            goto done;
        }

        outputFd = open(path, O_WRONLY | O_CREAT | O_TRUNC | O_CLOEXEC, 0644);
        if (outputFd < 0) {
            SetDetail(detail, detailSize, strerror(errno));
            status = RarStatusIO;
            goto done;
        }

        int entryFailed = 0;
        for (;;) {
            const void *block = NULL;
            size_t size = 0;
            la_int64_t offset = 0;
            int got = archive_read_data_block(archive, &block, &size, &offset);
            if (got == ARCHIVE_EOF) break;
            if (got < ARCHIVE_WARN) {
                SetDetail(detail, detailSize, archive_error_string(archive));
                RarStatus failure = ClassifyFailure(archive);
                close(outputFd);
                outputFd = -1;
                unlink(path);
                if (failure != RarStatusCorrupt) {
                    status = failure;
                    goto done;
                }

                /* One bad entry costs that entry. What matters is whether the reader can go
                 * on: after a fatal error it cannot, and that is the end of the archive. */
                local.entriesDamaged++;
                if (damagedEntry != NULL && damagedEntrySize > 0 && damagedEntry[0] == '\0') {
                    snprintf(damagedEntry, damagedEntrySize, "%s", relative);
                }
                if (got == ARCHIVE_FATAL) {
                    local.truncated = 1;
                    goto finished;
                }
                entryFailed = 1;
                break;
            }

            /* Blocks arrive in order, but a sparse entry may skip ahead. */
            if (lseek(outputFd, (off_t)offset, SEEK_SET) < 0 || !WriteAll(outputFd, block, size)) {
                SetDetail(detail, detailSize, strerror(errno));
                status = RarStatusIO;
                goto done;
            }

            if (progress != NULL) {
                la_int64_t consumed = archive_filter_bytes(archive, -1);
                if (progress(context, consumed > 0 ? (uint64_t)consumed : 0, archiveSize) != 0) {
                    status = RarStatusCancelled;
                    close(outputFd);
                    outputFd = -1;
                    unlink(path);
                    goto done;
                }
            }
        }

        if (entryFailed) continue;

        close(outputFd);
        outputFd = -1;
        local.entriesWritten++;
    }

finished:
    /* Damage that left nothing at all is a corrupt archive, not a recovered one. So is a
     * signature with nothing readable behind it, which libarchive takes for an empty archive. */
    if (local.entriesWritten == 0 && local.entriesSkipped == 0) {
        if (detail != NULL && detailSize > 0 && detail[0] == '\0') SetDetail(detail, detailSize, "no entries");
        status = RarStatusCorrupt;
        goto done;
    }

    if (progress != NULL) progress(context, archiveSize, archiveSize);

done:
    if (outputFd >= 0) close(outputFd);
    if (archive != NULL) archive_read_free(archive);
    if (stats != NULL) *stats = local;
    return status;
}
