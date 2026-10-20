#!/usr/bin/env python3
"""Build and apply the local-RDL BLE dispatcher to Restore 2 firmware 10.711.644."""

from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path
import struct
import subprocess
import tempfile


SOURCE_SHA256 = "7339e11f8193db6180443b37a6a09f68c427404a931f28b54ff00380d90e23aa"
CALLSITE_ADDRESS = 0x4010C099
LITERAL_ADDRESS = 0x40123E00
DISPATCHER_ADDRESS = 0x40123E14
CLOUD_TASK_CREATE_ADDRESS = 0x4013CCEC
TGA_COMMAND_NAME_ADDRESS = 0x3F49C188
GNVS_COMMAND_NAME_ADDRESS = 0x3F49C1A8

EXPECTED_CALLSITE = bytes.fromhex("a59c28")
EXPECTED_LITERAL_AREA = bytes.fromhex("364100b2a001a2a000659be1")
EXPECTED_DISPATCHER_AREA = bytes.fromhex(
    "3681000c08894189418941ad02303074ac42b65322b16db5c2c1108184b2e00800"
    "261a3181f1afe00800b166b5dd"
)
EXPECTED_CLOUD_TASK_CREATE = bytes.fromhex("36610082a0")

EXPECTED_CALLSITE_PATCH = bytes.fromhex("a5d717")
EXPECTED_LITERAL_PATCH = bytes.fromhex("7b225f6150491340644a1340")
EXPECTED_DISPATCHER_PATCH = bytes.fromhex(
    "364100b64319880291f9ff979811ad02bd030c0c0c0d81f6ffe008000c121df0"
    "ad02bd0381f4ffe008002d0a1df0"
)
EXPECTED_CLOUD_TASK_CREATE_PATCH = bytes.fromhex("3661001df0")


class ESP32AppImage:
    def __init__(self, data: bytes):
        self.data = bytearray(data)
        if len(self.data) < 24 or self.data[0] != 0xE9:
            raise ValueError("not an ESP32 app image")

        cursor = 24
        self.segments: list[tuple[int, int, int]] = []
        for _ in range(self.data[1]):
            if cursor + 8 > len(self.data):
                raise ValueError("truncated segment header")
            address, length = struct.unpack_from("<II", self.data, cursor)
            cursor += 8
            if cursor + length > len(self.data):
                raise ValueError("truncated segment data")
            self.segments.append((address, length, cursor))
            cursor += length

        self.hash_start = (cursor + 16) & ~15
        self.checksum_offset = self.hash_start - 1
        self.hash_appended = self.data[23] == 1
        minimum = self.hash_start + (32 if self.hash_appended else 0)
        if len(self.data) != minimum:
            raise ValueError("unexpected ESP32 image length")

    def read(self, address: int, length: int) -> bytes:
        offset = self._offset(address, length)
        return bytes(self.data[offset : offset + length])

    def replace(self, address: int, replacement: bytes, *, expected: bytes) -> None:
        if len(replacement) != len(expected):
            raise ValueError("replacement length differs from expected source length")
        offset = self._offset(address, len(expected))
        actual = bytes(self.data[offset : offset + len(expected)])
        if actual != expected:
            raise ValueError(
                f"expected source bytes at 0x{address:08x} do not match: "
                f"wanted {expected.hex()}, found {actual.hex()}"
            )
        self.data[offset : offset + len(replacement)] = replacement

    @property
    def checksum_valid(self) -> bool:
        return self.data[self.checksum_offset] == self._checksum()

    @property
    def hash_valid(self) -> bool:
        if not self.hash_appended:
            return True
        expected = hashlib.sha256(self.data[: self.hash_start]).digest()
        return bytes(self.data[self.hash_start : self.hash_start + 32]) == expected

    def finalize(self) -> bytes:
        self.data[self.checksum_offset] = self._checksum()
        if self.hash_appended:
            digest = hashlib.sha256(self.data[: self.hash_start]).digest()
            self.data[self.hash_start : self.hash_start + 32] = digest
        return bytes(self.data)

    def _checksum(self) -> int:
        value = 0xEF
        for _, length, offset in self.segments:
            for byte in self.data[offset : offset + length]:
                value ^= byte
        return value

    def _offset(self, address: int, length: int) -> int:
        for load_address, segment_length, file_offset in self.segments:
            relative = address - load_address
            if relative >= 0 and relative + length <= segment_length:
                return file_offset + relative
        raise ValueError(f"address 0x{address:08x} is outside all image segments")


def disable_cloud_task(image: ESP32AppImage) -> None:
    """Prevent the Hatch IoT task from being created while leaving Wi-Fi intact."""
    image.replace(
        CLOUD_TASK_CREATE_ADDRESS,
        EXPECTED_CLOUD_TASK_CREATE_PATCH,
        expected=EXPECTED_CLOUD_TASK_CREATE,
    )


def tombstone_overwritten_handlers(image: ESP32AppImage) -> None:
    """Make factory commands whose handlers became patch space unreachable."""
    image.replace(TGA_COMMAND_NAME_ADDRESS, b"X", expected=b"T")
    image.replace(GNVS_COMMAND_NAME_ADDRESS, b"X", expected=b"G")


def run(command: list[str], *, environment: dict[str, str]) -> None:
    subprocess.run(command, check=True, env=environment, capture_output=True, text=True)


def extract_section(objcopy: Path, elf: Path, section: str, output: Path, environment: dict[str, str]) -> bytes:
    run(
        [str(objcopy), "-O", "binary", "--only-section", section, str(elf), str(output)],
        environment=environment,
    )
    return output.read_bytes()


def assemble(source_dir: Path, toolchain: Path, work: Path) -> tuple[bytes, bytes, bytes, bytes]:
    bin_dir = toolchain / "bin"
    gcc = bin_dir / "xtensa-esp-elf-gcc"
    linker = bin_dir / "xtensa-esp-elf-ld"
    objcopy = bin_dir / "xtensa-esp-elf-objcopy"
    for tool in (gcc, linker, objcopy):
        if not tool.is_file():
            raise FileNotFoundError(tool)

    environment = os.environ.copy()
    environment["XTENSA_GNU_CONFIG"] = str(toolchain / "lib" / "xtensa_esp32.so")
    dispatcher_object = work / "dispatcher.o"
    dispatcher_elf = work / "dispatcher.elf"
    callsite_object = work / "callsite.o"
    callsite_elf = work / "callsite.elf"
    cloud_object = work / "disable_cloud.o"
    cloud_elf = work / "disable_cloud.elf"

    run(
        [str(gcc), "-c", "-Os", "-mlongcalls", "-ffreestanding", "-nostdlib", str(source_dir / "dispatcher.S"), "-o", str(dispatcher_object)],
        environment=environment,
    )
    run([str(linker), "-T", str(source_dir / "dispatcher.ld"), str(dispatcher_object), "-o", str(dispatcher_elf)], environment=environment)
    run(
        [str(gcc), "-c", "-Os", "-ffreestanding", "-nostdlib", str(source_dir / "callsite.S"), "-o", str(callsite_object)],
        environment=environment,
    )
    run([str(linker), "-T", str(source_dir / "callsite.ld"), str(callsite_object), "-o", str(callsite_elf)], environment=environment)
    run(
        [str(gcc), "-c", "-Os", "-ffreestanding", "-nostdlib", str(source_dir / "disable_cloud.S"), "-o", str(cloud_object)],
        environment=environment,
    )
    run([str(linker), "-T", str(source_dir / "disable_cloud.ld"), str(cloud_object), "-o", str(cloud_elf)], environment=environment)

    literal = extract_section(objcopy, dispatcher_elf, ".literal", work / "literal.bin", environment)
    dispatcher = extract_section(objcopy, dispatcher_elf, ".text", work / "dispatcher.bin", environment)
    callsite = extract_section(objcopy, callsite_elf, ".text", work / "callsite.bin", environment)
    cloud = extract_section(objcopy, cloud_elf, ".text", work / "disable_cloud.bin", environment)
    if (literal, dispatcher, callsite, cloud) != (
        EXPECTED_LITERAL_PATCH,
        EXPECTED_DISPATCHER_PATCH,
        EXPECTED_CALLSITE_PATCH,
        EXPECTED_CLOUD_TASK_CREATE_PATCH,
    ):
        raise ValueError("assembler output differs from the reviewed machine-code patch")
    return literal, dispatcher, callsite, cloud


def build(source: Path, output: Path, toolchain: Path) -> str:
    source_data = source.read_bytes()
    source_hash = hashlib.sha256(source_data).hexdigest()
    if source_hash != SOURCE_SHA256:
        raise ValueError(f"unsupported source firmware SHA-256: {source_hash}")

    source_dir = Path(__file__).resolve().parent
    with tempfile.TemporaryDirectory(prefix="aster-rdl-") as directory:
        literal, dispatcher, callsite, cloud = assemble(source_dir, toolchain, Path(directory))

    image = ESP32AppImage(source_data)
    if not image.checksum_valid or not image.hash_valid:
        raise ValueError("source firmware checksum or appended hash is invalid")
    image.replace(CALLSITE_ADDRESS, callsite, expected=EXPECTED_CALLSITE)
    image.replace(LITERAL_ADDRESS, literal, expected=EXPECTED_LITERAL_AREA)
    image.replace(DISPATCHER_ADDRESS, dispatcher, expected=EXPECTED_DISPATCHER_AREA)
    if cloud != EXPECTED_CLOUD_TASK_CREATE_PATCH:
        raise ValueError("cloud-task patch differs from the reviewed machine code")
    disable_cloud_task(image)
    tombstone_overwritten_handlers(image)
    patched = image.finalize()

    verified = ESP32AppImage(patched)
    if not verified.checksum_valid or not verified.hash_valid:
        raise ValueError("patched firmware failed checksum verification")
    if verified.read(CALLSITE_ADDRESS, len(callsite)) != callsite:
        raise ValueError("patched callsite did not survive verification")

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.with_suffix(output.suffix + ".tmp")
    temporary.write_bytes(patched)
    os.chmod(temporary, 0o600)
    temporary.replace(output)
    return hashlib.sha256(patched).hexdigest()


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--toolchain", type=Path, required=True)
    arguments = parser.parse_args()
    digest = build(arguments.input, arguments.output, arguments.toolchain)
    print(f"wrote {arguments.output}")
    print(f"sha256 {digest}")


if __name__ == "__main__":
    main()
