local game = Game()

AMMONIAC_ITEM_ID = Isaac.GetItemIdByName("Ammoniac") -- item id of Ammoniac

PLASMA_TYPE = EntityType.ENTITY_EFFECT
PLASMA_VARIANT = Isaac.GetEntityVariantByName("Plasma Projectile") -- custom entity (entities2.xml), art at resources/gfx/plasma.anm2

-- Amnestone art per costume folder; one half leaves the other on the Brimstone sheet, no entry falls back to shared
local AMNESTONE_SHEETS = {
    [""] = {
        head = "gfx/characters/costumes/costume_amnestoneH.png",
        body = "gfx/characters/costumes/costume_amnestoneB.png",
    },
    ["_apollyon"]  = { head = "gfx/characters/costumes_apollyon/costume_amnestoneH.png" },
    ["_forgotten"] = { head = "gfx/characters/costumes_forgotten/costume_amnestoneH.png" },
    ["_keeper"]    = { head = "gfx/characters/costumes_keeper/costume_amnestoneH.png" },
    ["_shadow"]    = { head = "gfx/characters/costumes_shadow/costume_amnestoneH.png" },
}

local function amnestoneSheetFor(layerName, suffix)
    local sheets = AMNESTONE_SHEETS[suffix] or AMNESTONE_SHEETS[""]

    layerName = layerName:lower()
    if layerName:sub(1, 4) == "body" then return sheets.body end
    if layerName:sub(1, 4) == "head" then return sheets.head end
    return nil
end

-- Finds the active Brimstone costume sprite on the player, if it currently has one.
local function brimstoneCostumeSprite(player)
    for _, desc in ipairs(player:GetCostumeSpriteDescs()) do
        local config = desc:GetItemConfig()
        if config and config.ID == CollectibleType.COLLECTIBLE_BRIMSTONE then
            return desc:GetSprite()
        end
    end
    return nil
end

-- Repaints the Brimstone costume sheet by sheet, as the ReplaceCostumeSprite SpriteId param is broken; unchanged layers are skipped
local function setAmnestoneSkin(player, restore)
    local sprite = brimstoneCostumeSprite(player)
    if not sprite then return end

    local suffix = POR.CostumeFolderSuffix(player:GetPlayerType())
    local changed = false
    for _, layer in ipairs(sprite:GetAllLayers()) do
        local sheet = restore and layer:GetDefaultSpritesheetPath() or amnestoneSheetFor(layer:GetName(), suffix)
        if sheet and layer:GetSpritesheetPath() ~= sheet then
            sprite:ReplaceSpritesheet(layer:GetLayerID(), sheet)
            changed = true
        end
    end

    if changed then
        sprite:LoadGraphics()
    end
end

-- Hides the Ammoniac costume, since the engine re-adds passive costumes after TryRemoveCollectibleCostume
local function hideAmmoniacCostume(player)
    for _, desc in ipairs(player:GetCostumeSpriteDescs()) do
        local config = desc:GetItemConfig()
        if config and config.ID == AMMONIAC_ITEM_ID then
            for _, layer in ipairs(desc:GetSprite():GetAllLayers()) do
                if layer.SetVisible then layer:SetVisible(false) end
            end
        end
    end
end

-- Holds the synergy look each frame and restores the Brimstone art once the pairing breaks
function POR.AmmoniacBrimstoneCostume(_, player)
    local hasSynergy = player:HasCollectible(AMMONIAC_ITEM_ID) and player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE)
    local pData = player:GetData()

    if hasSynergy then
        setAmnestoneSkin(player, false)
        player:TryRemoveCollectibleCostume(AMMONIAC_ITEM_ID, false)
        hideAmmoniacCostume(player)
    elseif pData.POR_AmnestoneCostumeActive then
        setAmnestoneSkin(player, true)
    end

    pData.POR_AmnestoneCostumeActive = hasSynergy
    POR.SetOrangeSkin(player, hasSynergy) -- drives the shared flag in orange_skin.lua, redirecting other item costumes to the "_orange" recolor
end

-- The engine rebuilds costumes on room transitions, which would otherwise revert the swap mid-run.
function POR.AmmoniacBrimstoneCostumeNewRoom()
    POR:ForEachPlayer(function(player)
        if player:GetData().POR_AmnestoneCostumeActive then
            setAmnestoneSkin(player, false)
        end
    end)
end

local FRAMES_PER_SECOND = 30

-- Custom chargebar as in spike.lua; charges while shooting and fires the instant it fills
local CHARGEBAR_ANM2 = "gfx/ui/ui_plasmachargebar.anm2"
local CHARGEBAR_ANIM_FRAMES = 100 -- "Charging" has 101 frames (0-100); scrubbed manually by charge progress
local CHARGEBAR_OFFSET = Vector(18, -54) -- scaled by player.SpriteScale at render time, matching spike.lua
local MAX_CHARGE_FRAMES = 300 -- 10s at 30fps
local SHOOT_DIR_THRESHOLD = 0.1

-- Registered after Spike (main.lua loads spike.lua first), so this bar is the one that offsets upward when both are held (chargebar_stacking.lua)
POR.RegisterChargeBarItem(AMMONIAC_ITEM_ID)
local CHARGEBAR_STACK_SPACING = 24 -- vertical gap between stacked bars, pre-SpriteScale, matches spike.lua

-- Brimstone disables the chargebar and volley and slows fire rate by 1/3; the beam is reskinned by ReplaceSpritesheet, as a full anm2 Load() crashes it
local BRIMSTONE_FIRE_DELAY_MULT = 1.5
local BRIMSTONE_LASER_SPRITESHEET = "gfx/effects/plasma_laser2.png"

-- Tints the beam each frame, oscillating green by sine between deep orange and bright yellow
local BRIMSTONE_TINT_DESATURATION = 0.2
local BRIMSTONE_RED_OFFSET = 0.18
local BRIMSTONE_MIN_GREEN_OFFSET = 0.06 -- deep orange end of the shift
local BRIMSTONE_MAX_GREEN_OFFSET = 0.32 -- bright yellow end of the shift
local BRIMSTONE_SHIFT_PERIOD_FRAMES = 60 -- one full orange->yellow->orange cycle every ~2s at 30fps

-- Builds the tint color for this frame, sliding the green offset back and forth between the two endpoints above.
local function brimstoneShiftColor()
    local t = (math.sin(Isaac.GetFrameCount() / BRIMSTONE_SHIFT_PERIOD_FRAMES * (2 * math.pi)) + 1) / 2 -- smooth 0..1..0
    local greenOffset = BRIMSTONE_MIN_GREEN_OFFSET + (BRIMSTONE_MAX_GREEN_OFFSET - BRIMSTONE_MIN_GREEN_OFFSET) * t

    local color = Color(1, 1, 1, 1, 0, 0, 0)
    color:SetColorize(1, 1, 1, BRIMSTONE_TINT_DESATURATION)
    color:SetOffset(BRIMSTONE_RED_OFFSET, greenOffset, 0)
    return color
end

function POR.AmmoniacBrimstoneFireDelay(_, player, cacheFlag)
    if not player:HasCollectible(AMMONIAC_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end
    player.MaxFireDelay = player.MaxFireDelay * BRIMSTONE_FIRE_DELAY_MULT
end

function POR.AmmoniacBrimstoneSkin(_, laser)
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(AMMONIAC_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end

    local data = laser:GetData()
    if not data.POR_PlasmaLaserSkinned then
        data.POR_PlasmaLaserSkinned = true
        local sprite = laser:GetSprite()
        sprite:ReplaceSpritesheet(0, BRIMSTONE_LASER_SPRITESHEET)
        sprite:LoadGraphics()
    end

    laser:SetColor(brimstoneShiftColor(), 1, 1, false, false)
end

-- 3 bolts fired in a narrow fan for width without a wide spread; each bolt pierces every enemy it passes through, affecting each one only once
local PROJECTILE_COUNT = 3
local PROJECTILE_SPREAD_DEGREES = 15 -- fan is -15/0/+15 degrees off the facing direction
local SHOT_SPEED_BASE = 10 -- matches the standard tear base-speed convention used elsewhere (spike.lua, nehemiahs_boulder.lua)
local BASE_LIFETIME_SECONDS = 1.5
local HORIZONTAL_SPAWN_HEIGHT_OFFSET = -10 -- matches the horizontal-shot spawn convention in spike.lua and nehemiahs_boulder.lua

-- Bolts deal no contact damage; each pierced enemy rolls one of three statuses instead, with Burn at 0 damage-per-tick so it stays a pure status
local STATUS_DURATION_SECONDS = 2
local STATUS_DURATION_FRAMES = STATUS_DURATION_SECONDS * FRAMES_PER_SECOND

-- A destroyed bolt leaves a Movable Fireplace (33.10.0), flagged friendly and left to fend for itself
AMMONIAC_FIRE_TYPE = EntityType.ENTITY_FIREPLACE
AMMONIAC_FIRE_VARIANT = 10 -- Movable Fireplace variant; no FireplaceVariant enum exists in the API

-- Spawns a friendly Movable Fireplace at the given position, owned by the given player.
local function igniteFirePatch(pos, player)
    local fire = Isaac.Spawn(AMMONIAC_FIRE_TYPE, AMMONIAC_FIRE_VARIANT, 0, pos, Vector.Zero, player):ToNPC()
    if not fire then return end

    fire:AddEntityFlags(EntityFlag.FLAG_FRIENDLY)
end

-- Applies one of Burn / Confusion / Freeze at equal odds; freeze needs AddIce, as AddFreeze only stuns
local function applyRandomStatus(enemy, player)
    local roll = math.random(1, 3)
    local source = EntityRef(player)

    if roll == 1 then
        enemy:AddBurn(source, STATUS_DURATION_FRAMES, 0)
    elseif roll == 2 then
        enemy:AddConfusion(source, STATUS_DURATION_FRAMES, false)
    else
        enemy:AddIce(source, STATUS_DURATION_FRAMES)
    end
end

-- The beam rolls the same statuses but skips enemies already carrying one, throttling it to once per duration
function POR.AmmoniacBrimstoneStatus(_, laser, collider)
    local player = laser.SpawnerEntity and laser.SpawnerEntity:ToPlayer()
    if not player or not player:HasCollectible(AMMONIAC_ITEM_ID) or not player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end

    local enemy = collider:ToNPC()
    if not enemy or not enemy:IsActiveEnemy() or not enemy:IsVulnerableEnemy() then return end

    if enemy:HasEntityFlags(EntityFlag.FLAG_BURN) or enemy:HasEntityFlags(EntityFlag.FLAG_CONFUSION) or enemy:HasEntityFlags(EntityFlag.FLAG_ICE_FROZEN) then
        return
    end

    applyRandomStatus(enemy, player)
end

-- Spawns and launches one Plasma Projectile, mirroring fireSpike in spike.lua
local function firePlasmaBolt(player, direction)
    direction = direction:Normalized()
    local vel = direction * player.ShotSpeed * SHOT_SPEED_BASE

    local spawnPos = player.Position
    if math.abs(direction.X) > math.abs(direction.Y) then
        spawnPos = spawnPos + Vector(0, HORIZONTAL_SPAWN_HEIGHT_OFFSET)
    end

    local bolt = Isaac.Spawn(PLASMA_TYPE, PLASMA_VARIANT, 0, spawnPos, Vector.Zero, player):ToEffect()
    if not bolt then return end

    local lifetimeFrames = BASE_LIFETIME_SECONDS * FRAMES_PER_SECOND + math.floor(player.TearRange / 10)

    local data = bolt:GetData()
    data.POR_PlasmaOwner = player
    data.POR_PlasmaVelocity = vel
    data.POR_PlasmaExpireFrame = Isaac.GetFrameCount() + lifetimeFrames
    data.POR_PlasmaHit = {} -- InitSeeds of enemies already affected by this bolt, so pierced enemies are only hit once

    bolt:GetSprite():Play("Idle", true)
end

-- Fires the full 3-bolt volley in a narrow fan centered on the given direction.
local function firePlasmaVolley(player, direction)
    local half = math.floor(PROJECTILE_COUNT / 2)
    for i = 1, PROJECTILE_COUNT do
        local offset = (i - 1 - half) * PROJECTILE_SPREAD_DEGREES
        firePlasmaBolt(player, direction:Rotated(offset))
    end
end

-- Charge builds while a shoot direction is held, then fires and resets to 0 the instant it fills rather than waiting for release
function POR.AmmoniacPlayerUpdate(_, player)
    if not player:HasCollectible(AMMONIAC_ITEM_ID) then return end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end -- see the Brimstone fire-rate caveat above

    local pData = player:GetData()
    local dir = player:GetShootingJoystick()

    if dir:Length() > SHOOT_DIR_THRESHOLD then
        pData.POR_PlasmaLastDir = dir
        local charge = pData.POR_PlasmaCharge or 0
        charge = charge + 1
        if charge >= MAX_CHARGE_FRAMES then
            firePlasmaVolley(player, pData.POR_PlasmaLastDir)
            charge = 0
        end
        pData.POR_PlasmaCharge = charge
    else
        pData.POR_PlasmaCharge = 0
    end
end

-- Renders the chargebar above the head of one player, following the same state flow as renderSpikeBar in spike.lua but never holding at full charge
local function renderAmmoniacBar(player)
    if not player:HasCollectible(AMMONIAC_ITEM_ID) or not Options.ChargeBars then return end
    if player:HasCollectible(CollectibleType.COLLECTIBLE_BRIMSTONE) then return end -- see the Brimstone fire-rate caveat above

    local pData = player:GetData()
    if not pData.POR_PlasmaBar then
        local sprite = Sprite()
        sprite:Load(CHARGEBAR_ANM2, true)
        pData.POR_PlasmaBar = sprite
    end
    local bar = pData.POR_PlasmaBar

    if Isaac.GetFrameCount() % 2 == 0 then
        bar:Update()
    end

    local charge = pData.POR_PlasmaCharge or 0
    local holding = player:GetShootingJoystick():Length() > SHOOT_DIR_THRESHOLD

    if holding then
        bar:Play("Charging")
        bar:SetFrame(math.floor(charge * CHARGEBAR_ANIM_FRAMES / MAX_CHARGE_FRAMES))
    else
        if not bar:IsPlaying("Disappear") and (bar:IsPlaying("Charging") or bar:IsPlaying("Charged") or bar:IsPlaying("StartCharged")) then
            bar:Play("Disappear")
        end
    end

    local room = game:GetRoom()
    if room:HasWater() and room:GetRenderMode() == RenderMode.RENDER_WATER_REFLECT then return end

    local stackIndex = POR.ChargeBarStackIndex(player, AMMONIAC_ITEM_ID)
    local offsetY = CHARGEBAR_OFFSET.Y - stackIndex * CHARGEBAR_STACK_SPACING
    local offset = Vector(CHARGEBAR_OFFSET.X * player.SpriteScale.X, offsetY * player.SpriteScale.Y)
    bar:Render(Isaac.WorldToScreen(player.Position + offset))
end

function POR.AmmoniacBarRender()
    POR:ForEachPlayer(renderAmmoniacBar)
end

-- Moves each Plasma Projectile, expiring on schedule or wall contact and rolling one status per enemy hit
function POR.AmmoniacEffectUpdate(_, effect)
    local data = effect:GetData()
    if not data.POR_PlasmaOwner then return end

    if Isaac.GetFrameCount() >= data.POR_PlasmaExpireFrame then
        igniteFirePatch(effect.Position, data.POR_PlasmaOwner)
        effect:Remove()
        return
    end

    local vel = data.POR_PlasmaVelocity
    local pos = effect.Position
    local room = game:GetRoom()

    for _, ent in ipairs(Isaac.FindInRadius(pos + vel, effect.Size, EntityPartition.ENEMY)) do
        local enemy = ent:ToNPC()
        if enemy and enemy:IsActiveEnemy() and enemy:IsVulnerableEnemy() and not data.POR_PlasmaHit[enemy.InitSeed] then
            data.POR_PlasmaHit[enemy.InitSeed] = true
            applyRandomStatus(enemy, data.POR_PlasmaOwner)
        end
    end

    if room:GetGridCollisionAtPos(pos + vel) ~= GridCollisionClass.COLLISION_NONE then
        igniteFirePatch(pos, data.POR_PlasmaOwner)
        effect:Remove()
        return
    end

    effect.Position = pos + vel
end

