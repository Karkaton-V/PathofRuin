local game = Game()

HAPPYHOUR_ITEM_ID = Isaac.GetItemIdByName("Happy Hour") -- item id of Happy Hour

local WORM_TRINKETS = {
    TrinketType.TRINKET_PULSE_WORM,
    TrinketType.TRINKET_WIGGLE_WORM,
    TrinketType.TRINKET_RING_WORM,
    TrinketType.TRINKET_FLAT_WORM,
    TrinketType.TRINKET_HOOK_WORM,
    TrinketType.TRINKET_WHIP_WORM,
    TrinketType.TRINKET_TAPE_WORM,
    TrinketType.TRINKET_LAZY_WORM,
    TrinketType.TRINKET_BRAIN_WORM,
}

-- Worms whose main effect is a single TearFlag
local WORM_TEAR_FLAGS = {
    [TrinketType.TRINKET_PULSE_WORM] = TearFlags.TEAR_PULSE,
    [TrinketType.TRINKET_WIGGLE_WORM] = TearFlags.TEAR_WIGGLE,
    [TrinketType.TRINKET_RING_WORM] = TearFlags.TEAR_SPIRAL,
    [TrinketType.TRINKET_FLAT_WORM] = TearFlags.TEAR_FLAT,
    [TrinketType.TRINKET_HOOK_WORM] = TearFlags.TEAR_SQUARE,
    [TrinketType.TRINKET_BRAIN_WORM] = TearFlags.TEAR_TURN_HORIZONTAL,
}

-- Worms that add a flat amount to Shot Speed instead of a TearFlag
local WORM_SHOT_SPEED = {
    [TrinketType.TRINKET_WHIP_WORM] = 0.5,
    [TrinketType.TRINKET_LAZY_WORM] = -0.5,
}

-- Worms that modify Range instead of a TearFlag; TAPE also doubles range, LAZY only adds flat range
local WORM_RANGE_FLAT = {
    [TrinketType.TRINKET_TAPE_WORM] = 3,
    [TrinketType.TRINKET_LAZY_WORM] = 4,
}
local WORM_RANGE_MULT = {
    [TrinketType.TRINKET_TAPE_WORM] = 2,
}

local STAT_MULT = 1.1 -- 10% all stats
local STAT_CACHE_FLAGS = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SPEED
    | CacheFlag.CACHE_RANGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_LUCK | CacheFlag.CACHE_TEARFLAG

-- Grants a 10% all-stats boost and a random worm trinket's effect, both lasting only the current room
function POR:HappyHourUse(_, rng, player)
    local pData = player:GetData()
    pData.POR_HappyHourActive = true
    pData.POR_HappyHourWorm = WORM_TRINKETS[math.random(1, #WORM_TRINKETS)]

    player:AddCacheFlags(STAT_CACHE_FLAGS, true)
    player:EvaluateItems()

    return true
end

-- Applies the flat 10% all-stats boost, plus the chosen worm's specific effect, while Happy Hour is active
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    local pData = player:GetData()
    if not pData.POR_HappyHourActive then return end

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage * STAT_MULT
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay / STAT_MULT
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed * STAT_MULT
    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        player.TearRange = player.TearRange * STAT_MULT
        local flat = WORM_RANGE_FLAT[pData.POR_HappyHourWorm]
        local mult = WORM_RANGE_MULT[pData.POR_HappyHourWorm]
        if flat then player.TearRange = player.TearRange + flat * 10 end -- approximate scaling; tune if range feels off
        if mult then player.TearRange = player.TearRange * mult end
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed * STAT_MULT
        local bonus = WORM_SHOT_SPEED[pData.POR_HappyHourWorm]
        if bonus then player.ShotSpeed = player.ShotSpeed + bonus end
    elseif cacheFlag == CacheFlag.CACHE_LUCK then
        player.Luck = player.Luck * STAT_MULT
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        local tearFlag = WORM_TEAR_FLAGS[pData.POR_HappyHourWorm]
        if tearFlag then player.TearFlags = player.TearFlags | tearFlag end
    end
end)

-- Clears the stat boost and worm effect
local function clearHappyHour(player)
    local pData = player:GetData()
    if pData.POR_HappyHourActive then
        pData.POR_HappyHourActive = false
        pData.POR_HappyHourWorm = nil
        player:AddCacheFlags(STAT_CACHE_FLAGS, true)
        player:EvaluateItems()
    end
end

-- Both effects expire when entering a new room or a new floor
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    POR:ForEachPlayer(clearHappyHour)
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    POR:ForEachPlayer(clearHappyHour)
end)