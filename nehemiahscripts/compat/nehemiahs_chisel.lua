-- Compat with the Tainted Treasure Rooms mod, which loads after this one, so the TaintedTreasure global is checked when a hook actually fires rather than at load time like compat/eid.lua does

local game = POR.game

local CHISEL = {}
POR.NehemiahsChisel = CHISEL

NEHEMIAHSCHISEL_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Chisel") -- item id of Nehemiah's Chisel

local CHISEL_ANM2 = "gfx/nehemiahs_chisel.anm2"
local ROCK_DROP_CHANCE = 0.10 -- plus 1% per point of luck
local ROCK_DROP_LUCK_STEP = 0.01

local chiselOwner = nil -- the player holding the chisel weapon, cleared when the effect ends

local DEBUG = true -- TEMPORARY: traces the weapon handoff for the chisel to log.txt, set false or strip once it works
local debugFrame = 0 -- throttles the per frame trace so the log stays readable

-- Writes one traced line to log.txt and the debug console at once
local function log(text)
    if not DEBUG then return end
    Isaac.DebugString("[POR CHISEL] " .. text)
    print("[POR CHISEL] " .. text)
end

-- Pickups a shattered rock can cough up, deliberately holding no collectibles or chests
local ROCK_DROP_TABLE = {
    { PickupVariant.PICKUP_HEART,       HeartSubType.HEART_FULL },
    { PickupVariant.PICKUP_HEART,       HeartSubType.HEART_HALF },
    { PickupVariant.PICKUP_HEART,       HeartSubType.HEART_SOUL },
    { PickupVariant.PICKUP_COIN,        CoinSubType.COIN_PENNY },
    { PickupVariant.PICKUP_COIN,        CoinSubType.COIN_NICKEL },
    { PickupVariant.PICKUP_KEY,         KeySubType.KEY_NORMAL },
    { PickupVariant.PICKUP_BOMB,        BombSubType.BOMB_NORMAL },
    { PickupVariant.PICKUP_TAROTCARD,   0 },
    { PickupVariant.PICKUP_PILL,        0 },
    { PickupVariant.PICKUP_LIL_BATTERY, BatterySubType.BATTERY_NORMAL },
}

-- Registers the chisel as the tainted counterpart to the hammer, which the API for that mod asks to be done once a run is underway
function CHISEL.OnGameStarted()
    log("game started, TaintedTreasure=" .. tostring(TaintedTreasure ~= nil)
        .. " chiselId=" .. tostring(NEHEMIAHSCHISEL_ITEM_ID)
        .. " hammerId=" .. tostring(NEHEMIAHSHAMMER_ITEM_ID)
        .. " WEAPON_KNIFE=" .. tostring(WeaponType and WeaponType.WEAPON_KNIFE))

    if not TaintedTreasure then
        log("TaintedTreasure global absent, chisel stays inert")
        return
    end
    if not TaintedTreasure.AddTaintedTreasure then
        log("AddTaintedTreasure missing on the TaintedTreasure global")
        return
    end
    TaintedTreasure:AddTaintedTreasure(NEHEMIAHSHAMMER_ITEM_ID, NEHEMIAHSCHISEL_ITEM_ID)
    log("registered counterpart hammer=" .. tostring(NEHEMIAHSHAMMER_ITEM_ID) .. " chisel=" .. tostring(NEHEMIAHSCHISEL_ITEM_ID))
end

-- Hands the player the knife and keeps it until the room changes
function POR:NehemiahsChiselUse(item, rng, player)
    if not TaintedTreasure then return end

    chiselOwner = player
    debugFrame = 0

    player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
    player:EvaluateItems()

    log("used by playerType=" .. tostring(player:GetPlayerType()))

    return { Discharge = true, Remove = false, ShowAnim = true }
end

-- Turns the granted weapon into a knife, which is only enabled while the chisel effect is running
function CHISEL.OnEvaluateCache(_, player)
    if not chiselOwner or player:GetPlayerIndex() ~= chiselOwner:GetPlayerIndex() then return end

    local ok, err = pcall(player.EnableWeaponType, player, WeaponType.WEAPON_KNIFE, true)
    log("EnableWeaponType(KNIFE) ok=" .. tostring(ok) .. (ok and "" or (" err=" .. tostring(err))))
end

-- Resolves the player a knife belongs to, following the parent chain the way the Broken Bottle in Tainted Treasure does so familiar and multi shot knives are covered
local function knifeOwner(knife)
    local parent = knife.Parent
    if not parent then return nil end

    local player = parent:ToPlayer()
    if player then return player end

    local familiar = parent:ToFamiliar()
    if familiar then return familiar.Player end

    local parentKnife = parent:ToKnife()
    if parentKnife and parentKnife:GetData().POR_ChiselKnife then
        return knifeOwner(parentKnife)
    end
    return nil
end

-- Dresses a knife in the chisel art, re-checked rather than reloaded blindly since the engine rebuilds knife sprites
local function skinChisel(knife)
    local sprite = knife:GetSprite()
    if sprite:GetFilename() == CHISEL_ANM2 then return end

    sprite:Load(CHISEL_ANM2, true)
    sprite:Play("Idle", true)
end

-- Rolls the luck scaled chance for a rock to cough up a pickup, capped so high luck cannot exceed a guaranteed drop
local function rollRockDrop(player, position)
    local chance = math.min(1, ROCK_DROP_CHANCE + player.Luck * ROCK_DROP_LUCK_STEP)
    if math.random() >= chance then return end

    local choice = ROCK_DROP_TABLE[math.random(1, #ROCK_DROP_TABLE)]
    local vel = Vector.FromAngle(math.random() * 360) * (math.random() * 3 + 1)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, choice[1], choice[2], position, vel, player)
end

-- Tiles sampled around the knife, mirroring the check in nehemiahs_hammer.lua rather than walking the whole grid every frame
local ROCK_CHECK_OFFSETS = {
    Vector(0, 0),
    Vector(20, 0),
    Vector(-20, 0),
    Vector(0, 20),
    Vector(0, -20),
}

-- Shatters every breakable rock a chisel knife overlaps, since the chisel cuts through stone rather than swinging at it
local function shatterRocks(player, knife)
    local room = game:GetRoom()
    for _, offset in ipairs(ROCK_CHECK_OFFSETS) do
        local index = room:GetGridIndex(knife.Position + offset)
        local gridEntity = room:GetGridEntity(index)
        if gridEntity and gridEntity:ToRock() and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE then
            gridEntity:Destroy(true)
            rollRockDrop(player, room:GetGridPosition(index))
        end
    end
end

-- Claims every knife the chisel owner puts out, including the extra ones Mom's Knife synergies spawn, so none of them revert to the vanilla blade
function CHISEL.OnKnifeUpdate(_, knife)
    if knife.Variant ~= 0 then return end

    local data = knife:GetData()
    local player = chiselOwner

    if not data.POR_ChiselKnife then
        if not player or not player:Exists() then return end

        local owner = knifeOwner(knife)
        if not owner or owner:GetPlayerIndex() ~= player:GetPlayerIndex() then return end

        data.POR_ChiselKnife = true
        debugFrame = 0
        log("claimed knife " .. knife.Type .. "." .. knife.Variant .. " parent=" .. tostring(knife.Parent and knife.Parent.Type))
    end

    if not player or not player:Exists() then return end

    skinChisel(knife)
    shatterRocks(player, knife)

    debugFrame = debugFrame + 1
    if DEBUG and debugFrame % 60 == 1 then
        log("knife active, sheet=" .. tostring(knife:GetSprite():GetFilename()))
    end
end

-- Drops the knife when the room changes, so the chisel lasts a room rather than the whole run
function CHISEL.OnNewRoom()
    if not chiselOwner or not chiselOwner:Exists() then
        chiselOwner = nil
        return
    end

    local player = chiselOwner
    chiselOwner = nil
    player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
    player:EvaluateItems()
end

return CHISEL
