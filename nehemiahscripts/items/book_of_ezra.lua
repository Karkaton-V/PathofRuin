local game = POR.Game()

BOOKOFEZRA_ITEM_ID = Isaac.GetItemIdByName("Book of Ezra")        -- item id of Book of Ezra
EZRASMOONLIGHTEFFECT = Isaac.GetEntityTypeByName("Ezra's Moonlight")   -- effect id of the book's light

function POR:BookofEzraUse(_, _, player)
    local room = game:GetRoom()
    Isaac.Spawn(EntityType.ENTITY_EFFECT, Isaac.GetEntityVariantByName("Ezra's Moonlight") , 1, room:GetCenterPos(), Vector.Zero, nil) 


    return true
end