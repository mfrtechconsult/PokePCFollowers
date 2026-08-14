-- Gen1Recomp 0.1.86+ sandbox bootstrap for PokePC Followers.
--
-- The legacy implementation still contains a Gen 1 debug-upvalue fallback and
-- builds its own asset paths from mod.path. The 0.1.86 sandbox deliberately
-- removes debug and raw filesystem access. This bootstrap installs the one
-- compatibility seam the legacy code needs, derives its root from the scoped
-- mod.assets API, then loads the existing implementation through mod:read.

return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local PikachuFollower = require("src.world.PikachuFollower")

  -- Keep every legacy asset lookup rooted in this mod. mod.assets:path() is
  -- the sandbox-supported path resolver and rejects absolute/traversal paths.
  if mod.assets and type(mod.assets.path) == "function" then
    local probe = mod.assets:path("assets/sprites/follower_004.png")
    if type(probe) == "string" then
      local suffix = "/assets/sprites/follower_004.png"
      if probe:sub(-#suffix) == suffix then
        mod.path = probe:sub(1, #probe - #suffix)
      end
    end
  end

  -- Gen 2 already exposes a named shouldSpawn seam through its compatibility
  -- facade. Current Gen 1 keeps that predicate private, which older PokePC
  -- releases reached with debug.getupvalue. debug is intentionally absent in
  -- the 0.1.86 sandbox, so provide a narrow setter without exposing internals.
  local generation = type(GameVersion.generation) == "function"
    and GameVersion.generation() or 1

  local sandboxShim = nil
  if generation == 1 and type(PikachuFollower.setShouldSpawn) ~= "function" then
    local shim = PikachuFollower.__pokepcSandboxSpawnGate
    if type(shim) ~= "table" then
      shim = {
        predicate = nil,
        nativeOnMapEntered = PikachuFollower.onMapEntered,
        nativeUpdate = PikachuFollower.update,
      }

      local function predicateAllows(game, ow)
        local fn = shim.predicate
        if type(fn) ~= "function" then return false end
        local ok, value = pcall(fn, game, ow)
        if not ok then
          if mod.log and mod.log.warn then
            mod.log:warn("follower spawn predicate failed: %s", tostring(value))
          end
          return false
        end
        return value == true
      end

      -- Native Gen 1's follower movement code is already correct; only its
      -- private Yellow/Pikachu spawn gate is too narrow for PokePC. Satisfy
      -- that gate for the duration of the synchronous native call, then
      -- restore the save/game view before returning.
      local function withNativeSpawnGate(game, fn, ...)
        if type(fn) ~= "function" then return nil end
        local save = game and game.save
        if type(save) ~= "table" then return fn(...) end

        local oldFlags = save.flags
        local madeFlags = type(oldFlags) ~= "table"
        local flags = madeFlags and {} or oldFlags
        if madeFlags then save.flags = flags end

        local oldGotStarter = flags.EVENT_GOT_STARTER
        local oldRival = flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB
        local oldInBall = save.pikachuInBall
        local party = type(save.party) == "table" and save.party or {}
        local mon = party[1]
        local oldSpecies = mon and mon.species or nil
        local oldIsYellow = GameVersion.isYellow

        flags.EVENT_GOT_STARTER = true
        flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = true
        save.pikachuInBall = false
        if mon then mon.species = "PIKACHU" end
        GameVersion.isYellow = function() return true end

        local results = { pcall(fn, ...) }

        GameVersion.isYellow = oldIsYellow
        if mon then mon.species = oldSpecies end
        save.pikachuInBall = oldInBall
        if madeFlags then
          save.flags = oldFlags
        else
          flags.EVENT_GOT_STARTER = oldGotStarter
          flags.EVENT_BATTLED_RIVAL_IN_OAKS_LAB = oldRival
        end

        if not results[1] then error(results[2], 0) end
        return unpack(results, 2)
      end

      shim.setShouldSpawn = function(fn)
        local previous = shim.predicate
        shim.predicate = type(fn) == "function" and fn or nil
        return previous
      end

      shim.onMapEntered = function(game, ow, ...)
        if predicateAllows(game, ow) then
          return withNativeSpawnGate(game, shim.nativeOnMapEntered,
            game, ow, ...)
        end
        return shim.nativeOnMapEntered(game, ow, ...)
      end

      shim.update = function(game, ow, ...)
        if predicateAllows(game, ow) then
          return withNativeSpawnGate(game, shim.nativeUpdate,
            game, ow, ...)
        end
        return shim.nativeUpdate(game, ow, ...)
      end

      PikachuFollower.__pokepcSandboxSpawnGate = shim
    end

    -- A hot reload may leave the shim table in the engine module. Reset only
    -- our predicate and put the same stable wrappers back in place before the
    -- legacy implementation installs its own wrappers on top.
    sandboxShim = shim
    shim.predicate = nil
    PikachuFollower.setShouldSpawn = shim.setShouldSpawn
    PikachuFollower.onMapEntered = shim.onMapEntered
    PikachuFollower.update = shim.update
  end

  local source, readErr = mod:read("main.lua")
  if type(source) ~= "string" then
    if mod.log and mod.log.error then
      mod.log:error("unable to read legacy main.lua: %s", tostring(readErr))
    end
    return
  end

  local chunk, compileErr = load(source, "@PokePCFollowers/main.lua")
  if not chunk then
    if mod.log and mod.log.error then
      mod.log:error("legacy main.lua did not compile: %s", tostring(compileErr))
    end
    return
  end

  local ok, legacy = pcall(chunk)
  if not ok then
    if mod.log and mod.log.error then
      mod.log:error("legacy main.lua failed to load: %s", tostring(legacy))
    end
    return
  end
  if type(legacy) ~= "function" then
    if mod.log and mod.log.error then
      mod.log:error("legacy main.lua must return the mod entry function")
    end
    return
  end

  local result = legacy(mod)

  -- Canonical sandbox-safe sprite provider contract for 0.1.86+ consumers.
  -- assetPath remains exported by the legacy core as a compatibility seam for
  -- older integrations; resolveFollowerSprite is the preferred definition API.
  if mod.exports then
    mod.exports.providerRepository = "mfrtechconsult/PokePCFollowers"
    mod.exports.resolveFollowerSprite = function(opts)
      local species = type(opts) == "table" and opts.species or opts
      if type(species) ~= "string" or species == "" then return nil end

      local resolver = mod.exports.assetPath
      if type(resolver) ~= "function" then return nil end
      local okPath, path = pcall(resolver, species)
      if not okPath or type(path) ~= "string" or path == "" then return nil end

      return {
        image = path,
        frames = 6,
        walker = true,
        trueColor = true,
        providerId = mod.id,
      }
    end
  end

  -- Make hot-unload/reload neutral: legacy restore removes its own wrappers;
  -- this extra tail clears the sandbox predicate so the remaining shim behaves
  -- exactly like vanilla until PokePC is initialized again.
  if sandboxShim then
    local state = PikachuFollower.__pokepcFollowersUniversal
    if type(state) == "table" and type(state.restore) == "function"
        and state.__pokepcSandboxRestoreWrapped ~= true then
      local rawRestore = state.restore
      state.restore = function(...)
        local restored = { pcall(rawRestore, ...) }
        sandboxShim.predicate = nil
        if not restored[1] then error(restored[2], 0) end
        return unpack(restored, 2)
      end
      state.__pokepcSandboxRestoreWrapped = true
      if mod.exports then mod.exports.restore = state.restore end
    end
  end

  return result
end
