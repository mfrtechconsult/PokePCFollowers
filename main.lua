-- PokePC Followers – Unified Mod for Pokémon Red, Blue, Yellow and Gold
-- Merges:
--   • Full follower mechanics (draw/resolve overrides) from main0.0.1
--   • Red/Blue support, persistent selection, talk wrapper from main0.0.2
--   • Dex‑numbered assets, icon patches, purge logic from main0.0.3
-- All improvements are integrated without breaking the core follower behaviour.

return function(mod)
  local GameVersion = require("src.core.GameVersion")
  local version = GameVersion.get()
  local generation = GameVersion.generation()
  local isGen2 = generation == 2
  local isYellow = GameVersion.isYellow()

  print(string.format("[PokePCFollowers] Initializing for %s", version:upper()))

  -- Core modules
  local PaletteFX = require("src.render.PaletteFX")
  local SpriteRenderer = require("src.render.SpriteRenderer")
  local Assets = require("src.render.Assets")
  local PikachuFollower = require("src.world.PikachuFollower")
  local Strings = require("src.core.Strings")
  local Sound = require("src.core.Sound")
  local TextBox = require("src.render.TextBox")
  local PartyMenu = require("src.ui.PartyMenu")
  local OverworldController = require("src.world.OverworldController")

  -- mod.game is resolved lazily by the loader. Do not cache fields from it at
  -- entry time: Gold's Game2 instance is not fully ready yet when mods load.
  local function liveGame()
    return mod.game
  end

  local function worldFor(game)
    local world = game and (game.overworld or game.world)
    if world then return world end
    local worldApi = mod.world
    return worldApi and worldApi.overworld and worldApi:overworld() or nil
  end

  local function spritesFor(game)
    local data = game and game.data
    return data and (data.sprites or data.gen2Sprites) or nil
  end

  -- Unique Menu Icons deliberately owns the party icon column when both mods
  -- are active.  Prefer its explicit capability export, while treating the
  -- released mod id as an ownership signal for older compatible builds.
  local function externalPartyIconOwner()
    if type(mod.find) ~= "function" then return false end
    local ok, handle = pcall(mod.find, mod, "unique_menu_icons")
    if not (ok and handle) then return false end
    local exports = handle.exports
    if type(exports) == "table" and exports.ownsPartyIcons ~= nil then
      return exports.ownsPartyIcons == true
    end
    return true
  end

  -- Constants
  local FALLBACK_SPECIES = "CHARMANDER"
  local SPRITE_ID = "SPRITE_PIKACHU"
  local OPPOSITE = { up = "down", down = "up", left = "right", right = "left" }

  -- A human-sized 1.70 m Pokemon keeps the original 16 px follower card.
  -- Power-curve compression preserves the Pokedex ordering without letting
  -- long species such as Onix cover most of the map. A readable floor keeps
  -- the smallest species visible, and one-pixel steps keep nearby sizes
  -- visually coherent with nearest-neighbour rendering.
  local POKEDEX_REFERENCE_METERS = 1.70
  local POKEDEX_SCALE_EXPONENT = 0.40
  local MIN_FOLLOWER_SCALE = 0.6875
  local MAX_FOLLOWER_SCALE = 2.50
  local SCALE_QUANTUM = 0.0625

  if mod.options and mod.options.define then
    mod.options:define({
      {
        key = "pokedex_follower_sizes",
        type = "toggle",
        label = "POKEDEX SIZES",
        default = true,
        help = "Scale follower sprites from each Pokemon's Pokedex height.",
      },
      {
        key = "follower_size_percent",
        type = "number",
        label = "FOLLOWER SIZE",
        default = 100,
        min = 75,
        max = 125,
        step = 5,
        help = "Adjust every Pokedex-derived follower size.",
      },
    })
  end

  local function optionValue(key, fallback)
    if not (mod.options and mod.options.get) then return fallback end
    local ok, value = pcall(mod.options.get, mod.options, key)
    if not ok or value == nil then return fallback end
    return value
  end

  local function clamp(value, minimum, maximum)
    return math.max(minimum, math.min(maximum, value))
  end

  -- ----------------------------------------------------------------------
  -- 1. Asset path helpers (dex-numbered files, e.g. follower_004.png)
  -- ----------------------------------------------------------------------
  local speciesToDex = {
    BULBASAUR=1, IVYSAUR=2, VENUSAUR=3, CHARMANDER=4, CHARMELEON=5, CHARIZARD=6,
    SQUIRTLE=7, WARTORTLE=8, BLASTOISE=9, CATERPIE=10, METAPOD=11, BUTTERFREE=12,
    WEEDLE=13, KAKUNA=14, BEEDRILL=15, PIDGEY=16, PIDGEOTTO=17, PIDGEOT=18,
    RATTATA=19, RATICATE=20, SPEAROW=21, FEAROW=22, EKANS=23, ARBOK=24,
    PIKACHU=25, RAICHU=26, SANDSHREW=27, SANDSLASH=28, NIDORAN_F=29, NIDORINA=30,
    NIDOQUEEN=31, NIDORAN_M=32, NIDORINO=33, NIDOKING=34, CLEFAIRY=35, CLEFABLE=36,
    VULPIX=37, NINETALES=38, JIGGLYPUFF=39, WIGGLYTUFF=40, ZUBAT=41, GOLBAT=42,
    ODDISH=43, GLOOM=44, VILEPLUME=45, PARAS=46, PARASECT=47, VENONAT=48,
    VENOMOTH=49, DIGLETT=50, DUGTRIO=51, MEOWTH=52, PERSIAN=53, PSYDUCK=54,
    GOLDUCK=55, MANKEY=56, PRIMEAPE=57, GROWLITHE=58, ARCANINE=59, POLIWAG=60,
    POLIWHIRL=61, POLIWRATH=62, ABRA=63, KADABRA=64, ALAKAZAM=65, MACHOP=66,
    MACHOKE=67, MACHAMP=68, BELLSPROUT=69, WEEPINBELL=70, VICTREEBEL=71, TENTACOOL=72,
    TENTACRUEL=73, GEODUDE=74, GRAVELER=75, GOLEM=76, PONYTA=77, RAPIDASH=78,
    SLOWPOKE=79, SLOWBRO=80, MAGNEMITE=81, MAGNETON=82, FARFETCHD=83, DODUO=84,
    DODRIO=85, SEEL=86, DEWGONG=87, GRIMER=88, MUK=89, SHELLDER=90,
    CLOYSTER=91, GASTLY=92, HAUNTER=93, GENGAR=94, ONIX=95, DROWZEE=96,
    HYPNO=97, KRABBY=98, KINGLER=99, VOLTORB=100, ELECTRODE=101, EXEGGCUTE=102,
    EXEGGUTOR=103, CUBONE=104, MAROWAK=105, HITMONLEE=106, HITMONCHAN=107, LICKITUNG=108,
    KOFFING=109, WEEZING=110, RHYHORN=111, RHYDON=112, CHANSEY=113, TANGELA=114,
    KANGASKHAN=115, HORSEA=116, SEADRA=117, GOLDEEN=118, SEAKING=119, STARYU=120,
    STARMIE=121, MR_MIME=122, SCYTHER=123, JYNX=124, ELECTABUZZ=125, MAGMAR=126,
    PINSIR=127, TAUROS=128, MAGIKARP=129, GYARADOS=130, LAPRAS=131, DITTO=132,
    EEVEE=133, VAPOREON=134, JOLTEON=135, FLAREON=136, PORYGON=137, OMANYTE=138,
    OMASTAR=139, KABUTO=140, KABUTOPS=141, AERODACTYL=142, SNORLAX=143, ARTICUNO=144,
    ZAPDOS=145, MOLTRES=146, DRATINI=147, DRAGONAIR=148, DRAGONITE=149, MEWTWO=150, MEW=151
  }

  local MAX_FOLLOWER_DEX = 251

  -- Other content mods can register additional species before this mod loads.
  -- Crystal 251 is an optional dependency, so its Johto records are visible
  -- here whenever it is enabled and has completed its ROM import.
  if mod.content and mod.content.pokemon and mod.content.pokemon.each then
    pcall(function()
      for id, def in mod.content.pokemon:each() do
        local dex = def and tonumber(def.dex)
        if type(id) == "string" and dex and dex >= 1 and dex <= MAX_FOLLOWER_DEX then
          speciesToDex[id:upper()] = math.floor(dex)
        end
      end
    end)
  end

  local function dexForSpecies(species)
    local numeric = tonumber(species)
    if numeric and numeric >= 1 and numeric <= MAX_FOLLOWER_DEX then
      return math.floor(numeric)
    end

    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dex = speciesToDex[key]
    if dex then return dex end

    -- Runtime fallback for species supplied by a mod that loaded after us.
    local game = liveGame()
    local pokemon = game and game.data and game.data.pokemon
    local def = pokemon and pokemon[key]
    dex = def and tonumber(def.dex)
    if dex and dex >= 1 and dex <= MAX_FOLLOWER_DEX then
      dex = math.floor(dex)
      speciesToDex[key] = dex
      return dex
    end
    return nil
  end

  local function pokemonDefForSpecies(species)
    local game = liveGame()
    local pokemon = game and game.data and game.data.pokemon
    if type(pokemon) ~= "table" then return nil end
    local key = tostring(species or FALLBACK_SPECIES):upper()
    if pokemon[key] then return pokemon[key] end

    local dex = dexForSpecies(key)
    if not dex then return nil end
    for _, def in pairs(pokemon) do
      if type(def) == "table" and tonumber(def.dex) == dex then return def end
    end
    return nil
  end

  local function pokedexHeightMeters(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local def = pokemonDefForSpecies(species)
    local entry = def and def.dexEntry
    local feet = entry and tonumber(entry.heightFt)
    local inches = entry and tonumber(entry.heightIn)
    if feet == nil or inches == nil then
      local game = liveGame()
      local dex = game and game.data and game.data.gen2Pokedex
      local gen2Entry = dex and dex.entries and dex.entries[key]
      local encoded = gen2Entry and tonumber(gen2Entry.height)
      if encoded then
        feet = math.floor(encoded / 100)
        inches = encoded % 100
      end
    end
    if feet == nil or inches == nil then return nil end
    local totalInches = feet * 12 + inches
    if totalInches <= 0 then return nil end
    return totalInches * 0.0254
  end

  local function followerVisualScale(species)
    if optionValue("pokedex_follower_sizes", true) ~= true then return 1 end
    local meters = pokedexHeightMeters(species)
    if not meters then return 1 end

    local scale = (meters / POKEDEX_REFERENCE_METERS) ^ POKEDEX_SCALE_EXPONENT
    scale = clamp(scale, MIN_FOLLOWER_SCALE, MAX_FOLLOWER_SCALE)
    local percent = tonumber(optionValue("follower_size_percent", 100)) or 100
    percent = clamp(percent, 75, 125)
    scale = clamp(scale * percent / 100,
      MIN_FOLLOWER_SCALE, MAX_FOLLOWER_SCALE)
    return math.floor(scale / SCALE_QUANTUM + 0.5) * SCALE_QUANTUM
  end

  local function assetPath(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dex = dexForSpecies(key)
    local filename = dex and string.format("follower_%03d.png", dex)
                  or "follower_004.png"
    return mod.path .. "/assets/sprites/" .. filename
  end

  -- Image cache (keyed by dex number string)
  local followerImgCache = {}
  local function getFollowerImage(species)
    local key = tostring(species or FALLBACK_SPECIES):upper()
    local dex = dexForSpecies(key) or 4
    local dexStr = string.format("%03d", dex)
    if not followerImgCache[dexStr] then
      local path = assetPath(key)
      local ok, img = pcall(Assets.image, path)
      followerImgCache[dexStr] = ok and img or Assets.image(assetPath(FALLBACK_SPECIES))
    end
    return followerImgCache[dexStr]
  end

  -- ----------------------------------------------------------------------
  -- 2. Helper functions: health, mon fingerprint, selection
  -- ----------------------------------------------------------------------
  local function healthy(mon)
    return type(mon) == "table" and (tonumber(mon.hp) or 0) > 0
  end

  local function monKey(mon)
    if type(mon) ~= "table" then return nil end
    local dvs = type(mon.dvs) == "table" and mon.dvs or {}
    return table.concat({
      tostring(mon.otId or -1),
      tostring(dvs.attack or -1),
      tostring(dvs.defense or -1),
      tostring(dvs.speed or -1),
      tostring(dvs.special or -1),
      tostring(mon.catchRate or -1),
    }, ":")
  end

  -- Returns the currently selected follower mon and its party slot
  local function getActiveFollowerMon(game, needHealthy)
    if not (game and game.save and game.save.party) then return nil end
    local party = game.save.party
    if #party == 0 then return nil end

    -- 1) Persistent selection (from mod.save)
    if mod.save then
      local selKey = mod.save:get("selected_mon")
      local selSlot = tonumber(mod.save:get("selected_slot"))
      if selKey then
        local atSlot = selSlot and party[selSlot]
        if atSlot and monKey(atSlot) == selKey and (not needHealthy or healthy(atSlot)) then
          return atSlot, selSlot
        end
        for i, mon in ipairs(party) do
          if monKey(mon) == selKey and (not needHealthy or healthy(mon)) then
            return mon, i
          end
        end
      end
    end

    -- 2) Legacy followerPartyIndex (from original mod)
    local idx = game.save.followerPartyIndex
    if idx and type(idx) == "number" and party[idx] and (not needHealthy or healthy(party[idx])) then
      return party[idx], idx
    end

    -- 3) First healthy mon, or first overall if needHealthy is false
    for i, mon in ipairs(party) do
      if not needHealthy or healthy(mon) then return mon, i end
    end
    if needHealthy then return nil end
    return party[1], 1
  end

  -- ----------------------------------------------------------------------
  -- 3. Purge any follower entities from the overworld
  -- ----------------------------------------------------------------------
  local function purgeFollowerEntities(ow)
    if not ow then return end
    local function isFollower(ent)
      return ent and (ent.pikachuFollower == true or ent.id == "pikachu" or
        (ent.sprite and ent.sprite.def and ent.sprite.def.id == SPRITE_ID))
    end
    local function purge(list)
      if type(list) ~= "table" then return end
      local j = 1
      for i = 1, #list do
        local ent = list[i]
        if not isFollower(ent) then
          list[j] = ent
          j = j + 1
        end
      end
      for i = j, #list do list[i] = nil end
    end
    purge(ow.entities)
    purge(ow.npcs)
    if isFollower(ow.follower) then ow.follower = nil end
  end

  -- ----------------------------------------------------------------------
  -- 4. Register / patch the SPRITE_PIKACHU sprite definition
  -- ----------------------------------------------------------------------
  local function colorMode()
    return not (mod.options and mod.options:get("color_mode") == "gbc")
  end

  local followerSpriteDef = {
    id = SPRITE_ID,
    image = assetPath(FALLBACK_SPECIES),
    frames = 6,
    walker = true,
    trueColor = colorMode(),
    spriteType = isGen2 and "WALKING_SPRITE" or nil,
  }

  if mod.content.sprites:get(SPRITE_ID) then
    mod.content.sprites:patch(SPRITE_ID, followerSpriteDef)
  else
    mod.content.sprites:register(SPRITE_ID, followerSpriteDef)
  end

  -- ----------------------------------------------------------------------
  -- 5. Icon patching (for party menu and UI)
  -- ----------------------------------------------------------------------
  -- Patch mod.content.icons for each species
  if mod.content and mod.content.icons then
    local icons = mod.content.icons
    local function replaceOrRegister(id, value)
      if icons:get(id) ~= nil then
        icons:override(id, value)
      else
        icons:register(id, value)
      end
    end
    for species, dex in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dex)
      local path = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
      pcall(function()
        if isGen2 then
          local iconId = "ICON_POKEPC_" .. dexStr
          replaceOrRegister(iconId, {
            id = iconId, image = path, width = 16, height = 16, frames = 1,
          })
          replaceOrRegister(species, iconId)
        else
          local iconDef = { image = path, frames = 1 }
          replaceOrRegister(species, iconDef)
          replaceOrRegister(dex, iconDef)
          replaceOrRegister(dexStr, iconDef)
        end
      end)
    end
    -- Also patch generic icon IDs used by the engine
    -- These are Gen 1 assignment keys. On Gold the ICON_* ids are shared
    -- sheets, so overriding them would also change unrelated species.
    if not isGen2 then
      local fallbacks = {
        "ICON_MON", "ICON_BIRD", "ICON_QUADRUPED", "ICON_PIKACHU",
        "ICON_FAIRY", "ICON_WATER", "ICON_BUG", "ICON_SNAKE",
        "ICON_BALL", "ICON_HELIX", "ICON_GRASS"
      }
      for _, id in ipairs(fallbacks) do
        pcall(function()
          replaceOrRegister(id, {
            image = mod.path .. "/assets/sprites/follower_CHARMANDER.png",
            frames = 1,
          })
        end)
      end
    end
  end

  -- Also patch the generated.icons table (used by some UI elements)
  local ok, baseIcons = pcall(require, "generated.icons")
  if baseIcons and baseIcons.byDex and baseIcons.icons then
    for species, dex in pairs(speciesToDex) do
      local dexStr = string.format("%03d", dex)
      local iconKey = "FOLLOWER_" .. species
      local path = mod.path .. "/assets/sprites/follower_" .. dexStr .. ".png"
      baseIcons.byDex[dex] = iconKey
      baseIcons.icons[iconKey] = path
    end
  end

  -- ----------------------------------------------------------------------
  -- 6. Core follower sprite configuration and live sync
  -- ----------------------------------------------------------------------
  local function configureSpriteDef(game, mon)
    local sprites = spritesFor(game)
    local def = sprites and sprites[SPRITE_ID]
    if not def or not mon then return nil end
    local species = mon.species or FALLBACK_SPECIES
    def.image = assetPath(species)
    def.frames = 6
    def.walker = true
    def.trueColor = colorMode()
    def.pokepcFollowerSpecies = species
    def.pokepcFollowerVisualScale = followerVisualScale(species)
    return def, species
  end

  local function syncLiveFollowerDef(game, ow)
    if not (game and ow) then return nil end
    local mon = getActiveFollowerMon(game, true)
    if not mon then
      purgeFollowerEntities(ow)
      return nil
    end

    local def, species = configureSpriteDef(game, mon)
    if not def then return nil end

    local npc = PikachuFollower.current(ow)
    if not npc then return nil end

    local newImage = getFollowerImage(species)
    local newScale = followerVisualScale(species)
    if npc._pokepcFollowerSpecies ~= species or not npc.sprite or npc.sprite.image ~= newImage then
      npc.sprite = SpriteRenderer.new(def, npc.id)
      npc._pokepcFollowerSpecies = species
    else
      -- Update the definition in case trueColor or path changed
      npc.sprite.def.image = assetPath(species)
      npc.sprite.def.frames = 6
      npc.sprite.def.walker = true
      npc.sprite.def.trueColor = colorMode()
      npc.sprite.def.pokepcFollowerSpecies = species
      npc.sprite.def.pokepcFollowerVisualScale = newScale
    end
    npc._pokepcFollowerVisualScale = newScale
    return npc
  end

  -- ----------------------------------------------------------------------
  -- 7. Upvalue patching (shouldSpawn, starterInParty)
  -- ----------------------------------------------------------------------
  local function replaceUpvalue(fn, wanted, replacement)
    if type(fn) ~= "function" or not (debug and debug.getupvalue and debug.setupvalue) then
      return false
    end
    local i = 1
    while true do
      local name, old = debug.getupvalue(fn, i)
      if not name then return false end
      if name == wanted then
        debug.setupvalue(fn, i, replacement)
        return true, old
      end
      i = i + 1
    end
  end

  -- Hot‑reload cleanup
  local previous = PikachuFollower.__pokepcFollowersUniversal
  if previous and type(previous.restore) == "function" then
    pcall(previous.restore)
  end

  local originalUpdate = PikachuFollower.update
  local originalOnMapEntered = PikachuFollower.onMapEntered
  local originalTalk = PikachuFollower.talk
  local originalStarterInParty = PikachuFollower.starterInParty
  local vanillaShouldSpawn
  local vanillaOnMapEnteredShouldSpawn
  local usedShouldSpawnSetter = false

  -- New shouldSpawn: works for all versions and checks our selection
  local function shouldSpawn(game, ow)
    local save = game and game.save
    if not (save and ow) then return false end
    if not save.party or #save.party == 0 then return false end
    local playerState = ow.playerState
    if save.onBike or (ow.player and ow.player.surfing)
       or playerState == "bike" or playerState == "surf"
       or playerState == "surf_pika" then return false end
    local sprites = spritesFor(game)
    if not (sprites and sprites[SPRITE_ID]) then
      return false
    end
    return getActiveFollowerMon(game, true) ~= nil
  end

  -- Gold exposes a named seam. Gen 1 still needs the legacy upvalue fallback.
  if type(PikachuFollower.setShouldSpawn) == "function" then
    vanillaShouldSpawn = PikachuFollower.setShouldSpawn(shouldSpawn)
    usedShouldSpawnSetter = true
  elseif originalUpdate then
    local _, oldSpawn = replaceUpvalue(originalUpdate, "shouldSpawn", shouldSpawn)
    vanillaShouldSpawn = oldSpawn
  end
  -- Also patch onMapEntered directly in case it has its own closure
  if not usedShouldSpawnSetter and originalOnMapEntered then
    pcall(function()
      local replaced, oldSpawn = replaceUpvalue(
        originalOnMapEntered, "shouldSpawn", shouldSpawn)
      if replaced then vanillaOnMapEnteredShouldSpawn = oldSpawn end
    end)
  end

  -- starterInParty – return any healthy mon, not just Pikachu
  local function wrappedStarterInParty(save, needHealthy)
    local game = liveGame()
    local active = getActiveFollowerMon(game, needHealthy)
    if active then return active end
    -- fallback: first healthy in party
    for _, mon in ipairs(save and save.party or {}) do
      if not needHealthy or healthy(mon) then return mon end
    end
    return nil
  end
  PikachuFollower.starterInParty = wrappedStarterInParty

  -- ----------------------------------------------------------------------
  -- 8. SpriteRenderer overrides (for dynamic texture and 3D voxel)
  -- ----------------------------------------------------------------------
  local origResolveImage = SpriteRenderer.resolveImage
  local wrappedResolveImage
  wrappedResolveImage = function(self, ...)
    if self and self.def and self.def.id == SPRITE_ID then
      local activeMon = getActiveFollowerMon(liveGame(), false)
      if activeMon then
        return getFollowerImage(activeMon.species)
      end
    end
    return origResolveImage(self, ...)
  end
  SpriteRenderer.resolveImage = wrappedResolveImage

  local origSpriteDraw = SpriteRenderer.draw
  local wrappedSpriteDraw
  wrappedSpriteDraw = function(self, px, py, camX, camY, facing, walkPhase, stepFlip)
    if self and self.def and self.def.id == SPRITE_ID then
      local activeMon = getActiveFollowerMon(liveGame(), false)
      if not activeMon then return end
      local followerImg = getFollowerImage(activeMon.species)

      local x = math.floor(px - camX)
      local y = math.floor(py - camY) - 4

      local STAND = SpriteRenderer.STAND or {}
      local WALK = SpriteRenderer.WALK or {}
      local dirMap = (walkPhase == 1) and WALK or STAND
      local frameIdx = dirMap[facing] or 0
      local quad = self.frames and self.frames[frameIdx] or self.frames[1] or {0,0,16,16}
      local flip = (facing == "right") or (stepFlip and (facing == "up" or facing == "down"))

      local drawX = flip and (x + 16) or x
      local flipSx = flip and -1 or 1

      local scale = followerVisualScale(activeMon.species)
      if math.abs(scale - 1) < 0.0001
         or not (love and love.graphics and love.graphics.draw) then
        PaletteFX.markSpriteRedraw(followerImg, quad, drawX, y, flipSx, nil, false)
        return
      end

      -- Pivot around the feet so changing size never makes the follower float
      -- or sink into the map. The logical entity remains one 16x16 cell.
      local anchorX, anchorY = x + 8, y + 16
      local w, h = 16 * scale, 16 * scale
      if self.def.trueColor and PaletteFX.markTrueColor then
        PaletteFX.markTrueColor(math.floor(anchorX - w / 2),
          math.floor(anchorY - h), math.ceil(w), math.ceil(h))
      end
      local sx = flip and -scale or scale
      love.graphics.draw(followerImg, quad, anchorX, anchorY,
        0, sx, scale, 8, 16)
      return
    end
    return origSpriteDraw(self, px, py, camX, camY, facing, walkPhase, stepFlip)
  end
  SpriteRenderer.draw = wrappedSpriteDraw

  -- Dramatic Shape and its maintained forks bypass SpriteRenderer.draw in
  -- voxel mode and build a billboard directly from the sprite definition.
  -- Compose a narrowly tagged mesh hook with any existing mount-size hook so
  -- PokéPC Followers, Dramatic Sky Ride and the voxel provider can coexist.
  local function dramaticModule(name)
    if not mod.find then return nil end
    local providerIds = {
      "BATTLE_ART_VOXEL_FORK", "DRAMALESS_SHAPE", "DRAMATIC_SHAPE"
    }
    for _, id in ipairs(providerIds) do
      local okHandle, handle = pcall(mod.find, mod, id)
      local lib = okHandle and handle and handle.exports and handle.exports.lib
      if type(lib) == "table" and type(lib.require) == "function" then
        local okModule, value = pcall(lib.require, name)
        if okModule then return value end
      end
    end
    return nil
  end

  local function installFollowerVoxelSizeHook()
    local billboards = dramaticModule("SpriteBillboards")
    local voxel3D = dramaticModule("Voxel3D")
    if not (billboards and voxel3D and voxel3D.newMesh
            and voxel3D.pushQuad) then return false end

    local previousHook = billboards.pokepcFollowerSizeHook
    if previousHook then
      if previousHook.clear then pcall(previousHook.clear) end
      return true
    end

    local meshes = {}
    local function clearMeshes()
      for _, mesh in pairs(meshes) do
        if mesh and mesh.release then pcall(mesh.release, mesh) end
      end
      meshes = {}
    end

    local function buildCard(def, frame, scale)
      local okImage, image = pcall(Assets.image, def.image)
      if not (okImage and image) then return nil end
      local iw, ih = image:getDimensions()
      local fy = (tonumber(frame) or 0) * 16
      if fy + 16 > ih then fy = 0 end
      local u0, u1 = 0.02 / iw, (16 - 0.02) / iw
      local v0, v1 = (fy + 0.05) / ih, (fy + 15.95) / ih
      local halfWidth = 8 * scale
      local x0, x1 = 8 - halfWidth, 8 + halfWidth
      local y1 = 16 * scale
      local vertices = {
        { x0, 0,  0, u0, v1, 1 }, { x1, 0,  0, u1, v1, 1 },
        { x1, y1, 0, u1, v0, 1 }, { x0, y1, 0, u0, v0, 1 },
      }
      local indices = {}
      voxel3D.pushQuad(indices, 0)
      local okMesh, mesh = pcall(voxel3D.newMesh, vertices, indices)
      return okMesh and mesh or nil
    end

    local rawMesh = billboards.mesh
    local rawShadowQuad = billboards.shadowQuad
    local function scaledMesh(def, frame, fallback)
      local species = def and def.pokepcFollowerSpecies
      local scale = def and tonumber(def.pokepcFollowerVisualScale)
      if not species or not scale or math.abs(scale - 1) < 0.0001 then
        return fallback(def, frame)
      end
      local key = table.concat({ tostring(def.image), tostring(frame),
        tostring(species), string.format("%.4f", scale) }, "#")
      if meshes[key] == nil then
        meshes[key] = buildCard(def, frame, scale) or false
      end
      return meshes[key] or fallback(def, frame)
    end

    billboards.mesh = function(def, frame)
      return scaledMesh(def, frame, rawMesh)
    end
    billboards.shadowQuad = function(def, frame)
      return scaledMesh(def, frame, rawShadowQuad)
    end
    billboards.pokepcFollowerSizeHook = { clear = clearMeshes }
    if Assets.register then Assets.register(clearMeshes) end
    return true
  end

  -- ----------------------------------------------------------------------
  -- 9. PikachuFollower function wrappers
  -- ----------------------------------------------------------------------
  local function wrappedOnMapEntered(game, ow, opts)
    local mon = getActiveFollowerMon(game, true)
    if mon then configureSpriteDef(game, mon) end
    local result = originalOnMapEntered and originalOnMapEntered(game, ow, opts)
    if ow and not shouldSpawn(game, ow) then
      purgeFollowerEntities(ow)
    else
      syncLiveFollowerDef(game, ow)
    end
    return result
  end

  local function wrappedUpdate(game, ow, ...)
    local mon = getActiveFollowerMon(game, true)
    if mon then configureSpriteDef(game, mon) end
    local result = originalUpdate and originalUpdate(game, ow, ...)
    pcall(syncLiveFollowerDef, game, ow)
    return result
  end

  -- Talk wrapper for Red/Blue (and fallback for Yellow if needed)
  local function wrappedTalk(a, b, c, d)
    -- Normalise arguments
    local game = type(a) == "table" and a.save and a or liveGame()
    local ow = type(b) == "table" and b.entities and b or worldFor(game)
    local done = type(c) == "function" and c or d

    local npc = PikachuFollower.current(ow)
    local mon = getActiveFollowerMon(game, true)

    if not mon then
      if originalTalk then return originalTalk(a, b, c, d) end
      if done then done() end
      return
    end

    -- For Yellow's Pikachu, keep vanilla behaviour
    if isYellow and mon.species == "PIKACHU" and originalTalk then
      return originalTalk(a, b, c, d)
    end

    -- Finish any movement and face player
    if npc then
      if npc.moving then
        npc.cellX = npc.targetX or npc.cellX
        npc.cellY = npc.targetY or npc.cellY
        npc.targetX, npc.targetY = nil, nil
        npc.px, npc.py = npc.cellX * 16, npc.cellY * 16
        npc.moving, npc.marching = false, false
        npc.progress, npc.hopStep = 0, nil
      end
      npc.idle, npc.goalX, npc.goalY = nil, nil, nil
      if npc.facePlayer and ow and ow.player then
        pcall(npc.facePlayer, npc, ow.player)
      end
      if ow and ow.player and npc.facing then
        ow.player.facing = OPPOSITE[npc.facing] or ow.player.facing
      end
    end

    -- Play cry and show message
    pcall(Sound.playCry, game.data, mon.species)
    local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
    local name = mon.nickname or (def and def.name) or mon.species
    local text = Strings("%s is following\nyou!", name)
    game.stack:push(TextBox.new(game, text, done))
  end

  -- Gen 1 dispatches its stock follower before OverworldController.talkTo.
  -- Gold resolves every facing NPC through the adapter's talkTo seam instead,
  -- so bridge that seam to the same follower dialogue.
  local originalWorldTalkTo = OverworldController.talkTo
  local wrappedWorldTalkTo = function(ow, npc, ...)
    if npc and npc.pikachuFollower then
      wrappedTalk(liveGame(), ow, npc)
      return true
    end
    return originalWorldTalkTo(ow, npc, ...)
  end

  -- Apply wrappers
  if originalOnMapEntered then PikachuFollower.onMapEntered = wrappedOnMapEntered end
  if originalUpdate then PikachuFollower.update = wrappedUpdate end
  if originalTalk then PikachuFollower.talk = wrappedTalk end
  OverworldController.talkTo = wrappedWorldTalkTo

  -- ----------------------------------------------------------------------
  -- 10. PartyMenu enhancements (true‑color and sync)
  -- ----------------------------------------------------------------------
  -- Keep one stable wrapper for the lifetime of the process.  Its callbacks
  -- are refreshed on every mod reload, so a later wrapper (for example Unique
  -- Menu Icons) can remain outside it without causing PokePC to stack another
  -- copy underneath on the next reload.
  local partyMenuState = PartyMenu.__pokepcFollowersPartyMenu
  if not partyMenuState then
    partyMenuState = {
      originalDraw = PartyMenu.draw,
      originalUpdate = PartyMenu.update,
    }

    partyMenuState.wrapperDraw = function(self, ...)
      local result = partyMenuState.originalDraw and partyMenuState.originalDraw(self, ...)
      if partyMenuState.afterDraw then pcall(partyMenuState.afterDraw, self) end
      return result
    end
    partyMenuState.wrapperUpdate = function(self, dt)
      local result = partyMenuState.originalUpdate and partyMenuState.originalUpdate(self, dt)
      if partyMenuState.afterUpdate then pcall(partyMenuState.afterUpdate, self) end
      return result
    end

    PartyMenu.draw = partyMenuState.wrapperDraw
    PartyMenu.update = partyMenuState.wrapperUpdate
    PartyMenu.__pokepcFollowersPartyMenu = partyMenuState
  end

  partyMenuState.afterDraw = function(self)
    if colorMode() and not externalPartyIconOwner() then
      local party = (self.game and self.game.save and self.game.save.party) or {}
      for i = 1, #party do
        PaletteFX.markTrueColor(0, (i - 1) * 16, 32, 16)
      end
    end
  end

  partyMenuState.afterUpdate = function(self)
    local game = self.game
    local ow = worldFor(game)
    if not game or not ow then return end
    local follower = PikachuFollower.current(ow)
    if not follower then return end
    local active = getActiveFollowerMon(game, false)
    if not active then return end
    if follower._pokepcFollowerSpecies ~= active.species then
      syncLiveFollowerDef(game, ow)
    end
  end

  -- ----------------------------------------------------------------------
  -- 11. Party submenu hook (FOLLOWER / FOLLOWING)
  -- ----------------------------------------------------------------------
  local function selectFollower(mon, game, quiet)
    if not (mon and game and healthy(mon)) then return false end
    local party = game.save and game.save.party or {}
    local slot
    for i, candidate in ipairs(party) do
      if candidate == mon then slot = i break end
    end
    if not slot then return false end

    if mod.save then
      mod.save:set("selected_mon", monKey(mon))
      mod.save:set("selected_slot", slot)
    end
    game.save.followerPartyIndex = slot
    game.save.followerSpecies = mon.species

    syncLiveFollowerDef(game, worldFor(game))

    if not quiet then
      pcall(Sound.play, game.data, "Swap")
      local def = game.data and game.data.pokemon and game.data.pokemon[mon.species]
      local name = mon.nickname or (def and def.name) or mon.species
      local text = Strings("%s is now\nyour follower!", name)
      game.stack:push(TextBox.new(game, text))
    end
    return true
  end

  -- Use mod.hooks:wrap to add the menu item (preferred method)
  if mod.hooks then
    mod.hooks:wrap("ui.party.submenu", function(next, game, items, mon, ctx)
      local out = next(game, items, mon, ctx)
      if type(out) ~= "table" or (ctx and ctx.battle) or not healthy(mon) then
        return out
      end
      local active = getActiveFollowerMon(game, true)
      local label = Strings(active == mon and "FOLLOWING" or "FOLLOWER")
      out[#out + 1] = {
        label = label,
        onSelect = function(selected, selectedGame)
          selectFollower(selected, selectedGame, false)
        end,
      }
      return out
    end)
  end

  -- Fallback event listener (for older mod API)
  if mod.events then
    mod.events:on("ui.party.submenu", function(e)
      if not e.ctx or e.ctx.battle or not e.items or not e.mon or not e.game then return end
      if not healthy(e.mon) then return end
      local active = getActiveFollowerMon(e.game, true)
      local isCurrent = (active == e.mon)
      local label = Strings(isCurrent and "FOLLOWING" or "FOLLOWER")
      table.insert(e.items, {
        label = label,
        onSelect = function(selectedMon, game)
          selectFollower(selectedMon, game, false)
        end
      })
    end)
  end

  -- ----------------------------------------------------------------------
  -- 12. Yellow‑specific story overrides (optional)
  -- ----------------------------------------------------------------------
  if isYellow then
    mod.content.strings:override("PIKACHU", "CHARMANDER")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText1", "OAK: What?")
    mod.content.text:override("_OaksLabPikachuDislikesPokeballsText2",
      "OAK: It's strange!\nCHARMANDER hates being\nin a POKéBALL!\fYou should keep it\nwith you!\fIt should be happy\nif it walks with\nyou!")
    mod.content.text:override("_OaksLabOak1YouShouldTalkToIt",
      "OAK: Look at it!\nCHARMANDER seems to\nlike you!")

    -- The encounter hook has the same contract on both generations.
    mod.hooks:wrap("encounter.species", function(next, encounter, ctx)
      local rolled = next(encounter, ctx)
      if rolled and rolled.species == "PIKACHU" and rolled.level == 5 then
        rolled.species = "CHARMANDER"
      end
      return rolled
    end)
  end

  -- ----------------------------------------------------------------------
  -- 13. Hot‑reload restore state
  -- ----------------------------------------------------------------------
  local state = {
    originalUpdate = originalUpdate,
    originalOnMapEntered = originalOnMapEntered,
    originalTalk = originalTalk,
    originalStarterInParty = originalStarterInParty,
    wrapperUpdate = wrappedUpdate,
    wrapperOnMapEntered = wrappedOnMapEntered,
    wrapperTalk = wrappedTalk,
    originalWorldTalkTo = originalWorldTalkTo,
    wrapperWorldTalkTo = wrappedWorldTalkTo,
    wrapperStarterInParty = wrappedStarterInParty,
    originalShouldSpawn = vanillaShouldSpawn,
    originalOnMapEnteredShouldSpawn = vanillaOnMapEnteredShouldSpawn,
    wrapperResolveImage = wrappedResolveImage,
    wrapperSpriteDraw = wrappedSpriteDraw,
    usedShouldSpawnSetter = usedShouldSpawnSetter,
  }

  state.restore = function()
    -- Restore the second closure first. If update and onMapEntered share the
    -- same shouldSpawn upvalue, restoring update last still leaves the shared
    -- cell at the true vanilla function.
    if usedShouldSpawnSetter and vanillaShouldSpawn then
      PikachuFollower.setShouldSpawn(vanillaShouldSpawn)
    elseif originalOnMapEntered and vanillaOnMapEnteredShouldSpawn then
      replaceUpvalue(originalOnMapEntered, "shouldSpawn", vanillaOnMapEnteredShouldSpawn)
    end
    if not usedShouldSpawnSetter and originalUpdate and vanillaShouldSpawn then
      replaceUpvalue(originalUpdate, "shouldSpawn", vanillaShouldSpawn)
    end
    if PikachuFollower.update == wrappedUpdate then
      PikachuFollower.update = originalUpdate
    end
    if PikachuFollower.onMapEntered == wrappedOnMapEntered then
      PikachuFollower.onMapEntered = originalOnMapEntered
    end
    if PikachuFollower.talk == wrappedTalk then
      PikachuFollower.talk = originalTalk
    end
    if PikachuFollower.starterInParty == wrappedStarterInParty then
      PikachuFollower.starterInParty = originalStarterInParty
    end
    if OverworldController.talkTo == wrappedWorldTalkTo then
      OverworldController.talkTo = originalWorldTalkTo
    end
    -- Only remove wrappers that are still the outermost function. Mods loaded
    -- after PokePC may legitimately wrap these methods and must not be erased.
    if SpriteRenderer.resolveImage == wrappedResolveImage and origResolveImage then
      SpriteRenderer.resolveImage = origResolveImage
    end
    if SpriteRenderer.draw == wrappedSpriteDraw and origSpriteDraw then
      SpriteRenderer.draw = origSpriteDraw
    end
    if PikachuFollower.__pokepcFollowersUniversal == state then
      PikachuFollower.__pokepcFollowersUniversal = nil
    end
  end
  PikachuFollower.__pokepcFollowersUniversal = state

  -- Install immediately for hot reloads, then retry after every enabled mod
  -- has published its exports during a normal startup.
  installFollowerVoxelSizeHook()
  if mod.events then
    mod.events:once("mods.loaded", installFollowerVoxelSizeHook)
    mod.events:on("mod.options_changed", function(payload)
      if not (payload and payload.mod == mod.id) then return end
      local key = tostring(payload.key or "")
      if key ~= "pokedex_follower_sizes" and key ~= "follower_size_percent" then
        return
      end
      local game = liveGame()
      local mon = getActiveFollowerMon(game, false)
      if mon then configureSpriteDef(game, mon) end
      pcall(syncLiveFollowerDef, game, worldFor(game))
      installFollowerVoxelSizeHook()
    end)
  end

  -- ----------------------------------------------------------------------
  -- 14. Mod exports
  -- ----------------------------------------------------------------------
  if mod.exports then
    mod.exports.supported = true
    mod.exports.activeMon = function(game) return getActiveFollowerMon(game, true) end
    mod.exports.assetPath = assetPath
    mod.exports.dexForSpecies = dexForSpecies
    mod.exports.pokedexHeightMeters = pokedexHeightMeters
    mod.exports.followerVisualScale = followerVisualScale
    mod.exports.shouldSpawn = shouldSpawn
    mod.exports.sync = syncLiveFollowerDef
    mod.exports.select = selectFollower
    mod.exports.restore = state.restore
  end

  if mod.log then
    mod.log:info("PokéPC Followers loaded for %s", version)
  end
  print(string.format("[PokePCFollowers] Mod initialized successfully for %s.", version:upper()))
end
