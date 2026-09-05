HOLYSMOKES_ITEM_ID = Isaac.GetItemIdByName("Holy Smokes!") -- item id of Holy Smokes!

local ANGEL_CHANCE_BONUS = 20 -- +20 Angel Room chance

-- Boosts Angel Room chance, not Devil; hooked on MC_PRE_DEVIL_APPLY_ITEMS since that's where most chance-boosting items apply, before the stage penalty
function POR.HolySmokesAngelChance(_, chance)
    if not PlayerManager.FirstCollectibleOwner(HOLYSMOKES_ITEM_ID) then return end
    return chance + ANGEL_CHANCE_BONUS
end

-- Burn aura radius matches the glow sprite in holy_smokes_item.anm2
local AURA_RADIUS = 96
local BURN_DURATION = 30 -- frames; matches the docs' own 1-tick-per-second example
local BURN_DAMAGE = 1

-- Burns every enemy inside the aura each frame, letting FindInRadius do the radius and enemy filtering natively rather than scanning the whole room
function POR.HolySmokesBurnAura(_, player)
    if not player:HasCollectible(HOLYSMOKES_ITEM_ID) then return end

    for _, ent in ipairs(Isaac.FindInRadius(player.Position, AURA_RADIUS, EntityPartition.ENEMY)) do
        local npc = ent:ToNPC()
        if npc and npc:IsActiveEnemy() and npc:IsVulnerableEnemy() then
            npc:AddBurn(EntityRef(player), BURN_DURATION, BURN_DAMAGE)
        end
    end
end

-- Rendered manually since the aura never renders through the vanilla costume pipeline
local AURA_SPRITE = Sprite()
AURA_SPRITE:Load("gfx/characters/holy_smokes_item.anm2", true)
AURA_SPRITE:Play("HeadDown", true)
AURA_SPRITE.Scale = Vector(3, 3)

function POR.HolySmokesRenderAura(_, player, renderOffset)
    if not player:HasCollectible(HOLYSMOKES_ITEM_ID) then return end

    AURA_SPRITE:Update()
    AURA_SPRITE:Render(Isaac.WorldToRenderPosition(player.Position) + renderOffset + Vector(0, 48), Vector.Zero, Vector.Zero)
end
