-- Per challenge setup the XML cannot express, keyed by challenge name so a shifting id never points the effects at the wrong run

local game = POR.game

local CHALLENGES = {}
POR.Challenges = CHALLENGES

local ABYSS_NAME = "[POR] Revenge of the Abyss"
local ABYSS_CEMENT_HEARTS = 3
local NO_HAMMER_NAME = "[POR] Who Needs Hammers?"

-- Resolves a challenge name to the id, returning nil when the lookup is unavailable or the name is unknown
local function challengeId(name)
    if type(Isaac.GetChallengeIdByName) ~= "function" then return nil end

    local ok, id = pcall(Isaac.GetChallengeIdByName, name)
    if not ok or not id or id <= Challenge.CHALLENGE_NULL then return nil end
    return id
end

-- True when the run currently in progress is the named challenge
local function inChallenge(name)
    local id = challengeId(name)
    return id ~= nil and Isaac.GetChallenge() == id
end

-- Hands every player the starting Cement Hearts for the challenge, granted as one call each the way the double pickup stacks them
local function grantCementHearts(count)
    if not POR.CementHeart or not CustomHealthAPI then return end

    POR:ForEachPlayer(function(player)
        CustomHealthAPI.Library.AddHealth(player, POR.CementHeart.KEY, POR.CementHeart.MAX_HP * count)
    end)
end

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local CONDEMNED_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)
local HARD_MODE_MARK = 2 -- the value a completion mark holds once earned on hard, where 1 is the normal mode version of the same mark

-- Lowest completion mark a character holds, so full marks on hard reads as 2 and any gap drops it lower; mirrors the Fiend Folio sweep, including the skip of the two unused ids
local function easiestCompletedMark(playerType)
    local lowest = 3
    for mark = CompletionType.MOMS_HEART, CompletionType.BEAST do
        if mark ~= 8 and mark ~= 10 then
            local value = Isaac.GetCompletionMark(playerType, mark)
            if value < lowest then lowest = value end
        end
    end
    return lowest
end

-- True once a character carries every completion mark on hard, since a mark reads 2 only when it was earned there and the weakest one decides
local function hasFullMarks(playerType)
    if type(Isaac.GetCompletionMark) ~= "function" or type(CompletionType) ~= "table" then return false end
    return easiestCompletedMark(playerType) >= HARD_MODE_MARK
end

-- True when a vanilla achievement has been earned, used to read the base game unlocks the challenges depend on
local function vanillaUnlocked(achievement)
    return achievement ~= nil and Isaac.GetPersistentGameData():Unlocked(achievement)
end

-- What the achievement for each challenge waits on, checked together so a condition met out of order still lands
local CHALLENGE_UNLOCKS = {
    { Achievement = "POR_BetaTest",  Met = function() return hasFullMarks(CONDEMNED_TYPE) end },
    { Achievement = "POR_MaskCurse", Met = function() return vanillaUnlocked(Achievement.TAINTED_SAMSON) and vanillaUnlocked(Achievement.PLANETARIUMS) end },
    { Achievement = "POR_SecretEar", Met = function() return POR.AchievementUnlocked("POR_Condemned") end },
    { Achievement = "POR_Injustice", Met = function() return vanillaUnlocked(Achievement.TAINTED_ISAAC) end },
    { Achievement = "POR_Revenge",   Met = function() return vanillaUnlocked(Achievement.TAINTED_APOLLYON) and POR.AchievementUnlocked("POR_Cement") end },
    { Achievement = "POR_WhoHammer", Met = function() return hasFullMarks(NEHEMIAH_TYPE) end },
}

-- Grants every challenge achievement whose condition is already satisfied, run on both a completion mark and a fresh game so nothing waits on a relaunch
function CHALLENGES.SyncChallengeUnlocks()
    if not POR.UnlockAchievement or not POR.AchievementUnlocked then return end

    for _, entry in ipairs(CHALLENGE_UNLOCKS) do
        local ok, met = pcall(entry.Met)
        if ok and met then POR.UnlockAchievement(entry.Achievement) end
    end
end

-- Takes back the pocket active Nehemiah is built around, applied on continues too since nehemiah.lua re-grants it on every player init
local function removeNehemiahsHammer()
    local hammer = Isaac.GetItemIdByName("Nehemiah's Hammer")
    if not hammer or hammer <= 0 then return end

    POR:ForEachPlayer(function(player)
        if player:GetActiveItem(ActiveSlot.SLOT_POCKET) == hammer then
            player:SetPocketActiveItem(CollectibleType.COLLECTIBLE_NULL, ActiveSlot.SLOT_POCKET, false)
        end
        if player:HasCollectible(hammer) then
            player:RemoveCollectible(hammer)
        end
    end)
end

-- Applies the extra setup for each challenge on a fresh run, skipping continues so nothing is handed out twice
function CHALLENGES.OnGameStarted(_, isContinued)
    CHALLENGES.SyncChallengeUnlocks()

    if inChallenge(NO_HAMMER_NAME) then
        removeNehemiahsHammer()
    end

    if isContinued then return end

    if inChallenge(ABYSS_NAME) then
        grantCementHearts(ABYSS_CEMENT_HEARTS)
    end
end

return CHALLENGES
