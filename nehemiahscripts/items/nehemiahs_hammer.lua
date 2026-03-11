local NehemiahBoulder = require("nehemiahscripts.entities.nehemiahs_boulder")

local SMALL_ROCK_ID  = CollectibleType.COLLECTIBLE_SMALL_ROCK
local ROCK_BOTTOM_ID = CollectibleType.COLLECTIBLE_ROCK_BOTTOM


NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")

local game = Game()

local swingActive    = false
local swingOwner     = nil
local swingAnimating = false
local swingEndDelay  = 0
local lastNumFired   = 0


-- CALL ME HEPHEASTUS 'CAUSE I AM THE GOD OF HAMMERS


-- Activates the swing by enabling the weapon type via cache evaluation.
function POR:NehemiahHammerUse(item, rng, player)
    swingActive    = true
    swingOwner     = player
    swingAnimating = false
    swingEndDelay  = 0
    lastNumFired   = 0

    player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
    player:EvaluateItems()

    return {
        Discharge = true,
        Remove    = false,
        ShowAnim  = true
    }
end


-- Opens locked/cracked (variant 3) and hidden (variant 7) doors
local function checkDoors(player)
    local room = game:GetRoom()
    for i = 0, 7 do
        local door = room:GetDoor(i)
        if door then
            local dist    = (door.Position - player.Position):Length()
            local variant = door:GetVariant()
            if dist < 100 and (variant == 3 or variant == 7) then
                door:Open()
            end
        end
    end
end


-- Uses ToRock() instead of a manual GridEntityType list — catches all rock subtypes
-- Guards against already-destroyed rocks via CollisionClass.
local function canDestroyGridEntity(gridEntity)
    return gridEntity:ToRock() ~= nil
        and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE
end


-- Calls FindFreePickupSpawnPosition on the grid position first
-- Retries with a larger radius if the result overlaps an existing boulder/player
-- Prevents boulders from stacking on top of each other / the player.
local function findFreeBoulderPosition(pos)
    local room   = game:GetRoom()
    local newPos = room:FindFreePickupSpawnPosition(pos)

    for _, effect in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, NehemiahBoulder.PICKUP_EFFECT_VARIANT)) do
        if effect.Position:Distance(newPos) < 20 then
            return room:FindFreePickupSpawnPosition(pos, 40)
        end
    end

    for i = 0, game:GetNumPlayers() - 1 do
        if Isaac.GetPlayer(i).Position:Distance(newPos) < 20 then
            return room:FindFreePickupSpawnPosition(pos, 40)
        end
    end

    return newPos
end


-- Checks the five grid tiles centred on the player (center + cardinals).
-- Uses canDestroyGridEntity (ToRock + CollisionClass) and findFreeBoulderPosition
-- Spawned boulders never overlap existing boulders or the player.
local ROCK_CHECK_OFFSETS = {
    Vector( 0,  0),
    Vector(40,  0),
    Vector(-40, 0),
    Vector( 0, 40),
    Vector( 0,-40),
}

local function checkRocks(player)
    local room = game:GetRoom()
    for _, offset in ipairs(ROCK_CHECK_OFFSETS) do
        local idx        = room:GetGridIndex(player.Position + offset)
        local gridEntity = room:GetGridEntity(idx)
        if gridEntity and canDestroyGridEntity(gridEntity) then
            local pos = findFreeBoulderPosition(room:GetGridPosition(idx))
            gridEntity:Destroy(true)
            NehemiahBoulder:SpawnBoulder(pos, player)
        end
    end
end


-- Fully recharges the hammer when the player picks up Small Rock or Rock Bottom.
POR:AddCallback(ModCallbacks.MC_POST_ADD_COLLECTIBLE, function(_, collectibleType, charge, firstTime, slot, varData, player)
    if collectibleType == SMALL_ROCK_ID or collectibleType == ROCK_BOTTOM_ID then
        local hammerSlot = player:GetActiveItemSlot(NEHEMIAHSHAMMER_ITEM_ID)
        if hammerSlot ~= -1 then
            player:FullCharge(hammerSlot)
        end
    end
end)


-- Enables the Notched Axe weapon type only while a swing is active
-- When swingActive is false and EvaluateItems() is called,
-- Callback doesn't enable the weapon, which removes it automatically.
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player)
    if swingActive and swingOwner
        and player:GetPlayerIndex() == swingOwner:GetPlayerIndex()
    then
        player:EnableWeaponType(WeaponType.WEAPON_NOTCHED_AXE, true)
    end
end, CacheFlag.CACHE_WEAPON)


-- Replaces the Notched Axe sprite with the hammer sprite
-- Only plays "Idle" when not mid-swing — guards against fighting the "SwingHammer" animation
POR:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
    if not swingActive or not swingOwner then return end
    if player:GetPlayerIndex() ~= swingOwner:GetPlayerIndex() then return end

    local weapon = player:GetWeapon(2)
    if not weapon then return end
    local mainEntity = weapon:GetMainEntity()
    if not mainEntity then return end

    local sprite = mainEntity:GetSprite()

    -- Load the anm2 if it isn't already loaded
    if sprite:GetFilename() ~= "gfx/nehemiahs_hammer.anm2" then
        sprite:Load("gfx/nehemiahs_hammer.anm2", true)
    end

    -- Only reset to Idle when no swing animation is in progress
    if not swingAnimating then
        sprite:Play("Idle", true)
    end
end)


-- Detects the swing firing (NumFired delta), plays the swing animation
-- Triggers door and rock checks, then cleans up the weapon once done.
POR:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if not swingActive or not swingOwner then return end

    local weapon = swingOwner:GetWeapon(2)
    if not weapon then return end
    local mainEntity = weapon:GetMainEntity()
    if not mainEntity then return end
    local sprite = mainEntity:GetSprite()

    local currentNumFired = swingOwner:GetActiveWeaponNumFired()

    -- Detect the moment the axe fires (delta, not just > 0, to avoid
    -- triggering on the initial spawn frame)
    if not swingAnimating and currentNumFired > lastNumFired then
        sprite:Play("SwingHammer", true)
        swingAnimating = true
        lastNumFired   = currentNumFired
        checkDoors(swingOwner)
        checkRocks(swingOwner)
    end

    -- Once the swing animation finishes, wait swingEndDelay frames then clean up
    if swingAnimating and not sprite:IsPlaying("SwingHammer") then
        swingEndDelay = swingEndDelay + 1
        if swingEndDelay >= 1 then
            swingActive    = false
            swingAnimating = false
            lastNumFired   = 0
            swingEndDelay  = 0
            swingOwner:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
            swingOwner:EvaluateItems()
            swingOwner = nil
        end
    end
end)