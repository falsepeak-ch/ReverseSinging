#!/bin/bash
# Builds a static XCFramework containing libogg + libtheora's decoder, for iOS.
# Decoder only: the encoder half of libtheora is stubbed out via encoder_disabled.c,
# which is exactly what that file exists for.
set -euo pipefail

ROOT="$1"; OUT="$2"
OGG="$ROOT/libogg-1.3.5"
THEORA="$ROOT/libtheora-1.1.1"
MINVER=17.0

WORK="$ROOT/work"; rm -rf "$WORK" "$OUT"; mkdir -p "$WORK"

# libogg's config_types.h is normally produced by configure; on Apple platforms the
# answers are fixed, so write it directly.
mkdir -p "$WORK/include/ogg"
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
mkdir -p "$WORK/include/theora"
cp "$THEORA/include/theora/codec.h" "$THEORA/include/theora/theora.h" \
   "$THEORA/include/theora/theoradec.h" "$WORK/include/theora/"

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
# The decoder file list from libtheora's own Makefile.am, minus the x86 asm
# (ARM has no equivalent there, so the portable C paths are used).
THEORA_SRC=(apiwrapper bitpack decapiwrapper decinfo decode dequant fragment \
            huffdec idct info internal quant state encoder_disabled)

build_slice() {
  local sdk="$1" target="$2" dir="$3"
  local sysroot; sysroot=$(xcrun --sdk "$sdk" --show-sdk-path)
  local objdir="$WORK/obj/$dir"; mkdir -p "$objdir"

  local cflags=(-arch "${target%%-*}" -target "$target" -isysroot "$sysroot"
                -O2 -fno-strict-aliasing -Wno-everything
                -I"$WORK/include" -I"$OGG/include" -I"$THEORA/include" -I"$THEORA/lib"
                -DTHEORA_DISABLE_ENCODE=1)

  for src in "${OGG_SRC[@]}"; do
    clang "${cflags[@]}" -c "$src" -o "$objdir/ogg_$(basename "${src%.c}").o"
  done
  for name in "${THEORA_SRC[@]}"; do
    clang "${cflags[@]}" -c "$THEORA/lib/$name.c" -o "$objdir/th_$name.o"
  done

  libtool -static -o "$WORK/lib_$dir.a" "$objdir"/*.o 2>/dev/null
}

build_slice iphoneos        "arm64-apple-ios$MINVER"            device
build_slice iphonesimulator "arm64-apple-ios$MINVER-simulator"  sim_arm64
build_slice iphonesimulator "x86_64-apple-ios$MINVER-simulator" sim_x86_64

lipo -create "$WORK/lib_sim_arm64.a" "$WORK/lib_sim_x86_64.a" -output "$WORK/lib_sim.a"

mkdir -p "$WORK/stage/device" "$WORK/stage/sim"
cp "$WORK/lib_device.a" "$WORK/stage/device/libXiphTheora.a"
cp "$WORK/lib_sim.a"    "$WORK/stage/sim/libXiphTheora.a"
cp -R "$WORK/include" "$WORK/stage/device/Headers"
cp -R "$WORK/include" "$WORK/stage/sim/Headers"

xcodebuild -create-xcframework \
  -library "$WORK/stage/device/libXiphTheora.a" -headers "$WORK/stage/device/Headers" \
  -library "$WORK/stage/sim/libXiphTheora.a"    -headers "$WORK/stage/sim/Headers" \
  -output "$OUT" > /dev/null

echo "built: $OUT"
lipo -info "$WORK/lib_device.a" 2>/dev/null | head -1
lipo -info "$WORK/lib_sim.a" 2>/dev/null | head -1
