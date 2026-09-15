-- Handles unlocking playable characters, which the game gates on the achievement each one names in players.xml

local game = POR.game

local UNLOCKS = {}
POR.CharacterUnlocks = UNLOCKS

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local CONDEMNED_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)
local NEHEMIAH_ACHIEVEMENT = "POR_Nehemiah"
local CONDEMNED_ACHIEVEMENT = "POR_Condemned"

local HOME_CLOSET_GRID_INDEX = 94 -- the bedroom closet in Home, the room vanilla hands the tainted characters over in
local GREAT_GIDEON_TYPE = 907 -- no EntityType constant is exposed for that entity, the id comes from the StageAPI boss table

-- Returns an achievement id only when the name resolves to a modded entry, since GetAchievementIdByName hands back a vanilla id for anything unknown
local function achievementId(name)
    local id = Isaac.GetAchievementIdByName(name)
    if not id or id <= Achievement.DEAD_GOD then return nil end
    return id
end

-- False on runs the game refuses to award achievements for, such as seeded ones, which is the same gate Fiend Folio puts in front of the unlocks
local function canUnlock()
    return not game:AchievementUnlocksDisallowed()
end

-- Unlocks an achievement by name, ignoring one that failed to resolve; TryUnlock leaves an already earned achievement alone, so repeat wins cost nothing
local function unlockAchievement(name)
    if not canUnlock() then return end

    local id = achievementId(name)
    if id then
        Isaac.GetPersistentGameData():TryUnlock(id)
    end
end

-- True once the named achievement has been earned, false when it is locked or the name does not resolve
local function achievementUnlocked(name)
    local id = achievementId(name)
    return id ~= nil and Isaac.GetPersistentGameData():Unlocked(id)
end

POR.UnlockAchievement = unlockAchievement -- shared so challenge scripts award through the same disallowed-run gate
POR.AchievementUnlocked = achievementUnlocked -- shared so challenge scripts can read an unlock as a prerequisite

-- True while The Condemned is still locked, which is the only time the closet should be offered
local function condemnedLocked()
    local id = achievementId(CONDEMNED_ACHIEVEMENT)
    if not id then return false end
    return not Isaac.GetPersistentGameData():Unlocked(id)
end

-- Hands Nehemiah over when Great Gideon dies, which only happens once the last wave has been cleared
function UNLOCKS.OnGideonDeath(_, npc)
    if npc.Variant ~= 0 then return end
    unlockAchievement(NEHEMIAH_ACHIEVEMENT)
end

-- Puts the closet in front of Nehemiah in the Home bedroom, clearing the shopkeeper and pickups in the room first so nothing sits on top of it
function UNLOCKS.OnNewRoom()
    if Isaac.GetPlayer():GetPlayerType() ~= NEHEMIAH_TYPE then return end
    if game:GetLevel():GetStage() ~= LevelStage.STAGE8 then return end
    if game:GetLevel():GetCurrentRoomDesc().SafeGridIndex ~= HOME_CLOSET_GRID_INDEX then return end
    if not canUnlock() or not condemnedLocked() then return end

    for _, shopkeeper in ipairs(Isaac.FindByType(EntityType.ENTITY_SHOPKEEPER)) do
        shopkeeper:Remove()
    end
    for _, pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
        pickup:Remove()
    end

    if #Isaac.FindByType(EntityType.ENTITY_SLOT, SlotVariant.HOME_CLOSET_PLAYER) == 0 then
        Isaac.Spawn(EntityType.ENTITY_SLOT, SlotVariant.HOME_CLOSET_PLAYER, 0, game:GetRoom():GetCenterPos(), Vector.Zero, nil)
    end
end

-- Dresses the closet in the skin for The Condemned so the silhouette inside matches that character rather than the default
function UNLOCKS.OnSlotInit(_, slot)
    if Isaac.GetPlayer():GetPlayerType() ~= NEHEMIAH_TYPE or not condemnedLocked() then return end

    local config = EntityConfig and EntityConfig.GetPlayer and EntityConfig.GetPlayer(CONDEMNED_TYPE)
    local skin = config and config.GetSkinPath and config:GetSkinPath()
    if not skin then return end

    slot:GetSprite():ReplaceSpritesheet(0, skin, true)
end

-- Hands The Condemned over once the closet finishes opening, which is the same cue vanilla and Fiend Folio unlock on
function UNLOCKS.OnSlotUpdate(_, slot)
    if not slot:GetSprite():IsFinished("PayPrize") then return end
    unlockAchievement(CONDEMNED_ACHIEVEMENT)
end

return UNLOCKS
