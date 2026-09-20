/* config.h -- libarchive's build configuration for Apple platforms, written by hand.
 *
 * Only what the RAR readers and the core they sit on need. No compression libraries, no
 * iconv, no crypto, no ACLs or extended attributes: archives are read, never written, and
 * nothing but file names and file contents is taken from them.
 */
#ifndef DUBPACKKIT_LIBARCHIVE_CONFIG_H
#define DUBPACKKIT_LIBARCHIVE_CONFIG_H

#define __LIBARCHIVE_CONFIG_H_INCLUDED 1

/* A debug build of the app defines DEBUG for every target, and the RAR 5 reader takes that as
 * leave to print each checksum it verifies to standard error. */
#undef DEBUG

#define HAVE_CTYPE_H 1
#define HAVE_ERRNO_H 1
#define HAVE_FCNTL_H 1
#define HAVE_INTTYPES_H 1
#define HAVE_LIMITS_H 1
#define HAVE_LOCALE_H 1
#define HAVE_STDARG_H 1
#define HAVE_STDINT_H 1
#define HAVE_STDLIB_H 1
#define HAVE_STRING_H 1
#define HAVE_STRINGS_H 1
#define HAVE_SYS_STAT_H 1
#define HAVE_SYS_TIME_H 1
#define HAVE_SYS_TYPES_H 1
#define HAVE_TIME_H 1
#define HAVE_UNISTD_H 1
#define HAVE_WCHAR_H 1
#define HAVE_WCTYPE_H 1
#define HAVE_PTHREAD_H 1

#define HAVE_DECL_INT32_MAX 1
#define HAVE_DECL_INT32_MIN 1
#define HAVE_DECL_INT64_MAX 1
#define HAVE_DECL_INT64_MIN 1
#define HAVE_DECL_INTMAX_MAX 1
#define HAVE_DECL_INTMAX_MIN 1
#define HAVE_DECL_SIZE_MAX 1
#define HAVE_DECL_UINT32_MAX 1
#define HAVE_DECL_UINT64_MAX 1
#define HAVE_DECL_UINTMAX_MAX 1
#define HAVE_DECL_STRERROR_R 1

#define HAVE_INTMAX_T 1
#define HAVE_UINTMAX_T 1
#define HAVE_LONG_LONG_INT 1
#define HAVE_UNSIGNED_LONG_LONG 1
#define HAVE_UNSIGNED_LONG_LONG_INT 1
#define HAVE_WCHAR_T 1
#define SIZEOF_WCHAR_T 4

#define HAVE_FSTAT 1
#define HAVE_LSTAT 1
#define HAVE_FSEEKO 1
#define HAVE_GMTIME_R 1
#define HAVE_LOCALTIME_R 1
#define HAVE_MEMMOVE 1
#define HAVE_MEMSET 1
#define HAVE_STRCHR 1
#define HAVE_STRDUP 1
#define HAVE_STRERROR 1
#define HAVE_STRERROR_R 1
#define HAVE_STRNLEN 1
#define HAVE_STRRCHR 1
#define HAVE_TIMEGM 1
#define HAVE_VPRINTF 1
#define HAVE_WCRTOMB 1
#define HAVE_WCSCPY 1
#define HAVE_WCSLEN 1
#define HAVE_WCTOMB 1
#define HAVE_WMEMCMP 1
#define HAVE_WMEMCPY 1
#define HAVE_WMEMMOVE 1
#define HAVE_MBRTOWC 1
#define HAVE_ARC4RANDOM_BUF 1
#define HAVE_EILSEQ 1
#define HAVE_EFTYPE 1

#define HAVE_STRUCT_STAT_ST_BLKSIZE 1
#define HAVE_STRUCT_STAT_ST_FLAGS 1
#define HAVE_STRUCT_STAT_ST_MTIMESPEC_TV_NSEC 1
#define HAVE_STRUCT_STAT_ST_BIRTHTIME 1
#define HAVE_STRUCT_STAT_ST_BIRTHTIMESPEC_TV_NSEC 1
#define HAVE_STRUCT_TM_TM_GMTOFF 1

#define STDC_HEADERS 1
#define TIME_WITH_SYS_TIME 1

#define LIBARCHIVE_VERSION_STRING "3.8.9"
#define LIBARCHIVE_VERSION_NUMBER "3008009"
#define VERSION "3.8.9"
#define PACKAGE_VERSION "3.8.9"
#define __LIBARCHIVE_BUILD 1

#endif
