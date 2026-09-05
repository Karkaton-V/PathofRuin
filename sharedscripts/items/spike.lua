local game = Game()

SPIKE_ITEM_ID = Isaac.GetItemIdByName("Spike") -- item id of Spike

SPIKE_TYPE = EntityType.ENTITY_EFFECT
SPIKE_VARIANT = Isaac.GetEntityVariantByName("Spike Ball") -- a custom entity (entities2.xml), fully custom AI/physics -- not tied to vanilla Ball and Chain (893), which fights the manual sprite control

local FRAGMENT_DAMAGE_MULT = 0.75 -- matches the boulder/old brick fragment burst convention elsewhere in this project
local MAX_FRAGMENTS = 10
local BASE_LIFETIME_SECONDS = 2
local FRAMES_PER_SECOND = 30
local HIT_COOLDOWN_FRAMES = 20 -- per-enemy deflect/speed-restore cooldown (damage itself has no cooldown -- see below)
local ENEMY_DEFLECT_ANGLE = 15 -- degrees, randomized +/- on each enemy pierce
local ENEMY_SPEED_RESTORE = 3 -- speed regained on each enemy pierce, capped at the original launch speed of the ball
local SHADOW_HEIGHT_OFFSET = -10 -- raises the ball sprite off the shadow, since ball_and_chain.anm2 pivots at the centre of the frame and would otherwise draw over it; matches the 10px pivot drop rock_pickup.anm2 uses

-- While Uranus is held the ball uses an icy spritesheet, explodes into TearVariant.ICE fragments instead of ROCK, and has a flat chance to freeze each enemy it pierces
local URANUS_SPRITESHEET = "gfx/effects/ball_and_chain_snow.png"
local URANUS_FREEZE_CHANCE = 0.8
local URANUS_FREEZE_DURATION_SECONDS = 1

-- EffectVariant.ROCK_EXPLOSION reused for the stone-chunk burst; a verified constant and the closest ROCK_* match, though not confirmed as the exact variant Stoney spawns
local STONE_CHUNKS_EFFECT_VARIANT = EffectVariant.ROCK_EXPLOSION

-- Brimstone disables the chargebar and ball and turns the beam into a petrify laser; a plain RGB tint cannot grey a pure red beam
local BRIMSTONE_PETRIFY_COLOR = Color(1, 1, 1, 1, 0, 0, 0)
BRIMSTONE_PETRIFY_COLOR:SetColorize(1, 1, 1, 1)
BRIMSTONE_PETRIFY_COLOR:SetOffset(0.25, 0.25, 0.25)
local BOSS_SLOW_VALUE = 0.5 -- 50% slow, matching the AddSlowing example in the official docs

local SHOOT_DIR_THRESHOLD = 0.1
local SHOT_SPEED_BASE = 10 -- matches the standard tear base-speed convention used elsewhere (see nehemiahs_boulder.lua)
local MOVEMENT_INHERITANCE_MULT = 1.1 -- matches ThrowBoulder in nehemiahs_boulder.lua
local HORIZONTAL_SPAWN_HEIGHT_OFFSET = -10 -- raises the spawn point for horizontal shots, matching HORIZONTAL_THROW_HEIGHT_OFFSET in nehemiahs_boulder.lua

-- Fully custom chargebar with no vanilla WeaponType, avoiding conflicting fire/explosion behavior such as the Monstro's Lungs duplication bug
local CHARGEBAR_ANM2 = "gfx/ui/ui_spikechargebar.anm2"
local CHARGEBAR_ANIM_FRAMES = 100 -- "Charging" has 101 frames (0-100); scrubbed manually by charge progress
local CHARGEBAR_OFFSET = Vector(18, -54) -- scaled by player.SpriteScale at render time, matching the reference mod
local MAX_CHARGE_FRAMES = 80 -- ~2.67s to fully charge (half the fill rate); nothing fires until it's reached, then release to fire

-- Registered first (main.lua loads spike.lua before ammoniac.lua), so this bar keeps the base CHARGEBAR_OFFSET and later-registered bars offset around it
POR.RegisterChargeBarItem(SPIKE_ITEM_ID)
local CHARGEBAR_STACK_SPACING = 24 -- vertical gap between stacked bars, pre-SpriteScale

-- 8-way compass angles (screen-space: 0=East, 90=South, 180=West, 270=North) for picking the closest Slow_X animation
local SLOW_DIRECTIONS = {
    { name = "Slow_E",  angle = 0 },
    { name = "Slow_SE", angle = 45 },
    { name = "Slow_S",  angle = 90 },
    { name = "Slow_SW", angle = 135 },
    { name = "Slow_W",  angle = 180 },
    { name = "Slow_NW", angle = 225 },
    { name = "Slow_N",  angle = 270 },
    { name = "Slow_NE", angle = 315 },
}

-- Picks the Slow_X animation whose compass angle is closest to the given direction
local function closestSlowAnim(direction)
    local angle = direction:GetAngleDegrees() % 360
    local best, bestDiff = SLOW_DIRECTIONS[1].name, math.huge
    for _, dir in ipairs(SLOW_DIRECTIONS) do
        local diff = math.abs(((angle - dir.angle + 180) % 360) - 180)
        if diff < bestDiff then
            best, bestDiff = dir.name, diff
        end
    end
    return best
end

-- Spawns a Spike ball at a position with a given velocity and linear decay to zero over the lifetime; shared so the Buff crew in The Masons can throw a shrunken one
function POR.SpawnSpikeBall(player, spawnPos, vel, scale, fragmentOverride)
    local spike = Isaac.Spawn(SPIKE_TYPE, SPIKE_VARIANT, 0, spawnPos, Vector.Zero, player):ToEffect()
    if not spike then return nil end

    scale = scale or 1
    spike.Size = spike.Size * scale
    spike.SpriteScale = spike.SpriteScale * scale
    spike.SpriteOffset = Vector(0, SHADOW_HEIGHT_OFFSET * scale)

    local lifetimeFrames = BASE_LIFETIME_SECONDS * FRAMES_PER_SECOND + math.floor(player.TearRange / 10)

    local data = spike:GetData()
    data.POR_SpikeOwner = player
    data.POR_SpikeDamage = player.Damage
    data.POR_SpikeVelocity = vel
    data.POR_SpikeLaunchSpeed = vel:Length() -- ceiling for the speed restored by piercing an enemy
    data.POR_SpikeDecayPerFrame = vel:Length() / lifetimeFrames -- linear falloff to ~0 by the time it expires
    data.POR_SpikeExpireFrame = Isaac.GetFrameCount() + lifetimeFrames
    data.POR_SpikeIcy = player:HasCollectible(CollectibleType.COLLECTIBLE_URANUS) -- cached at spawn, since Uranus is a passive
    data.POR_SpikeFragments = fragmentOverride -- nil leaves the burst on the default (2 + Luck) count

    local sprite = spike:GetSprite()
    if data.POR_SpikeIcy then
        sprite:ReplaceSpritesheet(0, URANUS_SPRITESHEET)
        sprite:LoadGraphics()
    end
    if math.abs(vel.X) > math.abs(vel.Y) then
        sprite:Play("RollHori", true)
    else
        sprite:Play("RollVert", true)
    end
    return spike
end

-- Launches a charged Spike ball from the player: raised spawn point for horizontal shots and player movement folded into the velocity
local function fireSpike(player, direction)
    direction = direction:Normalized()
    local vel = direction * player.ShotSpeed * SHOT_SPEED_BASE
    vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * MOVEMENT_INHERITANCE_MULT

    local spawnPos = player.Position
    if math.abs(direction.X) > math.abs(direction.Y) then
        spawnPos = spawnPos + Vector(0, HORIZONTAL_SPAWN_HEIGHT_OFFSET)
    end

    POR.SpawnSpikeBall(player, spawnPos, vel)
end

-- Hold the shoot direction to charge and keep holding to stay charged, then release to fire; releasing below full charge fires nothing
function POR.SpikePlayerUpdate(_, player)
    if not player:HasCollectible(SPIKE_ITEM_ID) then return end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end -- see the petrify-laser caveat below

    local pData = player:GetData()
    local dir = player:GetShootingJoystick()

    if dir:Length() > SHOOT_DIR_THRESHOLD then
        pData.POR_SpikeLastDir = dir
        local charge = pData.POR_SpikeCharge or 0
        if charge < MAX_CHARGE_FRAMES then
            pData.POR_SpikeCharge = charge + 1
        end
    else
        local charge = pData.POR_SpikeCharge or 0
        if charge >= MAX_CHARGE_FRAMES and pData.POR_SpikeLastDir then
            fireSpike(player, pData.POR_SpikeLastDir)
        end
        pData.POR_SpikeCharge = 0
    end
end

-- Renders the chargebar above the head of one player through the Charging -> StartCharged -> Charged -> Disappear state flow
local function renderSpikeBar(player)
    if not player:HasCollectible(SPIKE_ITEM_ID) or not Options.ChargeBars then return end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end -- see the petrify-laser caveat below

    local pData = player:GetData()
    if not pData.POR_SpikeBar then
        local sprite = Sprite()
        sprite:Load(CHARGEBAR_ANM2, true)
        pData.POR_SpikeBar = sprite
        pData.POR_SpikeStartCharged = true
    end
    local bar = pData.POR_SpikeBar

    if Isaac.GetFrameCount() % 2 == 0 then
        bar:Update()
    end

    local charge = pData.POR_SpikeCharge or 0
    local holding = player:GetShootingJoystick():Length() > SHOOT_DIR_THRESHOLD

    if holding then
        if charge < MAX_CHARGE_FRAMES then
            bar:Play("Charging")
            bar:SetFrame(math.floor(charge * CHARGEBAR_ANIM_FRAMES / MAX_CHARGE_FRAMES))
        elseif pData.POR_SpikeStartCharged then
            bar:Play("StartCharged")
            pData.POR_SpikeStartCharged = false
        elseif not bar:IsPlaying("StartCharged") and not bar:IsPlaying("Charged") then
            bar:Play("Charged")
        end
    else
        if not bar:IsPlaying("Disappear") and (bar:IsPlaying("Charging") or bar:IsPlaying("Charged") or bar:IsPlaying("StartCharged")) then
            bar:Play("Disappear")
        end
        pData.POR_SpikeStartCharged = true
    end

    local room = game:GetRoom()
    if room:HasWater() and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end

    local stackIndex = POR.ChargeBarStackIndex(player, SPIKE_ITEM_ID)
    local offsetY = CHARGEBAR_OFFSET.Y - stackIndex * CHARGEBAR_STACK_SPACING
    local offset = Vector(CHARGEBAR_OFFSET.X * player.SpriteScale.X, offsetY * player.SpriteScale.Y)
    bar:Render(Isaac.WorldToScreen(player.Position + offset))
end

function POR.SpikeBarRender()
    POR:ForEachPlayer(renderSpikeBar)
end

-- Bursts into (2 + Luck) rock or, with Uranus, icicle tear fragments capped at 10, plays the stone-chunk explosion visual, then removes the ball
local function explode(effect)
    local data = effect:GetData()
    local player = data.POR_SpikeOwner

    Isaac.Spawn(EntityType.ENTITY_EFFECT, STONE_CHUNKS_EFFECT_VARIANT, 0, effect.Position, Vector.Zero, player)

    if player and player:Exists() then
        local fragmentCount = data.POR_SpikeFragments or math.max(0, math.min(MAX_FRAGMENTS, math.floor(2 + player.Luck)))
        for _ = 1, fragmentCount do
            local velAngle = math.random() * 360
            local vel = Vector.FromAngle(velAngle) * (math.random() * 8 + 6)
            local fragment

            if data.POR_SpikeIcy then
                fragment = Isaac.Spawn(EntityType.ENTITY_TEAR, TearVariant.ICE, 0, effect.Position, vel, player):ToTear()
                fragment:AddTearFlags(TearFlags.TEAR_ICE)
            else
                fragment = player:FireTear(effect.Position, vel)
                fragment:ChangeVariant(TearVariant.ROCK)
            end

            fragment.CollisionDamage = player.Damage * FRAGMENT_DAMAGE_MULT
        end
    end

    effect:Remove()
end

-- Destroys any rock or poop grid obstacle at the position so the ball passes through instead of bouncing; fireplaces are regular NPCs and are handled by the enemy-pierce logic below
local function destroyGridObstacle(room, pos)
    local gridEntity = room:GetGridEntity(room:GetGridIndex(pos))
    if not gridEntity then return end
    if (gridEntity:ToRock() or gridEntity:ToPoop()) and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE then
        gridEntity:Destroy(true)
    end
end

-- Moves and collides Spike balls by hand each frame, mirroring ProjectileUpdate in nehemiahs_boulder.lua
function POR.SpikeEffectUpdate(_, effect)
    local data = effect:GetData()
    if not data.POR_SpikeOwner then return end

    if Isaac.GetFrameCount() >= data.POR_SpikeExpireFrame then
        explode(effect)
        return
    end

    local vel = data.POR_SpikeVelocity
    local decay = data.POR_SpikeDecayPerFrame
    if decay and decay > 0 then
        local speed = vel:Length()
        if speed > 0 then
            local newSpeed = math.max(0, speed - decay)
            vel = (newSpeed > 0) and vel:Resized(newSpeed) or Vector.Zero
        end
    end

    local pos = effect.Position
    local room = game:GetRoom()

    for _, ent in ipairs(Isaac.FindInRadius(pos + vel, effect.Size, EntityPartition.ENEMY)) do -- enemies are pierced, not bounced; the nudge and speed restore stay on a per-enemy cooldown
        if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
            ent:TakeDamage(data.POR_SpikeDamage, 0, EntityRef(data.POR_SpikeOwner), 0)

            local enemyData = ent:GetData()
            local lastHit = enemyData.POR_SpikeLastHitFrame
            if not lastHit or Isaac.GetFrameCount() - lastHit >= HIT_COOLDOWN_FRAMES then
                enemyData.POR_SpikeLastHitFrame = Isaac.GetFrameCount()

                vel = vel:Rotated(math.random(-ENEMY_DEFLECT_ANGLE, ENEMY_DEFLECT_ANGLE))
                local restoredSpeed = math.min(data.POR_SpikeLaunchSpeed, vel:Length() + ENEMY_SPEED_RESTORE)
                vel = vel:Resized(restoredSpeed)
                effect:GetSprite():Play(closestSlowAnim(vel), true)

                if data.POR_SpikeIcy and math.random() < URANUS_FREEZE_CHANCE then
                    ent:AddFreeze(EntityRef(data.POR_SpikeOwner), URANUS_FREEZE_DURATION_SECONDS * FRAMES_PER_SECOND, true)
                end
            end
            break -- only resolve one enemy per frame
        end
    end

    destroyGridObstacle(room, pos + vel)

    local blockedX = room:GetGridCollisionAtPos(Vector(pos.X + vel.X, pos.Y)) ~= GridCollisionClass.COLLISION_NONE -- tested per axis so corners bounce correctly
    local blockedY = room:GetGridCollisionAtPos(Vector(pos.X, pos.Y + vel.Y)) ~= GridCollisionClass.COLLISION_NONE

    if blockedX or blockedY then
        if blockedX then vel = Vector(-vel.X, vel.Y) end
        if blockedY then vel = Vector(vel.X, -vel.Y) end
        data.POR_SpikeVelocity = vel
        effect:GetSprite():Play(closestSlowAnim(vel), true)
        return -- bounced in place this frame; resumes moving next frame
    end

    data.POR_SpikeVelocity = vel
    effect.Position = pos + vel
end

-- Recolors the Brimstone beam light grey each frame for a player holding both items, using SetColor with a 1-frame duration rather than a plain .Color assignment
function POR.SpikeBrimstoneRecolor(_, laser)
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(SPIKE_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end
    laser:SetColor(BRIMSTONE_PETRIFY_COLOR, 1, 1, false, false)
end

-- Rolls a (10 + Luck)% chance per frame of contact to afflict an enemy for 5 + Luck seconds: AddFreeze for regular enemies, AddSlowing for bosses so a held beam cannot lock one down
function POR.SpikeBrimstonePetrify(_, laser, collider)
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(SPIKE_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end

    local enemy = collider:ToNPC()
    if not enemy or not enemy:IsActiveEnemy() or not enemy:IsVulnerableEnemy() then return end

    local chance = math.max(0, math.min(1, (10 + player.Luck) / 100))
    if math.random() >= chance then return end

    local durationFrames = math.floor((5 + player.Luck) * FRAMES_PER_SECOND)
    if enemy:IsBoss() then
        enemy:AddSlowing(EntityRef(player), durationFrames, BOSS_SLOW_VALUE, BRIMSTONE_PETRIFY_COLOR)
    else
        enemy:AddFreeze(EntityRef(player), durationFrames, true)
    end
end
