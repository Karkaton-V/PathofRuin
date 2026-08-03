-- Cement Heart //pickup: heart armor on your left-most red heart, 2 hits to destroy, insta-broken by explosions.
-- entities2.xml subtype 530 = single charge, 531 = double. Registered as a RED health "kind" via Custom Health API.

local CEMENT_HEART = {}
POR.CementHeart = CEMENT_HEART

CEMENT_HEART.KEY = "CEMENT_HEART"
CEMENT_HEART.SUBTYPE_SINGLE = 530
CEMENT_HEART.SUBTYPE_DOUBLE = 531

--#region Registration

-- cement_heart_ui.anm2 frames already match the API's RED-kind convention (16x16, pivot 8,8).
CustomHealthAPI.Library.RegisterRedHealth(CEMENT_HEART.KEY, {
    MaxHP = 2,
    AnimationFilenames = {
        EMPTY_HEART = "gfx/cement_heart_ui.anm2",
        BONE_HEART  = "gfx/cement_heart_ui.anm2",
    },
    AnimationNames = {
        EMPTY_HEART = { "CrackingHeartOverlay", "CementHeartOverlay" }, -- {Half, Full}
        BONE_HEART  = { "CrackingHeartOverlay", "CementHeartOverlay" },
    },
    SortOrder = 10,
    AddPriority = 10, -- > RED_HEART (0), < ROTTEN_HEART (100)
    HealFlashRO = 150 / 255,
    HealFlashGO = 150 / 255,
    HealFlashBO = 150 / 255,
    ProtectsDealChance = false,
    PrioritizeHealing = false,
})

-- Explosions ignore Cement Heart's protection entirely -- whatever HP is left breaks in one hit.
CustomHealthAPI.Library.AddCallback(POR, CustomHealthAPI.Enums.Callbacks.PRE_HEALTH_DAMAGED, CustomHealthAPI.Enums.CallbackPriorities.EARLY,
    function(_, flags, redKey, redHP, _, _, amountToRemove)
        if redKey == CEMENT_HEART.KEY and (flags & DamageFlag.DAMAGE_EXPLOSION == DamageFlag.DAMAGE_EXPLOSION) then
            return math.max(amountToRemove, redHP)
        end
    end)

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
    -- Placeholder pickup sound (rock-crumble fits "cement" and is already used elsewhere in this mod).
    SFXManager():Play(SoundEffect.SOUND_ROCK_CRUMBLE, 0.8, 0, false, 1.4)

    local hp = (pickup.SubType == CEMENT_HEART.SUBTYPE_DOUBLE) and 4 or 2
    CustomHealthAPI.Library.AddHealth(player, CEMENT_HEART.KEY, hp)

    POR.scrum_master_schedule.Schedule(20, function()
        if pickup and pickup:Exists() then
            pickup:Remove()
        end
    end)

    return true -- block the vanilla heart-pickup effect; 30/31 aren't real HeartSubTypes
end

POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, CEMENT_HEART.OnPickupCollide, PickupVariant.PICKUP_HEART)

--#endregion

return CEMENT_HEART
