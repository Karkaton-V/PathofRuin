local game = Game()

BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra") -- item id of Book of Ezra

-- Spawns Ezra's Moonlight at the room's center
function POR:BookofEzraUse(_, _, player)
    POR.EzrasMoonlight:SpawnMoonlight(game:GetRoom():GetCenterPos(), player)
    return true
end