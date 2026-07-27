local game = Game()

local EZRA_MOONLIGHT = {}
POR.EzrasMoonlight = EZRA_MOONLIGHT -- book_of_ezra.lua references this to spawn the moonlight effect

EZRA_MOONLIGHT.VARIANT = Isaac.GetEntityVariantByName("Ezra's Moonlight") -- variant 3555 in entities2.xml
POR.MOONLIGHT_VARIANT = EZRA_MOONLIGHT.VARIANT -- main.lua references this for callback registration

local COLLISION_RADIUS = 20
local BUFF_DURATION_FRAMES = 1250 -- 25 seconds; tuned from testing (750 measured as ~15s, so scaled up proportionally)
local BUFF_MAX_MULTIPLIER = 1.5 -- 1.5x all stats at pickup, fading linearly down to 1x
local BUFF_CACHE_FLAGS = CacheFlag.CACHE_DAMAGE | CacheFlag.CACHE_FIREDELAY | CacheFlag.CACHE_SPEED
    | CacheFlag.CACHE_RANGE | CacheFlag.CACHE_SHOTSPEED | CacheFlag.CACHE_LUCK

-- Spawns the moonlight effect playing its Appear animation
---@param position Vector
---@param player EntityPlayer
---@function
function EZRA_MOONLIGHT:SpawnMoonlight(position, player)
    local effect = Isaac.Spawn(EntityType.ENTITY_EFFECT, EZRA_MOONLIGHT.VARIANT, 0, position, Vector.Zero, player):ToEffect()
    effect:GetSprite():Play("Appear", true)
    return effect
end

-- Holds on Appear's 2nd frame once it finishes, then plays Disappear and grants the buff when any player overlaps it
---@param effect EntityEffect
---@function
function EZRA_MOONLIGHT:MoonlightUpdate(effect)
    local sprite = effect:GetSprite()
    local data = effect:GetData()

    if data.POR_Disappearing then
        if sprite:IsFinished("Disappear") then
            effect:Remove()
        end
        return
    end

    if sprite:IsPlaying("Appear") then
        if sprite:IsFinished("Appear") then
            sprite:SetFrame("Appear", 1) -- hold on the 2nd frame until a player collides with it
        end
        return
    end

    for _, ent in ipairs(Isaac.FindInRadius(effect.Position, COLLISION_RADIUS, EntityPartition.PLAYER)) do
        local player = ent:ToPlayer()
        if player then
            player:GetData().POR_EzraBuffFramesLeft = BUFF_DURATION_FRAMES
            player:AddCacheFlags(BUFF_CACHE_FLAGS, true)
            player:EvaluateItems()

            sprite:Play("Disappear", true)
            data.POR_Disappearing = true
            break
        end
    end
end

-- Ticks down the buff timer each frame and keeps the cache re-evaluating so the fade is smooth
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, function(_, player)
    local pData = player:GetData()
    local framesLeft = pData.POR_EzraBuffFramesLeft
    if framesLeft and framesLeft > 0 then
        pData.POR_EzraBuffFramesLeft = framesLeft - 1
        player:AddCacheFlags(BUFF_CACHE_FLAGS, true)
        player:EvaluateItems()
    end
end)

-- Applies the fading stat multiplier while the buff is active
POR:AddCallback(ModCallbacks.MC_EVALUATE_CACHE, function(_, player, cacheFlag)
    local framesLeft = player:GetData().POR_EzraBuffFramesLeft
    if not framesLeft or framesLeft <= 0 then return end

    local factor = 1 + (BUFF_MAX_MULTIPLIER - 1) * (framesLeft / BUFF_DURATION_FRAMES)

    if cacheFlag == CacheFlag.CACHE_DAMAGE then
        player.Damage = player.Damage * factor
    elseif cacheFlag == CacheFlag.CACHE_FIREDELAY then
        player.MaxFireDelay = player.MaxFireDelay / factor
    elseif cacheFlag == CacheFlag.CACHE_SPEED then
        player.MoveSpeed = player.MoveSpeed * factor
    elseif cacheFlag == CacheFlag.CACHE_RANGE then
        player.TearRange = player.TearRange * factor
    elseif cacheFlag == CacheFlag.CACHE_SHOTSPEED then
        player.ShotSpeed = player.ShotSpeed * factor
    elseif cacheFlag == CacheFlag.CACHE_LUCK then
        player.Luck = player.Luck * factor
    end
end)

return EZRA_MOONLIGHT