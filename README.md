# PokéPC Followers Mod — Gen 1 + Gen 2

An all-species overworld follower mod for **Pokémon Red, Blue, Yellow, and Gold (Gen1Recomp)**. Every Generation I Pokémon is supported out of the box; Gold supplies all 251 species natively, while Gen 1 can add Johto species through a compatible expansion such as **Crystal 251**.

---

## 🌟 Features

* **All 251 Gen 1 + Gen 2 Pokémon Supported**: Every Pokémon from Bulbasaur `#001` to Celebi `#251` has full overworld sprite animations.
* **Crystal 251 Compatibility**: Johto species are detected from Crystal 251's registered Pokédex data instead of relying on a second hard-coded species table.
* **Automatic Party Slot 1 Follower**: By default, your overworld follower automatically mirrors whichever Pokémon is in **Party Slot 1**. Swapping your party order or receiving a new lead Pokémon dynamically updates your overworld companion.
* **Party Menu UI Selection**:
  1. Press `START` -> select `POKéMON`.
  2. Choose any Pokémon in your party.
  3. Select the new **`FOLLOWER`** option.
  4. Your chosen Pokémon will instantly become your active follower!
* **Full-Color Overworld Graphics**: Sprites render with rich true-color graphics directly over 100% colorized overworld terrain tiles (grass, paths, dirt, water) with zero background artifacts.
* **Pokédex-Proportional Sizes**: Followers use the height recorded in their Pokédex entry. A progressive and capped scale keeps the smallest Pokémon at least 11 px tall while making very large Pokémon clearly more imposing, without changing collision or movement.
* **Smooth Movement Mechanics**:
  * Smooth 1-tile trailing behind the player.
  * In-place turning (no teleporting or jumping tiles when turning around).
  * Seamless map transition spawning across route seams and indoor/outdoor warps.

---

## 📋 Installation

**PokePCFollowers 0.8.2 requires Gen1Recomp 0.1.86 or newer.** Install the ZIP from the GitHub release through `MODS > Import mod .zip`, or place the unpacked mod inside `mods/`.

The sandbox entry point is `main_sandbox.lua`; it loads the existing follower implementation through Gen1Recomp's scoped mod APIs.

On Red, Blue, or Yellow, install and import **Crystal 251** to use Pokémon `#152`–`#251`. On Gold, all 251 species work directly from the game's own Pokédex data.

The manifest targets both `gen1` and `gen2`; no second Gold-specific copy of the mod is needed.

### Follower size options

`POKEDEX SIZES` enables or disables proportional follower sizes. `FOLLOWER SIZE`
adjusts the result globally from 75% to 125%. The default 100% setting uses the
Pokédex-derived scale. Only the visual sprite changes: followers still occupy one
logical map cell and retain their normal movement and interactions.

---

## Gen1Recomp 0.1.86+ sandbox compatibility

Version 0.8.2 is migrated to the Gen1Recomp per-mod sandbox. The mod does not request raw filesystem access. Its own asset paths are rooted through `mod.assets:path(...)`, its legacy implementation is read through `mod:read(...)`, and cross-mod integration continues through `mod.find(...).exports`.

The old Gen 1 fallback that depended on `debug.getupvalue` is no longer required at runtime: the sandbox entry installs a narrow follower-spawn compatibility seam before the existing implementation loads. This keeps Red/Blue follower spawning functional even though the sandbox intentionally does not expose the Lua `debug` library.

## 👥 Credits & Acknowledgments

* **Generation I + II Overworld Sprites**: Huge credit and special thanks to ShockSlayer, the makers of the legendary ROM hack **Pokémon Crystal Clear**, and the PokéPC / Followers EX lineage for the native GSC-style follower sheets. The Generation II sheets are distributed in the built-in Poke Followers pack from [Wilds of Kanto](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
* **Crystal 251 Integration**: Species identities and National Pokédex numbers are read from [Crystal 251](https://github.com/Deftones565/gen1recomp-mod-crystal-251) at runtime. No Crystal ROM content is bundled by this mod.
* **Development**: Built with **vibe coding** and pair programming for the `pokemon-gen1-recomp` project.

## Voxel compatibility

This build includes compatibility for Dramatic Shape-family voxel providers. The follower sprite is resolved dynamically through `SpriteRenderer:resolveImage()` as well as the normal 2D draw hook, preventing voxel mode from sampling the registered Charmander fallback sheet for every follower.

The follower sprite is also marked `trueColor` for render-pipeline use so the voxel renderer does not run the fixed `SPRITE_PIKACHU` image through its palette bake. Pokédex-derived sizes are forwarded to the billboard and shadow meshes used by Dramatic Shape, Dramaless Shape and Battle Art Voxel Fork.

## Inter-mod compatibility

Version 0.8.2 keeps its renderer, party-menu, follower and Yellow encounter wrappers chain-safe. During a hot reload it restores a function only when its own wrapper is still the active outermost function, so wrappers installed by later-loading mods are not overwritten. This is intended for stacks containing Dramatic Sky Ride, Kanto Dive or the standalone Dramatic Deep Dive; those mods remain responsible for their own mount and underwater movement rules.

When [Unique Menu Icons](https://github.com/menyas/unique-menu-icons) is also enabled, it owns the party-menu icon column and its color mode. PokePC keeps providing the overworld follower and the `FOLLOWER` action, but stops marking the party rows as true color. Without Unique Menu Icons, PokePC's own party icons remain the fallback. Use Unique Menu Icons 1.5.0 or newer; version 1.4.0 declares PokePC incompatible in its manifest.

## Red/Blue follower support

The mod extends the follower entity to Pokémon Red and Pokémon Blue. The stock Gen 1 `PikachuFollower` spawn condition is Yellow/Pikachu-specific, so PokePC supplies a version-neutral healthy-party condition while retaining the engine's native trailing, ledge and map-transition behavior.

Yellow-only Oak story/encounter overrides remain restricted to Yellow and are not applied to Red, Blue, or Gold.

## Gold support

PokePC targets the Gen 2 engine directly. It uses Gold's follower spawn seam, native 251-species Pokédex, Gen 2 sprite registry, and split icon sheet/species registry. Followers are hidden correctly while biking or surfing, and the Party Menu `FOLLOWER` action uses the same shared hook as Gen 1.

## Animation fix

The follower sprite definition is explicitly marked as a walking sprite (`walker=true`). Gen1Recomp uses this flag to provide the `walkPhase` state used by the 6-frame overworld sheets, so the follower switches between standing and walking frames correctly.
