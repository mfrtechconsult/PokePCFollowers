import hashlib
import json
import struct
import unittest
import zipfile
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SPRITES = ROOT / "assets" / "sprites"
GSC_REGRESSION_HASHES = {
    245: "eb4373253f4f5ec9f84b0bd07b7b638bfcfad4b5bec58cb2026e89284a2353d2",
    249: "c6687fc94b71faa8cbf060025b3cba5dd58909a5fd56f0d1aa3db02038c69ee5",
    250: "aecaccae60e21f82a017b93e2b184ab54b2e2948b47b95865982bdf79412e4b5",
}


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
        self.assertEqual(manifest["version"], "0.6.1")
        self.assertIn("CRYSTAL_251", manifest["optional_dependencies"])

    def test_reported_johto_sprites_use_native_gsc_sheets(self) -> None:
        for dex, expected in GSC_REGRESSION_HASHES.items():
            actual = hashlib.sha256(
                (SPRITES / f"follower_{dex:03d}.png").read_bytes()
            ).hexdigest()
            self.assertEqual(actual, expected, f"unexpected sprite source for #{dex}")

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
