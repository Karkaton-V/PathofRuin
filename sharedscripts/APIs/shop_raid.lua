local game = Game()

local RAID = {}
POR.ShopRaid = RAID

local DESTROY_SHOPKEEPERS = true -- set to false to leave shopkeepers alone during a raid
local RAID_MUSIC = Music.MUSIC_BOSS -- the sins are minibosses and use the standard boss track, as no separate miniboss track exists
local raidActive = false -- true between the raid starting and the boss dying, while the boss track is held
local previousMusic = nil -- whatever was playing before the raid, restored once it ends
local floorRaided = false -- true once a shop on this floor has been raided, so the trick is worth one shop per floor

-- Boss the raid summons; compat files may swap this table and IsRaidBoss follows
RAID.Boss = {
    Type = EntityType.ENTITY_GREED,
    Variant = 0,
    SuperVariant = 1,
}

-- True when an entity is the boss a raid would have spawned, matched on variant as well since a replacement may share the type with unrelated bosses
function RAID.IsRaidBoss(npc)
    return npc.Type == RAID.Boss.Type
       and (npc.Variant == RAID.Boss.Variant or npc.Variant == RAID.Boss.SuperVariant)
end

-- Closes every door in the room
function RAID.CloseAllDoors()
    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            door:Close(true)
        end
    end
end

-- Opens every door in the room
function RAID.OpenAllDoors()
    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            door:Open()
        end
    end
end

-- Strips the shop of the stock and staff so only the fight is left behind
function RAID.ClearShop()
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        local npc = ent:ToNPC()
        local isShopkeeper = DESTROY_SHOPKEEPERS and npc and npc.IsShopkeeper and npc:IsShopkeeper() -- bypassed if IsShopkeeper doesn't exist
        if isShopkeeper or ent.Type == EntityType.ENTITY_PICKUP or ent.Type == EntityType.ENTITY_SLOT then
            ent:Remove()
        end
    end
end

-- Clears any trapdoor already in the room, so the Member Card trapdoor in the shop cannot be used to walk out of the raid or sit beside the reward
function RAID.ClearTrapdoors()
    local room = game:GetRoom()
    for index = 0, room:GetGridSize() - 1 do
        local grid = room:GetGridEntity(index)
        if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR then
            room:RemoveGridEntity(index, 0, false)
        end
    end
end

-- True while this floor still has the shop raid going spare, checked by the books before they seal a room
function RAID.CanRaid()
    return not floorRaided
end

-- Frees the raid up again on a new floor, which is the only thing that resets the limit
function RAID.OnNewLevel()
    floorRaided = false
end

-- Clears the shop, seals the exits and spawns the raid boss; the super form is a variant, not a subtype
function RAID.Begin(player, forceSuperGreed)
    local room = game:GetRoom()
    floorRaided = true

    RAID.ClearShop()
    RAID.ClearTrapdoors()
    RAID.CloseAllDoors()

    local isSuper = forceSuperGreed or game:GetLevel():GetStage() >= LevelStage.STAGE5
    Isaac.Spawn(RAID.Boss.Type, isSuper and RAID.Boss.SuperVariant or RAID.Boss.Variant, 0, room:GetCenterPos(), Vector.Zero, player)

    local music = MusicManager()
    previousMusic = music:GetCurrentMusicID()
    raidActive = true
    music:Play(RAID_MUSIC, 0)
    music:UpdateVolume()
end

-- Reasserts the boss track, since the game keeps restoring the shop music in a non boss room
function RAID.OnUpdate()
    if not raidActive then return end

    local music = MusicManager()
    if music:GetCurrentMusicID() ~= RAID_MUSIC then
        music:Play(RAID_MUSIC, 0)
        music:UpdateVolume()
    end
end

-- Ends the raid: unseals the room and hands the music back to whatever was playing beforehand
function RAID.Finish()
    RAID.OpenAllDoors()

    if not raidActive then return end
    raidActive = false

    local music = MusicManager()
    if previousMusic then
        music:Fadein(previousMusic, 0.1)
    end
    previousMusic = nil
end

return RAID
