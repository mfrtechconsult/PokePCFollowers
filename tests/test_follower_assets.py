import json
import struct
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"


def png_size(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != b"\x89PNG\r\n\x1a\n":
        raise AssertionError(f"{path.name} is not a valid PNG")
    return struct.unpack(">II", header[16:24])


class FollowerAssetTests(unittest.TestCase):
    def test_all_national_dex_sheets_exist(self) -> None:
        missing = [
            dex
            for dex in range(1, 252)
            if not (SPRITES / f"follower_{dex:03d}.png").is_file()
        ]
        self.assertEqual(missing, [])

    def test_all_sheets_match_walker_layout(self) -> None:
        invalid = {}
        for dex in range(1, 252):
            path = SPRITES / f"follower_{dex:03d}.png"
            size = png_size(path)
            if size != (16, 96):
                invalid[dex] = size
        self.assertEqual(invalid, {})

    def test_manifest_advertises_crystal_251_integration(self) -> None:
        manifest = json.loads((ROOT / "manifest.json").read_text(encoding="utf-8"))
        self.assertEqual(manifest["version"], "0.6.0")
        self.assertIn("CRYSTAL_251", manifest["optional_dependencies"])

    def test_installable_archive_matches_runtime_sources(self) -> None:
        with zipfile.ZipFile(ROOT / "mod.zip") as archive:
            names = set(archive.namelist())
            self.assertEqual(archive.read("main.lua"), (ROOT / "main.lua").read_bytes())
            self.assertEqual(
                archive.read("manifest.json"), (ROOT / "manifest.json").read_bytes()
            )
            self.assertFalse(any("Zone.Identifier" in name for name in names))
            self.assertIn("overrides/sprites/pikachu.png", names)
            self.assertTrue(
                all(f"assets/sprites/follower_{dex:03d}.png" in names
                    for dex in range(1, 252))
            )


if __name__ == "__main__":
    unittest.main()
