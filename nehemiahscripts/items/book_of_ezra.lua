local game = Game()

BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra") -- item id of Book of Ezra
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)
local DESTROY_SHOPKEEPERS = true -- set to false to leave shopkeepers alone during the raid
local doorsClosedForGreed = false -- tracks whether we're waiting for the raid's Greed to die

-- Closes every door in the room
local function closeAllDoors()
    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            door:Close(true)
        end
    end
end

-- Opens every door in the room
local function openAllDoors()
    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door then
            door:Open()
        end
    end
end

-- Clears a shop's items and machines (and, if enabled, shopkeepers), locks the doors, then spawns Greed (or Super Greed on floor 5+); the Secret Shop trapdoor appears once Greed dies
local function raidShop(player)
    local room = game:GetRoom()

    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        local npc = ent:ToNPC()
        local isShopkeeper = DESTROY_SHOPKEEPERS and npc and npc.IsShopkeeper and npc:IsShopkeeper() -- bypassed if IsShopkeeper doesn't exist
        if isShopkeeper or ent.Type == EntityType.ENTITY_PICKUP or ent.Type == EntityType.ENTITY_SLOT then
            ent:Remove()
        end
    end

    closeAllDoors()
    doorsClosedForGreed = true

    local subType = game:GetLevel():GetStage() >= LevelStage.STAGE5 and 1 or 0 -- 1 = Super Greed
    Isaac.Spawn(EntityType.ENTITY_GREED, 0, subType, room:GetCenterPos(), Vector.Zero, player)
end

-- For Tainted Nehemiah in a shop, raids it instead of spawning the moonlight effect
function POR:BookofEzraUse(_, _, player)
    local room = game:GetRoom()

    if player:GetPlayerType() == TAINTED_NEHEMIAH_TYPE and room:GetType() == RoomType.ROOM_SHOP then
        raidShop(player)
        return true
    end

    POR.EzrasMoonlight:SpawnMoonlight(room:GetCenterPos(), player)
    return true
end

-- Reopens the doors and spawns the Secret Shop trapdoor once the raid's Greed dies
POR:AddCallback(ModCallbacks.MC_POST_NPC_DEATH, function(_, npc)
    if npc.Type == EntityType.ENTITY_GREED and doorsClosedForGreed then
        doorsClosedForGreed = false
        openAllDoors()
        game:GetRoom():TrySpawnSecretShop(true)
    end
end)