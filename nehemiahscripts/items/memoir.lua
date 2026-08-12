MEMOIR_ITEM_ID = Isaac.GetItemIdByName("The Memoir") -- item id of The Memoir

local DAMAGE_DOWN = 0.4
local TEARS_DOWN = 0.4
local RANDOM_STAT_BONUS = 0.15
local RANDOM_STAT_COUNT = 3

-- Eligible pool for the 3 random +15% stats -- everything except Health, and excluding Angel/Devil/
-- Planetarium chance since those aren't cache-flag stats to begin with
local STAT_CACHE_FLAGS = {
    CacheFlag.CACHE_DAMAGE,
    CacheFlag.CACHE_FIREDELAY,
    CacheFlag.CACHE_SPEED,
    CacheFlag.CACHE_RANGE,
    CacheFlag.CACHE_SHOTSPEED,
    CacheFlag.CACHE_LUCK,
}
local ALL_STAT_FLAGS = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SPEED
    | CacheFlag.CACHE_RANGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_LUCK
POR.MEMOIR_CACHE_FLAGS = ALL_STAT_FLAGS -- exposed for the MC_EVALUATE_CACHE registration in main.lua

-- Rolls the 3 bonus stats once per player and remembers the choice for the rest of the run
local function getMemoirStats(player)
    local pData = player:GetData()
    if not pData.POR_MemoirStats then
        local pool = {}
        for _, flag in ipairs(STAT_CACHE_FLAGS) do table.insert(pool, flag) end

        local chosen = {}
        for _ = 1, RANDOM_STAT_COUNT do
            chosen[table.remove(pool, math.random(#pool))] = true
        end
        pData.POR_MemoirStats = chosen
    end
    return pData.POR_MemoirStats
end

function POR.MemoirEvaluateCache(_, player, cacheFlag)
    if not player:HasCollectible(MEMOIR_ITEM_ID) then return end
    local stats = getMemoirStats(player)

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage - DAMAGE_DOWN
        if stats[CacheFlag.CACHE_DAMAGE] then player.Damage = player.Damage * (1 + RANDOM_STAT_BONUS) end
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        -- Tears stat <-> MaxFireDelay conversion: tears = 30 / (delay + 1)
        local tears = 30 / (player.MaxFireDelay + 1) - TEARS_DOWN
        if stats[CacheFlag.CACHE_FIREDELAY] then tears = tears * (1 + RANDOM_STAT_BONUS) end
        player.MaxFireDelay = 30 / math.max(tears, 0.2) - 1 -- clamped so delay never goes negative/infinite
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        if stats[CacheFlag.CACHE_SPEED] then player.MoveSpeed = player.MoveSpeed * (1 + RANDOM_STAT_BONUS) end
    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        if stats[CacheFlag.CACHE_RANGE] then player.TearRange = player.TearRange * (1 + RANDOM_STAT_BONUS) end
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        if stats[CacheFlag.CACHE_SHOTSPEED] then player.ShotSpeed = player.ShotSpeed * (1 + RANDOM_STAT_BONUS) end
    elseif cacheFlag == CacheFlag.CACHE_LUCK then
        if stats[CacheFlag.CACHE_LUCK] then player.Luck = player.Luck * (1 + RANDOM_STAT_BONUS) end
    end
end

-- Tear-repelling aura: re-triggers Windflower's Telekinesis trick on a timer instead of a standstill
-- check, so it never lapses (see dumb_luck.lua)
local TELEKINESIS_REFRESH_FRAMES = 60 -- ~2 seconds at 30fps

function POR.MemoirRefreshAura(_, player)
    if not player:HasCollectible(MEMOIR_ITEM_ID) then return end

    local pData = player:GetData()
    local lastTrigger = pData.POR_MemoirLastTelekinesis or -math.huge
    if Isaac.GetFrameCount() - lastTrigger < TELEKINESIS_REFRESH_FRAMES then return end

    pData.POR_MemoirLastTelekinesis = Isaac.GetFrameCount()
    player:UseActiveItem(CollectibleType.COLLECTIBLE_TELEKINESIS, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
end
