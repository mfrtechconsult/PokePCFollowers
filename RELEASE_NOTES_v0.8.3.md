# PokePCFollowers 0.8.3

Compatibility bridge release for Gen1Recomp 0.1.86+.

## Cross-mod sprite provider

- Publishes `providerRepository` so consumers can identify the maintained compatibility fork without changing the long-standing mod id.
- Publishes the sandbox-safe `resolveFollowerSprite(...)` provider contract expected by current Dramatic Sky Ride and other compatible consumers.
- Keeps the existing `assetPath(...)` export intact as a legacy compatibility seam for integrations that have not migrated yet.
- The provider returns the existing six-frame walking follower sheets and never reintroduces raw cross-mod filesystem access.

## Preserved behavior

- Red, Blue, Yellow and Gold follower support.
- All 251 follower assets and Pokédex-proportional sizing.
- Crystal 251 integration.
- Follower selection, restoration and supported voxel rendering.
