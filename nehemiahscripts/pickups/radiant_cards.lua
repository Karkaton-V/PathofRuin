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

local CONTINUUM_CONFIG = Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_CONTINUUM)
local ABADDON_CONFIG = Isaac.GetItemConfig():GetCollectible(CollectibleType.COLLECTIBLE_ABADDON)
local CONTACT_DAMAGE_COOLDOWN = 10 -- frames between successive Abaddon contact hits

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

-- Continuum Tears, Range x2, Tears x3, Continuum costume
function RADIANT_CARDS:Magician(player)
    player:GetData().POR_MagicianActive = true
    player:AddCacheFlags(CacheFlag.CACHE_RANGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_ALL, true)
    player:EvaluateItems()
end

-- Applies the Magician's room-scoped Continuum tear-wrap, double range, triple tears, and costume
function RADIANT_CARDS.MagicianCache(player, cacheFlag)
    if not player:GetData().POR_MagicianActive then return end

    if cacheFlag == CacheFlag.CACHE_RANGE then
        player.TearRange = player.TearRange * 2
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay / 3
    elseif cacheFlag == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_CONTINUUM
    elseif cacheFlag == CacheFlag.CACHE_ALL then
        player:AddCostume(CONTINUUM_CONFIG, false)
    end
end

-- Clears the Magician's buff
function RADIANT_CARDS.ClearMagician(player)
    local pData = player:GetData()
    if pData.POR_MagicianActive then
        pData.POR_MagicianActive = false
        player:AddCacheFlags(CacheFlag.CACHE_RANGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_TEARFLAG | CacheFlag.CACHE_ALL, true)
        player:EvaluateItems()
    end
end

-- Summons Mom's Hand
function RADIANT_CARDS:Priestess(player)
    Isaac.Spawn(213, 0, 0, player.Position, Vector.Zero, player)
end

-- Abaddon: flight, contact damage, Abaddon costume, for the room
function RADIANT_CARDS:Empress(player)
    player:GetData().POR_EmpressActive = true
    player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_ALL, true)
    player:EvaluateItems()
end

-- Applies the Empress's room-scoped flight and Abaddon costume
function RADIANT_CARDS.EmpressCache(player, cacheFlag)
    if not player:GetData().POR_EmpressActive then return end

    if cacheFlag == CacheFlag.CACHE_FLYING then
        player.CanFly = true
    elseif cacheFlag == CacheFlag.CACHE_ALL then
        player:AddCostume(ABADDON_CONFIG, false)
    end
end

-- Deals Abaddon-style contact damage to enemies touching the player while the Empress is active
function RADIANT_CARDS.EmpressContactDamage(player)
    local pData = player:GetData()
    if not pData.POR_EmpressActive then return end

    pData.POR_EmpressContactCooldown = math.max(0, (pData.POR_EmpressContactCooldown or 0) - 1)
    if pData.POR_EmpressContactCooldown > 0 then return end

    for _, ent in ipairs(Isaac.FindInRadius(player.Position, player.Size, EntityPartition.ENEMY)) do
        if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
            ent:TakeDamage(player.Damage, 0, EntityRef(player), 0)
            pData.POR_EmpressContactCooldown = CONTACT_DAMAGE_COOLDOWN
            break
        end
    end
end

-- Clears the Empress's buff
function RADIANT_CARDS.ClearEmpress(player)
    local pData = player:GetData()
    if pData.POR_EmpressActive then
        pData.POR_EmpressActive = false
        player:AddCacheFlags(CacheFlag.CACHE_FLYING | CacheFlag.CACHE_ALL, true)
        player:EvaluateItems()
    end
end

-- Teleports to the Boss Challenge Room, or Challenge, or Sacrifice, or Cursed Room, whichever is found first
function RADIANT_CARDS:Emperor(player)
    local rooms = game:GetLevel():GetRooms()

    for _, roomType in ipairs(TELEPORT_PRIORITY) do
        for i = 0, #rooms - 1 do
            local roomDesc = rooms:Get(i)
            if roomDesc.GridIndex ~= -1 and roomDesc.Data and roomDesc.Data.Type == roomType then
                player:AnimateTeleport(true)
                player:GetData().POR_EmperorTargetRoom = roomDesc.SafeGridIndex
                return
            end
        end
    end
end

-- Once the teleport-out animation finishes, actually performs the room transition
function RADIANT_CARDS.EmperorFinishTeleport(player)
    local target = player:GetData().POR_EmperorTargetRoom
    if not target then return end

    if player:IsExtraAnimationFinished() then
        player:GetData().POR_EmperorTargetRoom = nil
        game:StartRoomTransition(target, Direction.NO_DIRECTION, RoomTransitionAnim.TELEPORT)
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
-- Gives Mars and forces the Stompy transformation, both removed on room/level change
function RADIANT_CARDS:Chariot(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_MARS, 0, false)
    player:AddPlayerFormCounter(PlayerForm.PLAYERFORM_STOMPY, 3)
    player:GetData().POR_ChariotActive = true
end

-- Clears the Chariot's Mars and Stompy transformation
function RADIANT_CARDS.ClearChariot(player)
    local pData = player:GetData()
    if pData.POR_ChariotActive then
        pData.POR_ChariotActive = false
        player:RemoveCollectible(CollectibleType.COLLECTIBLE_MARS)
        player:AddPlayerFormCounter(PlayerForm.PLAYERFORM_STOMPY, -3)
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
-- Teleports to the Member Card (secret) shop, after playing the teleport-out animation
function RADIANT_CARDS:Hermit(player)
    player:AnimateTeleport(true)
    player:GetData().POR_HermitTeleporting = true
end

-- Once the teleport-out animation finishes, actually performs the transition
function RADIANT_CARDS.HermitFinishTeleport(player)
    if not player:GetData().POR_HermitTeleporting then return end

    if player:IsExtraAnimationFinished() then
        player:GetData().POR_HermitTeleporting = false
        Isaac.ExecuteCommand("goto s.membercard.0")
    end
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
-- Gives Death's List and Death's Touch (removed on room/level change), and mimics the Hourglass
function RADIANT_CARDS:Death(player)
    player:AddCollectible(CollectibleType.COLLECTIBLE_DEATHS_LIST, 0, false)
    player:AddCollectible(CollectibleType.COLLECTIBLE_DEATHS_TOUCH, 0, false)
    player:GetData().POR_DeathActive = true

    player:UseActiveItem(CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
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
-- Teleports to the Planetarium, after playing the teleport-out animation
function RADIANT_CARDS:Star(player)
    player:AnimateTeleport(true)
    player:GetData().POR_StarTeleporting = true
end

-- Once the teleport-out animation finishes, actually performs the transition
function RADIANT_CARDS.StarFinishTeleport(player)
    if not player:GetData().POR_StarTeleporting then return end

    if player:IsExtraAnimationFinished() then
        player:GetData().POR_StarTeleporting = false
        Isaac.ExecuteCommand("goto s.planetarium.0")
    end
end
-- Teleports to the Super Secret Room, after playing the teleport-out animation
function RADIANT_CARDS:Moon(player)
    player:AnimateTeleport(true)
    player:GetData().POR_MoonTeleporting = true
end

-- Once the teleport-out animation finishes, actually performs the transition
function RADIANT_CARDS.MoonFinishTeleport(player)
    if not player:GetData().POR_MoonTeleporting then return end

    if player:IsExtraAnimationFinished() then
        player:GetData().POR_MoonTeleporting = false
        Isaac.ExecuteCommand("goto s.supersecret.0")
    end
end
-- +2 soul hearts, reveals all rooms on the map, removes Curse of the Lost/Blind if present, gives Star of Bethlehem for the rest of the floor
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

--#region Callbacks

POR:AddCallback(ModCallbacks.MC_USE_CARD, function(_, card, player)
    RADIANT_CARDS.UseCard(card, player)
end)

POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    RADIANT_CARDS.MagicianCache(player, cacheFlag)
end)

POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    RADIANT_CARDS.EmpressCache(player, cacheFlag)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.EmpressContactDamage(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.EmperorFinishTeleport(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.HermitFinishTeleport(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.StarFinishTeleport(player)
end)

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    RADIANT_CARDS.MoonFinishTeleport(player)
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