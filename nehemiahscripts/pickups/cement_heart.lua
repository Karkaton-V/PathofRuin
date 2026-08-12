-- Cement Heart //pickup: heart armor on your left-most red heart, 2 hits to destroy, insta-broken by explosions; registered as a RED health "kind" via Custom Health API.

local CEMENT_HEART = {}
POR.CementHeart = CEMENT_HEART

CEMENT_HEART.KEY = "CEMENT_HEART"
CEMENT_HEART.SUBTYPE_SINGLE = 100
CEMENT_HEART.SUBTYPE_DOUBLE = 101

--#region Registration

-- cement_heart_ui.anm2 frames already match the API's RED-kind convention (16x16, pivot 8,8).
CEMENT_HEART.MAX_HP = 3

CustomHealthAPI.Library.RegisterRedHealth(CEMENT_HEART.KEY, {
    MaxHP = CEMENT_HEART.MAX_HP,
    AnimationFilenames = {
        EMPTY_HEART = "gfx/cement_heart_ui.anm2",
        BONE_HEART  = "gfx/cement_heart_ui.anm2",
    },
    AnimationNames = {
        -- Indexed by remaining HP: full (3) shows the whole shell, anything below that shows the
        -- cracked frame. The PRE_RENDER_HEART hook below adds transparency on top once damaged.
        EMPTY_HEART = { "CrackingHeartOverlay", "CrackingHeartOverlay", "CementHeartOverlay" }, -- {1, 2, 3=Full}
        BONE_HEART  = { "CrackingHeartOverlay", "CrackingHeartOverlay", "CementHeartOverlay" },
    },
    SortOrder = -10, -- < RED_HEART (0), so Cement Heart's overlay lands on the left-most heart
    AddPriority = 10, -- > RED_HEART (0), < ROTTEN_HEART (100)
    HealFlashRO = 150 / 255,
    HealFlashGO = 150 / 255,
    HealFlashBO = 150 / 255,
    ProtectsDealChance = false,
    PrioritizeHealing = false,
})

-- Explosions ignore Cement Heart's protection entirely; otherwise caps damage at its remaining HP so a breaking hit is fully absorbed, not carried over to real red hearts in the same hit.
-- Registered directly here (not moved to main.lua) since CustomHealthAPI.Library.AddCallback is the vendored CHAPI plugin's own registration system, tightly coupled to the RegisterRedHealth setup above.
function CEMENT_HEART.OnHealthDamaged(_, flags, redKey, redHP, _, _, amountToRemove)
    if redKey ~= CEMENT_HEART.KEY then return end

    if flags & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION then
        return math.max(amountToRemove, redHP)
    end
    return math.min(amountToRemove, redHP)
end
CustomHealthAPI.Library.AddCallback(POR, CustomHealthAPI.Enums.Callbacks.PRE_HEALTH_DAMAGED, CustomHealthAPI.Enums.CallbackPriorities.EARLY, CEMENT_HEART.OnHealthDamaged)

-- Draws a plain full RED_HEART underneath first, since RegisterRedHealth's overlay art replaces rather than layers on the container's art; HP=3 whole+opaque, HP=2 cracked+opaque, HP=1 cracked+transparent.
function CEMENT_HEART.OnRenderHeart(player, healthIndex, health, redHealth, filename, animname, color, extraOffset, playerSlot, renderOffset, numOtherHearts)
    if not redHealth or redHealth.Key ~= CEMENT_HEART.KEY then return end

    local redHeartDef = CustomHealthAPI.PersistentData.HealthDefinitions.RED_HEART
    local baseFilename = redHeartDef.AnimationFilenames[health.Key]
    local baseNames = redHeartDef.AnimationNames[health.Key]

    if not baseFilename or not baseNames then return end

    local baseSprite = CustomHealthAPI.Helper.GetHealthSprite(baseFilename)
    baseSprite:Play(baseNames[#baseNames], true) -- last entry = Full
    baseSprite.Color = Color(1, 1, 1, 1, 0, 0, 0)
    CustomHealthAPI.Helper.RenderHealth(baseSprite, player, playerSlot, healthIndex, renderOffset, numOtherHearts, extraOffset)

    if redHealth.HP < CEMENT_HEART.MAX_HP - 1 then
        return { Color = Color(1, 1, 1, 0.35, 0, 0, 0) }
    end
end
CustomHealthAPI.Library.AddCallback(POR, CustomHealthAPI.Enums.Callbacks.PRE_RENDER_HEART, CustomHealthAPI.Enums.CallbackPriorities.EARLY, CEMENT_HEART.OnRenderHeart)

--#endregion

--#region Sprite and collision setup

-- entities2.xml's registration doesn't reliably apply (other mods share this variant), so sprite/collision are set directly in Lua
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

-- Falls back to initializing here too, in case MC_POST_PICKUP_INIT doesn't have SubType set yet
function CEMENT_HEART.OnPickupUpdate(_, pickup)
    if not CEMENT_HEART_ANM2[pickup.SubType] then return end

    if not pickup:GetData().POR_CementHeartInitialized then
        InitCementHeartPickup(pickup)
        return
    end

    -- Once the spawn-in animation finishes, settle into the idle loop
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

-- Once every Hard-mode/Greed-mode Nehemiah Unlock has been earned, Soul Hearts get a 10% chance to spawn as a Cement Heart instead (see unlockmanager.lua's POR:IsNehemiahTrackComplete)
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
