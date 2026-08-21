# Changelog

## 0.9.0-rc.1 - 2026-08-21

### Added
- Add Pokémon Silver to the documented and validated Gen2 target set.
- Export the active game version/generation and the maintained repository id through the sandbox provider surface.
- Add an explicit Gen2 follower-facade guard so Gold/Silver cannot silently load without `setShouldSpawn`.
- Add CI against the current Gen1Recomp `dev` branch, including Silver target and Gen2 facade checks.

### Changed
- Raise the supported stable engine baseline from Gen1Recomp 0.1.86 to 0.2.0 while continuing to allow `0.0.0-dev` builds.
- Move repository metadata from `mfrtechconsult/PokePCFollowers` to `burgerslayer7/PokePCFollowers`.
- Treat Gold and Silver through the same `GameVersion.generation() == 2` path instead of adding edition-specific follower logic.

### Validation status
- Static sandbox/Lua validation is automated in CI.
- Gen1Recomp `dev` is checked for the Silver launcher target and the shared Gen2 follower adapter.
- Real in-game Silver validation is still required before promoting this RC to a stable release.

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
