local game = Game()

GOLDENAPPLE_ITEM_ID = Isaac.GetItemIdByName("Golden Apple") -- item id of Golden Apple
-- Costume is fully automatic: the <costume id="..." type="passive"> entry in costumes2.xml matches the <passive id="..."> entry in items.xml

local INVINCIBILITY_FRAMES = 500 -- ~10 seconds, using the empirically-tuned ~50fps conversion

-- Total effective HP across red/soul/black and bone hearts, in half-heart units
local function getTotalHealth(player)
    return player:GetHearts() + player:GetSoulHearts() + player:GetBoneHearts()
end

-- Grants a golden heart right before a fatal hit, so it absorbs the damage instead
function POR.GoldenAppleTakeDamage(_, entity, amount, damageFlags, source, countdownFrames)
    local player = entity:ToPlayer()
    if not player then return end

    if player:HasInvincibility() then return false end -- still within the i-frames from a previous save

    if not player:HasCollectible(GOLDENAPPLE_ITEM_ID) then return end
    if amount < getTotalHealth(player) then return end -- not fatal; let it through normally

    player:AddGoldenHearts(1)
    player:AddSoulHearts(1)

    player:SetMinDamageCooldown(INVINCIBILITY_FRAMES) -- native invincibility + vanilla flicker animation
    player:UseActiveItem(CollectibleType.COLLECTIBLE_MIDAS_TOUCH, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    player:RemoveCollectible(GOLDENAPPLE_ITEM_ID)
end