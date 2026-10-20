from __future__ import annotations

import argparse
import importlib.machinery
import importlib.util
import unittest
from pathlib import Path


PROJECT = Path(__file__).resolve().parents[1]
LOADER = importlib.machinery.SourceFileLoader("hatch_installer", str(PROJECT / "install"))
SPEC = importlib.util.spec_from_loader(LOADER.name, LOADER)
assert SPEC is not None
installer = importlib.util.module_from_spec(SPEC)
LOADER.exec_module(installer)


class InstallerValidationTests(unittest.TestCase):
    def test_accepts_normal_signing_values(self) -> None:
        self.assertEqual(installer.validate_team_id("A1B2C3D4E5"), "A1B2C3D4E5")
        self.assertEqual(
            installer.validate_bundle_id("com.example.rose-control"),
            "com.example.rose-control",
        )
        self.assertEqual(
            installer.validate_relay_url("https://rose-relay.local/rose-stream.mp3"),
            "https://rose-relay.local/rose-stream.mp3",
        )

    def test_rejects_malformed_signing_values(self) -> None:
        for validator, value in (
            (installer.validate_team_id, "short"),
            (installer.validate_bundle_id, "rose control"),
            (installer.validate_relay_url, "file:///tmp/audio"),
        ):
            with self.subTest(value=value):
                with self.assertRaises(argparse.ArgumentTypeError):
                    validator(value)

    def test_dry_run_parser_has_no_device_values(self) -> None:
        arguments = installer.parser().parse_args(["--dry-run"])
        self.assertTrue(arguments.dry_run)
        self.assertIsNone(arguments.device_id)


if __name__ == "__main__":
    unittest.main()
