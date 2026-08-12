OLDBRICK_ITEM_ID = Isaac.GetItemIdByName("Old Brick") -- item id of Old Brick

local RANGE_DOWN = 1.5 -- range stat down; *10 matches the TearRange scaling convention used elsewhere
local PROC_CHANCE = 0.15
local SCALE_MULT = 1.4 -- "Large" tear
local TEAR_TINT = Color(0.65, 0.12, 0.12, 1, 0, 0, 0) -- darker red
local TINT_DURATION = 1000 -- frames; generously longer than any tear's lifespan

-- Tuned to mimic Ipecac's lob arc; adjust to taste
local ARC_FALLING_SPEED = -9
local ARC_FALLING_ACCELERATION = 0.5

local FRAGMENT_COUNT = 4
local FRAGMENT_DAMAGE_MULT = 0.75 -- matches Nehemiah's Hammer's boulder-burst fragments (nehemiahs_boulder.lua)

function POR.OldBrickEvaluateCache(_, player)
    if not player:HasCollectible(OLDBRICK_ITEM_ID) then return end
    player.TearRange = player.TearRange - RANGE_DOWN * 10
end

-- 15% chance to convert a fired tear into a large, red-tinted rock tear that lobs like Ipecac
function POR.OldBrickFireTear(_, tear)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(OLDBRICK_ITEM_ID) then return end
    if math.random() >= PROC_CHANCE then return end

    tear:ChangeVariant(TearVariant.ROCK)
    tear.Scale = tear.Scale * SCALE_MULT
    tear:SetColor(TEAR_TINT, TINT_DURATION, 1, false, false)
    tear.FallingSpeed = ARC_FALLING_SPEED
    tear.FallingAcceleration = ARC_FALLING_ACCELERATION

    tear:GetData().POR_OldBrickTear = true
end

-- Spawns the 4-fragment burst at the tear's current position; marks it split so it only ever fires once
local function splitOldBrickTear(tear, data)
    data.POR_OldBrickSplit = true

    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player then return end

    for _ = 1, FRAGMENT_COUNT do
        local velAngle = math.random() * 360
        local vel = Vector.FromAngle(velAngle) * (math.random() * 6 + 4)
        local fragment = player:FireTear(tear.Position, vel)

        fragment.CollisionDamage = player.Damage * FRAGMENT_DAMAGE_MULT
        fragment:ChangeVariant(TearVariant.ROCK)
        fragment.FallingSpeed = -8 * (math.random() * 2 - 0.5)
        fragment.FallingAcceleration = 2 + math.random() * 2
    end
end

-- Splits the instant it hits an enemy -- catches contact a frame earlier than waiting on IsDead()
function POR.OldBrickTearCollision(_, tear, collider)
    local data = tear:GetData()
    if not data.POR_OldBrickTear or data.POR_OldBrickSplit then return end
    if not collider:ToNPC() then return end

    splitOldBrickTear(tear, data)
end

-- Splits once the tear dies from hitting an obstacle (walls don't fire a tear collision callback)
function POR.OldBrickTearUpdate(_, tear)
    local data = tear:GetData()
    if not data.POR_OldBrickTear or data.POR_OldBrickSplit then return end
    if not tear:IsDead() then return end

    splitOldBrickTear(tear, data)
end
