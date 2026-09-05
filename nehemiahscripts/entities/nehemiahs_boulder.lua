-- Boulder entity logic for Nehemiah's Hammer (ground pickup + thrown projectile)

local game = Game()

local BOULDER = {}
POR.ROCKTABLE = BOULDER -- main.lua references POR.ROCKTABLE for all callbacks

BOULDER.PICKUP_VARIANT = Isaac.GetEntityVariantByName("Throwing Boulder") -- ground effect: rock_pickup.anm2 (Appear#, Idle, Collect)
BOULDER.PICKUP_VARIANT_TINTED = Isaac.GetEntityVariantByName("Throwing Boulder (Tinted)")
BOULDER.PICKUP_VARIANT_GOLDEN = Isaac.GetEntityVariantByName("Throwing Boulder (Golden)")
BOULDER.PROJECTILE_VARIANT = Isaac.GetEntityVariantByName("Holding Boulder") -- thrown effect: rock_tear.anm2 (Idle# per floor)
BOULDER.PROJECTILE_VARIANT_TINTED = Isaac.GetEntityVariantByName("Holding Boulder (Tinted)")
BOULDER.PROJECTILE_VARIANT_GOLDEN = Isaac.GetEntityVariantByName("Holding Boulder (Golden)")

-- Exposed on POR directly for callback registration in main.lua
POR.ROCK_VARIANT = BOULDER.PICKUP_VARIANT
POR.ROCK_VARIANT_TINTED = BOULDER.PICKUP_VARIANT_TINTED
POR.ROCK_VARIANT_GOLDEN = BOULDER.PICKUP_VARIANT_GOLDEN
POR.ROCK_PROJECTILE_VARIANT = BOULDER.PROJECTILE_VARIANT
POR.ROCK_PROJECTILE_VARIANT_TINTED = BOULDER.PROJECTILE_VARIANT_TINTED
POR.ROCK_PROJECTILE_VARIANT_GOLDEN = BOULDER.PROJECTILE_VARIANT_GOLDEN

local PROJECTILE_DAMAGE = 40
local PROJECTILE_FRAGMENTS = 3 -- fragments spawned on impact; ordinary tears, no splitting callback attached
local BOULDER_FALL_SPEED_BEAST = 8
local HORIZONTAL_THROW_HEIGHT_OFFSET = -10 -- raises the spawn point when thrown mostly left/right

-- Boulder kinds: which spritesheet + entity variants each rolls (all 3 share one anm2 each; only ReplaceSpritesheet changes the look, variants exist so ProjectileUpdate can tell them apart)
BOULDER.KIND_NORMAL = "Normal"
BOULDER.KIND_GOLDEN = "Golden"
BOULDER.KIND_TINTED = "Tinted"

local GOLDEN_CHANCE = 0.10
local TINTED_CHANCE = 0.01
local NEHEMIAH_KIND_BONUS = 0.05 -- untainted Nehemiah gets +5% to each of golden and tinted

BOULDER.KIND_DATA = {
    [BOULDER.KIND_NORMAL] = {
        Sheet = "gfx/effects/rock_variation_1.png",
        SheetFF = "gfx/effects/rock_variation_1_ff.png",
        PickupVariant = BOULDER.PICKUP_VARIANT,
        ProjectileVariant = BOULDER.PROJECTILE_VARIANT,
    },
    [BOULDER.KIND_GOLDEN] = {
        Sheet = "gfx/effects/rock_variation_3.png",
        SheetFF = "gfx/effects/rock_variation_3_ff.png",
        PickupVariant = BOULDER.PICKUP_VARIANT_GOLDEN,
        ProjectileVariant = BOULDER.PROJECTILE_VARIANT_GOLDEN,
    },
    [BOULDER.KIND_TINTED] = {
        Sheet = "gfx/effects/rock_variation_2.png",
        SheetFF = "gfx/effects/rock_variation_2_ff.png",
        PickupVariant = BOULDER.PICKUP_VARIANT_TINTED,
        ProjectileVariant = BOULDER.PROJECTILE_VARIANT_TINTED,
    },
}

-- Prefers the _ff spritesheet for a kind while Fiend Folio is loaded, read at call time since that mod loads after this file
local function kindSheet(kindData)
    if FiendFolio and kindData.SheetFF then return kindData.SheetFF end
    return kindData.Sheet
end

-- All pickup/projectile variants across all 3 kinds, for room-cap counting across the whole set
BOULDER.ALL_PICKUP_VARIANTS = { BOULDER.PICKUP_VARIANT, BOULDER.PICKUP_VARIANT_GOLDEN, BOULDER.PICKUP_VARIANT_TINTED }
BOULDER.ALL_PROJECTILE_VARIANTS = { BOULDER.PROJECTILE_VARIANT, BOULDER.PROJECTILE_VARIANT_GOLDEN, BOULDER.PROJECTILE_VARIANT_TINTED }

local GOLD_DUST_COUNT = 8
local GOLD_COIN_MIN, GOLD_COIN_MAX = 0, 2
local TINTED_PICKUP_MIN, TINTED_PICKUP_MAX = 0, 2
local TINTED_PICKUP_TABLE = {
    { PickupVariant.PICKUP_KEY,   KeySubType.KEY_NORMAL },
    { PickupVariant.PICKUP_BOMB,  BombSubType.BOMB_NORMAL },
    { PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL },
}

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local TAINTED_NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("The Condemned", true)

-- Anyone but Nehemiah gets a weaker boulder: half damage, no fragment burst, and thinner golden and tinted payouts
local OUTSIDER_DAMAGE_MULT = 0.5
local OUTSIDER_GOLD_COIN_MIN, OUTSIDER_GOLD_COIN_MAX = 0, 1
local OUTSIDER_TINTED_CHANCE = 0.15
local OUTSIDER_TINTED_TABLE = {
    { PickupVariant.PICKUP_HEART, HeartSubType.HEART_SOUL },
    { PickupVariant.PICKUP_KEY,   KeySubType.KEY_NORMAL },
}

local DUST_CLOUD_COUNT = 3 -- puffs left behind wherever a boulder breaks

-- True when the thrower is one of the two Nehemiahs, who alone get the full boulder behaviour
local function isNehemiahWielder(player)
    if not player then return false end
    local playerType = player:GetPlayerType()
    return playerType == NEHEMIAH_TYPE or playerType == TAINTED_NEHEMIAH_TYPE
end

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
    BlueWomb = 19, -- the Hush floor
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

-- Returns a stage config id for picking the sprite variant, or nil if unrecognized
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

-- Rolls a boulder kind: 1% tinted, 10% golden, the rest normal -- untainted Nehemiah gets +5% to each
---@param player EntityPlayer?
---@function
function BOULDER:RollKind(player)
    local tintedChance = TINTED_CHANCE
    local goldenChance = GOLDEN_CHANCE
    if player and player:GetPlayerType() == NEHEMIAH_TYPE then
        tintedChance = tintedChance + NEHEMIAH_KIND_BONUS
        goldenChance = goldenChance + NEHEMIAH_KIND_BONUS
    end

    local roll = math.random()
    if roll < tintedChance then
        return BOULDER.KIND_TINTED
    elseif roll < tintedChance + goldenChance then
        return BOULDER.KIND_GOLDEN
    end
    return BOULDER.KIND_NORMAL
end

-- Counts every boulder pickup on the ground, across all 3 kinds
---@function
function BOULDER:CountBoulders()
    local total = 0
    for _, variant in ipairs(BOULDER.ALL_PICKUP_VARIANTS) do
        total = total + Isaac.CountEntities(nil, EntityType.ENTITY_EFFECT, variant)
    end
    return total
end

-- Finds every boulder pickup on the ground, across all 3 kinds, oldest-spawned first
---@function
function BOULDER:FindAllBoulders()
    local all = {}
    for _, variant in ipairs(BOULDER.ALL_PICKUP_VARIANTS) do
        for _, rock in ipairs(Isaac.FindByType(EntityType.ENTITY_EFFECT, variant)) do
            table.insert(all, rock)
        end
    end
    table.sort(all, function(a, b) return a.FrameCount < b.FrameCount end)
    return all
end

-- PickupInit — sets up a freshly spawned ground boulder pickup; kind must match the spawned variant (SpawnBoulder handles this) or falls back to Normal
---@param effect EntityEffect
---@param kind string?
---@function
function BOULDER:PickupInit(effect, kind)
    local data = effect:GetData()
    local sprite = effect:GetSprite()
    local kindData = BOULDER.KIND_DATA[kind] or BOULDER.KIND_DATA[BOULDER.KIND_NORMAL]

    data.POR_BoulderKind = kind or BOULDER.KIND_NORMAL
    data.POR_BoulderSheet = kindSheet(kindData)
    data.POR_SpriteVariant = BOULDER:GetSpriteVariant()

    sprite:ReplaceSpritesheet(0, data.POR_BoulderSheet)
    sprite:LoadGraphics()
    sprite:Play("Appear" .. data.POR_SpriteVariant, true)

end

-- ENTITY_EFFECT is not covered by native room save and restore, so ground boulders track themselves in POR:RoomSave() keyed by ListIndex
local boulderSaveIdCounter = 0

-- RegisterPersistence — records a freshly spawned ground boulder into the save data for the current room
---@param effect EntityEffect
---@function
function BOULDER:RegisterPersistence(effect)
    local data = effect:GetData()
    boulderSaveIdCounter = boulderSaveIdCounter + 1
    local saveId = boulderSaveIdCounter
    data.POR_BoulderSaveId = saveId

    local roomSave = POR:RoomSave()
    if not roomSave then return end

    roomSave.__POR_Boulders = roomSave.__POR_Boulders or {}
    roomSave.__POR_Boulders[saveId] = {
        Kind = data.POR_BoulderKind,
        X = effect.Position.X,
        Y = effect.Position.Y,
    }
end

-- UnregisterPersistence — clears the save record for a boulder; call right before removing/collecting it, or it'll keep reappearing on room re-entry
---@param effect EntityEffect
---@function
function BOULDER:UnregisterPersistence(effect)
    local data = effect:GetData()
    local saveId = data.POR_BoulderSaveId
    if not saveId then return end

    local roomSave = POR:RoomSave()
    if roomSave and roomSave.__POR_Boulders then
        roomSave.__POR_Boulders[saveId] = nil
    end
end

-- Respawns boulders recorded for the current room, reusing the save id on each record so it clears the same slot
---@function
function BOULDER:RestorePersistentBoulders()
    local roomSave = POR:RoomSave()
    local records = roomSave and roomSave.__POR_Boulders
    if not records then return end

    for saveId, record in pairs(records) do
        local kindData = BOULDER.KIND_DATA[record.Kind] or BOULDER.KIND_DATA[BOULDER.KIND_NORMAL]
        local pos = Vector(record.X, record.Y)

        local boulder = Isaac.Spawn(EntityType.ENTITY_EFFECT, kindData.PickupVariant, 0, pos, Vector.Zero, nil):ToEffect()
        if boulder then
            BOULDER:PickupInit(boulder, record.Kind)
            boulder:GetData().POR_BoulderSaveId = saveId
            boulder:GetSprite():Play("Idle" .. boulder:GetData().POR_SpriteVariant, true)
        end
    end
end

-- SpawnBoulderOfKind — spawns a specific boulder kind at a given position, bypassing RollKind; for callers that supply the odds table themselves (e.g. the Soul of Nehemiah rune effect in runes.lua)
---@param position Vector
---@param player EntityPlayer
---@param kind string
---@function
function BOULDER:SpawnBoulderOfKind(position, player, kind)
    local kindData = BOULDER.KIND_DATA[kind] or BOULDER.KIND_DATA[BOULDER.KIND_NORMAL]

    local boulder = Isaac.Spawn(EntityType.ENTITY_EFFECT, kindData.PickupVariant, 0, position, Vector.Zero, player):ToEffect()
    if not boulder then return end

    BOULDER:PickupInit(boulder, kind)
    BOULDER:RegisterPersistence(boulder)
    return boulder
end

-- SpawnBoulder — rolls a kind and spawns the matching boulder pickup effect at a given position
---@param position Vector
---@param player EntityPlayer
---@function
function BOULDER:SpawnBoulder(position, player)
    return BOULDER:SpawnBoulderOfKind(position, player, BOULDER:RollKind(player))
end

-- Runs each frame on ground boulders: fall -> idle -> collect, plus Beast/Crawlspace gravity
---@param effect EntityEffect
---@function
function BOULDER:PickupUpdate(effect)
    local data = effect:GetData()
    local sprite = effect:GetSprite()

    if data.POR_RockFallingBeast then
        effect.Position = effect.Position + Vector(0, BOULDER_FALL_SPEED_BEAST)
        if effect.Position.Y > game:GetRoom():GetBottomRightPos().Y then
            BOULDER:UnregisterPersistence(effect)
            effect:Remove()
        end
        return
    end

    local appearAnim = "Appear" .. data.POR_SpriteVariant
    local idleAnim = "Idle" .. data.POR_SpriteVariant
    if sprite:IsPlaying(appearAnim) then
        if sprite:IsFinished(appearAnim) then
            sprite:Play(idleAnim, true)
        end
        return -- can't be collected while still falling
    end

    for _, ent in ipairs(Isaac.FindInRadius(effect.Position, effect.Size, EntityPartition.PLAYER)) do
        local player = ent:ToPlayer()
        if player
            and player.Variant == 0
            and player:IsExtraAnimationFinished()
            and not player:IsCoopGhost()
            and not player:GetData().POR_HoldingBoulder
        then
            local pData = player:GetData()
            pData.POR_HoldingBoulder = true
            pData.POR_HoldingBoulderSheet = data.POR_BoulderSheet
            pData.POR_HoldingBoulderKind = data.POR_BoulderKind
            pData.POR_HoldingBoulderVariant = data.POR_SpriteVariant -- floor variant rolled on the ground, so the held sprite matches that floor
            player:AnimatePickup(sprite, false, "LiftItem")
            BOULDER:UnregisterPersistence(effect)
            effect:Remove()
            break
        end
    end
end

-- ThrowBoulder — spawns and launches the thrown projectile
---@param player EntityPlayer
---@param direction Vector
---@function
function BOULDER:ThrowBoulder(player, direction)
    direction = direction:Normalized()
    local vel = direction * player.ShotSpeed * 10 * 2.5 -- 10 is the standard tear base speed; 2.5 is boulder-specific weight
    vel = vel + player:GetTearMovementInheritance(vel) * player.ShotSpeed * 1.1

    local spawnPos = player.Position
    if math.abs(direction.X) > math.abs(direction.Y) then
        spawnPos = spawnPos + Vector(0, HORIZONTAL_THROW_HEIGHT_OFFSET) -- raise it off the floor for sideways throws
    end

    local kind = player:GetData().POR_HoldingBoulderKind or BOULDER.KIND_NORMAL
    local kindData = BOULDER.KIND_DATA[kind]

    local boulder = Isaac.Spawn(EntityType.ENTITY_EFFECT, kindData.ProjectileVariant, 0, spawnPos, Vector.Zero, player):ToEffect()
    boulder.Velocity = Vector.Zero -- movement is fully manual, see ProjectileUpdate

    local data = boulder:GetData()
    data.POR_Velocity = vel
    data.POR_BoulderSpawner = EntityRef(player)
    data.POR_SpriteVariant = BOULDER:GetSpriteVariant()
    data.POR_BoulderKind = kind

    local sheet = player:GetData().POR_HoldingBoulderSheet or kindSheet(kindData)
    local sprite = boulder:GetSprite()
    sprite:ReplaceSpritesheet(0, sheet)
    sprite:LoadGraphics()
    sprite:Play("Idle" .. data.POR_SpriteVariant, true)

    SFXManager():Stop(SoundEffect.SOUND_TEARS_FIRE)

    return boulder
end

-- Golden boulder impact: bursts into gold dust, turns the enemy to gold (Midas' Touch flag, also freezes it in place), and drops 0-2 coins
---@param enemy Entity
---@param position Vector
---@param player EntityPlayer?
---@function
local function applyGoldenHitEffect(enemy, position, player)
    for _ = 1, GOLD_DUST_COUNT do
        local velAngle = math.random() * 360
        local vel = Vector.FromAngle(velAngle) * (math.random() * 4 + 2)
        Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.GOLD_PARTICLE, 0, position, vel, player)
    end

    enemy:AddEntityFlags(EntityFlag.FLAG_MIDAS_FREEZE)

    local coinMin, coinMax = GOLD_COIN_MIN, GOLD_COIN_MAX
    if not isNehemiahWielder(player) then
        coinMin, coinMax = OUTSIDER_GOLD_COIN_MIN, OUTSIDER_GOLD_COIN_MAX
    end

    local coinCount = math.random(coinMin, coinMax)
    for _ = 1, coinCount do
        local velAngle = math.random() * 360
        local vel = Vector.FromAngle(velAngle) * (math.random() * 6 + 4)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, PickupVariant.PICKUP_COIN, CoinSubType.COIN_PENNY, position, vel, player)
    end
end

-- Tinted boulder impact: splits into 0-2 pickups, each randomly a key, bomb, or soul heart
---@param position Vector
---@param player EntityPlayer?
---@function
local function applyTintedHitEffect(position, player)
    local pickupCount, pickupTable = math.random(TINTED_PICKUP_MIN, TINTED_PICKUP_MAX), TINTED_PICKUP_TABLE
    if not isNehemiahWielder(player) then
        pickupCount = math.random() < OUTSIDER_TINTED_CHANCE and 1 or 0
        pickupTable = OUTSIDER_TINTED_TABLE
    end

    for _ = 1, pickupCount do
        local choice = pickupTable[math.random(1, #pickupTable)]
        local velAngle = math.random() * 360
        local vel = Vector.FromAngle(velAngle) * (math.random() * 6 + 4)
        Isaac.Spawn(EntityType.ENTITY_PICKUP, choice[1], choice[2], position, vel, player)
    end
end

-- Dispatches the on-hit bonus effect for golden/tinted boulders; no-ops for Normal
---@param kind string
---@param enemy Entity
---@param position Vector
---@param player EntityPlayer?
---@function
function BOULDER:ApplyKindHitEffect(kind, enemy, position, player)
    if kind == BOULDER.KIND_GOLDEN then
        applyGoldenHitEffect(enemy, position, player)
    elseif kind == BOULDER.KIND_TINTED then
        applyTintedHitEffect(position, player)
    end
end

-- Spawns rock fragments (or blue spiders, for Birthright Nehemiah) and removes the boulder
---@param boulder EntityEffect
---@param player EntityPlayer?
---@function
local function burstBoulder(boulder, player)
    SFXManager():Play(SoundEffect.SOUND_HELLBOSS_GROUNDPOUND)

    for _ = 1, DUST_CLOUD_COUNT do
        local vel = Vector.FromAngle(math.random() * 360) * (math.random() * 2)
        local dust = Isaac.Spawn(EntityType.ENTITY_EFFECT, EffectVariant.DUST_CLOUD, 0, boulder.Position, vel, player):ToEffect()
        dust.SpriteScale = Vector(0.5, 0.5)
        dust:SetTimeout(20)
    end

    if player and isNehemiahWielder(player) then
        local spiderCount = 0
        if player:GetPlayerType() == NEHEMIAH_TYPE and player:HasCollectible(CollectibleType.COLLECTIBLE_BIRTHRIGHT) then
            spiderCount = math.random(0, PROJECTILE_FRAGMENTS)
        end
        local rockCount = PROJECTILE_FRAGMENTS - spiderCount

        for _ = 1, spiderCount do
            local velAngle = math.random() * 360
            local vel = Vector.FromAngle(velAngle) * (math.random() * 10 + 6)
            Isaac.Spawn(EntityType.ENTITY_FAMILIAR, FamiliarVariant.BLUE_SPIDER, 0, boulder.Position, vel, player)
        end

        for _ = 1, rockCount do
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

-- ProjectileUpdate — runs every frame on thrown boulders; manual movement and collision
---@param boulder EntityEffect
---@function
function BOULDER:ProjectileUpdate(boulder)
    boulder.Velocity = Vector.Zero -- movement below is fully manual

    local data = boulder:GetData()
    local ref = data.POR_BoulderSpawner
    local player = ref and ref.Entity and ref.Entity:ToPlayer()
    local room = game:GetRoom()
    local vel = data.POR_Velocity or Vector.Zero
    local newPos = boulder.Position + vel

    if room:GetGridCollisionAtPos(newPos) ~= GridCollisionClass.COLLISION_NONE then
        burstBoulder(boulder, player)
        return
    end

    for _, ent in ipairs(Isaac.FindInRadius(newPos, boulder.Size, EntityPartition.ENEMY)) do
        if ent:IsActiveEnemy() and ent:IsVulnerableEnemy() then
            local damage = isNehemiahWielder(player) and PROJECTILE_DAMAGE or PROJECTILE_DAMAGE * OUTSIDER_DAMAGE_MULT
            ent:TakeDamage(damage, 0, EntityRef(player), 0)
            BOULDER:ApplyKindHitEffect(data.POR_BoulderKind, ent, boulder.Position, player)
            burstBoulder(boulder, player)
            return
        end
    end

    boulder.Position = newPos
end

-- BuildHeldSprite — builds the carried-boulder overlay sprite; variant selects Idle1..Idle27 (per-floor look, matching the AppearN crop columns) or nil for the plain "Idle"
---@param sheet string
---@param variant number?
---@return Sprite
---@function
function BOULDER:BuildHeldSprite(sheet, variant)
    local sprite = Sprite()
    sprite:Load("gfx/rock_pickup.anm2", false)
    sprite:ReplaceSpritesheet(0, sheet)
    sprite:LoadGraphics()
    sprite:Play(variant and ("Idle" .. variant) or "Idle", true)
    return sprite
end

-- RestoreHeldBoulderVisual — re-triggers the carry animation on room load (the logical state survives unaided; only the extra-animation overlay needs restarting)
---@param player EntityPlayer
---@function
function BOULDER:RestoreHeldBoulderVisual(player)
    local pData = player:GetData()
    if not pData.POR_HoldingBoulder then return end
    player:AnimatePickup(BOULDER:BuildHeldSprite(pData.POR_HoldingBoulderSheet, pData.POR_HoldingBoulderVariant), false, "LiftItem")
    pData.POR_BoulderFrameCount = 1
end

-- PostPlayerUpdate — handles throw-on-shoot and re-playing the carry animation
---@param player EntityPlayer
---@function
function BOULDER:PostPlayerUpdate(player)
    local pData = player:GetData()
    if not pData.POR_BoulderFrameCount then pData.POR_BoulderFrameCount = 0 end

    if pData.POR_HoldingBoulder then
        local isShooting = player:GetShootingJoystick():Length() > 1e-3

        if isShooting then
            if pData.POR_BoulderFrameCount > 9 then
                BOULDER:ThrowBoulder(player, player:GetShootingJoystick():Normalized())
                player:AnimatePickup(Sprite(), false, "HideItem")
                pData.POR_HoldingBoulder = false
                pData.POR_BoulderFrameCount = 0
            end
        else
            for _, chest in ipairs(Isaac.FindInRadius(player.Position, 10, EntityPartition.PICKUP)) do
                if chest.Variant == PickupVariant.PICKUP_BIGCHEST then
                    pData.POR_HoldingBoulder = false
                end
            end

            if player:IsExtraAnimationFinished() then -- re-play the hold animation each time the previous one ends
                player:AnimatePickup(BOULDER:BuildHeldSprite(pData.POR_HoldingBoulderSheet, pData.POR_HoldingBoulderVariant), false, "LiftItem")
                pData.POR_BoulderFrameCount = 1
            end
        end

        pData.POR_BoulderFrameCount = pData.POR_BoulderFrameCount + 1
    end
end

-- StopHolding — makes the player drop the held boulder
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

-- HideRocksOnTrapdoor — drops all held boulders when any player enters a trapdoor
---@function
function BOULDER:HideRocksOnTrapdoor()
    local enteringTrapdoor = POR:ForEachPlayer(function(player)
        local sprite = player:GetSprite()
        return (sprite:IsPlaying("Trapdoor") or sprite:IsPlaying("LightTravel")) and player.ControlsEnabled == false
    end)

    if enteringTrapdoor then
        POR:ForEachPlayer(function(player) BOULDER:StopHolding(player, true) end)
    end
end

-- BedSleptCheck — reserved for future home-stage sprite reset logic
---@function
function BOULDER:BedSleptCheck(bed, player)
end

return BOULDER