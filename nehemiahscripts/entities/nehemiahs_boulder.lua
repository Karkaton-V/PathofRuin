-- Boulder entity logic for Nehemiah's Hammer, adapted from Epiphany (TR Samson) by Team Epiphany
-- "Holding Boulder" (rock_tear.anm2) is the ground pickup: falls from sky, idles, gets collected
-- "Throwing Boulder" (rock_pickup.anm2) is the thrown projectile: flies, hits, fragments

local game = Game()

local BOULDER = {}
POR.ROCKTABLE = BOULDER -- main.lua references POR.ROCKTABLE for all callbacks

BOULDER.PICKUP_VARIANT = Isaac.GetEntityVariantByName("Throwing Boulder") -- ground effect: rock_pickup.anm2 (Appear#, Idle, Collect)
BOULDER.PROJECTILE_VARIANT = Isaac.GetEntityVariantByName("Holding Boulder") -- thrown effect: rock_tear.anm2 (Idle# per floor)

-- Exposed on POR directly for callback registration in main.lua
POR.ROCK_VARIANT = BOULDER.PICKUP_VARIANT
POR.ROCK_PROJECTILE_VARIANT = BOULDER.PROJECTILE_VARIANT

local PROJECTILE_DAMAGE = 40
local PROJECTILE_FRAGMENTS = 3 -- fragments spawned on impact; ordinary tears, no splitting callback attached
local BOULDER_FALL_SPEED_BEAST = 8
local BOULDER_PICKUP_RADIUS = 20

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

-- Sprite variant numbers, matching Appear1-26 / Idle1-26 in the entities' anm2s
BOULDER.SPRITE_VARIANTS = {
    Basement = 1,
    Cellar = 2,
    BurningBasement = 3,
    Downpour = 4,
    Dross = 5,
    Caves = 6,
    Catacombs = 7,
    FloodedCaves = 8,
    Mines = 9,
    Ashpit = 10,
    Depths = 11,
    Necropolis = 12,
    DankDepths = 13,
    Mausoleum = 14,
    Gehenna = 15,
    Womb = 16,
    Utero = 17,
    ScarredWomb = 18,
    BlueWomb = 19, -- Hush's floor
    Corpse = 20,
    Sheol = 21,
    Cathedral = 22,
    Chest = 23, -- Greed/Greedier
    DarkRoom = 24,
    Home = 25,
    HomeB = 26,
}

-- Maps GetRoomConfigStage()-style stage ids to sprite variants; nil for unrecognized stages (e.g. Void)
BOULDER.STAGE_TO_VARIANT = {
    [1] = BOULDER.SPRITE_VARIANTS.Basement,
    [2] = BOULDER.SPRITE_VARIANTS.Cellar,
    [3] = BOULDER.SPRITE_VARIANTS.BurningBasement,
    [27] = BOULDER.SPRITE_VARIANTS.Downpour,
    [28] = BOULDER.SPRITE_VARIANTS.Dross,
    [4] = BOULDER.SPRITE_VARIANTS.Caves,
    [5] = BOULDER.SPRITE_VARIANTS.Catacombs,
    [6] = BOULDER.SPRITE_VARIANTS.FloodedCaves,
    [29] = BOULDER.SPRITE_VARIANTS.Mines,
    [30] = BOULDER.SPRITE_VARIANTS.Ashpit,
    [7] = BOULDER.SPRITE_VARIANTS.Depths,
    [8] = BOULDER.SPRITE_VARIANTS.Necropolis,
    [9] = BOULDER.SPRITE_VARIANTS.DankDepths,
    [31] = BOULDER.SPRITE_VARIANTS.Mausoleum,
    [32] = BOULDER.SPRITE_VARIANTS.Gehenna,
    [10] = BOULDER.SPRITE_VARIANTS.Womb,
    [11] = BOULDER.SPRITE_VARIANTS.Utero,
    [12] = BOULDER.SPRITE_VARIANTS.ScarredWomb,
    [33] = BOULDER.SPRITE_VARIANTS.Corpse,
    [13] = BOULDER.SPRITE_VARIANTS.BlueWomb,
    [14] = BOULDER.SPRITE_VARIANTS.Sheol,
    [15] = BOULDER.SPRITE_VARIANTS.Cathedral,
    [16] = BOULDER.SPRITE_VARIANTS.DarkRoom,
    [17] = BOULDER.SPRITE_VARIANTS.Chest,
    [35] = BOULDER.SPRITE_VARIANTS.Home,
}

-- Special room types that override the stage-based variant regardless of floor
BOULDER.ROOMTYPE_TO_VARIANT = {
    [RoomType.ROOM_DEVIL] = BOULDER.SPRITE_VARIANTS.Sheol,
    [RoomType.ROOM_ANGEL] = BOULDER.SPRITE_VARIANTS.Cathedral,
    [RoomType.ROOM_CHEST] = BOULDER.SPRITE_VARIANTS.Chest,
    [RoomType.ROOM_BLUE] = BOULDER.SPRITE_VARIANTS.BlueWomb,
    [RoomType.ROOM_ISAACS] = BOULDER.SPRITE_VARIANTS.Home,
    [RoomType.ROOM_BARREN] = BOULDER.SPRITE_VARIANTS.Home,
}

-- ================================================================================
-- GetStageId — returns a stage config id used to pick the sprite variant, or nil if unrecognized
-- ================================================================================

---@function
function BOULDER:GetStageId()
    local level = game:GetLevel()
    local stage = level:GetAbsoluteStage()
    local isAlt = level:IsAltStage()
    local stageType = level:GetStageType()

    if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 or stage == LevelStage.STAGE1_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then return 27 end
        if stageType == StageType.STAGETYPE_REPENTANCE_B then return 28 end
        if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then return 3 end
        if stageType == StageType.STAGETYPE_ORIGINAL then return 1 end
        return 2
    end

    if stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 or stage == LevelStage.STAGE2_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then return 29 end
        if stageType == StageType.STAGETYPE_REPENTANCE_B then return 30 end
        if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then return 6 end
        if stageType == StageType.STAGETYPE_ORIGINAL then return 4 end
        return 5
    end

    if stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 or stage == LevelStage.STAGE3_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then return 31 end
        if stageType == StageType.STAGETYPE_REPENTANCE_B then return 32 end
        if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then return 9 end
        if stageType == StageType.STAGETYPE_ORIGINAL then return 7 end
        return 8
    end

    if stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 or stage == LevelStage.STAGE4_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then return 33 end
        if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then return 12 end
        if stageType == StageType.STAGETYPE_ORIGINAL then return 10 end
        return 11
    end

    if stage == LevelStage.STAGE4_3 then return 13 end
    if stage == LevelStage.STAGE5_GREED then return 15 end
    if stage == LevelStage.STAGE5 then return isAlt and 15 or 14 end
    if stage == LevelStage.STAGE6 then return isAlt and 17 or 16 end
    if stage == LevelStage.STAGE6_GREED then return 16 end
    if stage == LevelStage.STAGE7 then return 25 end
    if stage == LevelStage.STAGE7_GREED then return 25 end
    if stage == LevelStage.STAGE8 then return 35 end
    -- Anything else (e.g. Void) falls through and returns nil
end

-- Picks the sprite variant to use, honoring special room types, then floor, then a random fallback
---@function
function BOULDER:GetSpriteVariant()
    local roomType = game:GetRoom():GetType()
    if BOULDER.ROOMTYPE_TO_VARIANT[roomType] then
        return BOULDER.ROOMTYPE_TO_VARIANT[roomType]
    end

    local stageId = BOULDER:GetStageId()
    if stageId and BOULDER.STAGE_TO_VARIANT[stageId] then
        return BOULDER.STAGE_TO_VARIANT[stageId]
    end

    return math.random(1, 26) -- unrecognized stage (Void); rooms there take a random appearance anyway
end

-- Picks one of the 3 rock spritesheets at random
---@function
local function randomRockSheet()
    return "gfx/effects/rock_variation_" .. tostring(math.random(1, 3)) .. ".png"
end

-- ================================================================================
-- PickupInit — sets up a freshly spawned ground boulder pickup
-- ================================================================================

---@param effect EntityEffect
---@function
function BOULDER:PickupInit(effect)
    local data = effect:GetData()
    local sprite = effect:GetSprite()

    data.POR_BoulderSheet = randomRockSheet()
    data.POR_SpriteVariant = BOULDER:GetSpriteVariant()

    Isaac.DebugString("[BoulderDebug] PickupInit: variant=" .. tostring(data.POR_SpriteVariant) .. " sheet=" .. tostring(data.POR_BoulderSheet) .. " roomType=" .. tostring(game:GetRoom():GetType()) .. " stageId=" .. tostring(BOULDER:GetStageId()))

    sprite:ReplaceSpritesheet(0, data.POR_BoulderSheet)
    sprite:LoadGraphics()
    sprite:Play("Appear" .. data.POR_SpriteVariant, true)

    Isaac.DebugString("[BoulderDebug] PickupInit: requested Appear" .. tostring(data.POR_SpriteVariant) .. ", sprite now actually playing: " .. tostring(sprite:GetAnimation()) .. " filename: " .. tostring(sprite:GetFilename()))
end

-- ================================================================================
-- SpawnBoulder — spawns a boulder pickup effect at a given position
-- ================================================================================

---@param position Vector
---@param player EntityPlayer
---@function
function BOULDER:SpawnBoulder(position, player)
    local boulder = Isaac.Spawn(EntityType.ENTITY_EFFECT, BOULDER.PICKUP_VARIANT, 0, position, Vector.Zero, player):ToEffect()
    if not boulder then return end

    BOULDER:PickupInit(boulder)
    return boulder
end

-- ================================================================================
-- PickupUpdate — runs every frame on ground boulder pickups
-- Handles the fall -> idle -> collect state machine, and Beast/Crawlspace gravity fall
-- ================================================================================

---@param effect EntityEffect
---@function
function BOULDER:PickupUpdate(effect)
    local data = effect:GetData()
    local sprite = effect:GetSprite()

    if data.POR_RockFallingBeast then
        effect.Position = effect.Position + Vector(0, BOULDER_FALL_SPEED_BEAST)
        if effect.Position.Y > game:GetRoom():GetBottomRightPos().Y then
            effect:Remove()
        end
        return
    end

    local appearAnim = "Appear" .. data.POR_SpriteVariant
    local idleAnim = "Idle" .. data.POR_SpriteVariant
    if effect.FrameCount % 30 == 0 then
        Isaac.DebugString("[BoulderDebug] PickupUpdate: frame=" .. tostring(effect.FrameCount) .. " currentAnim=" .. tostring(sprite:GetAnimation()) .. " isPlaying(" .. appearAnim .. ")=" .. tostring(sprite:IsPlaying(appearAnim)))
    end
    if sprite:IsPlaying(appearAnim) then
        if sprite:IsFinished(appearAnim) then
            Isaac.DebugString("[BoulderDebug] PickupUpdate: " .. appearAnim .. " finished, switching to " .. idleAnim)
            sprite:Play(idleAnim, true)
        end
        return -- can't be collected while still falling
    end

    for _, ent in ipairs(Isaac.FindInRadius(effect.Position, BOULDER_PICKUP_RADIUS, EntityPartition.PLAYER)) do
        local player = ent:ToPlayer()
        local playerType = player and player:GetPlayerType()
        if effect.FrameCount % 30 == 0 then
            Isaac.DebugString("[BoulderDebug] PickupUpdate: nearby player, type=" .. tostring(playerType) .. " NEHEMIAH_TYPE=" .. tostring(NEHEMIAH_TYPE) .. " dist=" .. tostring(player and (player.Position - effect.Position):Length()) .. " holdingBoulder=" .. tostring(player and player:GetData().POR_HoldingBoulder))
        end
        if player
            and (playerType == NEHEMIAH_TYPE or playerType == TAINTED_NEHEMIAH_TYPE)
            and player.Variant == 0
            and player:IsExtraAnimationFinished()
            and not player:IsCoopGhost()
            and not player:GetData().POR_HoldingBoulder
        then
            Isaac.DebugString("[BoulderDebug] PickupUpdate: granting boulder to player")
            local pData = player:GetData()
            pData.POR_HoldingBoulder = true
            pData.POR_HoldingBoulderSheet = data.POR_BoulderSheet
            player:AnimatePickup(sprite, false, "LiftItem")
            effect:Remove()
            break
        end
    end
end

-- ================================================================================
-- ThrowBoulder — spawns and launches the thrown projectile
-- ================================================================================

---@param player EntityPlayer
---@param direction Vector
---@function
function BOULDER:ThrowBoulder(player, direction)
    direction = direction:Normalized()
    local vel = direction * player.ShotSpeed * 10 * 2.5 -- 10 is the standard tear base speed; 2.5 is boulder-specific weight
    vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * 1.1

    local boulder = Isaac.Spawn(EntityType.ENTITY_EFFECT, BOULDER.PROJECTILE_VARIANT, 0, player.Position, Vector.Zero, player):ToEffect()
    boulder.Velocity = Vector.Zero -- movement is fully manual (see ProjectileUpdate); prevents the engine's own physics/friction from fighting it

    local data = boulder:GetData()
    data.POR_Velocity = vel
    data.POR_BoulderSpawner = EntityRef(player)
    data.POR_SpriteVariant = BOULDER:GetSpriteVariant()

    Isaac.DebugString("[BoulderDebug] ThrowBoulder: spawned=" .. tostring(boulder ~= nil) .. " pos=" .. tostring(boulder.Position) .. " vel=" .. tostring(vel) .. " variant=" .. tostring(boulder.Variant) .. " expectedVariant=" .. tostring(BOULDER.PROJECTILE_VARIANT))

    local sheet = player:GetData().POR_HoldingBoulderSheet or randomRockSheet()
    local sprite = boulder:GetSprite()
    sprite:ReplaceSpritesheet(0, sheet)
    sprite:LoadGraphics()
    sprite:Play("Idle" .. data.POR_SpriteVariant, true)

    SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE)

    return boulder
end

-- ================================================================================
-- burstBoulder — spawns 3 plain, non-recursing rock fragments and removes the boulder
-- ================================================================================

---@param boulder EntityEffect
---@param player EntityPlayer?
---@function
local function burstBoulder(boulder, player)
    SFXManager():Play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND)

    if player then
        for _ = 1, PROJECTILE_FRAGMENTS do
            local velAngle = math.random() * 360
            local vel = Vector.FromAngle(velAngle) * (math.random() * 10 + 6)
            local fragment = player:FireTear(boulder.Position, vel)

            fragment.CollisionDamage = player.Damage * 0.75
            fragment:ChangeVariant(TearVariant.ROCK) -- plain rock tear; no callback is hooked to this variant
            fragment.FallingSpeed = -8 * (math.random() * 2 - 0.5)
            fragment.FallingAcceleration = 2 + math.random() * 2
        end
    end

    boulder:Remove()
end

-- ================================================================================
-- ProjectileUpdate — runs every frame on thrown boulders; manual movement and collision
-- ================================================================================

---@param boulder EntityEffect
---@function
function BOULDER:ProjectileUpdate(boulder)
    boulder.Velocity = Vector.Zero -- keep the engine's own physics from fighting our manual movement below

    local data = boulder:GetData()
    local ref = data.POR_BoulderSpawner
    local player = ref and ref.Entity and ref.Entity:ToPlayer()
    local room = game:GetRoom()
    local vel = data.POR_Velocity or Vector.Zero
    local newPos = boulder.Position + vel

    Isaac.DebugString("[BoulderDebug] ProjectileUpdate: frame=" .. tostring(boulder.FrameCount) .. " pos=" .. tostring(boulder.Position) .. " vel=" .. tostring(vel) .. " newPos=" .. tostring(newPos))

    if room:GetGridCollisionAtPos(newPos) ~= GridCollisionClass.COLLISION_NONE then
        Isaac.DebugString("[BoulderDebug] ProjectileUpdate: hit grid collision, bursting")
        burstBoulder(boulder, player)
        return
    end

    for _, ent in ipairs(Isaac.FindInRadius(newPos, boulder.Size, EntityPartition.ENEMY)) do
        if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
            Isaac.DebugString("[BoulderDebug] ProjectileUpdate: hit enemy, bursting")
            ent:TakeDamage(PROJECTILE_DAMAGE, 0, EntityRef(player), 0)
            burstBoulder(boulder, player)
            return
        end
    end

    boulder.Position = newPos
end

-- ================================================================================
-- PostPlayerUpdate — handles throw-on-shoot and re-playing the carry animation
-- ================================================================================

---@param player EntityPlayer
---@function
function BOULDER:PostPlayerUpdate(player)
    local pData = player:GetData()
    if not pData.POR_BoulderFrameCount then pData.POR_BoulderFrameCount = 0 end

    if pData.POR_HoldingBoulder then
        local isShooting = player:GetShootingJoystick():Length() > 1e-3

        if isShooting then
            -- Require 9 frames of held shoot direction before firing to prevent accidental throws
            if pData.POR_BoulderFrameCount > 9 then
                BOULDER:ThrowBoulder(player, player:GetShootingJoystick():Normalized())
                player:AnimatePickup(Sprite(), false, "HideItem")
                pData.POR_HoldingBoulder = false
                pData.POR_BoulderFrameCount = 0
            end
        else
            -- Drop automatically if near a big chest
            for _, chest in ipairs(Isaac.FindInRadius(player.Position, 10, EntityPartition.PICKUP)) do
                if chest.Variant == PickupVariant.PICKUP_BIGCHEST then
                    pData.POR_HoldingBoulder = false
                end
            end

            -- Re-play hold animation each time the previous one ends
            if player:IsExtraAnimationFinished() then
                local sprite = Sprite()
                sprite:Load("rock_pickup.anm2", false)
                sprite:ReplaceSpritesheet(0, pData.POR_HoldingBoulderSheet)
                sprite:LoadGraphics()
                sprite:Play("Idle" .. BOULDER:GetSpriteVariant(), true)
                player:AnimatePickup(sprite, false, "LiftItem")
                pData.POR_BoulderFrameCount = 1
            end
        end

        pData.POR_BoulderFrameCount = pData.POR_BoulderFrameCount + 1
    end
end

-- ================================================================================
-- StopHolding — makes the player drop their held boulder
-- ================================================================================

---@param player EntityPlayer
---@param playHideAnim boolean?  if true, also plays the HideItem animation
---@function
function BOULDER:StopHolding(player, playHideAnim)
    local pData = player:GetData()
    if pData.POR_HoldingBoulder then
        if playHideAnim then
            player:AnimatePickup(Sprite(), false, "HideItem")
        else
            player:StopExtraAnimation()
        end
        pData.POR_HoldingBoulder = false
        pData.POR_BoulderFrameCount = 0
    end
end

-- Exposed on POR for item use callbacks registered in main.lua
POR.stopHoldingRock = function(_, _, _, player) BOULDER:StopHolding(player) end
POR.stopHoldingHideAnim = function(_, _, _, player) BOULDER:StopHolding(player, true) end

-- ================================================================================
-- HideRocksOnTrapdoor — drops all held boulders when any player enters a trapdoor
-- ================================================================================

---@function
function BOULDER:HideRocksOnTrapdoor()
    local enteringTrapdoor = false
    local numPlayers = game:GetNumPlayers()

    for i = 0, numPlayers - 1 do
        local player = Isaac.GetPlayer(i)
        if (player:GetSprite():IsPlaying("Trapdoor") or player:GetSprite():IsPlaying("LightTravel"))
            and player.ControlsEnabled == false
        then
            enteringTrapdoor = true
            break
        end
    end

    if enteringTrapdoor then
        for i = 0, numPlayers - 1 do BOULDER:StopHolding(Isaac.GetPlayer(i), true) end
    end
end

-- ================================================================================
-- BedSleptCheck — reserved for future home-stage sprite reset logic
-- ================================================================================

---@function
function BOULDER:BedSleptCheck(bed, player)
end

return BOULDER