-- Compatibility entry point.
-- Keeps the original runtime untouched, then publishes a stable sprite-provider
-- API that companion mods can use without taking ownership of the follower
-- lifecycle.

local function loadOriginal(mod)
  local source, readErr = mod:read("main.lua")
  if not source then
    error("PokePCFollowers: could not read main.lua: " .. tostring(readErr), 0)
  end
  local compiler = loadstring or load
  local chunk, loadErr = compiler(source, "@" .. mod.path .. "/main.lua")
  if not chunk then
    error("PokePCFollowers: could not compile main.lua: " .. tostring(loadErr), 0)
  end
  local entry = chunk()
  if type(entry) ~= "function" then
    error("PokePCFollowers: main.lua did not return an initializer", 0)
  end
  return entry
end

return function(mod)
  local original = loadOriginal(mod)
  original(mod)

  local ex = mod.exports
  if not ex then return end

  -- Common contract shared with Wilds of Kanto. Consumers should detect this
  -- capability instead of depending on a specific follower runtime.
  ex.resolveFollowerSprite = function(opts)
    opts = opts or {}
    local species = tostring(opts.species or "CHARMANDER"):upper()
    if type(ex.assetPath) ~= "function" then return nil end
    local path = ex.assetPath(species)
    if not path then return nil end

    local trueColor = true
    if mod.options and mod.options.get then
      local ok, mode = pcall(mod.options.get, mod.options, "color_mode")
      if ok and mode == "gbc" then trueColor = false end
    end

    local visualScale = 1
    if type(ex.followerVisualScale) == "function" then
      local ok, scale = pcall(ex.followerVisualScale, species)
      if ok and tonumber(scale) then visualScale = tonumber(scale) end
    end

    return {
      id = opts.id or ("SPRITE_POKEPC_PROVIDER_" .. species),
      image = path,
      frames = 6,
      walker = true,
      trueColor = trueColor,
      providerId = mod.id,
      role = opts.role or "follower",
      surface = opts.surface or "land",
      species = species,
      visualScale = visualScale,
    }
  end

  ex.spriteProviderId = mod.id
  ex.providerOnly = false

  local function refreshProviderMode()
    if not mod.find then return end
    local ok, wilds = pcall(mod.find, mod, "overworld_wild_spawns")
    ex.providerOnly = ok and wilds ~= nil or false
  end

  refreshProviderMode()
  if mod.events and mod.events.on then
    mod.events:on("mods.loaded", refreshProviderMode)
  end
end
