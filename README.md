# PokéPC Followers Mod — Gen 1 + Gen 2

An all-species overworld follower mod for **Pokémon Red, Blue, and Yellow (Gen1Recomp)**. Every Generation I Pokémon is supported out of the box, and all Generation II Pokémon are supported when a compatible species expansion such as **Crystal 251** is enabled.

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

1. Place the `pokepcfollowers` folder inside your `mods/` directory:
   ```
   pokemon-gen1-recomp/
   └── mods/
       └── pokepcfollowers/
           ├── manifest.json
           ├── mod.card
           ├── main.lua
           ├── README.md
           └── assets/
               └── sprites/
   ```
2. Launch `gen1recomp` — the mod will load automatically!

To use Pokémon `#152`–`#251`, install and import **Crystal 251**, then enable both mods. PokéPC Followers remains fully usable by itself for the original 151 species.

### Follower size options

`POKEDEX SIZES` enables or disables proportional follower sizes. `FOLLOWER SIZE`
adjusts the result globally from 75% to 125%. The default 100% setting uses the
Pokédex-derived scale. Only the visual sprite changes: followers still occupy one
logical map cell and retain their normal movement and interactions.

---

## 👥 Credits & Acknowledgments

* **Generation I + II Overworld Sprites**: Huge credit and special thanks to ShockSlayer, the makers of the legendary ROM hack **Pokémon Crystal Clear**, and the PokéPC / Followers EX lineage for the native GSC-style follower sheets. The Generation II sheets are distributed in the built-in Poke Followers pack from [Wilds of Kanto](https://github.com/YoDrehDenSwagAuf/overworld-spawn-mod). See [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
* **Crystal 251 Integration**: Species identities and National Pokédex numbers are read from [Crystal 251](https://github.com/Deftones565/gen1recomp-mod-crystal-251) at runtime. No Crystal ROM content is bundled by this mod.
* **Development**: Built with **vibe coding** and pair programming for the `pokemon-gen1-recomp` project.

## Voxel compatibility

This build includes a compatibility fix for **Dramatic Shape Voxel Mod 1.3.0**.
The follower sprite is now resolved dynamically through `SpriteRenderer:resolveImage()`
as well as the normal 2D draw hook. This prevents voxel mode from sampling the
registered Charmander fallback sheet for every follower.

The follower sprite is also marked `trueColor` for render-pipeline use so the
voxel renderer does not run the fixed `SPRITE_PIKACHU` image through its palette
bake. Pokédex-derived sizes are forwarded to the billboard and shadow meshes used
by Dramatic Shape, Dramaless Shape and Battle Art Voxel Fork.

## Inter-mod compatibility

Version 0.6.1 keeps its renderer, party-menu, follower and Yellow encounter
wrappers chain-safe. During a hot reload it restores a function only when its
own wrapper is still the active outermost function, so wrappers installed by
later-loading mods are not overwritten. This is intended for stacks containing
Dramatic Sky Ride, Kanto Dive or the standalone Dramatic Deep Dive; those mods
remain responsible for their own mount and underwater movement rules.

## Experimental Red/Blue + Voxel Fix

This build extends the follower entity to Pokémon Red and Pokémon Blue.
The stock `PikachuFollower` logic is Yellow-only, so the mod replaces its
spawn condition with a version-neutral healthy-party check.

It also keeps the Dramatic Shape compatibility fix: voxel/tilt rendering
resolves the active follower's `follower_<species>.png` instead of the
registered Charmander fallback.

Yellow-only Oak story/encounter overrides remain restricted to Yellow and
are not applied to Red or Blue.


## Animation fix

Version 1.1.1 explicitly marks the follower sprite definition as a walking sprite (`walker=true`). Gen1Recomp uses this flag to provide the `walkPhase` state used by the 6-frame overworld sheets, so the follower now switches between standing and walking frames correctly.
