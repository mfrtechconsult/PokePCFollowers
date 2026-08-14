# PokePCFollowers 0.8.2

Sandbox compatibility release for **Gen1Recomp 0.1.86 and newer**.

## Sandbox migration

- Targets Gen1Recomp `0.1.86+` and keeps only the existing `engine_internals` permission.
- Uses a sandbox bootstrap as the mod entry point.
- Derives legacy asset paths from the scoped `mod.assets:path(...)` API instead of relying on unrestricted filesystem access.
- Loads the existing implementation through `mod:read(...)` and the sandboxed `load(...)` supplied by Gen1Recomp.
- Replaces the old Gen 1 `debug.getupvalue` spawn fallback at runtime with a narrow follower spawn seam, because the 0.1.86 sandbox intentionally does not expose `debug`.
- Keeps cross-mod compatibility through `mod.find(...).exports` for Unique Menu Icons, Battle Art, Dramaless Shape and compatible voxel providers.
- Does not request or use a raw filesystem permission.

## Preserved behavior

- Red, Blue, Yellow and Gold follower support.
- All 251 follower sprite assets and Pokédex-proportional sizing.
- Crystal 251 species integration.
- `FOLLOWER` / `FOLLOWING` party action and saved selection.
- Unique Menu Icons ownership hand-off.
- 2D and supported voxel follower rendering.

The attached ZIP is built from the release commit, strips the old tracked `mod.zip` and Windows Zone.Identifier metadata, and is syntax-checked with LuaJIT before publication.
