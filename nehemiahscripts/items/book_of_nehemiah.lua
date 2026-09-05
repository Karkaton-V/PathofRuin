local game = Game()

BOOKOFNEHEMIAH_ITEM_ID = Isaac.GetItemIdByName("Book of Nehemiah") -- item id of Book of Nehemiah
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)
local doorsClosedForGreed = false -- tracks whether the raid is still waiting for Super Greed to die
local raidingPlayer = nil -- the player who started the raid, remembered for the luck check on the Super Greed death

-- Relative to content/rooms; only the numbered vanilla stb names load unaided
local ROOMS_FILE = "nehemiah_sss.stb"

-- Super Secret Shop layouts ordered from the highest luck bracket down, matching the brackets written into the room names
local LUCK_ROOMS = {
    { minLuck = 10, variant = 53543 },
    { minLuck = 7,  variant = 53542 },
    { minLuck = 4,  variant = 53541 },
    { minLuck = 1,  variant = 53540 },
    { minLuck = 0,  variant = 53539 },
}

-- Lookup of the same variants, used to recognise the room again on entry without keeping a flag across the transition
local SS_SHOP_VARIANTS = {}
for _, bracket in ipairs(LUCK_ROOMS) do SS_SHOP_VARIANTS[bracket.variant] = true end

local ssShopGfx = nil -- built on demand because the StageAPI constructors only exist once it has loaded
local ssShopDoors = {} -- per slot { sprite, wasOpen } for the doors in the room, rebuilt on every room change

local SS_SHOP_DOOR_ANM2 = "gfx/grid/SS Shop Door.anm2"

-- Maps the wall direction on a door to a sprite rotation, matching custom_secret_door.lua where UP is the artwork baseline
local DOOR_ROTATION = {
    [Direction.UP] = 0,
    [Direction.DOWN] = 180,
    [Direction.LEFT] = 270,
    [Direction.RIGHT] = 90,
}

-- Registers the room file and builds the backdrop and rocks for the shop, as neither loads unaided
function POR.BookofNehemiahLoadRooms()
    if type(RoomConfig) == "table" and type(RoomConfig.LoadStb) == "function" then
        RoomConfig.LoadStb(StbType.SPECIAL_ROOMS, 0, ROOMS_FILE)
    end

    if not StageAPI then return end

    local backdrop = StageAPI.BackdropHelper({
        Walls = { "1" },
        NFloors = { "nfloor" },
    }, "gfx/backdrop/ssshop_", ".png")

    local grids = StageAPI.GridGfx()
    grids:SetRocks("gfx/grid/rocks_ssshop.png")

    ssShopGfx = StageAPI.RoomGfx(backdrop, grids)
end

-- True when the current room is one of the swapped in Super Secret Shop layouts
local function inSecretShop()
    local desc = game:GetLevel():GetCurrentRoomDesc()
    local data = desc and desc.Data
    return data ~= nil and SS_SHOP_VARIANTS[data.Variant] == true
end

-- Clears prices and rerolls pedestals from the secret room pool, first visit only
local function restockSecretShop()
    local isFirstVisit = game:GetRoom():IsFirstVisit()
    local itemPool = game:GetItemPool()

    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, -1, -1, false, false)) do
        local pickup = ent:ToPickup()
        if pickup then
            if pickup.Price ~= 0 then
                pickup.Price = 0
                pickup.AutoUpdatePrice = false
            end
            if isFirstVisit and pickup.Variant == PickupVariant.PICKUP_COLLECTIBLE and pickup.SubType ~= 0 then
                local rolled = itemPool:GetCollectible(ItemPoolType.POOL_SECRET, true, pickup.InitSeed)
                pickup:Morph(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COLLECTIBLE, rolled, true, true, false)
            end
        end
    end
end

-- Room types where the entrance keeps the hole in the wall art, which custom_secret_door.lua owns
local SECRET_ROOM_TYPES = {
    [RoomType.ROOM_SECRET] = true,
    [RoomType.ROOM_SUPERSECRET] = true,
    [RoomType.ROOM_ULTRASECRET] = true,
}

-- True for a secret entrance on either side of the doorway, so neither room skins it
local function isSecretEntrance(door)
    return SECRET_ROOM_TYPES[door.TargetRoomType] == true
        or SECRET_ROOM_TYPES[door.CurrentRoomType] == true
end

-- True when a door should wear the shop art, covering both the doors inside the shop and the one a neighbouring room uses to enter it
local function shouldSkinDoor(door)
    if isSecretEntrance(door) then return false end
    if inSecretShop() then return true end

    local desc = game:GetLevel():GetRoomByIdx(door.TargetRoomIndex, -1)
    local data = desc and desc.Data
    return data ~= nil and SS_SHOP_VARIANTS[data.Variant] == true
end

-- Lazily builds the sprite for a door, starting it on whichever state the door is already in
local function getDoorSprite(door)
    local data = ssShopDoors[door.Slot]
    if not data then
        local sprite = Sprite()
        sprite:Load(SS_SHOP_DOOR_ANM2, true)
        sprite.Rotation = DOOR_ROTATION[door.Direction] or 0
        sprite:Play(door:IsOpen() and "Opened" or "Closed", true)

        data = { sprite = sprite, wasOpen = door:IsOpen() }
        ssShopDoors[door.Slot] = data
    end
    return data
end

-- Dresses the Super Secret Shop and fixes up the contents whenever it is entered
function POR.BookofNehemiahNewRoom()
    ssShopDoors = {}
    if not inSecretShop() then return end

    if StageAPI and ssShopGfx then
        StageAPI.ChangeRoomGfx(ssShopGfx)
    end

    restockSecretShop()
end

-- Draws the dedicated shop door art in place of the room art, so nothing another mod does to the underlying door sprite can show through
function POR.BookofNehemiahDoorRender(_, door, offset)
    if not shouldSkinDoor(door) then return end

    getDoorSprite(door).sprite:Render(Isaac.WorldToScreen(door.Position), Vector.Zero, Vector.Zero)
    return false
end

-- Advances the shop door animation and follows the door between the open and closed states
function POR.BookofNehemiahDoorUpdate(_, door)
    if not shouldSkinDoor(door) then return end

    local data = getDoorSprite(door)
    local sprite = data.sprite

    if sprite:IsFinished("Open") then
        sprite:Play("Opened", true)
    elseif sprite:IsFinished("Close") then
        sprite:Play("Closed", true)
    end

    local isOpen = door:IsOpen()
    if isOpen ~= data.wasOpen then
        sprite:Play(isOpen and "Open" or "Close", false)
        data.wasOpen = isOpen
    end

    sprite:Update()
end

-- Returns the shop variant for a luck value, treating anything at or below zero as the lowest bracket
local function shopVariantForLuck(luck)
    for _, bracket in ipairs(LUCK_ROOMS) do
        if luck >= bracket.minLuck then return bracket.variant end
    end
    return LUCK_ROOMS[#LUCK_ROOMS].variant
end

-- Wipes the saved contents on the descriptor, which the game would otherwise restore over the new layout
local function clearRoomSaveState(desc)
    if type(desc.GetEntitiesSaveState) ~= "function" then return end

    desc:GetDecoSaveState():Clear()
    desc:GetEntitiesSaveState():Clear()

    local gridSaveState = desc:GetGridEntitiesSaveState()
    for i = 0, #gridSaveState - 1 do
        local gridDesc = gridSaveState:Get(i)
        gridDesc.Initialized = false
        gridDesc.SpawnCount = 0
        gridDesc.State = 0
        gridDesc.Type = 0
        gridDesc.Variant = 0
        gridDesc.VarData = 0
    end
end

-- Rewrites the descriptor to the luck matched layout and fades back into it, as Andromeda does
local function replaceShopWithSecretShop(player)
    if type(RoomConfig) ~= "table" or type(RoomConfig.GetRoomByStageTypeAndVariant) ~= "function" then return false end

    local level = game:GetLevel()
    local index = level:GetCurrentRoomIndex()
    local desc = level:GetRoomByIdx(index, -1)
    if not desc then return false end

    local data = RoomConfig.GetRoomByStageTypeAndVariant(StbType.SPECIAL_ROOMS, RoomType.ROOM_DEFAULT, shopVariantForLuck(player.Luck), 0)
    if not data then return false end

    desc.Data = data
    desc.VisitedCount = 0
    desc.Clear = false
    desc.ClearCount = 0
    clearRoomSaveState(desc)
    game:StartRoomTransition(index, Direction.NO_DIRECTION, RoomTransitionAnim.FADE, player)
    return true
end

-- For Tainted Nehemiah in a shop, raids it with Super Greed instead of mimicking Crack the Sky
function POR:BookofNehemiahUse(_, _, player)
    local room = game:GetRoom()

    if player:GetPlayerType() == TAINTED_NEHEMIAH_TYPE and room:GetType() == RoomType.ROOM_SHOP and POR.ShopRaid.CanRaid() then
        POR.ShopRaid.Begin(player, true)
        doorsClosedForGreed = true
        raidingPlayer = player
        return true
    end

    player:UseActiveItem(CollectibleType.COLLECTIBLE_CRACK_THE_SKY, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    POR.EzrasMoonlight:SpawnMoonlight(room:GetCenterPos(), player, true)

    return true
end

-- Reopens the doors once the raid Super Greed dies and turns the shop itself into the luck matched Super Secret Shop
function POR:BookofNehemiahGreedDeath(npc)
    if POR.ShopRaid.IsRaidBoss(npc) and doorsClosedForGreed then
        doorsClosedForGreed = false
        POR.ShopRaid.Finish()

        local player = raidingPlayer
        raidingPlayer = nil
        if not player or not player:Exists() then return end

        POR.ShopRaid.ClearTrapdoors()
        replaceShopWithSecretShop(player)
    end
end
