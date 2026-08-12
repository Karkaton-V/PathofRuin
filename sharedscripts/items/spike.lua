local game = Game()

SPIKE_ITEM_ID = Isaac.GetItemIdByName("Spike") -- item id of Spike

SPIKE_TYPE = EntityType.ENTITY_EFFECT
SPIKE_VARIANT = Isaac.GetEntityVariantByName("Spike Ball") -- our own entity (entities2.xml), fully custom AI/physics -- not tied to vanilla Ball and Chain (893), which fights our manual sprite control

local FRAGMENT_DAMAGE_MULT = 0.75 -- matches the boulder/old brick fragment burst convention elsewhere in this project
local MAX_FRAGMENTS = 10
local BASE_LIFETIME_SECONDS = 2
local FRAMES_PER_SECOND = 30
local HIT_COOLDOWN_FRAMES = 20 -- per-enemy deflect/speed-restore cooldown (damage itself has no cooldown -- see below)
local ENEMY_DEFLECT_ANGLE = 15 -- degrees, randomized +/- on each enemy pierce
local ENEMY_SPEED_RESTORE = 3 -- speed regained on each enemy pierce, capped at the ball's original launch speed
local HITBOX_MULT = 1.5 -- matches nehemiahs_boulder.lua's BOULDER_HITBOX_MULT convention

-- Uranus caveat: while held, the ball uses an icy spritesheet, and its explosion fires icy-tinted
-- ROCK-variant tears (see ICE_TEAR_COLOR below) instead of plain rock tears.
local URANUS_SPRITESHEET = "gfx/effects/ball_and_chain_snow.png"

-- TearVariant.ICE rendered fully invisible in testing regardless of TearFlags.TEAR_ICE ordering, so the
-- "icicle" look is instead a light blue-white tint over the (confirmed-visible) ROCK tear variant.
-- TEAR_ICE is still applied for its own freeze/slow mechanic, independent of the visual.
local ICE_TEAR_COLOR = Color(0.75, 0.95, 1, 1, 0.1, 0.2, 0.25)

-- Stoney (302) shatters into rock chunks on death via EffectVariant.ROCK_EXPLOSION -- reused here for the
-- same "blows up into stone chunks" look on our own explosion. Not 100% confirmed to be the exact variant
-- Stoney itself spawns (couldn't inspect its vanilla script directly), but it's a real, verified constant
-- and the closest thematic match among the ROCK_* effect variants.
local STONE_CHUNKS_EFFECT_VARIANT = EffectVariant.ROCK_EXPLOSION

-- Brimstone + Spike caveat: while both are held, Spike's chargebar/ball is disabled entirely and
-- Brimstone's beam (LaserVariant.THICK_RED, filtered in main.lua) becomes a petrify laser instead.
-- AddFreeze is the closest real status-effect API to "petrify" (there's no dedicated Petrify status).
-- Bosses are slowed (AddSlowing) instead of petrified.
-- A plain RGB tint can't turn the beam grey -- its sprite is pure red, so the green/blue channels are
-- already ~0 and multiplying them by anything stays ~0. SetColorize desaturates it to true greyscale
-- first (regardless of the underlying red pixels), then SetOffset brightens it toward "light" grey.
local BRIMSTONE_PETRIFY_COLOR = Color(1, 1, 1, 1, 0, 0, 0)
BRIMSTONE_PETRIFY_COLOR:SetColorize(1, 1, 1, 1)
BRIMSTONE_PETRIFY_COLOR:SetOffset(0.25, 0.25, 0.25)
local BOSS_SLOW_VALUE = 0.5 -- 50% slow, matching the AddSlowing example in the official docs

local SHOOT_DIR_THRESHOLD = 0.1
local SHOT_SPEED_BASE = 10 -- matches the standard tear base-speed convention used elsewhere (see nehemiahs_boulder.lua)
local MOVEMENT_INHERITANCE_MULT = 1.1 -- matches nehemiahs_boulder.lua's ThrowBoulder
local HORIZONTAL_SPAWN_HEIGHT_OFFSET = -10 -- raises the spawn point for horizontal shots, matching nehemiahs_boulder.lua's HORIZONTAL_THROW_HEIGHT_OFFSET

-- Fully custom chargebar -- no vanilla WeaponType involved at all, so there's nothing else's fire/explosion
-- behavior to fight (that's what caused the Monstro's Lungs duplication bug). The bar art/animation states
-- (Charging/StartCharged/Charged/Disappear) were provided by the user, adapted from another mod's chargebar.
local CHARGEBAR_ANM2 = "gfx/ui/ui_spikechargebar.anm2"
local CHARGEBAR_ANIM_FRAMES = 100 -- "Charging" has 101 frames (0-100); scrubbed manually by charge progress
local CHARGEBAR_OFFSET = Vector(18, -54) -- scaled by player.SpriteScale at render time, matching the reference mod
local MAX_CHARGE_FRAMES = 80 -- ~2.67s to fully charge (half the fill rate); nothing fires until it's reached, then release to fire

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

-- Spawns and launches a Spike ball from the player in the given direction. Raises the spawn point for
-- horizontal shots, adds Isaac's own movement into the velocity when he's moving perpendicular to the
-- shot, and decays that velocity linearly to zero over the ball's lifetime.
local function fireSpike(player, direction)
    direction = direction:Normalized()
    local vel = direction * player.ShotSpeed * SHOT_SPEED_BASE
    vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * MOVEMENT_INHERITANCE_MULT

    local spawnPos = player.Position
    if math.abs(direction.X) > math.abs(direction.Y) then
        spawnPos = spawnPos + Vector(0, HORIZONTAL_SPAWN_HEIGHT_OFFSET)
    end

    local spike = Isaac.Spawn(SPIKE_TYPE, SPIKE_VARIANT, 0, spawnPos, Vector.Zero, player):ToEffect()
    if not spike then return end
    spike.Size = spike.Size * HITBOX_MULT

    local lifetimeFrames = BASE_LIFETIME_SECONDS * FRAMES_PER_SECOND + math.floor(player.TearRange / 10)

    local data = spike:GetData()
    data.POR_SpikeOwner = player
    data.POR_SpikeDamage = player.Damage
    data.POR_SpikeVelocity = vel
    data.POR_SpikeLaunchSpeed = vel:Length() -- ceiling for the speed restored by piercing an enemy
    data.POR_SpikeDecayPerFrame = vel:Length() / lifetimeFrames -- linear falloff to ~0 by the time it expires
    data.POR_SpikeExpireFrame = Isaac.GetFrameCount() + lifetimeFrames
    data.POR_SpikeIcy = player:HasCollectible(CollectibleType.COLLECTIBLE_URANUS) -- cached at spawn, since Uranus is a passive

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
end

-- Charge/release gameplay logic: hold the shoot direction to charge, keep holding once full to stay
-- charged (matching the bar's StartCharged flash + Charged loop), then release to fire. Releasing before
-- reaching full charge fires nothing.
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

-- Renders the chargebar above one player's head, driving the sprite through the same
-- Charging -> StartCharged -> Charged -> Disappear state flow as the reference mod
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

    local offset = Vector(CHARGEBAR_OFFSET.X * player.SpriteScale.X, CHARGEBAR_OFFSET.Y * player.SpriteScale.Y)
    bar:Render(Isaac.WorldToScreen(player.Position + offset))
end

function POR.SpikeBarRender()
    POR:ForEachPlayer(renderSpikeBar)
end

-- Bursts into (2 + Luck) rock- or (with Uranus) icicle-variant tear fragments, capped at 10, fired by the
-- original owner, plays the same stone-chunk explosion visual Stoney uses on death, then removes the ball
local function explode(effect)
    local data = effect:GetData()
    local player = data.POR_SpikeOwner

    Isaac.Spawn(EntityType.ENTITY_EFFECT, STONE_CHUNKS_EFFECT_VARIANT, 0, effect.Position, Vector.Zero, player)

    if player and player:Exists() then
        local fragmentCount = math.max(0, math.min(MAX_FRAGMENTS, math.floor(2 + player.Luck)))
        for _ = 1, fragmentCount do
            local velAngle = math.random() * 360
            local vel = Vector.FromAngle(velAngle) * (math.random() * 8 + 6)
            local fragment = player:FireTear(effect.Position, vel)
            fragment.CollisionDamage = player.Damage * FRAGMENT_DAMAGE_MULT
            fragment:ChangeVariant(TearVariant.ROCK)
            if data.POR_SpikeIcy then
                fragment:AddTearFlags(TearFlags.TEAR_ICE) -- freeze/slow mechanic
                fragment:SetColor(ICE_TEAR_COLOR, 1000, 1, false, false) -- icy tint (TearVariant.ICE itself rendered invisible)
            end
        end
    end

    effect:Remove()
end

-- Destroys a rock/poop grid obstacle at the given position, if any, so the ball can pass through it
-- instead of bouncing off it like a wall. Fireplaces aren't handled here -- they're regular NPCs
-- (EntityType.ENTITY_FIREPLACE) and already take damage through the enemy-pierce logic below.
local function destroyGridObstacle(room, pos)
    local gridEntity = room:GetGridEntity(room:GetGridIndex(pos))
    if not gridEntity then return end
    if (gridEntity:ToRock() or gridEntity:ToPoop()) and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE then
        gridEntity:Destroy(true)
    end
end

-- Runs each frame on our Spike balls: fully manual movement/collision (mirrors nehemiahs_boulder.lua's
-- ProjectileUpdate), since this is our own custom effect entity with no built-in AI to lean on.
-- Expires on schedule into a fragment burst; destroys rocks/poop and pierces through enemies (each pierce
-- deals damage, nudges its direction slightly, and restores a bit of speed), but still bounces off walls,
-- switching to the matching Slow_X animation on every bounce or pierce.
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

    -- Enemies: pierced through rather than bounced off of. Damage applies every single frame of overlap
    -- (no cooldown), but the direction nudge + speed restore stays on a per-enemy cooldown so the ball
    -- doesn't spin wildly while sitting inside a big hitbox for several frames in a row
    for _, ent in ipairs(Isaac.FindInRadius(pos + vel, effect.Size, EntityPartition.ENEMY)) do
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
            end
            break -- only resolve one enemy per frame
        end
    end

    destroyGridObstacle(room, pos + vel)

    -- Wall collision, tested per-axis so corners bounce correctly
    local blockedX = room:GetGridCollisionAtPos(Vector(pos.X + vel.X, pos.Y)) ~= GridCollisionClass.COLLISION_NONE
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

-- Brimstone + Spike caveat: recolors Brimstone's beam light grey every frame it's active for a player
-- holding both items (Spike's own chargebar/ball is disabled for them -- see the HasCollectible guards above).
-- Uses SetColor (refreshed every frame via a 1-frame duration) rather than a plain .Color assignment,
-- matching the officially documented way to tint an entity.
function POR.SpikeBrimstoneRecolor(_, laser)
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(SPIKE_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end
    laser:SetColor(BRIMSTONE_PETRIFY_COLOR, 1, 1, false, false)
end

-- Rolls a (10 + Luck)% chance every frame an enemy is touching the recolored beam to afflict it for
-- 5 + Luck seconds: petrified (AddFreeze) for regular enemies, or slowed (AddSlowing) instead for bosses,
-- since a long beam-hold shouldn't be able to just lock a boss down entirely.
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
