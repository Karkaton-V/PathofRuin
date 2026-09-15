PISTANTHROPHOBIA_ITEM_ID = Isaac.GetItemIdByName("Pistanthrophobia") -- item id of Pistanthrophobia

local DAMAGE_PER_ENEMY = 0.5

-- Counts active, vulnerable enemies currently in the room (same definition as POR:RoomHasEnemies)
local function countRoomEnemies()
    local count = 0
    for _, ent in ipairs(Isaac.GetRoomEntities()) do
        if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
            count = count + 1
        end
    end
    return count
end

-- +0.5 damage per enemy currently in the room
function POR.PistanthrophobiaEvaluateCache(_, player)
    if not player:HasCollectible(PISTANTHROPHOBIA_ITEM_ID) then return end

    player.Damage = player.Damage + DAMAGE_PER_ENEMY * countRoomEnemies()
end

-- Forces a damage re-evaluation for any player holding the item, recalculating live as enemies spawn or die rather than waiting on the next unrelated cache trigger
function POR.RefreshPistanthrophobia()
    POR:ForEachPlayer(function(player)
        if player:HasCollectible(PISTANTHROPHOBIA_ITEM_ID) then
            player:AddCacheFlags(CacheFlag.CACHE_DAMAGE, true)
            player:EvaluateItems()
        end
    end)
end

-- Rendered manually since the aura never renders through the vanilla costume pipeline
local AURA_SPRITE = Sprite()
AURA_SPRITE:Load("gfx/characters/pistanthrophobia_item.anm2", true)
AURA_SPRITE:Play("HeadDown", true)
AURA_SPRITE.Scale = Vector(2, 2)

-- T. Nehemiah is the only exception: keeps the stat effect, not the visual (see nehemiah.lua)
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)

function POR.PistanthrophobiaRenderAura(_, player, renderOffset)
    if not player:HasCollectible(PISTANTHROPHOBIA_ITEM_ID) then return end
    if player:GetPlayerType() == TAINTED_NEHEMIAH_TYPE then return end

    AURA_SPRITE:Update()
    AURA_SPRITE:Render(Isaac.WorldToRenderPosition(player.Position) + renderOffset + Vector(0, 32), Vector.Zero, Vector.Zero)
end
