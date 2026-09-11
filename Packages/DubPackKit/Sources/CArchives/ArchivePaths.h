/* ArchivePaths.h -- where an archive entry may be written
 *
 * Shared by the 7z and zip extractors, so both refuse the same unsafe names in the same way.
 */

#ifndef ARCHIVE_PATHS_H
#define ARCHIVE_PATHS_H

#include <stddef.h>

#define ARCHIVE_MAX_PATH 4096

/*
 * Rewrites an entry name as a safe relative path: backslashes become slashes, a drive letter and
 * empty or "." components are dropped. Returns 0 for a name that must be skipped: one with a ".."
 * component, one too long for `out`, or one with nothing left.
 */
int ArchiveSanitizePath(const char *name, char *out, size_t outSize);

/* mkdir -p. Returns 0 on failure. `path` is modified while working and restored. */
int ArchiveEnsureDirectory(char *path);

/*
 * Joins `destination` and the sanitized `name` into `path`, puts the relative part in `relative`,
 * and creates the parent directory. Returns 1 for a usable path, 0 for an entry to skip, and -1
 * when the parent directory could not be created.
 */
int ArchiveResolveEntryPath(const char *destination, const char *name,
                            char *path, size_t pathSize,
                            char *relative, size_t relativeSize);

#endif
