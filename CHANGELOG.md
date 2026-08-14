# Changelog

## 0.8.2 - 2026-08-14

### Changed
- Target Gen1Recomp 0.1.86+ and its per-mod sandbox.
- Route the legacy implementation through a sandbox-safe bootstrap using `mod.assets:path` and `mod:read`.
- Replace the Gen 1 debug-upvalue follower-spawn fallback with a narrow runtime compatibility seam.
- Keep cross-mod integration on public `mod.find(...).exports` surfaces.

### Preserved
- Red, Blue, Yellow and Gold follower support.
- All 251 follower sprites, Pokédex sizing, Crystal 251 integration and voxel compatibility.
- Unique Menu Icons compatibility and saved follower selection.

## 0.8.1 - 2026-08-12

### Changed
- Let Unique Menu Icons own party-menu icons and color handling when both mods are enabled.
- Prevent PartyMenu wrappers from stacking during hot reloads.
