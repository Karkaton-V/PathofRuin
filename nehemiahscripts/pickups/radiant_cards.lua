local game = Game()

local RADIANT_CARDS = {}
POR.RadiantCards = RADIANT_CARDS

-- Card ids, looked up by their "hud" attribute in pocketitems.xml
RADIANT_CARDS.FOOL_ID       = Isaac.GetCardIdByName("FFool")
RADIANT_CARDS.MAGICIAN_ID   = Isaac.GetCardIdByName("FMagician")
RADIANT_CARDS.PRIESTESS_ID  = Isaac.GetCardIdByName("FHighPriestess")
RADIANT_CARDS.EMPRESS_ID    = Isaac.GetCardIdByName("FEmpress")
RADIANT_CARDS.EMPEROR_ID    = Isaac.GetCardIdByName("FEmperor")
RADIANT_CARDS.HIEROPHANT_ID = Isaac.GetCardIdByName("FHierophant")
RADIANT_CARDS.LOVERS_ID     = Isaac.GetCardIdByName("FLovers")
RADIANT_CARDS.CHARIOT_ID    = Isaac.GetCardIdByName("FChariot")
RADIANT_CARDS.JUSTICE_ID    = Isaac.GetCardIdByName("FJustice")
RADIANT_CARDS.HERMIT_ID     = Isaac.GetCardIdByName("FHermit")
RADIANT_CARDS.FORTUNE_ID    = Isaac.GetCardIdByName("FWheelOfFortune")
RADIANT_CARDS.STRENGTH_ID   = Isaac.GetCardIdByName("FStrength")
RADIANT_CARDS.HANGED_ID     = Isaac.GetCardIdByName("FHangedMan")
RADIANT_CARDS.DEATH_ID      = Isaac.GetCardIdByName("FDeath")
RADIANT_CARDS.TEMPERANCE_ID = Isaac.GetCardIdByName("FTemperance")
RADIANT_CARDS.DEVIL_ID      = Isaac.GetCardIdByName("FDevil")
RADIANT_CARDS.TOWER_ID      = Isaac.GetCardIdByName("FTower")
RADIANT_CARDS.STAR_ID       = Isaac.GetCardIdByName("FStar")
RADIANT_CARDS.MOON_ID       = Isaac.GetCardIdByName("FMoon")
RADIANT_CARDS.SUN_ID        = Isaac.GetCardIdByName("FSun")
RADIANT_CARDS.JUDGEMENT_ID  = Isaac.GetCardIdByName("FJudgement")
RADIANT_CARDS.WORLD_ID      = Isaac.GetCardIdByName("FWorld")

-- Re-applies each card's HUD icon from ui_cardfronts.anm2, in case the native hud= link desyncs
local function SetCardFront(cardId, animName)
    if not cardId or cardId == 0 then return end
    local cardConfig = Isaac.GetItemConfig():GetCard(cardId)
    if not cardConfig or not cardConfig.ModdedCardFront then return end
    cardConfig.ModdedCardFront:Load("gfx/ui_cardfronts.anm2", true)
    cardConfig.ModdedCardFront:Play(animName, true)
end

SetCardFront(RADIANT_CARDS.FOOL_ID, "FFool")
SetCardFront(RADIANT_CARDS.MAGICIAN_ID, "FMagician")
SetCardFront(RADIANT_CARDS.PRIESTESS_ID, "FHighPriestess")
SetCardFront(RADIANT_CARDS.EMPRESS_ID, "FEmpress")
SetCardFront(RADIANT_CARDS.EMPEROR_ID, "FEmperor")
SetCardFront(RADIANT_CARDS.HIEROPHANT_ID, "FHierophant")
SetCardFront(RADIANT_CARDS.LOVERS_ID, "FLovers")
SetCardFront(RADIANT_CARDS.CHARIOT_ID, "FChariot")
SetCardFront(RADIANT_CARDS.JUSTICE_ID, "FJustice")
SetCardFront(RADIANT_CARDS.HERMIT_ID, "FHermit")
SetCardFront(RADIANT_CARDS.FORTUNE_ID, "FWheelOfFortune")
SetCardFront(RADIANT_CARDS.STRENGTH_ID, "FStrength")
SetCardFront(RADIANT_CARDS.HANGED_ID, "FHangedMan")
SetCardFront(RADIANT_CARDS.DEATH_ID, "FDeath")
SetCardFront(RADIANT_CARDS.TEMPERANCE_ID, "FTemperance")
SetCardFront(RADIANT_CARDS.DEVIL_ID, "FDevil")
SetCardFront(RADIANT_CARDS.TOWER_ID, "FTower")
SetCardFront(RADIANT_CARDS.STAR_ID, "FStar")
SetCardFront(RADIANT_CARDS.MOON_ID, "FMoon")
SetCardFront(RADIANT_CARDS.SUN_ID, "FSun")
SetCardFront(RADIANT_CARDS.JUDGEMENT_ID, "FJudgement")
SetCardFront(RADIANT_CARDS.WORLD_ID, "FWorld")

local JUSTICE_PICKUPS = {
    { PickupVariant.PICKUP_BOMB, BombSubType.BOMB_DOUBLEPACK },
    { PickupVariant.PICKUP_KEY, KeySubType.KEY_DOUBLEPACK },
    { PickupVariant.PICKUP_COIN, CoinSubType.COIN_DOUBLEPACK },
    { PickupVariant.PICKUP_HEART, HeartSubType.HEART_DOUBLEPACK },
}

local TELEPORT_PRIORITY = {
    RoomType.ROOM_MINIBOSS,  -- Boss Challenge Room
    RoomType.ROOM_CHALLENGE, -- Challenge Room
    RoomType.ROOM_SACRIFICE, -- Sacrifice Room
    RoomType.ROOM_CURSE,     -- Cursed Room
}

-- Forget Me Now, then Removes Curses
function RADIANT_CARDS:Fool(player)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_FORGET_ME_NOW, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)

    local level = game:GetLevel()
    local labyrinthBit = 1 << (Isaac.GetCurseIdByName("Curse of the Labyrinth") - 1)
    level:RemoveCurses(level:GetCurses() & ~labyrinthBit)
end

local MAGICIAN_CACHE_FLAGS = CacheFlag.CACHE_RANGE | CacheFlag.CACHE_FIREDELAY

-- Gives Continuum, doubles range, and triples tears; all removed on room/floor change
function RADIANT_CARDS:Magician(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_CONTINUUM, 0, false)
    player:GetData().POR_MagicianActive = true
    player:AddCacheFlags(MAGICIAN_CACHE_FLAGS, true)
    player:EvaluateItems()
end

-- Applies the Magician's range/tears bonus while active
function RADIANT_CARDS.MagicianCache(player, cacheFlag)
    if not player:GetData().POR_MagicianActive then return end

    if cacheFlag == CacheFlag.CACHE_RANGE then
        player.TearRange = player.TearRange * 2
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay / 3
    end
end

-- Clears the Magician's Continuum, range, and tears bonus
function RADIANT_CARDS.ClearMagician(player)
    local pData = player:GetData()
    if pData.POR_MagicianActive then
        pData.POR_MagicianActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_CONTINUUM)
        player:AddCacheFlags(MAGICIAN_CACHE_FLAGS, true)
        player:EvaluateItems()
    end
end

-- Summons Mom's Hand in a top corner of the room
function RADIANT_CARDS:Priestess(player)
    local room = game:GetRoom()
    local useLeft = math.random() < 0.5
    local cornerX = useLeft and room:GetTopLeftPos().X or room:GetBottomRightPos().X
    local insetX = useLeft and 60 or -60
    local pos = Vector(cornerX + insetX, room:GetTopLeftPos().Y + 60)

    Isaac.Spawn(213, 0, 0, pos, Vector.Zero, player)
end

-- Gives Abaddon, removed on room/floor change
function RADIANT_CARDS:Empress(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_ABADDON, 0, false)
    player:GetData().POR_EmpressActive = true
end

-- Clears the Empress's Abaddon
function RADIANT_CARDS.ClearEmpress(player)
    local pData = player:GetData()
    if pData.POR_EmpressActive then
        pData.POR_EmpressActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_ABADDON)
    end
end

-- Teleports to the first Boss Challenge, Challenge, Sacrifice, or Cursed Room found
function RADIANT_CARDS:Emperor(player)
    local rooms = game:GetLevel():GetRooms()

    for _, roomType in ipairs(TELEPORT_PRIORITY) do
        for i = 0, #rooms - 1 do
            local roomDesc = rooms:Get(i)
            if roomDesc.GridIndex ~= -1 and roomDesc.Data and roomDesc.Data.Type == roomType then
                game:StartRoomTransition(roomDesc.SafeGridIndex, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT)
                return
            end
        end
    end
end

-- Spawns 2 Gold Hearts around Isaac, offset to either side rather than directly on top of him
function RADIANT_CARDS:Hierophant(player)
    local room = game:GetRoom()

    for i = 1, 2 do
        local angle = (i - 1) * 180 + math.random() * 60 - 30
        local offset = Vector.FromAngle(angle) * 40
        local pos = room:FindFreePickupSpawnPosition(player.Position + offset, 40)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_HEART, HeartSubType.HEART_GOLDEN, pos, Vector.Zero, player)
    end
end
-- Mimics Yum Heart, then spawns The Heart item pedestal nearby
function RADIANT_CARDS:Lovers(player)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_YUM_HEART, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)

    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(player.Position, 40)
    Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, CollectibleType.COLLECTIBLE_HEART, pos, Vector.Zero, player)
end
-- Gives Leo for the room, without its costume
function RADIANT_CARDS:Chariot(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_LEO, 0, false)
    player:TryRemoveCollectibleCostume(CollectibleType.COLLECTIBLE_LEO, false)
    player:GetData().POR_ChariotActive = true
end

-- Defensively keeps Leo's costume suppressed each tick, in case it reapplies on its own
function RADIANT_CARDS.ChariotSuppressCostume(player)
    if player:GetData().POR_ChariotActive then
        player:TryRemoveCollectibleCostume(CollectibleType.COLLECTIBLE_LEO, false)
    end
end

-- Clears the Chariot's Leo
function RADIANT_CARDS.ClearChariot(player)
    local pData = player:GetData()
    if pData.POR_ChariotActive then
        pData.POR_ChariotActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_LEO)
    end
end
-- Spawns a Bomb, Key, Coin, and Heart Doublepack spread around Isaac
function RADIANT_CARDS:Justice(player)
    local room = game:GetRoom()

    for i, pickupData in ipairs(JUSTICE_PICKUPS) do
        local angle = (i - 1) * 90 + math.random() * 30 - 15
        local offset = Vector.FromAngle(angle) * 40
        local pos = room:FindFreePickupSpawnPosition(player.Position + offset, 40)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, pickupData[1], pickupData[2], pos, Vector.Zero, player)
    end
end
-- Summons a trapdoor to the Member Card (secret) shop
function RADIANT_CARDS:Hermit(player)
    game:GetRoom():TrySpawnSecretShop(true)
end
-- Spawns a Crane Game below Isaac
function RADIANT_CARDS:Fortune(player)
    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 40), 40)
    Isaac.Spawn(EntityType.ENTITY_SLOT, SlotVariant.CRANE_GAME, 0, pos, Vector.Zero, player)
end
-- Mimics Mega Mush
function RADIANT_CARDS:Strength(player)
    player:UseActiveItem(CollectibleType.COLLECTIBLE_MEGA_MUSH, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
end
-- Mimics Keeper's Box 3 times, 5 frames apart
function RADIANT_CARDS:Hanged(player)
    for i = 0, 2 do
        POR.scrum_master_schedule.Schedule(i * 5, function()
            if player and player:Exists() then
                player:UseActiveItem(CollectibleType.COLLECTIBLE_KEEPERS_BOX, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
            end
        end)
    end
end
-- Gives Death's List and Death's Touch, removed on room/level change
function RADIANT_CARDS:Death(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_DEATHS_LIST, 0, false)
    player:AddCollectible(CollectibleType.COLLECTIBLE_DEATHS_TOUCH, 0, false)
    player:GetData().POR_DeathActive = true
end

-- Clears Death's List and Death's Touch
function RADIANT_CARDS.ClearDeath(player)
    local pData = player:GetData()
    if pData.POR_DeathActive then
        pData.POR_DeathActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_DEATHS_LIST)
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_DEATHS_TOUCH)
    end
end
-- Spawns a Confessional below Isaac
function RADIANT_CARDS:Temperance(player)
    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(player.Position + Vector(0, 40), 40)
    Isaac.Spawn(EntityType.ENTITY_SLOT, SlotVariant.CONFESSIONAL, 0, pos, Vector.Zero, player)
end
-- Mimics Lemegeton 3 times, 5 frames apart
function RADIANT_CARDS:Devil(player)
    for i = 0, 2 do
        POR.scrum_master_schedule.Schedule(i * 5, function()
            if player and player:Exists() then
                player:UseActiveItem(CollectibleType.COLLECTIBLE_LEMEGETON, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
            end
        end)
    end
end
-- Spawns 3 live Giga Bombs at random positions in the room
function RADIANT_CARDS:Tower(player)
    for _ = 1, 3 do
        local pos = POR:GetRandomRoomTile()
        Isaac.Spawn(4, 17, 0, pos, Vector.Zero, player)
    end
end
-- Teleports to the Planetarium
function RADIANT_CARDS:Star(player)
    Isaac.ExecuteCommand("goto s.planetarium.0")
end
-- Force-opens the door to the Super Secret Room, then teleports there
function RADIANT_CARDS:Moon(player)
    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door and door.TargetRoomType == RoomType.ROOM_SUPERSECRET then
            door:Open()
        end
    end

    local rooms = game:GetLevel():GetRooms()
    for i = 0, #rooms - 1 do
        local roomDesc = rooms:Get(i)
        if roomDesc.GridIndex ~= -1 and roomDesc.Data and roomDesc.Data.Type == RoomType.ROOM_SUPERSECRET then
            game:StartRoomTransition(roomDesc.SafeGridIndex, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT)
            return
        end
    end
end
-- +2 soul hearts, reveals the map, clears Lost/Blind, and gives Star of Bethlehem for the floor
function RADIANT_CARDS:Sun(player)
    player:AddSoulHearts(4) -- 1 unit = half a heart

    local level = game:GetLevel()
    local rooms = level:GetRooms()
    for i = 0, #rooms - 1 do
        local roomDesc = rooms:Get(i)
        if roomDesc.GridIndex ~= -1 then
            roomDesc.DisplayFlags = 0xFFFF
        end
    end

    local curses = level:GetCurses()
    local lostBit = 1 << (Isaac.GetCurseIdByName("Curse of the Lost") - 1)
    local blindBit = 1 << (Isaac.GetCurseIdByName("Curse of the Blind") - 1)
    level:RemoveCurses(curses & (lostBit | blindBit))

    player:AddCollectible(CollectibleType.COLLECTIBLE_STAR_OF_BETHLEHEM, 0, false)
    player:GetData().POR_SunActive = true
end

-- Clears Star of Bethlehem at the start of the next level
function RADIANT_CARDS.ClearSun(player)
    local pData = player:GetData()
    if pData.POR_SunActive then
        pData.POR_SunActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_STAR_OF_BETHLEHEM)
    end
end
-- Spawns a Battery Bum, with a 5% chance to spawn a Rotten Beggar instead
function RADIANT_CARDS:Judgement(player)
    local room = game:GetRoom()
    local pos = room:FindFreePickupSpawnPosition(player.Position, 40)

    local variant = 13 -- Battery Bum
    if math.random() < 0.05 then
        variant = 18 -- Rotten Beggar
    end

    Isaac.Spawn(6, variant, 0, pos, Vector.Zero, player)
end
-- Force opens all doors in the room and spawns an unlocked trapdoor south of Isaac
function RADIANT_CARDS:World(player)
    local room = game:GetRoom()

    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            door:Open()
        end
    end

    local pos = player.Position + Vector(0, 80)
    Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, pos, true)
end

-- Maps each card id to its handler function
local CARD_HANDLERS = {
    [RADIANT_CARDS.FOOL_ID]       = RADIANT_CARDS.Fool,
    [RADIANT_CARDS.MAGICIAN_ID]   = RADIANT_CARDS.Magician,
    [RADIANT_CARDS.PRIESTESS_ID]  = RADIANT_CARDS.Priestess,
    [RADIANT_CARDS.EMPRESS_ID]    = RADIANT_CARDS.Empress,
    [RADIANT_CARDS.EMPEROR_ID]    = RADIANT_CARDS.Emperor,
    [RADIANT_CARDS.HIEROPHANT_ID] = RADIANT_CARDS.Hierophant,
    [RADIANT_CARDS.LOVERS_ID]     = RADIANT_CARDS.Lovers,
    [RADIANT_CARDS.CHARIOT_ID]    = RADIANT_CARDS.Chariot,
    [RADIANT_CARDS.JUSTICE_ID]    = RADIANT_CARDS.Justice,
    [RADIANT_CARDS.HERMIT_ID]     = RADIANT_CARDS.Hermit,
    [RADIANT_CARDS.FORTUNE_ID]    = RADIANT_CARDS.Fortune,
    [RADIANT_CARDS.STRENGTH_ID]   = RADIANT_CARDS.Strength,
    [RADIANT_CARDS.HANGED_ID]     = RADIANT_CARDS.Hanged,
    [RADIANT_CARDS.DEATH_ID]      = RADIANT_CARDS.Death,
    [RADIANT_CARDS.TEMPERANCE_ID] = RADIANT_CARDS.Temperance,
    [RADIANT_CARDS.DEVIL_ID]      = RADIANT_CARDS.Devil,
    [RADIANT_CARDS.TOWER_ID]      = RADIANT_CARDS.Tower,
    [RADIANT_CARDS.STAR_ID]       = RADIANT_CARDS.Star,
    [RADIANT_CARDS.MOON_ID]       = RADIANT_CARDS.Moon,
    [RADIANT_CARDS.SUN_ID]        = RADIANT_CARDS.Sun,
    [RADIANT_CARDS.JUDGEMENT_ID]  = RADIANT_CARDS.Judgement,
    [RADIANT_CARDS.WORLD_ID]      = RADIANT_CARDS.World,
}

-- Dispatches to the matching card's effect stub on use
function RADIANT_CARDS.UseCard(card, player)
    local handler = CARD_HANDLERS[card]
    if handler then
        handler(RADIANT_CARDS, player)
    end
end

-- Clears all room-scoped card buffs
function RADIANT_CARDS.ClearRoomBuffs(player)
    RADIANT_CARDS.ClearMagician(player)
    RADIANT_CARDS.ClearEmpress(player)
    RADIANT_CARDS.ClearChariot(player)
    RADIANT_CARDS.ClearDeath(player)
end

-- entities2.xml's card entries are disabled (registering out of sync with pocketitems.xml), so the
-- world-pickup sprite is set manually here instead.
local IS_RADIANT_CARD = {}
for _, id in ipairs({
    RADIANT_CARDS.FOOL_ID, RADIANT_CARDS.MAGICIAN_ID, RADIANT_CARDS.PRIESTESS_ID, RADIANT_CARDS.EMPRESS_ID,
    RADIANT_CARDS.EMPEROR_ID, RADIANT_CARDS.HIEROPHANT_ID, RADIANT_CARDS.LOVERS_ID, RADIANT_CARDS.CHARIOT_ID,
    RADIANT_CARDS.JUSTICE_ID, RADIANT_CARDS.HERMIT_ID, RADIANT_CARDS.FORTUNE_ID, RADIANT_CARDS.STRENGTH_ID,
    RADIANT_CARDS.HANGED_ID, RADIANT_CARDS.DEATH_ID, RADIANT_CARDS.TEMPERANCE_ID, RADIANT_CARDS.DEVIL_ID,
    RADIANT_CARDS.TOWER_ID, RADIANT_CARDS.STAR_ID, RADIANT_CARDS.MOON_ID, RADIANT_CARDS.SUN_ID,
    RADIANT_CARDS.JUDGEMENT_ID, RADIANT_CARDS.WORLD_ID,
}) do
    IS_RADIANT_CARD[id] = true
end

-- Loads the sprite, plays the spawn-in animation, and restores collision physics (custom CardType
-- ids are assigned dynamically at runtime, so no entities2.xml entry can ever match them; without
-- one the entity gets zeroed collision -- Size 0 = walk-through -- so it's set here instead).
local function InitCardPickup(pickup)
    pickup:GetSprite():Load("gfx/radiant_cards.anm2", true)
    pickup:GetSprite():Play("Appear", true)

    pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
    pickup.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
    pickup:SetSize(12, pickup.SizeMulti, 24)
    pickup.Friction = 1
    pickup.Mass = 3

    pickup:GetData().POR_CardInitialized = true
end

function RADIANT_CARDS.FixPickupSprite(_, pickup)
    if IS_RADIANT_CARD[pickup.SubType] then
        InitCardPickup(pickup)
    end
end

-- Falls back to initializing here too (MC_POST_PICKUP_INIT doesn't guarantee SubType is set yet in
-- every spawn path, e.g. dropping a currently-held card), then handles Appear -> looping Idle.
function RADIANT_CARDS.OnPickupUpdate(_, pickup)
    if not IS_RADIANT_CARD[pickup.SubType] then return end

    if not pickup:GetData().POR_CardInitialized then
        InitCardPickup(pickup)
        return
    end

    local sprite = pickup:GetSprite()
    if sprite:IsPlaying("Appear") and sprite:IsFinished("Appear") then
        sprite:Play("Idle", true)
    end
end

-- Plays the Collect flourish the moment the player touches the card
function RADIANT_CARDS.OnPickupCollide(_, pickup, collider)
    if not IS_RADIANT_CARD[pickup.SubType] then return end
    if not collider:ToPlayer() then return end
    if pickup:GetData().POR_CardCollectAnimPlayed then return end

    pickup:GetData().POR_CardCollectAnimPlayed = true
    pickup:GetSprite():Play("Collect", true)
end

--#region Callbacks

POR:AddCallback(ModCallbacks.MC_USE_CARD, function(_, card, player)
    RADIANT_CARDS.UseCard(card, player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PICKUP_INIT, RADIANT_CARDS.FixPickupSprite, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_POST_PICKUP_UPDATE, RADIANT_CARDS.OnPickupUpdate, PickupVariant.PICKUP_TAROTCARD)
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, RADIANT_CARDS.OnPickupCollide, PickupVariant.PICKUP_TAROTCARD)

POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    RADIANT_CARDS.MagicianCache(player, cacheFlag)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.ChariotSuppressCostume(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    POR:ForEachPlayer(RADIANT_CARDS.ClearRoomBuffs)
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    POR:ForEachPlayer(RADIANT_CARDS.ClearRoomBuffs)
    POR:ForEachPlayer(RADIANT_CARDS.ClearSun)
end)

--#endregion

return RADIANT_CARDS