local game = Game()

local SECRET_DOOR = {}
POR.SecretDoor = SECRET_DOOR

local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

local REQUIRED_BOMB_HITS = 2
local BOMB_PROXIMITY = 90 -- same range used to match an explosion to a door
local doorStates = {} -- keyed by "listIndex_slot" -> { sprite, bombHits, wasOpen, needsGating, oneShotArmed }

-- Predicates run against every live bomb; any match arms nearby doors to break in a single blast, and compat files may append more
SECRET_DOOR.OneShotBombTests = {
    function(bomb)
        return bomb.Variant == BombVariant.BOMB_GIGA or bomb:HasTearFlags(TearFlags.TEAR_GIGA_BOMB)
    end,
}

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

-- The resting open frame for the side being looked at, since the doorway is drawn differently from within the secret room than from the approach to it
local function openedAnim()
    return isInSecretRoom() and "OpenedInside" or "Opened"
end

-- Doors bombed from inside a secret/super secret room only need 1 hit; from outside, the full amount
local function requiredHitsFor()
    return isInSecretRoom() and 1 or REQUIRED_BOMB_HITS
end

local function doorKey(door)
    return tostring(game:GetLevel():GetCurrentRoomDesc().ListIndex) .. "_" .. tostring(door.Slot)
end

-- Maps the wall direction on the door to a sprite rotation; UP is the artwork baseline (0 degrees)
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
            sprite:Play(openedAnim(), true)
        else
            sprite:Play("Closed", true)
        end

        local isOnlyDoor = isInSecretRoom() and countRoomDoors() <= 1 -- the only door in a room is never gated, so the player cannot be trapped
        data = { sprite = sprite, bombHits = 0, wasOpen = door:IsOpen(), needsGating = (not door:IsOpen()) and not isOnlyDoor, oneShotArmed = false }
        doorStates[key] = data
    end
    return data
end

-- Arms any nearby gated door while a one-shot bomb is still live, since the bomb entity is gone by the time the explosion effect spawns
function SECRET_DOOR.OnBombUpdate(_, bomb)
    local isOneShot = false
    for _, test in ipairs(SECRET_DOOR.OneShotBombTests) do
        if test(bomb) then
            isOneShot = true
            break
        end
    end
    if not isOneShot then return end

    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door and shouldSkinDoor(door) and bomb.Position:Distance(door.Position) < BOMB_PROXIMITY then
            getDoorState(door).oneShotArmed = true
        end
    end
end

-- Blocks the mere contact of a bomb from opening the door; only an actual explosion counts
function SECRET_DOOR.OnBombGridCollision(_, bomb, gridIndex)
    local gridEntity = game:GetRoom():GetGridEntity(gridIndex)
    local door = gridEntity and gridEntity:ToDoor()
    if not door or not shouldSkinDoor(door) then return end

    local data = getDoorState(door)
    if not data.needsGating or data.bombHits >= (data.oneShotArmed and 1 or requiredHitsFor()) then return end

    return false
end

-- Counts a hit when a bomb explosion spawns near the door, and advances the reveal animation
function SECRET_DOOR.OnEffectInit(_, effect)
    if effect.Variant ~= EffectVariant.BOMB_EXPLOSION then return end

    local room = game:GetRoom()
    for slot = DoorSlot.NO_DOOR_SLOT + 1, DoorSlot.NUM_DOOR_SLOTS - 1 do
        local door = room:GetDoor(slot)
        if door and shouldSkinDoor(door) then
            local data = getDoorState(door)
            local required = data.oneShotArmed and 1 or requiredHitsFor()
            if data.needsGating and data.bombHits < required and effect.Position:Distance(door.Position) < BOMB_PROXIMITY then
                data.bombHits = data.bombHits + 1

                if data.bombHits >= required then
                    data.sprite:Play("BreakingOpen", true)
                else
                    data.sprite:Play("Discovering", true)
                end
            end
        end
    end
end

-- Cancels the native door sprite and draws a custom one instead
function SECRET_DOOR.OnDoorRender(_, door, offset)
    if not shouldSkinDoor(door) then return end
    local data = getDoorState(door)
    local renderPos = Isaac.WorldToScreen(door.Position)
    data.sprite:Render(renderPos, Vector.Zero, Vector.Zero)
    return false
end

-- Advances animations and enforces the bomb gate; Close() alone leaves physics open, so CollisionClass is forced solid
function SECRET_DOOR.OnDoorUpdate(_, door)
    if shouldSkinDoor(door) then
        local lockData = getDoorState(door)
        if lockData.needsGating and lockData.bombHits < (lockData.oneShotArmed and 1 or requiredHitsFor()) then
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
        sprite:Play(openedAnim(), true)
        door:Open()
    elseif sprite:IsFinished("Open") then
        sprite:Play(openedAnim(), true)
    elseif sprite:IsFinished("Close") then
        sprite:Play("Closed", true)
    end

    local isOpenNow = door:IsOpen()
    if isOpenNow ~= data.wasOpen then
        sprite:Play(isOpenNow and "Open" or "Close", false)
        data.wasOpen = isOpenNow
    end

    sprite:Update()
end

-- Per-door state is keyed to the room it belongs to, so clear it out on floor change
function SECRET_DOOR.OnNewLevel()
    doorStates = {}
end

return SECRET_DOOR