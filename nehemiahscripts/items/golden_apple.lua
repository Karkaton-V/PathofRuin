local game = Game()

GOLDENAPPLE_ITEM_ID = Isaac.GetItemIdByName("Golden Apple") -- item id of Golden Apple
-- Costume is fully automatic: costumes2.xml's <costume id="..." type="passive"> matches items.xml's <passive id="...">

local INVINCIBILITY_FRAMES = 500 -- ~10 seconds, using this project's empirically-tuned ~50fps conversion

-- Total effective HP across red/soul/black and bone hearts, in half-heart units
local function getTotalHealth(player)
    return player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts()
end

-- Grants a golden heart just before fatal damage lands, so the native damage code consumes it instead of Isaac's real health
POR:AddCallback(ModCallbacks.MC_ENTITY_TAKE_DMG, function(_, entity, amount, damageFlags, source, countdownFrames)
    local player = entity:ToPlayer()
    if not player then return end

    if player:HasInvincibility() then return false end -- still within a previous save's i-frames

    if not player:HasCollectible(GOLDENAPPLE_ITEM_ID) then return end
    if amount < getTotalHealth(player) then return end -- not fatal; let it through normally

    -- Fatal hit: grant the golden heart (and a half soul heart) so they absorb this hit, then let the damage proceed
    player:AddGoldenHearts(1)
    player:AddSoulHearts(1) -- 1 unit = half a soul heart

    player:SetMinDamageCooldown(INVINCIBILITY_FRAMES) -- native invincibility + vanilla flicker animation
    player:UseActiveItem(CollectibleType.COLLECTIBLE_MIDAS_TOUCH, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    player:RemoveCollectible(GOLDENAPPLE_ITEM_ID)

    -- no explicit return: the damage goes through, and the golden heart is what actually gets consumed
end, EntityType.ENTITY_PLAYER)