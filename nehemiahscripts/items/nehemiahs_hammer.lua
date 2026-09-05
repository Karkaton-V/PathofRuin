local game = POR.game
local player = Isaac.GetPlayer()

local swingActive = false
local swingOwner = nil
local swingAnimating = false
local swingEndDelay = 0
local lastNumFired = 0
local swingFrames = 0 -- frames the swing has been live, used by the failsafe below

local SWING_TIMEOUT_FRAMES = 120 -- a swing this old is stuck, since a chargebar item can take the weapon slot and strand it forever

local ROCK_CHECK_OFFSETS = {
    Vector(0, 0),
    Vector(40, 0),
    Vector(-40, 0),
    Vector(0, 40),
    Vector(0, -40),
}

NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")

-- Uses ToRock() instead of a manual GridEntityType list — catches all rock subtypes
local function canDestroyGridEntity(gridEntity)
    return gridEntity:ToRock() ~= nil
        and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE
end

-- Checks the tiles around the player, destroys any breakable rocks found, and drops a boulder for each one broken
local function checkRocks(swingPlayer)
    local room = game:GetRoom()
    for _, offset in ipairs(ROCK_CHECK_OFFSETS) do
        local idx = room:GetGridIndex(swingPlayer.Position + offset)
        local gridEntity = room:GetGridEntity(idx)
        if gridEntity and canDestroyGridEntity(gridEntity) then
            gridEntity:Destroy(true)
            POR:DropRocks(swingPlayer)
        end
    end
end

-- Puts the weapon back the way it was, kept separate so every exit path can reach it rather than only the one that sees the swing finish
local function endSwing()
    local player = swingOwner

    swingActive = false
    swingAnimating = false
    lastNumFired = 0
    swingEndDelay = 0
    swingFrames = 0
    swingOwner = nil

    if player and player:Exists() then
        player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
        player:EvaluateItems()
    end
end

function POR:NehemiahHammerUse(item, rng, player)
    swingActive = true
    swingOwner = player
    swingFrames = 0

    player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
    player:EvaluateItems()

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end

-- Cache eval — only enables the axe if swing is active
function POR.NehemiahHammerEvaluateCache(_, player)
    if swingActive and swingOwner and player:GetPlayerIndex() == swingOwner:GetPlayerIndex() then
        player:EnableWeaponType(WeaponType.WEAPON_NOTCHED_AXE, true)
    end
end

-- Replace the notched axe sprite with the hammer after the player updates
function POR.NehemiahHammerSwapSprite(_, player)
    if not swingActive or not swingOwner then return end
    if player:GetPlayerIndex() ~= swingOwner:GetPlayerIndex() then return end

    local weapon = player:GetWeapon(2)
    if weapon then
        local mainEntity = weapon:GetMainEntity()
        if mainEntity then
            local sprite = mainEntity:GetSprite()
            if sprite:GetFilename() ~= "gfx/nehemiahs_hammer.anm2" then
                sprite:Load("gfx/nehemiahs_hammer.anm2", true)
                sprite:Play("Idle", true)
            end
        end
    end
end

-- Watch for swing, then re-eval cache without weapon
function POR.NehemiahHammerUpdate()
    if not swingActive or not swingOwner then return end

    if not swingOwner:Exists() then
        endSwing()
        return
    end

    swingFrames = swingFrames + 1

    local weapon = swingOwner:GetWeapon(2)
    local mainEntity = weapon and weapon:GetMainEntity()
    local sprite = mainEntity and mainEntity:GetSprite()

    if sprite then
        local currentNumFired = swingOwner:GetActiveWeaponNumFired()

        if not swingAnimating and currentNumFired > lastNumFired then
            sprite:Play("SwingHammer", true)
            swingAnimating = true
            lastNumFired = currentNumFired
            checkRocks(swingOwner)
        end

        if swingAnimating and not sprite:IsPlaying("SwingHammer") then
            swingEndDelay = swingEndDelay + 1
            if swingEndDelay >= 1 then
                endSwing()
            end
            return
        end
    end

    if swingFrames >= SWING_TIMEOUT_FRAMES then
        endSwing()
    end
end

-- Ends any swing still live when the room changes, since the weapon it was watching does not survive the transition
function POR.NehemiahHammerNewRoom()
    if swingActive then endSwing() end
end
