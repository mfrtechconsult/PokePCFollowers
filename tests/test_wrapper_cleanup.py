import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SOURCE = (ROOT / "main.lua").read_text(encoding="utf-8")


class WrapperCleanupTests(unittest.TestCase):
    def test_renderer_restore_checks_wrapper_identity(self) -> None:
        self.assertIn(
            "SpriteRenderer.resolveImage == wrappedResolveImage", SOURCE
        )
        self.assertIn("SpriteRenderer.draw == wrappedSpriteDraw", SOURCE)
        self.assertNotIn(
            "SpriteRenderer.resolveImage == SpriteRenderer.resolveImage", SOURCE
        )
        self.assertNotIn("SpriteRenderer.draw == SpriteRenderer.draw", SOURCE)

    def test_party_menu_wrappers_are_restored_safely(self) -> None:
        self.assertIn("PartyMenu.draw == wrappedPartyMenuDraw", SOURCE)
        self.assertIn("PartyMenu.update == wrappedPartyMenuUpdate", SOURCE)

    def test_yellow_battle_wrapper_is_restored_safely(self) -> None:
        self.assertIn("yellowBattleState.newWild == wrappedNewWild", SOURCE)
        self.assertIn("yellowBattleState.newWild = originalNewWild", SOURCE)

    def test_both_should_spawn_closures_are_restored(self) -> None:
        self.assertIn("vanillaOnMapEnteredShouldSpawn", SOURCE)
        self.assertIn(
            'replaceUpvalue(originalOnMapEntered, "shouldSpawn", '
            "vanillaOnMapEnteredShouldSpawn)",
            SOURCE,
        )


if __name__ == "__main__":
    unittest.main()
