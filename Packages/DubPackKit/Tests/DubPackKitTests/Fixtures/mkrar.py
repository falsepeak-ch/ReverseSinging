#!/usr/bin/env python3
"""Writes a RAR 5 archive with every entry stored (uncompressed).

There is no free RAR writer, and the format's decoders are what is under test, not its
compressor, so the fixtures are written from the format description instead:
https://www.rarlab.com/technote.htm. Real compressed archives are exercised by the real-pack
harness, which the two RAR packs found in the wild pass.

    mkrar.py out.rar <folder>                 every file under <folder>, names relative to its parent
    mkrar.py out.rar --entry NAME=TEXT ...    literal entries, for names no folder can hold
"""
import os
import sys
import zlib


def vint(value):
    out = bytearray()
    while True:
        byte = value & 0x7F
        value >>= 7
        if value:
            out.append(byte | 0x80)
        else:
            out.append(byte)
            return bytes(out)


def header(kind, flags, body, data_size=None):
    fields = vint(kind) + vint(flags | (0x02 if data_size is not None else 0))
    if data_size is not None:
        fields += vint(data_size)
    fields += body
    sized = vint(len(fields)) + fields
    return zlib.crc32(sized).to_bytes(4, "little") + sized


def file_entry(name, data):
    encoded = name.encode("utf-8")
    body = (
        vint(0x04)                                   # file flags: CRC32 present
        + vint(len(data))                            # unpacked size
        + vint(0o100644)                             # attributes: a Unix mode, regular file
        + zlib.crc32(data).to_bytes(4, "little")
        + vint(0)                                    # compression: version 0, method 0 (store)
        + vint(1)                                    # host OS: Unix
        + vint(len(encoded))
        + encoded
    )
    return header(2, 0, body, data_size=len(data)) + data


def archive(entries):
    out = bytearray(b"Rar!\x1a\x07\x01\x00")
    out += header(1, 0, vint(0))                     # main archive header, no flags
    for name, data in entries:
        out += file_entry(name, data)
    out += header(5, 0, vint(0))                     # end of archive
    return bytes(out)


def main():
    target, *rest = sys.argv[1:]
    entries = []
    if rest and rest[0] == "--entry":
        for spec in (item for item in rest if item != "--entry"):
            name, _, text = spec.partition("=")
            entries.append((name, text.encode("utf-8")))
    else:
        folder = os.path.abspath(rest[0])
        parent = os.path.dirname(folder)
        for root, _, files in sorted(os.walk(folder)):
            for file in sorted(files):
                path = os.path.join(root, file)
                with open(path, "rb") as handle:
                    entries.append((os.path.relpath(path, parent), handle.read()))
    with open(target, "wb") as handle:
        handle.write(archive(entries))


if __name__ == "__main__":
    main()
