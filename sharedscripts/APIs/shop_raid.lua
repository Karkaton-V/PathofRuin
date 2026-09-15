local game = Game()

local RAID = {}
POR.ShopRaid = RAID

local DESTROY_SHOPKEEPERS = true -- set to false to leave shopkeepers alone during a raid
local RAID_MUSIC = Music.MUSIC_BOSS -- the sins are minibosses and use the standard boss track, as no separate miniboss track exists
local raidActive = false -- true between the raid starting and the boss dying, while the boss track is held
local previousMusic = nil -- whatever was playing before the raid, restored once it ends
local floorRaided = false -- true once a shop on this floor has been raided, so the trick is worth one shop per floor
local raidRoomIndex = nil -- ListIndex of the sealed room, so leaving it can be told apart from moving around inside it
local removedTrapdoors = {} -- grid indices the raid cleared, kept so an abandoned fight can put them back
local pendingRestore = nil -- ListIndex of a room still owed its doors and trapdoors after a fight was abandoned

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

-- ListIndex of the room the player is standing in, which identifies a room across re-entries
local function currentRoomIndex()
    return game:GetLevel():GetCurrentRoomDesc().ListIndex
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

-- True while the player is standing in the room a raid sealed, so callers can refuse to alter a room the fight was never in
function RAID.IsInRaidRoom()
    return raidRoomIndex ~= nil and currentRoomIndex() == raidRoomIndex
end

-- Clears any trapdoor in the current room so the Member Card trapdoor cannot be used to walk out of the raid, returning the indices it took
function RAID.ClearTrapdoors()
    local room = game:GetRoom()
    local cleared = {}

    for index = 0, room:GetGridSize() - 1 do
        local grid = room:GetGridEntity(index)
        if grid and grid:GetType() == GridEntityType.GRID_TRAPDOOR then
            cleared[#cleared + 1] = index
            room:RemoveGridEntity(index, 0, false)
        end
    end
    return cleared
end

-- Puts back the doors and trapdoors a raid sealed away, run on returning to a room whose fight was abandoned
function RAID.RestoreRoom()
    RAID.OpenAllDoors()

    local room = game:GetRoom()
    for _, index in ipairs(removedTrapdoors) do
        if not room:GetGridEntity(index) then
            Isaac.GridSpawn(GridEntityType.GRID_TRAPDOOR, 0, room:GetGridPosition(index), true)
        end
    end

    removedTrapdoors = {}
    pendingRestore = nil
    raidRoomIndex = nil
end

-- Hands the music back to whatever was playing before the raid and stops the boss track being reasserted
local function releaseMusic()
    if not raidActive then return end
    raidActive = false

    local music = MusicManager()
    if previousMusic then
        music:Fadein(previousMusic, 0.1)
    end
    previousMusic = nil
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
    raidRoomIndex = currentRoomIndex()
    pendingRestore = nil

    RAID.ClearShop()
    removedTrapdoors = RAID.ClearTrapdoors()
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

-- Drops a raid the player has been taken out of and repays the sealed room on returning, since the boss death that would normally end it can no longer be seen
function RAID.OnNewRoom()
    local index = currentRoomIndex()

    if raidActive and raidRoomIndex ~= nil and index ~= raidRoomIndex then
        pendingRestore = raidRoomIndex
        releaseMusic()
    end

    if pendingRestore ~= nil and index == pendingRestore then
        RAID.RestoreRoom()
    end
end

-- Ends the raid, unsealing right away when the player is still in the room and otherwise leaving the room owed a restore
function RAID.Finish()
    if raidRoomIndex ~= nil and currentRoomIndex() ~= raidRoomIndex then
        pendingRestore = raidRoomIndex
        releaseMusic()
        return
    end

    RAID.OpenAllDoors()
    releaseMusic()

    removedTrapdoors = {}
    pendingRestore = nil
    raidRoomIndex = nil
end

return RAID
