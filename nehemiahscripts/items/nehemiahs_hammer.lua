local swingActive = false
local swingOwner = nil
local swingAnimating = false
local swingEndDelay = 0
local lastNumFired = 0

NEHEMIAHSHAMMER_ITEM_ID = Isaac.GetItemIdByName("Nehemiah's Hammer")

function POR:NehemiahHammerUse(item, rng, player)
    swingActive = true
    swingOwner = player

    -- Eval cache to add the weapon
    player:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
    player:EvaluateItems()

    return {
        Discharge = true,
        Remove = false,
        ShowAnim = true
    }
end

-- Cache eval — only enables the axe if swing is active
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player)
    if swingActive and swingOwner and player:GetPlayerIndex() == swingOwner:GetPlayerIndex() then
        player:EnableWeaponType(WeaponType.WEAPON_NOTCHED_AXE, true)
    end
end, CacheFlag.CACHE_WEAPON)

-- Replace the notched axe sprite with the hammer after the player updates
POR:AddCallback(ModCallbacks.MC_POST_PEFFECT_UPDATE, function(_, player)
    if not swingActive or not swingOwner then return end
    if player:GetPlayerIndex() ~= swingOwner:GetPlayerIndex() then return end

    local weapon = player:GetWeapon(2)
    if weapon then
        local mainEntity = weapon:GetMainEntity()
        if mainEntity then
            local sprite = mainEntity:GetSprite()
            sprite:Load("gfx/nehemiahs_hammer.anm2", true)
            sprite:Play("Idle", true)
        end
    end
end)

-- Watch for swing, then re-eval cache without weapon
POR:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
    if not swingActive or not swingOwner then return end

    local weapon = swingOwner:GetWeapon(2)
    if not weapon then return end
    local mainEntity = weapon:GetMainEntity()
    if not mainEntity then return end
    local sprite = mainEntity:GetSprite()

    local currentNumFired = swingOwner:GetActiveWeaponNumFired()

    if not swingAnimating and currentNumFired > lastNumFired then
        sprite:Play("SwingHammer", true)
        swingAnimating = true
        lastNumFired = currentNumFired
    end

    if swingAnimating and not sprite:IsPlaying("SwingHammer") then
        swingEndDelay = swingEndDelay + 1
        if swingEndDelay >= 1 then
            swingActive = false
            swingAnimating = false
            lastNumFired = 0
            swingEndDelay = 0
            swingOwner:AddCacheFlags(CacheFlag.CACHE_WEAPON, true)
            swingOwner:EvaluateItems()
            swingOwner = nil
        end
    end
end)