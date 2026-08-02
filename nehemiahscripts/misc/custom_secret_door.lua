local game = Game()

local SECRET_DOOR = {}
POR.SecretDoor = SECRET_DOOR

local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

local REQUIRED_BOMB_HITS = 2
local doorStates = {} -- keyed by "listIndex_slot" -> { sprite, bombHits, wasOpen, needsGating }

-- True if any player in the run is currently Tainted Nehemiah
local function isTaintedNehemiahPresent()
    return POR:ForEachPlayer(function(player)
        if player:GetPlayerType() == TAINTED_NEHEMIAH_TYPE then
            return true
        end
    end) == true
end

-- The door found from outside, leading into a secret/super secret room; gets the full reveal sequence
local function isSecretEntryDoor(door)
    return door.TargetRoomType == RoomType.ROOM_SECRET or door.TargetRoomType == RoomType.ROOM_SUPERSECRET
end

-- True while standing inside a secret/super secret room; any door here gets the new skin too
local function isInSecretRoom()
    local roomType = game:GetRoom():GetType()
    return roomType == RoomType.ROOM_SECRET or roomType == RoomType.ROOM_SUPERSECRET
end

local function shouldSkinDoor(door)
    return isTaintedNehemiahPresent() and (isSecretEntryDoor(door) or isInSecretRoom())
end

-- Doors bombed from inside a secret/super secret room only need 1 hit; from outside, the full amount
local function requiredHitsFor()
    return isInSecretRoom() and 1 or REQUIRED_BOMB_HITS
end

local function doorKey(door)
    return tostring(game:GetLevel():GetCurrentRoomDesc().ListIndex) .. "_" .. tostring(door.Slot)
end

-- Maps the door's wall direction to a sprite rotation; UP is the artwork's baseline (0 degrees)
local DIRECTION_ROTATION = {
    [Direction.UP] = 0,
    [Direction.DOWN] = 180,
    [Direction.LEFT] = 270,
    [Direction.RIGHT] = 90,
}

-- Counts how many doors currently exist in this room
local function countRoomDoors()
    local room = game:GetRoom()
    local count = 0
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        if room:GetDoor(slot) then
            count = count + 1
        end
    end
    return count
end

-- Lazily creates and caches per-door state
local function getDoorState(door)
    local key = doorKey(door)
    local data = doorStates[key]
    if not data then
        local sprite = Sprite()
        sprite:Load("gfx/grid/SecretDoor.anm2", true)
        sprite.Rotation = DIRECTION_ROTATION[door.Direction] or 0

        if isSecretEntryDoor(door) then
            sprite:Play("Hidden", true)
        elseif door:IsOpen() then
            sprite:Play("Opened", true)
        else
            sprite:Play("Closed", true)
        end

        -- If this is the only door in the room, never gate it, so the player is never trapped
        local isOnlyDoor = isInSecretRoom() and countRoomDoors() <= 1
        data = { sprite = sprite, bombHits = 0, wasOpen = door:IsOpen(), needsGating = (not door:IsOpen()) and not isOnlyDoor }
        doorStates[key] = data
    end
    return data
end

-- Always blocks a bomb's mere contact from opening a not-yet-fully-revealed secret door; real progress only happens on actual explosion
POR:AddCallback(ModCallbacks.MC_PRE_BOMB_GRID_COLLISION, function(_, bomb, gridIndex)
    local gridEntity = game:GetRoom():GetGridEntity(gridIndex)
    local door = gridEntity and gridEntity:ToDoor()
    if not door or not shouldSkinDoor(door) then return end

    local data = getDoorState(door)
    if not data.needsGating or data.bombHits >= requiredHitsFor() then return end

    return false
end)

-- Counts a hit only when a bomb explosion effect actually spawns near the door, and advances the reveal animation
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_INIT, function(_, effect)
    if effect.Variant ~= EffectVariant.BOMB_EXPLOSION then return end

    local room = game:GetRoom()
    local required = requiredHitsFor()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door and shouldSkinDoor(door) then
            local data = getDoorState(door)
            if data.needsGating and data.bombHits < required and effect.Position:Distance(door.Position) < 90 then
                data.bombHits = data.bombHits + 1

                if data.bombHits >= required then
                    data.sprite:Play("BreakingOpen", true)
                else
                    data.sprite:Play("Discovering", true)
                end
            end
        end
    end
end)

-- Cancels the door's native sprite and draws our own instead
POR:AddCallback(ModCallbacks.MC_PRE_GRID_ENTITY_DOOR_RENDER, function(_, door, offset)
    if not shouldSkinDoor(door) then return end
    local data = getDoorState(door)
    local renderPos = Isaac.WorldToScreen(door.Position)
    data.sprite:Render(renderPos, Vector.Zero, Vector.Zero)
    return false
end)

-- Advances one-shot animations, keeps the sprite in sync with the door's open/closed state, and enforces the bomb gate
POR:AddCallback(ModCallbacks.MC_POST_GRID_ENTITY_DOOR_UPDATE, function(_, door)
    -- Close()/Busted only affect the door's animation state, not actual physics, so also force CollisionClass solid
    if shouldSkinDoor(door) then
        local lockData = getDoorState(door)
        if lockData.needsGating and lockData.bombHits < requiredHitsFor() then
            if door:IsOpen() then
                door:Close(true)
                door.Busted = false
            end
            door.CollisionClass = GridCollisionClass.COLLISION_WALL
        end
    end

    if not shouldSkinDoor(door) then return end
    local data = getDoorState(door)
    local sprite = data.sprite

    if sprite:IsFinished("Discovering") then
        sprite:Play("BrokenOnce", true)
    elseif sprite:IsFinished("BreakingOpen") then
        sprite:Play("Opened", true)
        door:Open()
    elseif sprite:IsFinished("Open") then
        sprite:Play("Opened", true)
    elseif sprite:IsFinished("Close") then
        sprite:Play("Closed", true)
    end

    local isOpenNow = door:IsOpen()
    if isOpenNow ~= data.wasOpen then
        sprite:Play(isOpenNow and "Open" or "Close", false)
        data.wasOpen = isOpenNow
    end

    sprite:Update()
end)

-- Per-door state is keyed to the room it belongs to, so clear it out on floor change
POR:AddCallback(ModCallbacks.MC_POST_NEW_LEVEL, function()
    doorStates = {}
end)

return SECRET_DOOR