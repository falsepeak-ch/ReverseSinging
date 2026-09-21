/* RarExtract.h -- unpacks a .rar archive to a directory
 *
 * A thin, streaming front end over libarchive's RAR and RAR5 readers (BSD-2-Clause, clean-room
 * decoders; not RARLAB's unrar, whose licence is not). Pack authors on Windows reach for WinRAR
 * as often as for 7-Zip, and then rename the result `.zip` to get it past an upload form.
 * Entries are decoded straight to disk a block at a time, so a 300 MB pack never needs 300 MB.
 */

#ifndef RAR_EXTRACT_H
#define RAR_EXTRACT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    RarStatusOK = 0,
    /** The file does not start with a RAR signature. */
    RarStatusNotAnArchive = 1,
    /** Truncated, damaged, or a checksum did not match. */
    RarStatusCorrupt = 2,
    /** Something this decoder does not do: a multi-volume set, an unknown method. */
    RarStatusUnsupported = 3,
    /** The archive's names or contents are encrypted. */
    RarStatusEncrypted = 4,
    RarStatusOutOfMemory = 5,
    /** Reading the archive or writing an output file failed. */
    RarStatusIO = 7,
    /** The progress callback asked to stop. */
    RarStatusCancelled = 8
} RarStatus;

/** What an extraction did, beyond succeeding or failing. */
typedef struct {
    /** Files written. */
    uint32_t entriesWritten;
    /** Entries refused because their path was absolute or climbed out with `..`. */
    uint32_t entriesSkipped;
    /** Entries that failed their checksum or would not decode, and were left out. */
    uint32_t entriesDamaged;
    /** 1 when the archive stopped before its end marker: a download that was cut off. */
    uint32_t truncated;
} RarExtractStats;

/**
 * Called as the archive is consumed. Return 0 to continue, anything else to cancel.
 * A RAR has no index to add sizes up from, so progress is measured in bytes of the archive
 * read, out of the archive's size.
 */
typedef int (*RarProgressCallback)(void *context, uint64_t bytesRead, uint64_t bytesTotal);

/**
 * Unpacks `archivePath` into `destinationDirectory`, which must already exist.
 *
 * Entry paths are sanitised exactly as the 7z and zip extractors do: `..` components, absolute
 * paths and drive letters are refused and those entries skipped rather than failing the
 * archive. Only regular files are written; links and devices are skipped. File times and
 * attributes are not restored.
 *
 * An archive that is damaged or cut off partway still gives up every entry that came out whole:
 * that is RarStatusOK with `entriesDamaged` or `truncated` set, the same bargain the zip
 * recovery makes. It is RarStatusCorrupt only when nothing could be read at all.
 *
 * @param detail        Optional buffer that receives a short English description of a failure
 *                      or of the damage met, for logs. Never shown to users.
 * @param damagedEntry  Optional buffer that receives the pack-relative name of the first entry
 *                      that was damaged or cut through.
 * @param stats         Optional. Filled in whether or not the extraction succeeds.
 */
RarStatus RarExtract(const char *archivePath,
                     const char *destinationDirectory,
                     RarProgressCallback progress,
                     void *context,
                     char *detail,
                     size_t detailSize,
                     char *damagedEntry,
                     size_t damagedEntrySize,
                     RarExtractStats *stats);

/** Whether the first bytes of the file are a RAR 1.5-4.x or RAR 5 signature. Cheap. */
int RarLooksLikeArchive(const char *path);

#ifdef __cplusplus
}
#endif

#endif
