local game = Game()

OILYBRANCH_TRINKET_ID = Isaac.GetTrinketIdByName("Oily Branch") -- trinket id of Oily Branch

local BASE_CHANCE = 0.10 -- at 0 luck
local MAX_CHANCE = 0.80 -- at +10 luck
local CHANCE_PER_LUCK = (MAX_CHANCE - BASE_CHANCE) / 10
local CHARM_TEAR_COLOR = Color(1, 0.55, 0.75, 1, 0, 0, 0) -- pink

-- Gives tears a chance to become charming (colored pink), scaling from 10% at 0 luck up to 80% at +10 luck
POR:AddCallback(ModCallbacks.MC_POST_FIRE_TEAR, function(_, tear)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player then return end
    if not player:HasTrinket(OILYBRANCH_TRINKET_ID) then return end

    local chance = math.min(MAX_CHANCE, math.max(0, BASE_CHANCE + CHANCE_PER_LUCK * player.Luck))
    local rng = player:GetTrinketRNG(OILYBRANCH_TRINKET_ID)

    if rng:RandomFloat() < chance then
        tear:AddTearFlags(TearFlags.TEAR_CHARM | TearFlags.TEAR_COLOR)
        tear.Color = CHARM_TEAR_COLOR
    end
end)