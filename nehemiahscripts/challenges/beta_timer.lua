-- Draws a 30 minute countdown across the top of the screen during the beta test challenge, stepping aside when Enhanced Boss Bars claims the same edge

local game = POR.game

local TIMER = {}
POR.BetaTimer = TIMER

local CHALLENGE_NAME = "[POR] BET4 T3ST"
local FRAMES_PER_SECOND = 30
local START_SECONDS = 5 * 60
local FLOOR_BONUS_SECONDS = 90 -- earned on arriving at each new floor after the first
local FINAL_FLOOR = 6 -- the endstage the challenge declares, so the run can never bank more than the opening five minutes plus five bonuses
local MAX_SECONDS = START_SECONDS + FLOOR_BONUS_SECONDS * (FINAL_FLOOR - 1)

local CREAK_SOUND = Isaac.GetSoundIdByName("CreakyWall")
local CREAK_MIN_GAP = 20 * FRAMES_PER_SECOND
local CREAK_MAX_GAP = 35 * FRAMES_PER_SECOND
local CREAK_MIN_VOLUME = 0.35
local CREAK_MAX_VOLUME = 0.70

local COLLAPSE_SOUND = Isaac.GetSoundIdByName("CollapsingBasement")
local COLLAPSE_FIRST_FRAME = 5 * 60 * FRAMES_PER_SECOND
local COLLAPSE_GAP = 90 * FRAMES_PER_SECOND
local COLLAPSE_MIN_VOLUME = 0.45
local COLLAPSE_MAX_VOLUME = 0.80
local COLLAPSE_VOLUME_STEP = 0.07 -- reaches the ceiling on the fifth collapse, so the run audibly worsens without topping out immediately

local BASE_ANM2 = "gfx/ui/timer/timer_base.anm2"
local OVERLAY_ANM2 = "gfx/ui/timer/timer_overlay.anm2"
local ICON_ANM2 = "gfx/ui/timer/timer_icon.anm2"
local FONT_PATH = "font/pftempestasevencondensed.fnt"

local BACKGROUND_ANIM = "bg100" -- the full width bar; 50/25/12 are the narrower crops Enhanced Boss Bars uses when several bosses share a row
local FILL_ANIM = "charge100"
local OVERLAY_ANIM = "overlay100"
local ICON_ANIM = "idle"

local BAR_WIDTH = 160 -- the crop width layer 0 of bg100 declares
local BAR_PIVOT_X = 20 -- that layer pivots this far into the crop, so the render point sits right of the visible left edge
local TOP_ANCHOR_Y = 22 -- sits the bar over the vanilla Time readout; the HUD renders at a quarter of the window size, so one unit here is four screen pixels
local BOTTOM_ANCHOR_Y = 18 -- measured up from the bottom edge when a boss bar pushes the timer down there
local HUD_OFFSET_STEP = 12 -- matches the per notch shift Enhanced Boss Bars applies for the HUD offset option

local ICON_OFFSET = Vector(6, 17) -- the icon is a 64x64 crop pivoted at its centre, so this is measured from the bar's render origin to the middle of the rock
local TEXT_OFFSET_Y = -8 -- DrawString measures from the top of the line, so this lifts the numbers to sit centred inside the bar
local TEXT_COLOR = KColor(1, 1, 1, 1, 0, 0, 0)

local sprites = nil
local font = nil

-- The challenge id for the beta test, resolved by name so a shifting id never points the timer at the wrong run
local function challengeId()
    if type(Isaac.GetChallengeIdByName) ~= "function" then return nil end

    local ok, id = pcall(Isaac.GetChallengeIdByName, CHALLENGE_NAME)
    if not ok or not id or id <= Challenge.CHALLENGE_NULL then return nil end
    return id
end

-- True only while the beta test challenge is the run in progress, since the timer belongs to that challenge alone
local function inBetaTest()
    local id = challengeId()
    return id ~= nil and Isaac.GetChallenge() == id
end

-- Builds the sprites and font once and reuses them, as a render callback must not load files every frame
local function getSprites()
    if sprites then return sprites end

    local background, fill, overlay, icon = Sprite(), Sprite(), Sprite(), Sprite()
    background:Load(BASE_ANM2, true)
    fill:Load(BASE_ANM2, true)
    overlay:Load(OVERLAY_ANM2, true)
    icon:Load(ICON_ANM2, true)

    background:SetFrame(BACKGROUND_ANIM, 0)
    fill:SetFrame(FILL_ANIM, 0)
    overlay:SetFrame(OVERLAY_ANIM, 0)
    icon:SetFrame(ICON_ANIM, 0)

    font = Font()
    font:Load(FONT_PATH)

    sprites = { Background = background, Fill = fill, Overlay = overlay, Icon = icon }
    return sprites
end

-- Countdown state in the run save, so the time already earned survives a continue
local function progress()
    local run = POR:RunSave()
    if not run then return nil end

    run.POR_BetaTimer = run.POR_BetaTimer or { Budget = START_SECONDS }
    return run.POR_BetaTimer
end

-- Total seconds the countdown has been granted so far, falling back to the opening five minutes when the run save is unavailable
local function budgetFrames()
    local state = progress()
    return ((state and state.Budget) or START_SECONDS) * FRAMES_PER_SECOND
end

-- Frames left on the countdown, floored at zero so an overrun parks the bar empty rather than running negative
local function remainingFrames()
    return math.max(0, budgetFrames() - (game.TimeCounter or 0))
end

-- Books the next creak a random gap ahead, so the wall never settles into a rhythm the player can tune out
local function scheduleCreak(state, now)
    state.NextCreak = now + math.random(CREAK_MIN_GAP, CREAK_MAX_GAP)
end

-- Creaks the wall on its own irregular schedule at a randomised volume, kept quiet enough to sit under the room audio
local function updateCreak(state, now, sfx)
    if CREAK_SOUND == nil or CREAK_SOUND < 0 then return end

    if state.NextCreak == nil then
        scheduleCreak(state, now)
        return
    end
    if now < state.NextCreak then return end

    sfx:Play(CREAK_SOUND, CREAK_MIN_VOLUME + math.random() * (CREAK_MAX_VOLUME - CREAK_MIN_VOLUME), 0, false, 1)
    scheduleCreak(state, now)
end

-- Drops the basement from five minutes in and every ninety seconds after, each one louder than the last until it reaches the ceiling
local function updateCollapse(state, now, sfx)
    if COLLAPSE_SOUND == nil or COLLAPSE_SOUND < 0 then return end

    local due = state.NextCollapse or COLLAPSE_FIRST_FRAME
    if now < due then return end

    local volume = math.min(COLLAPSE_MAX_VOLUME, state.CollapseVolume or COLLAPSE_MIN_VOLUME)
    sfx:Play(COLLAPSE_SOUND, volume, 0, false, 1)

    state.CollapseVolume = math.min(COLLAPSE_MAX_VOLUME, volume + COLLAPSE_VOLUME_STEP)
    state.NextCollapse = due + COLLAPSE_GAP
end

-- Runs both ambience tracks off the same clock the countdown uses, so they pause with the game rather than with real time
function TIMER.OnUpdate()
    if not inBetaTest() then return end

    local state = progress()
    if not state then return end

    local now = game.TimeCounter or 0
    local sfx = SFXManager()

    updateCreak(state, now, sfx)
    updateCollapse(state, now, sfx)
end

-- Pays the floor bonus once per new floor, keyed on the stage last recorded so a continue reloading the same floor cannot claim it twice
function TIMER.OnNewLevel()
    if not inBetaTest() then return end

    local state = progress()
    if not state then return end

    local stage = game:GetLevel():GetAbsoluteStage()
    if state.LastStage == nil then
        state.LastStage = stage
        return
    end
    if state.LastStage == stage then return end

    state.LastStage = stage
    state.Budget = state.Budget + FLOOR_BONUS_SECONDS
end

-- The remaining time as MM:SS, rounded up so the display only reaches zero when the countdown truly has
local function remainingText()
    local seconds = math.ceil(remainingFrames() / FRAMES_PER_SECOND)
    return string.format("%02d:%02d", math.floor(seconds / 60), seconds % 60)
end

-- True while Enhanced Boss Bars is drawing at least one bar, read from the table that mod keeps its live bosses in
local function bossBarActive()
    return HPBars ~= nil and type(HPBars.currentBosses) == "table" and next(HPBars.currentBosses) ~= nil
end

-- The screen edge Enhanced Boss Bars is configured to use, nil for the Left and Right layouts that never share a band with the timer
local function bossBarBand()
    if HPBars == nil or type(HPBars.Config) ~= "table" then return nil end

    local position = HPBars.Config.Position
    if position == "Top" or position == "Bottom" then return position end
    return nil
end

-- The bar's left edge, centred horizontally and sitting at the top unless a live boss bar already occupies that band
local function barLeftEdge()
    local offset = HUD_OFFSET_STEP * (Options.HUDOffset or 0)
    local x = Isaac.GetScreenWidth() / 2 - BAR_WIDTH / 2

    if bossBarActive() and bossBarBand() == "Top" then
        return Vector(x, Isaac.GetScreenHeight() - BOTTOM_ANCHOR_Y - offset)
    end
    return Vector(x, TOP_ANCHOR_Y + offset)
end

-- Draws the countdown, clamping the fill in from the right the way Enhanced Boss Bars reveals a boss health bar
function TIMER.OnRender()
    if not inBetaTest() then return end

    local hud = game:GetHUD()
    if hud and hud.IsVisible and not hud:IsVisible() then return end

    local set = getSprites()
    local left = barLeftEdge()
    local origin = left + Vector(BAR_PIVOT_X, 0)
    local filled = math.max(0, math.min(1, remainingFrames() / (MAX_SECONDS * FRAMES_PER_SECOND)))
    local hidden = BAR_WIDTH * (1 - filled)

    set.Background:Render(origin, Vector.Zero, Vector.Zero)
    set.Fill:Render(origin, Vector.Zero, Vector(hidden, 0))
    set.Overlay:Render(origin, Vector.Zero, Vector.Zero)
    set.Icon:Render(origin + ICON_OFFSET, Vector.Zero, Vector.Zero)

    if font then
        font:DrawString(remainingText(), left.X, left.Y + TEXT_OFFSET_Y, TEXT_COLOR, BAR_WIDTH, true)
    end
end

return TIMER
