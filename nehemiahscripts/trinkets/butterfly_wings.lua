local game = Game()

BUTTERFLYWINGS_TRINKET_ID = Isaac.GetTrinketIdByName("Butterfly Wings") -- trinket id of Butterfly Wings

local BASE_CHANCE = 0.002 -- 0.2% at 0 luck
local MAX_CHANCE = 0.02 -- 2% at +10 luck
local CHANCE_PER_LUCK = (MAX_CHANCE - BASE_CHANCE) / 10

-- Has a luck-scaled chance to upgrade one plain rock in the room into a Tinted Rock, if the room doesn't already have one
POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function()
    local player = Isaac.GetPlayer(0)
    if not player:HasTrinket(BUTTERFLYWINGS_TRINKET_ID) then return end

    local room = game:GetRoom()
    local plainRocks = {}
    local alreadyTinted = false

    for i = 0, room:GetGridSize() - 1 do
        local grid = room:GetGridEntity(i)
        if grid then
            local gridType = grid:GetType()
            if gridType == GridEntityType.GRID_ROCK and grid:GetVariant() == 0 then
                table.insert(plainRocks, i)
            elseif gridType == GridEntityType.GRID_ROCK_SS then
                alreadyTinted = true
            end
        end
    end

    if alreadyTinted or #plainRocks == 0 then return end

    local chance = math.min(MAX_CHANCE, math.max(0, BASE_CHANCE + CHANCE_PER_LUCK * player.Luck))
    local rng = player:GetTrinketRNG(BUTTERFLYWINGS_TRINKET_ID)

    if rng:RandomFloat() < chance then
        local gridIndex = plainRocks[rng:RandomInt(#plainRocks) + 1]
        local pos = room:GetGridPosition(gridIndex)
        room:RemoveGridEntity(gridIndex, 0, false)
        Isaac.GridSpawn(GridEntityType.GRID_ROCK_SS, 0, pos, true)
    end
end)