"""Write a Large-Address-Aware copy of the UHC test exe (docs/performance.md, "Levers").

Usage: python -I tools/set_laa.py <UHC-patched age3y.exe> <out.exe>

The copy differs from the input only in IMAGE_FILE_LARGE_ADDRESS_AWARE (0x20) in
FileHeader.Characteristics and in the recomputed PE checksum. On 64-bit Windows this gives the
32-bit game 4 GB of user address space instead of 2 GB. The flag is read when the process
starts, so UHC.dll cannot set it at runtime.

The script refuses any input that is not the known UHC-patched build (docs/binaries.md). The
stock Steam exe is never a valid input. It also refuses to overwrite an existing output.
"""
import hashlib
import pathlib
import struct
import sys

UHC_PATCHED_SHA256 = "d21d0173c3028c190055ae1f14f9a4c282e8e58318975fc5d4cefdeb61a15df9"
IMAGE_FILE_LARGE_ADDRESS_AWARE = 0x20


def pe_checksum(data, checksum_offset):
    """CheckSumMappedFile: 16-bit one's-complement sum of the file, skipping the checksum field,
    plus the file length."""
    total = 0
    for i in range(0, len(data) - 1, 2):
        if i in (checksum_offset, checksum_offset + 2):
            continue
        total += data[i] | data[i + 1] << 8
        total = (total & 0xFFFF) + (total >> 16)
    if len(data) % 2:
        total += data[-1]
        total = (total & 0xFFFF) + (total >> 16)
    total = (total & 0xFFFF) + (total >> 16)
    return (total + len(data)) & 0xFFFFFFFF


def main():
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    source, target = pathlib.Path(sys.argv[1]), pathlib.Path(sys.argv[2])
    data = bytearray(source.read_bytes())
    digest = hashlib.sha256(data).hexdigest()
    if digest != UHC_PATCHED_SHA256:
        sys.exit(f"refusing: {source} has SHA-256 {digest}, expected the UHC-patched build {UHC_PATCHED_SHA256}")
    if target.exists():
        sys.exit(f"refusing: {target} already exists")

    e_lfanew = struct.unpack_from("<I", data, 0x3C)[0]
    characteristics_offset = e_lfanew + 4 + 0x12  # IMAGE_FILE_HEADER.Characteristics
    checksum_offset = e_lfanew + 4 + 0x14 + 0x40  # IMAGE_OPTIONAL_HEADER32.CheckSum
    characteristics = struct.unpack_from("<H", data, characteristics_offset)[0]
    # The UHC patcher leaves a stale checksum (0xB11FCF; the contents give 0xB18410). Windows does
    # not check it for an exe, so it is only reported; the output gets a correct one.
    old_checksum = struct.unpack_from("<I", data, checksum_offset)[0]
    if old_checksum != pe_checksum(data, checksum_offset):
        print(f"note: the input's stored checksum {old_checksum:#x} does not match its contents "
              f"({pe_checksum(data, checksum_offset):#x})")

    struct.pack_into("<H", data, characteristics_offset, characteristics | IMAGE_FILE_LARGE_ADDRESS_AWARE)
    struct.pack_into("<I", data, checksum_offset, pe_checksum(data, checksum_offset))
    target.write_bytes(data)
    print(f"wrote {target}: Characteristics {characteristics:#06x} -> "
          f"{characteristics | IMAGE_FILE_LARGE_ADDRESS_AWARE:#06x}, CheckSum {old_checksum:#x} -> "
          f"{struct.unpack_from('<I', data, checksum_offset)[0]:#x}, "
          f"SHA-256 {hashlib.sha256(data).hexdigest()}")


if __name__ == "__main__":
    main()
