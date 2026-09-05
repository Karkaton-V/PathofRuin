-- Cement Heart pickup: armor on the left-most red heart, 2 hits to break, instantly broken by explosions

local CEMENT_HEART = {}
POR.CementHeart = CEMENT_HEART

CEMENT_HEART.KEY = "CEMENT_HEART"
CEMENT_HEART.SUBTYPE_SINGLE = 100
CEMENT_HEART.SUBTYPE_DOUBLE = 101

--#region Registration

-- cement_heart_ui.anm2 frames already match the RED-kind convention in the API (16x16, pivot 8,8).
CEMENT_HEART.MAX_HP = 3

CustomHealthAPI.Library.RegisterRedHealth(CEMENT_HEART.KEY, {
    MaxHP = CEMENT_HEART.MAX_HP,
    AnimationFilenames = {
        EMPTY_HEART = "gfx/cement_heart_ui.anm2",
        BONE_HEART  = "gfx/cement_heart_ui.anm2",
    },
    AnimationNames = {
        -- Indexed by remaining HP; the render hook below adds transparency once damaged
        EMPTY_HEART = { "CrackingHeartOverlay", "CrackingHeartOverlay", "CementHeartOverlay" }, -- {1, 2, 3=Full}
        BONE_HEART  = { "CrackingHeartOverlay", "CrackingHeartOverlay", "CementHeartOverlay" },
    },
    SortOrder = -10, -- < RED_HEART (0), so the Cement Heart overlay lands on the left-most heart
    AddPriority = 10, -- > RED_HEART (0), < ROTTEN_HEART (100)
    HealFlashRO = 150 / 255,
    HealFlashGO = 150 / 255,
    HealFlashBO = 150 / 255,
    ProtectsDealChance = false,
    PrioritizeHealing = false,
})

-- Explosions bypass Cement Heart; other damage is capped at the HP so a breaking hit is absorbed, not carried into real hearts
function CEMENT_HEART.OnHealthDamaged(_, flags, redKey, redHP, _, _, amountToRemove)
    if redKey ~= CEMENT_HEART.KEY then return end

    if flags & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION then
        return math.max(amountToRemove, redHP)
    end
    return math.min(amountToRemove, redHP)
end
CustomHealthAPI.Library.AddCallback(POR, CustomHealthAPI.Enums.Callbacks.PRE_HEALTH_DAMAGED, CustomHealthAPI.Enums.CallbackPriorities.EARLY, CEMENT_HEART.OnHealthDamaged)

-- Draws a full RED_HEART underneath, as the overlay replaces container art; the legacy render id drops args RenderHealth needs
function CEMENT_HEART.OnRenderHeart(player, playerSlot, healthIndex, info)
    local redHealth = info.RedHealth
    if not redHealth or redHealth.Key ~= CEMENT_HEART.KEY then return end

    local health = info.OtherHealth
    if not health then return end

    local redHeartDef = CustomHealthAPI.PersistentData.HealthDefinitions.RED_HEART
    local baseFilename = redHeartDef.AnimationFilenames[health.Key]
    local baseNames = redHeartDef.AnimationNames[health.Key]

    if not baseFilename or not baseNames then return end

    local baseSprite = CustomHealthAPI.Helper.GetHealthSprite(baseFilename)
    baseSprite:Play(baseNames[#baseNames], true) -- last entry = Full
    baseSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
    CustomHealthAPI.Helper.RenderHealth(baseSprite, player, playerSlot, healthIndex, info.RenderOffset, info.TotalHealthRendered, info.ExtraOffset)

    if redHealth.HP < CEMENT_HEART.MAX_HP - 1 then
        return { Color = Color(1, 1, 1, 0.35, 0, 0, 0) }
    end
end
CustomHealthAPI.Library.AddCallback(POR, CustomHealthAPI.Enums.Callbacks.PRE_HEALTH_RENDER, CustomHealthAPI.Enums.CallbackPriorities.EARLY, CEMENT_HEART.OnRenderHeart)

--#endregion

--#region Red heart healing

-- Reports every Cement Heart currently held, paired with the real HP so a caller can restore it
local function collectCementHealth(player)
    local data = CustomHealthAPI.Helper.GetSavedata(player)
    local found = {}

    for _, mask in ipairs(data and data.RedHealthMasks or {}) do
        for _, health in ipairs(mask) do
            if health.Key == CEMENT_HEART.KEY then
                found[#found + 1] = { Health = health, HP = health.HP }
            end
        end
    end

    return found
end

-- Runs a Custom Health API heal with every Cement Heart reported as already full, so the heal passes over them and lands on real containers instead
local function healPastCementHearts(player, heal)
    local masked = collectCementHealth(player)
    for _, entry in ipairs(masked) do
        entry.Health.HP = CustomHealthAPI.Library.GetInfoOfHealth(entry.Health, "MaxHP")
    end

    local result = heal()

    for _, entry in ipairs(masked) do
        entry.Health.HP = entry.HP
    end

    return result
end

-- Wraps the healing in the API rather than editing it, keeping the vendored copy re-syncable; a Cement Heart keyed heal still repairs one
local function hookRedHealing()
    local originalTryHealingRedHP = CustomHealthAPI.Helper.TryHealingRedHP
    local originalHealRedAnywhere = CustomHealthAPI.Helper.HealRedAnywhere

    CustomHealthAPI.Helper.TryHealingRedHP = function(player, key, hpAddedByKey, overflowedHP, ignoreRoomForRedKeys)
        if key == CEMENT_HEART.KEY then
            return originalTryHealingRedHP(player, key, hpAddedByKey, overflowedHP, ignoreRoomForRedKeys)
        end
        return healPastCementHearts(player, function()
            return originalTryHealingRedHP(player, key, hpAddedByKey, overflowedHP, ignoreRoomForRedKeys)
        end)
    end

    CustomHealthAPI.Helper.HealRedAnywhere = function(player, hp)
        return healPastCementHearts(player, function()
            return originalHealRedAnywhere(player, hp)
        end)
    end
end

if type(CustomHealthAPI.Helper.TryHealingRedHP) == "function" and type(CustomHealthAPI.Helper.HealRedAnywhere) == "function" then
    hookRedHealing()
end

--#endregion

--#region Sprite and collision setup

-- the registration in entities2.xml doesn't reliably apply (other mods share this variant), so sprite/collision are set directly in Lua
local CEMENT_HEART_ANM2 = {
    [CEMENT_HEART.SUBTYPE_SINGLE] = "gfx/cement_heart_pickup.anm2",
    [CEMENT_HEART.SUBTYPE_DOUBLE] = "gfx/cement_heart_pickup_double.anm2",
}

local function InitCementHeartPickup(pickup)
    local anm2 = CEMENT_HEART_ANM2[pickup.SubType]
    if not anm2 then return end

    local sprite = pickup:GetSprite()
    sprite:Load(anm2, true)
    sprite:Play("Appear", true)

    pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_ALL
    pickup.GridCollisionClass = EntityGridCollisionClass.GRIDCOLL_GROUND
    pickup:SetSize(12, pickup.SizeMulti, 24)
    pickup.Friction = 1
    pickup.Mass = 3

    pickup:GetData().POR_CementHeartInitialized = true
end

function CEMENT_HEART.FixPickupSprite(_, pickup)
    InitCementHeartPickup(pickup)
end

-- Initializes here too in case SubType was unset at pickup init, then settles into the idle loop
function CEMENT_HEART.OnPickupUpdate(_, pickup)
    if not CEMENT_HEART_ANM2[pickup.SubType] then return end

    if not pickup:GetData().POR_CementHeartInitialized then
        InitCementHeartPickup(pickup)
        return
    end

    local sprite = pickup:GetSprite()
    if sprite:IsPlaying("Appear") and sprite:IsFinished("Appear") then
        sprite:Play("Idle", true)
    end
end

--#endregion

--#region Pickup collection

function CEMENT_HEART.OnPickupCollide(_, pickup, collider, low)
    if pickup.SubType ~= CEMENT_HEART.SUBTYPE_SINGLE and pickup.SubType ~= CEMENT_HEART.SUBTYPE_DOUBLE then
        return
    end

    local player = collider:ToPlayer()
    if not player then return end
    if pickup:GetData().POR_CementHeartCollected then return end
    if not pickup:GetSprite():IsPlaying("Idle") then return end -- only react on a fresh touch

    pickup:GetData().POR_CementHeartCollected = true
    pickup.EntityCollisionClass = EntityCollisionClass.ENTCOLL_NONE
    pickup:GetSprite():Play("Collect", true)
    SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 0.8, 0, false, 1.4) -- placeholder pickup sound

    local hp = (pickup.SubType == CEMENT_HEART.SUBTYPE_DOUBLE) and (CEMENT_HEART.MAX_HP * 2) or CEMENT_HEART.MAX_HP
    CustomHealthAPI.Library.AddHealth(player, CEMENT_HEART.KEY, hp)

    POR.scrum_master_schedule.Schedule(20, function()
        if pickup and pickup:Exists() then
            pickup:Remove()
        end
    end)

    return true -- block the vanilla heart-pickup effect; 100/101 aren't real HeartSubTypes
end

--#endregion

--#region Nehemiah-track completion reward

-- Once the Nehemiah track is complete, Soul Hearts have a 10% chance to spawn as a Cement Heart
local SOUL_HEART_REPLACE_CHANCE = 0.10

function CEMENT_HEART.OnHeartSelection(_, pickup, variant, subType)
    if variant ~= PickupVariant.PICKUP_HEART then return end
    if subType ~= HeartSubType.HEART_SOUL and subType ~= HeartSubType.HEART_HALF_SOUL then return end
    if not POR:IsNehemiahTrackComplete() then return end
    if math.random() >= SOUL_HEART_REPLACE_CHANCE then return end

    return { variant, CEMENT_HEART.SUBTYPE_SINGLE }
end

--#endregion

return CEMENT_HEART
