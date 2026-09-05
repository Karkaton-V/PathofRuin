GOLDBRICK_ITEM_ID = Isaac.GetItemIdByName("Gold Brick") -- item id of Gold Brick

local PETRIFY_CHANCE = 0.5
local GOLD_DUST_COUNT = 8 -- matches the impact burst on a golden boulder (nehemiahs_boulder.lua)
local GOLD_TEAR_COLOR = Color(1, 0.85, 0.3, 1, 0, 0, 0)

-- Grants golden rock tears for the rest of the room
function POR:GoldBrickUse(_, rng, player)
    player:GetData().POR_GoldBrickActive = true
    player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR, true)
    player:EvaluateItems()
    return true
end

-- Tints every tear gold while active
function POR:GoldBrickTearColor(player)
    if not player:GetData().POR_GoldBrickActive then return end
    player.TearColor = GOLD_TEAR_COLOR
end

-- Converts each fired tear into a rock tear while active, tagged for the petrify roll below
function POR:GoldBrickFireTear(tear)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player or not player:GetData().POR_GoldBrickActive then return end

    tear:ChangeVariant(TearVariant.ROCK)
    tear:GetData().POR_GoldBrickTear = true
end

-- Same dust burst and gold-freeze combo as the impact on a golden boulder (nehemiahs_boulder.lua); FLAG_MIDAS_FREEZE is the flag on Midas' Touch, covering both the petrify and the gold-ify
local function applyGoldEffect(enemy, position, player)
    for _ = 1, GOLD_DUST_COUNT do
        local velAngle = math.random() * 360
        local vel = Vector.FromAngle(velAngle) * (math.random() * 4 + 2)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.GOLD_PARTICLE, 0, position, vel, player)
    end
    enemy:AddEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE)
end

-- 50% chance to petrify + gold-ify the enemy a golden rock tear hits
function POR:GoldBrickTearCollision(tear, collider)
    local data = tear:GetData()
    if not data.POR_GoldBrickTear then return end

    local npc = collider:ToNPC()
    if not npc then return end
    if math.random() >= PETRIFY_CHANCE then return end

    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    applyGoldEffect(npc, tear.Position, player)
end

-- Expires when the room or floor changes; a plain dot-function, since ForEachPlayer calls it positionally as func(player, index) rather than via colon self-binding
function POR.ClearGoldBrick(player)
    local pData = player:GetData()
    if pData.POR_GoldBrickActive then
        pData.POR_GoldBrickActive = false
        player:AddCacheFlags(CacheFlag.CACHE_TEARCOLOR, true)
        player:EvaluateItems()
    end
end

function POR:GoldBrickClearAll()
    POR:ForEachPlayer(POR.ClearGoldBrick)
end
