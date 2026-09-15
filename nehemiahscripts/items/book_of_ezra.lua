local game = Game()

BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra") -- item id of Book of Ezra
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)
local doorsClosedForGreed = false -- tracks whether the raid is still waiting for Greed to die
local builtGideonDungeon = false -- true only for a dungeon this mod built, so a legitimate Great Gideon visit is left untouched
local raidingPlayer = nil -- the player who started the raid, remembered for the Member Card check on the Greed death

-- GREAT_GIDEON crawl space variant, written as a literal since this build exposes no CrawlSpaceVariant enum
local GIDEON_CRAWLSPACE_VARIANT = 1

-- Room config of "Gideon's Grave", the only ROOM_DUNGEON entry in SPECIAL_ROOMS naming Gideon, found by scanning every special room variant in game
local GIDEON_GRAVE_VARIANT = 1000

-- Reward overrides tried before the Member Card and default rewards; returning true claims the drop
POR.RaidRewardOverrides = POR.RaidRewardOverrides or {}

-- Returns a nonzero 32 bit seed, since the engine asserts on a zero room seed and Random() can legitimately roll zero
local function nonZeroSeed()
    local seed = Random()
    return seed ~= 0 and seed or 1
end

-- Fills the reserved but empty Gideon descriptor, as a crawl space into an unbuilt room crashes the engine
local function ensureGideonDungeon()
    local desc = game:GetLevel():GetRoomByIdx(GridRooms.ROOM_GIDEON_DUNGEON_IDX, -1)
    if not desc then return false end
    if desc.Data then return true end
    if type(RoomConfig) ~= "table" or type(RoomConfig.GetRoomByStageTypeAndVariant) ~= "function" then return false end

    local data = RoomConfig.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, RoomType.ROOM_DUNGEON, GIDEON_GRAVE_VARIANT, 0)
    if not data then return false end

    desc.Data = data
    if desc.SpawnSeed == 0 then desc.SpawnSeed = nonZeroSeed() end
    if desc.DecorationSeed == 0 then desc.DecorationSeed = nonZeroSeed() end
    if desc.AwardSeed == 0 then desc.AwardSeed = nonZeroSeed() end
    builtGideonDungeon = desc.Data ~= nil
    return builtGideonDungeon
end

-- Downgrades the loot in the grave, but only in a dungeon this mod built rather than a real Gideon fight
function POR:BookofEzraGraveEntity(entityType, variant, subType, gridIndex, seed)
    if not builtGideonDungeon then return end
    if game:GetLevel():GetCurrentRoomIndex() ~= GridRooms.ROOM_GIDEON_DUNGEON_IDX then return end
    if entityType ~= EntityType.ENTITY_PICKUP then return end

    if variant == PickupVariant.PICKUP_LOCKEDCHEST then
        return { EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_OLDCHEST, 0 }
    elseif variant == PickupVariant.PICKUP_COLLECTIBLE then
        return { EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_WOODENCHEST, 0 }
    end
end

-- Forgets the built dungeon on a floor change, since the descriptor the game reallocates is no longer the one this mod filled in
function POR.BookofEzraNewLevel()
    builtGideonDungeon = false
end

-- For Tainted Nehemiah in a shop, raids it instead of spawning the moonlight effect
function POR:BookofEzraUse(_, _, player)
    local room = game:GetRoom()

    if player:GetPlayerType() == TAINTED_NEHEMIAH_TYPE and room:GetType() == RoomType.ROOM_SHOP and POR.ShopRaid.CanRaid() then
        POR.ShopRaid.Begin(player, false)
        doorsClosedForGreed = true
        raidingPlayer = player
        return true
    end

    POR.EzrasMoonlight:SpawnMoonlight(room:GetCenterPos(), player)
    return true
end

-- Reopens the doors on the boss death and drops the reward: override, then the Gideon crawl space, then the shop trapdoor
function POR:BookofEzraGreedDeath(npc)
    if POR.ShopRaid.IsRaidBoss(npc) and doorsClosedForGreed then
        doorsClosedForGreed = false

        local inRaidRoom = POR.ShopRaid.IsInRaidRoom() -- read before Finish, which clears the room it was tracking
        POR.ShopRaid.Finish()

        local player = raidingPlayer
        raidingPlayer = nil
        if not inRaidRoom then return end
        if not player or not player:Exists() then
            game:GetRoom():TrySpawnSecretShop(true)
            return
        end

        for _, override in ipairs(POR.RaidRewardOverrides) do
            if override(player, npc) then return end
        end

        if player:HasCollectible(CollectibleType.COLLECTIBLE_MEMBER_CARD) and ensureGideonDungeon() then
            POR.ShopRaid.ClearTrapdoors()
            Isaac.GridSpawn(GridEntityType.GRID_STAIRS, GIDEON_CRAWLSPACE_VARIANT, npc.Position)
        else
            game:GetRoom():TrySpawnSecretShop(true)
        end
    end
end