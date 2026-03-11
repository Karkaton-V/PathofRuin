-- Boulder entity logic for Nehemiah's Hammer
-- Adapted from Epiphany (TR Samson's Boulder) by Team Epiphany
-- Key changes from original:
--   - TR Samson references replaced with Nehemiah equivalents
--   - Scheduler.Schedule replaced with frame counter
--   - Returns BOULDER table for use via require()

local game = Game()

local BOULDER = {}

POR.BOULDER = BOULDER

Isaac.DebugString("Boulder: " .. tostring(Isaac.GetEntityVariantByName("Nehemiah Throwing Boulder")))
Isaac.DebugString("Holding: " .. tostring(Isaac.GetEntityVariantByName("Nehemiah Holding Boulder")))

BOULDER.PICKUP_EFFECT_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Throwing Boulder")
local BOULDER_VARIANT = BOULDER.PICKUP_EFFECT_VARIANT

-- Currently unused, kept for future use
BOULDER.HOLDING_BOULDER_VARIANT = Isaac.GetEntityVariantByName("Nehemiah Holding Boulder")

BOULDER.TEAR_VARIANT = TearVariant.ROCK
local BOULDER_TEAR_VARIANT = BOULDER.TEAR_VARIANT

local BOULDER_FALL_SPEED_BEAST = 8

-- Defined locally here so boulder code is self-contained
local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

--[[
-- Sprite variants corresponding to the rock sprites of each stage.
BOULDER.SPRITE_VARIANTS = {
    Basement       = 1,
    Cellar         = 2,
    BurningBasement = 3,
    Downpour       = 4,
    Dross          = 5,
    Caves          = 6,
    Catacombs      = 7,
    FloodedCaves   = 8,
    Mines          = 9,
    Ashpit         = 10,
    Depths         = 11,
    Necropolis     = 12,
    DankDepths     = 13,
    Mausoleum      = 14,
    Gehenna        = 15,
    Womb           = 16,
    Utero          = 17,
    ScarredWomb    = 18,
    BlueWomb       = 19,
    Corpse         = 20,
    Sheol          = 21,
    Cathedral      = 22,
    Chest          = 23,
    DarkRoom       = 24,
    Home           = 25,
    HomeB          = 26,
}

-- Maps GetRoomConfigStage() return values to sprite variants.
-- https://wofsauge.github.io/IsaacDocs/rep/Room.html?h=stage#getroomconfigstage
BOULDER.STAGE_TO_VARIANT = {
    [1]  = BOULDER.SPRITE_VARIANTS.Basement,
    [2]  = BOULDER.SPRITE_VARIANTS.Cellar,
    [3]  = BOULDER.SPRITE_VARIANTS.BurningBasement,
    [27] = BOULDER.SPRITE_VARIANTS.Downpour,
    [28] = BOULDER.SPRITE_VARIANTS.Dross,

    [4]  = BOULDER.SPRITE_VARIANTS.Caves,
    [5]  = BOULDER.SPRITE_VARIANTS.Catacombs,
    [6]  = BOULDER.SPRITE_VARIANTS.FloodedCaves,
    [29] = BOULDER.SPRITE_VARIANTS.Mines,
    [30] = BOULDER.SPRITE_VARIANTS.Ashpit,

    [7]  = BOULDER.SPRITE_VARIANTS.Depths,
    [8]  = BOULDER.SPRITE_VARIANTS.Necropolis,
    [9]  = BOULDER.SPRITE_VARIANTS.DankDepths,
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

-- Special room types that override the stage-based variant.
BOULDER.ROOMTYPE_TO_VARIANT = {
    [RoomType.ROOM_DEVIL]  = BOULDER.SPRITE_VARIANTS.Sheol,
    [RoomType.ROOM_ANGEL]  = BOULDER.SPRITE_VARIANTS.Cathedral,
    [RoomType.ROOM_CHEST]  = BOULDER.SPRITE_VARIANTS.Chest,
    [RoomType.ROOM_BLUE]   = BOULDER.SPRITE_VARIANTS.BlueWomb,
    [RoomType.ROOM_ISAACS] = BOULDER.SPRITE_VARIANTS.Home,
    [RoomType.ROOM_BARREN] = BOULDER.SPRITE_VARIANTS.Home,
}

-- Tear flags that produce bad results on boulder tears.
-- These are stripped when a boulder is fired.
BOULDER.ForbiddenTearFlags =
    TearFlags.TEAR_ABSORB       |
    TearFlags.TEAR_SPLIT        |
    TearFlags.TEAR_SHIELDED     |
    TearFlags.TEAR_STICKY       |
    TearFlags.TEAR_BELIAL       |
    TearFlags.TEAR_BURSTSPLIT   |
    TearFlags.TEAR_ORBIT_ADVANCED

-- Copies all visual properties from one sprite to another.
local function cloneSprite(sprite, toClone)
    sprite:Load(toClone:GetFilename(), true)
    sprite.Color         = toClone.Color
    sprite.FlipX         = toClone.FlipX
    sprite.FlipY         = toClone.FlipY
    sprite.Offset        = toClone.Offset
    sprite.PlaybackSpeed = toClone.PlaybackSpeed
    sprite.Rotation      = toClone.PlaybackSpeed -- matches original (intentional copy from PlaybackSpeed)
    sprite.Scale         = toClone.Scale
    sprite:SetFrame(toClone:GetAnimation(), toClone:GetFrame())
    sprite:SetOverlayFrame(toClone:GetOverlayAnimation(), toClone:GetOverlayFrame())
end

-- ================================================================================
-- FireBoulder
-- Fires the held boulder as a tear in the given direction.
-- ================================================================================

---@param player EntityPlayer
---@param direction Vector
---@param damage? number
---@function
function BOULDER:FireBoulder(player, direction, damage)
    direction = direction:Normalized()
    damage = damage or (player.Damage * 2)

    local vel = direction * player.ShotSpeed * 10 * 2.5
    vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * 1.1

    local boulder = player:FireTear(player.Position, vel, true, false, true, player)
    boulder.Position = player.Position -- override position set by FireTear
    boulder:ChangeVariant(BOULDER_TEAR_VARIANT)
    boulder.CollisionDamage = damage
    boulder:ClearTearFlags(BOULDER.ForbiddenTearFlags)

    BOULDER:BoulderInit(
        boulder,
        player,
        player:GetData().POR_HoldingBoulderSprite,
        player:GetData().POR_HoldingBoulderAnm2,
        player:GetData().POR_HoldingBoulderDontUpdate
    )
    boulder:GetData().POR_BoulderTags = {}

    SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE)

    return boulder
end


---@function
function BOULDER:SpawnBoulder(position, player)
    local boulder = Isaac.Spawn(
        EntityType.ENTITY_EFFECT,
        BOULDER.PICKUP_EFFECT_VARIANT,
        0,
        position,
        Vector.Zero,
        player
    ):ToEffect()

    if not boulder then return end

    BOULDER:BoulderInit(boulder, player)
    return boulder
end


-- ================================================================================
-- GetStageId
-- Returns the current stage's config ID, used to select the correct rock sprite.
-- No official enum exists for these values.
-- ================================================================================

---@function
function BOULDER:GetStageId()
    local level     = game:GetLevel()
    local stage     = level:GetAbsoluteStage()
    local isAlt     = level:IsAltStage()
    local stageType = level:GetStageType()

    if stage == LevelStage.STAGE1_1 or stage == LevelStage.STAGE1_2 or stage == LevelStage.STAGE1_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then
            return 27
        elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
            return 28
        else
            if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
                return 3
            elseif stageType == StageType.STAGETYPE_ORIGINAL then
                return 1
            else
                return 2
            end
        end
    end

    if stage == LevelStage.STAGE2_1 or stage == LevelStage.STAGE2_2 or stage == LevelStage.STAGE2_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then
            return 29
        elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
            return 30
        else
            if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
                return 6
            elseif stageType == StageType.STAGETYPE_ORIGINAL then
                return 4
            else
                return 5
            end
        end
    end

    if stage == LevelStage.STAGE3_1 or stage == LevelStage.STAGE3_2 or stage == LevelStage.STAGE3_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then
            return 31
        elseif stageType == StageType.STAGETYPE_REPENTANCE_B then
            return 32
        else
            if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
                return 9
            elseif stageType == StageType.STAGETYPE_ORIGINAL then
                return 7
            else
                return 8
            end
        end
    end

    if stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2 or stage == LevelStage.STAGE4_GREED then
        if stageType == StageType.STAGETYPE_REPENTANCE then
            return 33
        else
            if isAlt and stageType == StageType.STAGETYPE_AFTERBIRTH then
                return 12
            elseif stageType == StageType.STAGETYPE_ORIGINAL then
                return 10
            else
                return 11
            end
        end
    end

    if stage == LevelStage.STAGE4_3 then
        return 13
    end

    if stage == LevelStage.STAGE5_GREED then
        return 15
    end

    if stage == LevelStage.STAGE5 then
        if isAlt then
            return 15
        else
            return 14
        end
    end

    if stage == LevelStage.STAGE6 then
        if isAlt then
            return 17
        else
            return 16
        end
    end

    if stage == LevelStage.STAGE6_GREED then
        return 24
    end

    if stage == LevelStage.STAGE7 then
        return 26
    end

    if stage == LevelStage.STAGE7_GREED then
        return 25
    end

    if stage == LevelStage.STAGE8 then
        return 35
    end
end

-- ================================================================================
-- BoulderInit
-- Initialises the sprite on a boulder pickup effect or thrown tear.
-- Called once when the entity is first encountered.
-- ================================================================================

---@param entity EntityEffect | EntityTear
---@param sender EntityPlayer
---@param forceSheet string?    Override the spritesheet path.
---@param forceAnm2 string?     Override the anm2 path.
---@param dontUpdate boolean?   If true, skip sprite loading/playing entirely.
---@function
function BOULDER:BoulderInit(entity, sender, forceSheet, forceAnm2, dontUpdate)
    local variant     = math.random(1, 3)  -- picks one of the three boulder variation spritesheets
    local sprite      = entity:GetSprite()
    local stage       = BOULDER:GetStageId()
    local roomType    = game:GetRoom():GetType()
    local stageVariant = BOULDER.ROOMTYPE_TO_VARIANT[roomType]
        or BOULDER.STAGE_TO_VARIANT[stage]
        or BOULDER.SPRITE_VARIANTS.Basement

    local newSheet
    if forceSheet then
        newSheet = forceSheet
    else
        newSheet = "gfx/misc/boulders_" .. tostring(variant) .. ".png"
    end

    if not entity:GetData().POR_HoldingBoulderDontUpdate and not dontUpdate then
        if forceAnm2 then
            sprite:Load(forceAnm2, false)
        end
        sprite:ReplaceSpritesheet(0, newSheet)
        sprite:LoadGraphics()
    end

    entity:GetData().POR_BoulderSheet = newSheet

    if not entity:GetData().POR_HoldingBoulderDontUpdate and not dontUpdate then
        if entity.Type == EntityType.ENTITY_EFFECT then
            -- per-variant drop animation (Appear1 through Appear27)
            sprite:Play("Appear" .. tostring(stageVariant), true)
        else
            -- idle animation on the thrown tear
            sprite:Play("Idle" .. tostring(stageVariant), true)
        end
    end

    if entity:GetData().POR_BoulderFallingBeast then
        sprite:Stop()
    end

    return newSheet
end

-- ================================================================================
-- ManageBoulderPickupSprite
-- After the per-variant appear animation finishes, transitions to the
-- single-frame "Appear" idle pose at the correct variant offset.
-- ================================================================================

---@param boulder EntityEffect
---@function
function BOULDER:ManageBoulderPickupSprite(boulder)
    if not boulder then return end
    local sprite      = boulder:GetSprite()
    local stage       = BOULDER:GetStageId()
    local roomType    = game:GetRoom():GetType()
    local stageVariant = BOULDER.ROOMTYPE_TO_VARIANT[roomType]
        or BOULDER.STAGE_TO_VARIANT[stage]
        or BOULDER.SPRITE_VARIANTS.Basement

    if not boulder:GetData().POR_HoldingBoulderDontUpdate then
        if not sprite:IsPlaying("Appear" .. tostring(stageVariant))
            or boulder:GetData().POR_BoulderFallingBeast
        then
            sprite:SetFrame("Appear", stageVariant - 1)
        end
    end
end

POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, BOULDER.ManageBoulderPickupSprite, BOULDER_VARIANT)

-- ================================================================================
-- BoulderBeastFalling
-- Moves Beast-fight boulders downward each frame and removes them
-- if they leave the room bounds.
-- ================================================================================

---@param boulder EntityEffect
---@function
function BOULDER:BoulderBeastFalling(boulder)
    if not boulder then return end
    if boulder:GetData().POR_BoulderFallingBeast then
        boulder.Position = boulder.Position + Vector(0, BOULDER_FALL_SPEED_BEAST)
        if boulder.Position.Y > game:GetRoom():GetBottomRightPos().Y then
            boulder:Remove()
        end
    end
end

POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, BOULDER.BoulderBeastFalling, BOULDER_VARIANT)

-- ================================================================================
-- StopHolding
-- Makes the player drop the held boulder immediately.
-- ================================================================================

---@param player EntityPlayer
---@param playHideAnim boolean?  If true, plays the HideItem animation as well.
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

-- ================================================================================
-- PostPlayerUpdate
-- Handles throwing the boulder when the player shoots,
-- and re-playing the hold animation while the boulder is held.
-- ================================================================================

---@param player EntityPlayer
---@function
function BOULDER:PostPlayerUpdate(player)
    local pData = player:GetData()
    if not pData.POR_BoulderFrameCount then
        pData.POR_BoulderFrameCount = 0
    end

    if pData.POR_HoldingBoulder then
        local isShooting = player:GetShootingJoystick():Length() > 1e-3

        if isShooting then
            -- Require the player to hold the shoot direction for at least 9 frames
            -- before firing, to avoid accidental throws.
            if pData.POR_BoulderFrameCount > 9 then
                local aimDirection = player:GetShootingJoystick():Normalized()
                BOULDER:FireBoulder(player, aimDirection)

                player:AnimatePickup(Sprite(), false, "HideItem")
                pData.POR_HoldingBoulder = false
                pData.POR_BoulderFrameCount = 0
            end
        else
            -- Drop boulder automatically if the player is near a big chest.
            for _, chest in ipairs(Isaac.FindInRadius(player.Position, 10, EntityPartition.PICKUP)) do
                if chest.Variant == PickupVariant.PICKUP_BIGCHEST then
                    pData.POR_HoldingBoulder = false
                end
            end

            -- Re-play the LiftItem hold animation each time the previous one ends.
            if player:IsExtraAnimationFinished() then
                local stage = BOULDER:GetStageId()
                local stageVariant = pData.POR_HoldingBoulderIsSpecial and 1
                    or BOULDER.STAGE_TO_VARIANT[stage]
                    or BOULDER.SPRITE_VARIANTS.Basement

                if not pData.POR_HoldingBoulderDontUpdate then
                    local Bould = Sprite()
                    Bould:Load("gfx/nehemiahs_boulder.anm2", false)
                    Bould:ReplaceSpritesheet(0, pData.POR_HoldingBoulderSprite)
                    Bould:SetFrame("Appear", stageVariant - 1)
                    Bould:LoadGraphics()
                    player:AnimatePickup(Bould, false, "LiftItem")
                else
                    if pData.POR_EnemyBoulderSprite then
                        local sprite = Sprite()
                        cloneSprite(sprite, pData.POR_EnemyBoulderSprite)
                        player:AnimatePickup(sprite, false, "LiftItem")
                    end
                end

                pData.POR_BoulderFrameCount = 1
            end
        end

        pData.POR_BoulderFrameCount = pData.POR_BoulderFrameCount + 1
    end
end

POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, BOULDER.PostPlayerUpdate)

-- ================================================================================
-- PickupEffectCollision
-- Called when a player walks into a boulder pickup effect.
-- Only Nehemiah and Tainted Nehemiah can pick up boulders.
-- Returns true if the boulder was successfully picked up.
-- ================================================================================

---@param pickup EntityEffect
---@param player EntityPlayer
---@function
function BOULDER:PickupEffectCollision(pickup, player)
    local pData = player:GetData()
    local playerType = player:GetPlayerType()

    if playerType ~= NEHEMIAH_TYPE and playerType ~= TAINTED_NEHEMIAH_TYPE then
        return
    end

    if not pData.POR_HoldingBoulder then
        player:AnimatePickup(pickup:GetSprite(), false, "LiftItem")
        pData.POR_HoldingBoulder        = true
        pData.POR_HoldingBoulderSprite  = pickup:GetData().POR_BoulderSheet
        pData.POR_HoldingBoulderAnm2    = pickup:GetData().POR_BoulderAnm2
        pData.POR_HoldingBoulderIsSpecial  = pickup:GetData().POR_HoldingBoulderIsSpecial
        pData.POR_HoldingBoulderDontUpdate = pickup:GetData().POR_HoldingBoulderDontUpdate
        pData.POR_EnemyBoulderSprite    = pickup:GetData().POR_EnemyBoulderSprite

        pickup:Remove()
        return true
    end
end

-- ================================================================================
-- OnUpdate
-- Each frame, checks every boulder pickup effect for player collisions.
-- The boulder can only be picked up once its appear animation is complete.
-- ================================================================================

---@function
function BOULDER:OnUpdate()
    for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, BOULDER_VARIANT)) do
        local boulder = ent:ToEffect()
        if not boulder then goto continue end

        -- "AppearXX" (numbered) = still dropping. "Appear" (no number) = idle, can be picked up.
        if boulder:GetSprite():GetAnimation():match("Appear.+") then
            goto continue
        end

        local collidingPlayers = Isaac.FindInRadius(boulder.Position, boulder.Size, EntityPartition.PLAYER)
        for _, entPlayer in ipairs(collidingPlayers) do
            local player = entPlayer:ToPlayer()
            if player
                and player.Variant == 0
                and player:IsExtraAnimationFinished()
                and not player:IsCoopGhost()
            then
                if BOULDER:PickupEffectCollision(boulder, player) then
                    break
                end
            end
        end

        ::continue::
    end
end

POR:AddCallback(ModCallbacks.MC_POST_UPDATE, BOULDER.OnUpdate)

-- ================================================================================
-- OnBoulderDeath
-- Spawns 5 small rock tears in random directions when the boulder dies.
-- If it hit a wall, scatters them away from the wall direction.
-- ================================================================================

---@param boulder EntityTear
---@param player EntityPlayer
---@param hitWall boolean
---@function
function BOULDER:OnBoulderDeath(boulder, player, hitWall)
    SFXManager():Play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND)

    for _ = 1, 5 do
        local pos = boulder.Position - boulder.Velocity * 1.5

        local velAngle
        if hitWall then
            velAngle = (pos - boulder.Position):GetAngleDegrees() + math.random() * 180 - 90
        else
            velAngle = math.random() * 360
        end

        local vel    = Vector.FromAngle(velAngle) * (math.random() * 10 + 6)
        local newTear = player:FireTear(pos, vel)

        newTear.CollisionDamage      = player.Damage * 0.75
        newTear:ChangeVariant(TearVariant.ROCK)
        newTear.FallingSpeed         = -8 * (math.random() * 2 - 0.5)
        newTear.FallingAcceleration  = 2 + math.random() * 2
    end

    if hitWall then
        boulder:Die()
        boulder.Visible = false
    end
end

-- ================================================================================
-- BoulderUpdate
-- Runs every frame on thrown boulder tears.
-- Handles on-death rock scatter for both wall collisions (collidingNormally /
-- collidingWithWall) and entity collisions (via a 1-frame delayed check stored
-- in POR_BoulderCollideCheck, replacing Epiphany's Scheduler.Schedule).
-- ================================================================================

---@param tear EntityTear
---@function
function BOULDER:BoulderUpdate(tear)
    local spawner = tear.SpawnerEntity
    local player  = spawner and spawner:ToPlayer()

    local collidingNormally = tear:CollidesWithGrid()
        and not tear:HasTearFlags(TearFlags.TEAR_HYDROBOUNCE | TearFlags.TEAR_BOUNCE)

    local collidingWithWall = not tear:HasTearFlags(TearFlags.TEAR_SPECTRAL | TearFlags.TEAR_BOUNCE_WALLSONLY)
        and tear.Position:Distance(game:GetRoom():GetClampedPosition(tear.Position, tear.Size)) > 1e-6

    -- Initialise sprite on first update
    if tear:GetData().POR_BoulderSheet == nil then
        BOULDER:BoulderInit(tear, player or Isaac.GetPlayer(0))
    end

    local data = tear:GetData()

    -- 1-frame delayed death check for entity collision (replaces Scheduler.Schedule).
    -- POR_BoulderCollideCheck is set to 1 by BoulderCollide when an entity is hit.
    if data.POR_BoulderCollideCheck then
        data.POR_BoulderCollideCheck = data.POR_BoulderCollideCheck - 1
        if data.POR_BoulderCollideCheck <= 0 then
            data.POR_BoulderCollideCheck = nil
            local playerRef    = data.POR_BoulderCollidePlayer
            local collidePlayer = playerRef and playerRef.Entity and playerRef.Entity:ToPlayer()
            if tear:IsDead() and collidePlayer then
                BOULDER:OnBoulderDeath(tear, collidePlayer, false)
            end
            data.POR_BoulderCollidePlayer = nil
        end
    end

    if not player then return end

    if tear:IsDead() or tear:CollidesWithGrid() then
        BOULDER:OnBoulderDeath(tear, player, collidingNormally or collidingWithWall)
    end
end

POR:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, BOULDER.BoulderUpdate, BOULDER_TEAR_VARIANT)

-- ================================================================================
-- BoulderCollide
-- Called when the boulder tear hits an entity.
-- Sets a 1-frame delay flag so BoulderUpdate can check if the tear died from it.
-- ================================================================================

---@param tear EntityTear
---@param collider Entity
---@function
function BOULDER:BoulderCollide(tear, collider)
    local spawner = tear.SpawnerEntity
    local player  = spawner and spawner:ToPlayer()

    if player then
        local data = tear:GetData()
        data.POR_BoulderCollideCheck  = 1
        data.POR_BoulderCollidePlayer = EntityRef(player)
    end
end

POR:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, BOULDER.BoulderCollide, BOULDER_TEAR_VARIANT)

-- ================================================================================
-- Stop-holding callbacks
-- Cancels the held boulder when the player uses items that require both hands.
-- ================================================================================

local function stopHoldingBoulder(_, _, _, player)
    BOULDER:StopHolding(player)
end

local function stopHoldingHideAnim(_, _, _, player)
    BOULDER:StopHolding(player, true)
end

POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingBoulder, CollectibleType.COLLECTIBLE_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingBoulder, CollectibleType.COLLECTIBLE_RED_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingBoulder, CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingBoulder, CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingHideAnim, CollectibleType.COLLECTIBLE_URN_OF_SOULS)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, stopHoldingHideAnim, CollectibleType.COLLECTIBLE_NOTCHED_AXE)

-- ================================================================================
-- HideBouldersOnTrapdoor
-- Stops all players from holding boulders when entering a trapdoor or beam.
-- ================================================================================

---@function
function BOULDER:HideBouldersOnTrapdoor()
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
        for i = 0, numPlayers - 1 do
            BOULDER:StopHolding(Isaac.GetPlayer(i), true)
        end
    end
end

POR:AddCallback(ModCallbacks.MC_POST_UPDATE, BOULDER.HideBouldersOnTrapdoor)
--]]

return BOULDER