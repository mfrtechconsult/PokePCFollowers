# PokéPC Followers Mod — Gen 1 + Gen 2

An all-species overworld follower mod for **Pokémon Red, Blue, Yellow, Gold, and Silver** on Gen1Recomp. Every Generation I Pokémon is supported out of the box; Generation II games supply the 251-species Pokédex natively, while Gen 1 can add Johto species through a compatible expansion such as **Crystal 251**.

## Current development target

**0.9.0-rc.1** targets **Gen1Recomp 0.2.x / mod API 2** and the current `dev` branch. Pokémon Silver was added as a first-class Gen2 launcher target in upstream Gen1Recomp on 2026-08-20. Gold and Silver deliberately share one generation-driven follower path; PokePC does not duplicate edition-specific data or hard-code Gold-only behavior.

The last stable PokePC release remains 0.8.3 until this RC has been exercised in-game on Silver.

## Features

* **All 251 Gen 1 + Gen 2 Pokémon supported**: every Pokémon from Bulbasaur `#001` to Celebi `#251` has an overworld follower sheet.
* **Red / Blue / Yellow / Gold / Silver**: one mod package targets both `gen1` and `gen2` through Gen1Recomp's shared mod API.
* **Crystal 251 compatibility**: Johto species are discovered from registered Pokédex data instead of a second hard-coded species table.
* **Automatic lead follower**: Party Slot 1 is used by default and changes are reflected dynamically.
* **Party Menu selection**: choose any healthy party Pokémon and select **FOLLOWER**.
* **Pokédex-proportional sizes**: visual scale derives from Pokédex height with safe minimum/maximum limits; collision remains one logical map cell.
* **True-color overworld rendering** with six-frame walking animation sheets.
* **Voxel compatibility** with Dramatic Shape-family providers through the public provider/export surface.
* **Sandbox-safe provider API**: other mods can consume `resolveFollowerSprite(...)` without raw cross-mod filesystem access.

## Installation

For the stable public build, install the ZIP from GitHub Releases through `MODS > Import mod .zip`.

For this RC, use a Gen1Recomp build compatible with **0.2.x**. Silver support specifically requires an upstream build that contains the Silver launcher/runtime work added on 2026-08-20; Gen1Recomp 0.2.0 itself predates that commit.

The sandbox entry point is `main_sandbox.lua`; it loads the legacy follower implementation through scoped Gen1Recomp APIs.

On Red, Blue, or Yellow, install/import **Crystal 251** if you want species `#152`–`#251`. Gold and Silver use their own native Gen2 Pokédex data.

The manifest uses:

```json
"games": ["gen1", "gen2"]
```

Gen1Recomp resolves that generation target to Red/Blue/Yellow and Gold/Silver. No Gold-specific or Silver-specific copy of the mod is required.

### Follower size options

`POKEDEX SIZES` enables or disables proportional follower sizes. `FOLLOWER SIZE` adjusts the result globally from 75% to 125%. Only the visual sprite changes; follower collision and movement stay on one logical map cell.

## Gen1Recomp 0.2.x compatibility

PokePC stays inside the per-mod sandbox. It does not request raw filesystem access. Asset paths are rooted through `mod.assets:path(...)`, the legacy implementation is loaded through `mod:read(...)`, and cross-mod integration uses `mod.find(...).exports`.

The Gen 1 follower spawn predicate is private, so the sandbox entry installs a narrow compatibility shim for Red/Blue/Yellow. Gen 2 is different: upstream exposes a named `PikachuFollower.setShouldSpawn` facade backed by the shared Gen2 follower runtime. PokePC now requires that named seam for both Gold and Silver and fails loudly rather than silently running a half-working follower if the engine contract regresses.

The runtime branches on `GameVersion.generation() == 2`, not `GameVersion.isGold()`. This is the key Silver compatibility rule: Gold and Silver share the same follower adapter, while species, maps, caches, saves and edition data remain owned by Gen1Recomp.

## Silver support

Silver is treated exactly as a Gen2 edition, not as a special fork of the PokePC logic.

* `GameVersion.get()` may return `silver`.
* `GameVersion.generation()` must return `2`.
* The same Gen2 sprite registry, follower spawn seam, Party Menu hook and world adapter used by Gold are used by Silver.
* The manifest's `gen2` target automatically includes both Gold and Silver.
* The compatibility CI tracks the current Gen1Recomp `dev` branch and asserts the Silver target plus the Gen2 follower facade are still present.

This means future edition fixes in Gen1Recomp remain upstream responsibilities instead of being duplicated in this mod.

## Voxel compatibility

The follower image is resolved dynamically through `SpriteRenderer:resolveImage()` as well as the normal 2D draw hook, preventing voxel mode from sampling the registered fallback sheet for every follower.

Pokédex-derived size metadata is forwarded to compatible billboard/shadow meshes used by Dramatic Shape, Dramaless Shape and Battle Art Voxel Fork.

## Inter-mod compatibility

PokePC keeps renderer, Party Menu, follower and Yellow encounter wrappers chain-safe. During hot reload it restores a function only when its wrapper is still the active outermost function, so later-loading mods are not erased.

Dramatic Sky Ride, Kanto Dive and Dramatic Deep Dive remain responsible for their own mount/underwater movement rules.

When **Unique Menu Icons 1.5.0+** is enabled, it owns the Party Menu icon column and color handling; PokePC continues to provide the overworld follower and FOLLOWER action.

## Red / Blue / Yellow behavior

The stock Gen1 follower system is Yellow/Pikachu-specific. PokePC supplies a healthy-party follower condition while retaining the engine's native trailing, ledge and map-transition behavior.

Yellow-only Oak story/encounter overrides remain restricted to Yellow and are not applied to Red, Blue, Gold or Silver.

## Gold / Silver behavior

PokePC targets Gen2 directly through Gen1Recomp's compatibility facade. It uses the native 251-species Pokédex, Gen2 sprite registry, Gen2 follower runtime and shared Party Menu hook. Followers hide while biking or surfing and respawn through the same generation-neutral selection state.

## Credits & acknowledgments

* **Generation I + II overworld sprites**: ShockSlayer, Pokémon Crystal Clear contributors, and the PokéPC / Followers EX lineage. The Generation II sheets are distributed in the built-in Poke Followers pack from Wilds of Kanto. See `THIRD_PARTY_NOTICES.md`.
* **Crystal 251 integration**: species identities and National Pokédex numbers are read from Crystal 251 at runtime; no Crystal ROM content is bundled.
* **Gen1Recomp**: the mod targets the public mod API and Gen2 compatibility facade maintained by the Gen1Recomp project.
