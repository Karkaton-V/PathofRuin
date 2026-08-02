local game = Game()

BOOKOFNEHEMIAH_ITEM_ID = Isaac.GetItemIdByName("Book of Nehemiah") -- item id of Book of Nehemiah

-- Mimics Crack the Sky's meteor shower and summons Ezra's Moonlight, which grants the fading all-stats buff and clears the floor's curse on contact
function POR:BookofNehemiahUse(_, _, player)
    local room = game:GetRoom()

    player:UseActiveItem(CollectibleType.COLLECTIBLE_CRACK_THE_SKY, UseFlag.USE_NOANNOUNCER | UseFlag.USE_NOANIM | UseFlag.USE_OWNED)
    POR.EzrasMoonlight:SpawnMoonlight(room:GetCenterPos(), player, true)

    return true
end