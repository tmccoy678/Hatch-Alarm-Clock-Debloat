import hashlib
import struct
import unittest

from firmware.patch_local_rdl.build_patch import (
    ESP32AppImage,
    disable_cloud_task,
    tombstone_overwritten_handlers,
)


def fixture_image() -> bytes:
    header = bytearray(24)
    header[0] = 0xE9
    header[1] = 1
    header[23] = 1
    segment = bytes(range(32))
    body = bytearray(header)
    body.extend(struct.pack("<II", 0x40100000, len(segment)))
    body.extend(segment)
    hash_start = (len(body) + 16) & ~15
    body.extend(b"\0" * (hash_start - len(body)))
    body[hash_start - 1] = 0xEF ^ _xor(segment)
    body.extend(hashlib.sha256(body).digest())
    return bytes(body)


def fixture_image_at(address: int, segment: bytes) -> bytes:
    header = bytearray(24)
    header[0] = 0xE9
    header[1] = 1
    header[23] = 1
    body = bytearray(header)
    body.extend(struct.pack("<II", address, len(segment)))
    body.extend(segment)
    hash_start = (len(body) + 16) & ~15
    body.extend(b"\0" * (hash_start - len(body)))
    body[hash_start - 1] = 0xEF ^ _xor(segment)
    body.extend(hashlib.sha256(body).digest())
    return bytes(body)


def _xor(data: bytes) -> int:
    value = 0
    for byte in data:
        value ^= byte
    return value


class ESP32AppImageTests(unittest.TestCase):
    def test_address_patch_recomputes_checksum_and_hash(self):
        image = ESP32AppImage(fixture_image())
        image.replace(0x40100004, b"ASTER", expected=bytes(range(4, 9)))

        output = image.finalize()
        verified = ESP32AppImage(output)

        self.assertEqual(verified.read(0x40100004, 5), b"ASTER")
        self.assertTrue(verified.checksum_valid)
        self.assertTrue(verified.hash_valid)

    def test_patch_rejects_an_unexpected_source_build(self):
        image = ESP32AppImage(fixture_image())

        with self.assertRaisesRegex(ValueError, "expected source bytes"):
            image.replace(0x40100004, b"ASTER", expected=b"wrong")

    def test_cloud_task_creation_is_replaced_with_a_clean_return(self):
        source = bytes.fromhex("36610082a001826103")
        image = ESP32AppImage(fixture_image_at(0x4013CCEC, source))

        disable_cloud_task(image)

        self.assertEqual(image.read(0x4013CCEC, 5), bytes.fromhex("3661001df0"))

    def test_overwritten_factory_handlers_are_no_longer_reachable_by_name(self):
        source = bytearray(36)
        source[0] = ord("T")
        source[32] = ord("G")
        image = ESP32AppImage(fixture_image_at(0x3F49C188, bytes(source)))

        tombstone_overwritten_handlers(image)

        self.assertEqual(image.read(0x3F49C188, 1), b"X")
        self.assertEqual(image.read(0x3F49C1A8, 1), b"X")


if __name__ == "__main__":
    unittest.main()
