ORPIMENT_ITEM_ID = Isaac.GetItemIdByName("Orpiment") -- item id of Orpiment

-- the suggested TEAR_POISON tint from the official docs, so the tears render green
local ORPIMENT_TEAR_COLOR = Color(0.4, 0.97, 0.5, 1, 0, 0, 0)

-- Poison total is a flat 3x the tear damage, overriding the automatic TEAR_POISON amount
local POISON_DAMAGE_MULT = 3

-- NPCs process at most 6 poison ticks (documented engine quirk), landing every 20 frames from frame 23; 123 frames is exactly 6
local POISON_TICKS = 6
local POISON_DURATION_FRAMES = 123

-- On-death explosion radius; nearby enemies take the poison total from the dying enemy and may be poisoned themselves
local EXPLOSION_RADIUS = 100

local EXPLOSION_CREEP_VARIANT = EffectVariant.PLAYER_CREEP_GREEN
local EXPLOSION_CREEP_SCALE = 4 -- bare creep spawns small; scaled up to read as an "explosion"
local EXPLOSION_POISON_BASE_CHANCE = 0.20

-- Ignitable gas cloud, a second hazard spawned alongside the creep: lingers, then explodes if touched by fire, otherwise fades harmlessly
local GAS_CLOUD_LIFETIME_FRAMES = 90
local GAS_CLOUD_VARIANT = EffectVariant.SMOKE_CLOUD -- EntityType.ENTITY_EFFECT (1000), variant 141
local GAS_CLOUD_SCALE = 1.5
local GAS_CLOUD_SPAWN_CHANCE = 0.33
local GAS_IGNITE_RADIUS = 120
local GAS_IGNITE_DAMAGE_MULT = 2
local GAS_IGNITE_VISUAL = EffectVariant.BOMB_EXPLOSION

local gasClouds = {} -- keyed by the InitSeed on the cloud effect: { entity, owner, damage, expireFrame }

-- Keyed by InitSeed rather than enemy:GetData(), which loses the tags before MC_POST_NPC_DEATH fires; cleared on room change to stay bounded
local poisonedEnemies = {}

function POR.OrpimentClearPoisonedOnNewRoom(_)
    poisonedEnemies = {}
    gasClouds = {}
end

-- True if the entity counts as fire for igniting a gas cloud: currently burning, or a Fire Mind / TEAR_BURN tear
local function isFireSource(ent)
    if ent:HasEntityFlags(EntityFlag.FLAG_BURN) then return true end

    local tear = ent:ToTear()
    if tear and (tear.Variant == TearVariant.FIRE_MIND or tear:HasTearFlags(TearFlags.TEAR_BURN)) then
        return true
    end

    return false
end

-- Explodes a gas cloud: fiery visual, bonus damage to everything nearby, cloud removed.
local function igniteGasCloud(record)
    Isaac.Spawn(EntityType.ENTITY_EFFECT, GAS_IGNITE_VISUAL, 0, record.entity.Position, Vector.Zero, record.owner)

    for _, ent in ipairs(Isaac.FindInRadius(record.entity.Position, GAS_IGNITE_RADIUS, EntityPartition.ENEMY)) do
        local enemy = ent:ToNPC()
        if enemy and enemy:IsActiveEnemy() and enemy:IsVulnerableEnemy() then
            enemy:TakeDamage(record.damage * GAS_IGNITE_DAMAGE_MULT, DamageFlag.DAMAGE_FIRE, EntityRef(record.owner), 0)
        end
    end

    record.entity:Remove()
end

-- Runs every frame: expires/removes gas clouds past the lifetime, and checks the rest for nearby fire.
function POR.OrpimentUpdateGasClouds(_)
    for initSeed, record in pairs(gasClouds) do
        if not record.entity:Exists() or Isaac.GetFrameCount() >= record.expireFrame then
            gasClouds[initSeed] = nil
        else
            local ignited = false
            for _, ent in ipairs(Isaac.FindInRadius(record.entity.Position, record.entity.Size, EntityPartition.ENEMY | EntityPartition.TEAR)) do
                if isFireSource(ent) then
                    ignited = true
                    break
                end
            end

            if ignited then
                igniteGasCloud(record)
                gasClouds[initSeed] = nil
            end
        end
    end
end

-- Poisons an enemy for the given total split across the 6 processed ticks, recording owner and total for the on-death explosion
local function applyOrpimentPoison(enemy, player, totalDamage)
    enemy:AddPoison(EntityRef(player), POISON_DURATION_FRAMES, totalDamage / POISON_TICKS)

    poisonedEnemies[enemy.InitSeed] = { owner = player, damage = totalDamage }
end

-- All of the Isaac tears are poison tears while Orpiment is held (items.xml cache="tearflag, tearcolor")
function POR.OrpimentEvaluateCache(_, player, cacheFlag)
    if not player:HasCollectible(ORPIMENT_ITEM_ID) then return end

    if cacheFlag == CacheFlag.CACHE_TEARFLAG then
        player.TearFlags = player.TearFlags | TearFlags.TEAR_POISON
    elseif cacheFlag == CacheFlag.CACHE_TEARCOLOR then
        player.TearColor = ORPIMENT_TEAR_COLOR
    end
end

-- Overrides on-hit poison to 3x the tear damage and tags the enemy for the on-death explosion
function POR.OrpimentTearCollision(_, tear, collider)
    local player = tear.SpawnerEntity and tear.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(ORPIMENT_ITEM_ID) then return end

    local enemy = collider:ToNPC()
    if not enemy or not enemy:IsActiveEnemy() or not enemy:IsVulnerableEnemy() then return end

    applyOrpimentPoison(enemy, player, tear.CollisionDamage * POISON_DAMAGE_MULT)
end

-- An enemy dying while Orpiment-poisoned bursts into creep: nearby enemies take the same damage, with a (20 + Luck)% chance to be poisoned too
function POR.OrpimentNpcDeath(_, npc)
    local record = poisonedEnemies[npc.InitSeed]
    if not record then return end
    poisonedEnemies[npc.InitSeed] = nil

    local player = record.owner
    local damage = record.damage
    if not player or not player:Exists() or not damage then return end

    local spawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, EXPLOSION_CREEP_VARIANT, 0, npc.Position, Vector.Zero, player)
    local creep = spawned and spawned:ToEffect()
    if creep then
        creep.SpriteScale = Vector(EXPLOSION_CREEP_SCALE, EXPLOSION_CREEP_SCALE)
    end

    if math.random() < GAS_CLOUD_SPAWN_CHANCE then
        local gasSpawned = Isaac.Spawn(EntityType.ENTITY_EFFECT, GAS_CLOUD_VARIANT, 0, npc.Position, Vector.Zero, player)
        local gas = gasSpawned and gasSpawned:ToEffect()
        if gas then
            gas.SpriteScale = Vector(GAS_CLOUD_SCALE, GAS_CLOUD_SCALE)
            gasClouds[gas.InitSeed] = {
                entity = gas,
                owner = player,
                damage = damage,
                expireFrame = Isaac.GetFrameCount() + GAS_CLOUD_LIFETIME_FRAMES,
            }
        end
    end

    local poisonChance = math.max(0, math.min(1, EXPLOSION_POISON_BASE_CHANCE + player.Luck / 100))

    for _, ent in ipairs(Isaac.FindInRadius(npc.Position, EXPLOSION_RADIUS, EntityPartition.ENEMY)) do
        local enemy = ent:ToNPC()
        if enemy and enemy ~= npc and enemy:IsActiveEnemy() and enemy:IsVulnerableEnemy() then
            enemy:TakeDamage(damage, 0, EntityRef(player), 0)
            if math.random() < poisonChance then
                applyOrpimentPoison(enemy, player, damage)
            end
        end
    end
end
