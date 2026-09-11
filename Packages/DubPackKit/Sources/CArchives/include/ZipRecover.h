/* ZipRecover.h -- unpacks a zip by walking its entries from the front
 *
 * A zip keeps its index, the central directory, at the very end of the file. A download cut off
 * even a few bytes short loses it, and readers that start from the index refuse the whole
 * archive. Every entry also has its own local header in front of its data, which is enough to
 * read everything up to the break. This reads Stored and Deflate entries that way, with or without
 * the data descriptors streaming zip writers put after each entry, and says what it could not.
 */

#ifndef ZIP_RECOVER_H
#define ZIP_RECOVER_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    ZipRecoverStatusOK = 0,
    /** The file does not start with a zip local header. */
    ZipRecoverStatusNotAZip = 1,
    /** Not a single entry could be recovered. */
    ZipRecoverStatusCorrupt = 2,
    /** An entry uses a compression method other than Stored or Deflate. */
    ZipRecoverStatusUnsupported = 3,
    /** An entry is encrypted. */
    ZipRecoverStatusEncrypted = 4,
    /** Reading the archive or writing what it holds failed. */
    ZipRecoverStatusIO = 5,
    /** The progress callback asked to stop. */
    ZipRecoverStatusCancelled = 6
} ZipRecoverStatus;

typedef struct {
    /** Files written whole, with a checksum that matched when one was available. */
    uint32_t entriesWritten;
    /** Entries refused because their path was absolute or climbed out with `..`. */
    uint32_t entriesSkipped;
    /** Entries whose data failed its checksum or would not decompress. Their files are removed. */
    uint32_t entriesDamaged;
    /** 1 when the walk reached the archive's index, 0 when the file ended before it. */
    uint32_t reachedIndex;
} ZipRecoverStats;

/** Called as the archive is read. Return 0 to continue, anything else to cancel. */
typedef int (*ZipRecoverProgressCallback)(void *context, uint64_t bytesRead, uint64_t bytesTotal);

/**
 * Unpacks `archivePath` into `destinationDirectory`, which must already exist.
 *
 * Entry paths are sanitised as the 7z extractor's are: `..` components, absolute paths and drive
 * letters are refused, and those entries skipped.
 *
 * @param truncatedEntry  Receives the relative path of a file the end of the archive cut through,
 *                        written as far as the data goes, or an empty string. Optional.
 * @param detail          Receives a short English description of a failure, for logs. Optional.
 * @param stats           Filled in whether or not the extraction succeeds. Optional.
 */
ZipRecoverStatus ZipRecoverExtract(const char *archivePath,
                                   const char *destinationDirectory,
                                   ZipRecoverProgressCallback progress,
                                   void *context,
                                   char *truncatedEntry,
                                   size_t truncatedEntrySize,
                                   char *detail,
                                   size_t detailSize,
                                   ZipRecoverStats *stats);

#ifdef __cplusplus
}
#endif

#endif
