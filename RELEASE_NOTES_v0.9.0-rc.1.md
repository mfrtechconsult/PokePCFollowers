# PokePCFollowers 0.9.0-rc.1

Compatibility candidate for the Gen1Recomp 0.2.x line and the new Pokémon Silver Gen2 target.

## What changed

- Targets Gen1Recomp 0.2.x / mod API 2 while keeping current `dev` builds accepted.
- Adds Pokémon Silver to the documented/validated game matrix alongside Red, Blue, Yellow and Gold.
- Keeps Gold and Silver on one shared `GameVersion.generation() == 2` code path.
- Requires the public Gen2 follower `setShouldSpawn` seam instead of falling back to private implementation details.
- Updates repository/provider metadata to `burgerslayer7/PokePCFollowers`.
- Adds CI against the current upstream Gen1Recomp `dev` branch to detect Silver or Gen2-facade regressions.

## Testing status

Automated checks cover Lua compilation, manifest/sandbox contracts, the current Gen1Recomp modkit, the Silver launcher target and the Gen2 follower facade.

**Manual in-game Silver validation is still required before promoting this RC to stable.**

## Compatibility

- Red / Blue / Yellow: supported through the Gen1 follower compatibility shim.
- Gold / Silver: supported through the shared Gen2 follower runtime and compatibility facade.
- Crystal 251: optional for Johto species on Gen1.
- Dramatic Shape / Dramaless / Battle Art integrations remain handled through the existing public provider hooks.
