/* SevenZipExtract.h -- unpacks a .7z archive to a directory
 *
 * A thin, streaming front end over the LZMA SDK's 7z decoder (public domain, Igor Pavlov).
 * The SDK only offers whole-solid-block extraction into memory, which on a phone means a
 * 400 MB pack is a 400 MB allocation. This wrapper decodes the common single-coder blocks
 * (Copy, LZMA, LZMA2, Deflate, BZip2) straight to disk in small chunks, and falls back to
 * the SDK's in-memory path for everything else (PPMd, BCJ/BCJ2/Delta filtered blocks).
 */

#ifndef SEVENZIP_EXTRACT_H
#define SEVENZIP_EXTRACT_H

#include <stddef.h>
#include <stdint.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef enum {
    SevenZipStatusOK = 0,
    /** The file does not start with the 7z signature. */
    SevenZipStatusNotAnArchive = 1,
    /** Truncated, damaged, or a CRC did not match. */
    SevenZipStatusCorrupt = 2,
    /** A compression method this decoder does not have, or encrypted headers. */
    SevenZipStatusUnsupported = 3,
    /** The archive's contents are AES-encrypted. */
    SevenZipStatusEncrypted = 4,
    SevenZipStatusOutOfMemory = 5,
    /** A block that can only be decoded in memory is bigger than `memoryLimit`. */
    SevenZipStatusTooLarge = 6,
    /** Reading the archive or writing an output file failed. */
    SevenZipStatusIO = 7,
    /** The progress callback asked to stop. */
    SevenZipStatusCancelled = 8
} SevenZipStatus;

/** What an extraction did, beyond succeeding or failing. */
typedef struct {
    /** Files and directories written. */
    uint32_t entriesWritten;
    /** Entries refused because their path was absolute or climbed out with `..`. */
    uint32_t entriesSkipped;
} SevenZipExtractStats;

/**
 * Called as bytes land on disk. Return 0 to continue, anything else to cancel.
 * `bytesTotal` is the sum of every entry's unpacked size.
 */
typedef int (*SevenZipProgressCallback)(void *context, uint64_t bytesWritten, uint64_t bytesTotal);

/**
 * Unpacks `archivePath` into `destinationDirectory`, which must already exist.
 *
 * Entry paths are sanitised: `..` components, absolute paths and drive letters are refused
 * and those entries are skipped rather than failing the archive. Directories are created as
 * needed. File times and attributes are not restored.
 *
 * @param memoryLimit  Largest solid block the in-memory fallback may allocate, in bytes.
 *                     0 means no limit. Streamed blocks are not subject to it.
 * @param progress     Optional. See SevenZipProgressCallback.
 * @param detail       Optional buffer that receives a short English description of a
 *                     failure, for logs. Never shown to users.
 * @param stats        Optional. Filled in whether or not the extraction succeeds.
 * @return SevenZipStatusOK on success.
 */
SevenZipStatus SevenZipExtract(const char *archivePath,
                               const char *destinationDirectory,
                               size_t memoryLimit,
                               SevenZipProgressCallback progress,
                               void *context,
                               char *detail,
                               size_t detailSize,
                               SevenZipExtractStats *stats);

/** Whether the first bytes of the file are the 7z signature. Cheap; reads six bytes. */
int SevenZipLooksLikeArchive(const char *path);

#ifdef __cplusplus
}
#endif

#endif
