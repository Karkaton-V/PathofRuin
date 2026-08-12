CURSEDRING_ITEM_ID = Isaac.GetItemIdByName("Cursed Ring") -- item id of Cursed Ring
-- Costume is fully automatic: costumes2.xml's <costume id="..." type="passive"> matches items.xml's <passive id="...">

local SEAL_BASE_DURATION = 8 -- seconds, before adding Luck

-- Seals any active, vulnerable enemy that touches a Cursed Ring holder
function POR:CursedRingSeal(npc, collider, low)
    if not npc:IsActiveEnemy() or not npc:IsVulnerableEnemy() then return end

    local player = collider:ToPlayer()
    if not player then return end
    if not player:HasCollectible(CURSEDRING_ITEM_ID) then return end

    POR.Sealed.Apply(npc, player, SEAL_BASE_DURATION + player.Luck)
end
