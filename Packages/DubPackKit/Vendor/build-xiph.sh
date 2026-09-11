#!/bin/bash
# Builds XiphTheora.xcframework: libogg plus libtheora's decoder, as static libraries for iOS
# devices, the iOS simulator and macOS. The macOS slice is what lets `swift test` exercise the
# transcoder on the Mac without a simulator.
#
# Decoder only: the encoder half of libtheora is stubbed out through encoder_disabled.c, which
# is exactly what that file exists for.
#
#     ./Vendor/build-xiph.sh <dir-with-unpacked-sources> [output.xcframework]
#
# The directory must contain libogg-1.3.5/ and libtheora-1.1.1/, unpacked from
# https://downloads.xiph.org/releases/ and checked against the SHA256SUMS published there.
# Needs only Xcode's clang: no autotools, no Homebrew packages.
set -euo pipefail

ROOT="$1"
HERE="$(cd "$(dirname "$0")" && pwd)"
OUT="${2:-$HERE/XiphTheora.xcframework}"
OGG="$ROOT/libogg-1.3.5"
THEORA="$ROOT/libtheora-1.1.1"

# Keep in step with the platforms in Package.swift.
IOS_MINVER=17.0
MACOS_MINVER=14.0

WORK="$(mktemp -d /tmp/xiph-build.XXXXXX)"
trap 'rm -rf "$WORK"' EXIT
rm -rf "$OUT"

# libogg's config_types.h is normally produced by configure; on Apple platforms the answers
# are fixed, so it is written directly.
mkdir -p "$WORK/include/ogg" "$WORK/include/theora"
cat > "$WORK/include/ogg/config_types.h" <<'HDR'
#ifndef __CONFIG_TYPES_H__
#define __CONFIG_TYPES_H__

#define INCLUDE_INTTYPES_H 1
#define INCLUDE_STDINT_H 1
#define INCLUDE_SYS_TYPES_H 1

#if INCLUDE_INTTYPES_H
#  include <inttypes.h>
#endif
#if INCLUDE_STDINT_H
#  include <stdint.h>
#endif
#if INCLUDE_SYS_TYPES_H
#  include <sys/types.h>
#endif

typedef int16_t ogg_int16_t;
typedef uint16_t ogg_uint16_t;
typedef int32_t ogg_int32_t;
typedef uint32_t ogg_uint32_t;
typedef int64_t ogg_int64_t;
typedef uint64_t ogg_uint64_t;

#endif
HDR

cp "$OGG/include/ogg/ogg.h" "$OGG/include/ogg/os_types.h" "$WORK/include/ogg/"
cp "$THEORA/include/theora/codec.h" "$THEORA/include/theora/theora.h" \
   "$THEORA/include/theora/theoradec.h" "$WORK/include/theora/"

# The headers stay flat under Headers/ because libtheora's own headers include <ogg/ogg.h>.
cat > "$WORK/include/module.modulemap" <<'MOD'
module XiphTheora {
    header "ogg/ogg.h"
    header "theora/codec.h"
    header "theora/theoradec.h"
    header "theora/theora.h"
    export *
}
MOD

OGG_SRC=("$OGG/src/bitwise.c" "$OGG/src/framing.c")
# The decoder file list from libtheora's own Makefile.am, minus the x86 assembly (ARM has no
# equivalent there, so the portable C paths are used on every slice).
THEORA_SRC=(apiwrapper bitpack decapiwrapper decinfo decode dequant fragment \
            huffdec idct info internal quant state encoder_disabled)

build_slice() {
  local sdk="$1" target="$2" name="$3"
  local sysroot; sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
  local objdir="$WORK/obj/$name"; mkdir -p "$objdir"

  local cflags=(-arch "${target%%-*}" -target "$target" -isysroot "$sysroot"
                -O2 -fno-strict-aliasing -Wno-everything
                -I"$WORK/include" -I"$OGG/include" -I"$THEORA/include" -I"$THEORA/lib"
                -DTHEORA_DISABLE_ENCODE=1)

  for src in "${OGG_SRC[@]}"; do
    clang "${cflags[@]}" -c "$src" -o "$objdir/ogg_$(basename "${src%.c}").o"
  done
  for file in "${THEORA_SRC[@]}"; do
    clang "${cflags[@]}" -c "$THEORA/lib/$file.c" -o "$objdir/th_$file.o"
  done

  libtool -static -o "$WORK/lib_$name.a" "$objdir"/*.o 2>/dev/null
}

build_slice iphoneos        "arm64-apple-ios$IOS_MINVER"             ios_device
build_slice iphonesimulator "arm64-apple-ios$IOS_MINVER-simulator"   ios_sim_arm64
build_slice iphonesimulator "x86_64-apple-ios$IOS_MINVER-simulator"  ios_sim_x86_64
build_slice macosx          "arm64-apple-macos$MACOS_MINVER"         mac_arm64
build_slice macosx          "x86_64-apple-macos$MACOS_MINVER"        mac_x86_64

lipo -create "$WORK/lib_ios_sim_arm64.a" "$WORK/lib_ios_sim_x86_64.a" -output "$WORK/lib_ios_sim.a"
lipo -create "$WORK/lib_mac_arm64.a" "$WORK/lib_mac_x86_64.a" -output "$WORK/lib_mac.a"

library_args=()
for slice in ios_device ios_sim mac; do
  mkdir -p "$WORK/stage/$slice"
  cp "$WORK/lib_$slice.a" "$WORK/stage/$slice/libXiphTheora.a"
  cp -R "$WORK/include" "$WORK/stage/$slice/Headers"
  library_args+=(-library "$WORK/stage/$slice/libXiphTheora.a" -headers "$WORK/stage/$slice/Headers")
done

xcodebuild -create-xcframework "${library_args[@]}" -output "$OUT" > /dev/null

echo "built: $OUT"
for slice in ios_device ios_sim mac; do
  lipo -info "$WORK/lib_$slice.a"
done
