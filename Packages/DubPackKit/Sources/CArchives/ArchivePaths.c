/* ArchivePaths.c -- where an archive entry may be written */

#include "ArchivePaths.h"

#include <ctype.h>
#include <errno.h>
#include <stdio.h>
#include <string.h>
#include <sys/stat.h>

int ArchiveSanitizePath(const char *name, char *out, size_t outSize) {
    size_t outLen = 0;
    const char *p = name;

    if (outSize == 0) return 0;
    if (isalpha((unsigned char)p[0]) && p[1] == ':') p += 2;

    while (*p) {
        while (*p == '/' || *p == '\\') p++;
        if (!*p) break;

        const char *start = p;
        while (*p && *p != '/' && *p != '\\') p++;
        size_t len = (size_t)(p - start);

        if (len == 1 && start[0] == '.') continue;
        if (len == 2 && start[0] == '.' && start[1] == '.') return 0;

        if (outLen + len + 2 > outSize) return 0;
        if (outLen > 0) out[outLen++] = '/';
        memcpy(out + outLen, start, len);
        outLen += len;
    }

    out[outLen] = 0;
    return outLen > 0;
}

int ArchiveEnsureDirectory(char *path) {
    for (char *p = path + 1; *p; p++) {
        if (*p != '/') continue;
        *p = 0;
        if (mkdir(path, 0755) != 0 && errno != EEXIST) {
            *p = '/';
            return 0;
        }
        *p = '/';
    }
    return mkdir(path, 0755) == 0 || errno == EEXIST;
}

int ArchiveResolveEntryPath(const char *destination, const char *name,
                            char *path, size_t pathSize,
                            char *relative, size_t relativeSize) {
    if (!ArchiveSanitizePath(name, relative, relativeSize)) return 0;

    int written = snprintf(path, pathSize, "%s/%s", destination, relative);
    if (written < 0 || (size_t)written >= pathSize) return 0;

    // The parent has to exist before the entry can.
    char *slash = strrchr(path, '/');
    if (slash && slash != path) {
        *slash = 0;
        int ok = ArchiveEnsureDirectory(path);
        *slash = '/';
        if (!ok) return -1;
    }
    return 1;
}
