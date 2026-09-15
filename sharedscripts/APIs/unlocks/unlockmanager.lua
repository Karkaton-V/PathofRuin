-- Reads POR unlocks off the completion marks the two Nehemiahs hold, so the game's own save tracks them rather than a parallel boss-kill log

local game = POR.game

local NEHEMIAH_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", false)
local CONDEMNED_TYPE = Isaac.GetPlayerTypeByName("Nehemiah", true)

-- Mark field each flag base reads; the two Greed bases carry their own Value because Greed mode has no hard variant, so the single Greed mark encodes Greed and Greedier instead of difficulty
local FLAG_MARKS = {
    Mom           = { Field = "MomsHeart" },
    Isaac         = { Field = "Isaac" },
    BlueBaby      = { Field = "BlueBaby" },
    Satan         = { Field = "Satan" },
    TheLamb       = { Field = "Lamb" },
    MegaSatan     = { Field = "MegaSatan" },
    BossRush      = { Field = "BossRush" },
    Hush          = { Field = "Hush" },
    Delirium      = { Field = "Delirium" },
    Mother        = { Field = "Mother" },
    Beast         = { Field = "Beast" },
    UltraGreed    = { Field = "UltraGreed", Value = 1 },
    UltraGreedier = { Field = "UltraGreed", Value = 2 },
}

local HARD_MARK = 2 -- the value a completion mark only reaches on hard, which every unlock outside Greed mode requires

-- Character each suffix reads; both demand the hard value, so the suffix picks the track rather than the difficulty despite the _Any name
local FLAG_SUFFIXES = {
    Hard = { PlayerType = NEHEMIAH_TYPE,  Value = HARD_MARK },
    Any  = { PlayerType = CONDEMNED_TYPE, Value = HARD_MARK },
}

-- Completion marks for one character, memoised per lookup pass so a multi flag requirement costs one read per character
local function markSet(cache, playerType)
    if cache[playerType] == nil then
        local ok, marks = pcall(Isaac.GetCompletionMarks, playerType)
        cache[playerType] = (ok and type(marks) == "table") and marks or false
    end
    return cache[playerType] or nil
end

local MOM_HARD_FLAG = "MomHard" -- Mom herself, who has no completion mark of her own, so this one flag is tracked rather than read

-- True once Mom has been beaten on hard, taken from the persistent save because the mark set jumps straight from nothing to Mom's Heart
local function momHardMet()
    local save = POR:GameSave()
    return save ~= nil and save.POR_MomHard == true
end

-- Records a hard mode Mom kill, the one unlock in this mod that no completion mark can supply
function POR.OnMomDeathRecordHardKill(_, npc)
    if npc.Variant ~= 0 then return end
    if game.Difficulty ~= Difficulty.DIFFICULTY_HARD then return end

    local save = POR:GameSave()
    if not save or save.POR_MomHard then return end

    save.POR_MomHard = true
    POR.SyncUnlockAchievements()
end

-- True once one flag's mark has reached the value it needs on the character its suffix names; an unrecognised flag fails closed
local function flagMet(flag, cache)
    if flag == MOM_HARD_FLAG then return momHardMet() end

    local base, suffix = tostring(flag):match("^(.+)_(%a+)$")
    local mark = base and FLAG_MARKS[base]
    local rule = suffix and FLAG_SUFFIXES[suffix]
    if not mark or not rule or not rule.PlayerType or rule.PlayerType <= 0 then return false end

    local marks = markSet(cache, rule.PlayerType)
    if not marks then return false end

    return (marks[mark.Field] or 0) >= (mark.Value or rule.Value)
end

-- AND-checks a list of unlock flag names against the marks, used by the item/trinket consumer in this file and by the pool gating in card_pool.lua
function POR:UnlockMet(requiresList)
    if type(Isaac.GetCompletionMarks) ~= "function" then return false end

    local cache = {}
    for _, flag in ipairs(requiresList) do
        if not flagMet(flag, cache) then return false end
    end
    return true
end

-- AND-checks the mark flags on a definition and the prerequisite achievement together, since a challenge reward is gated on an achievement no mark ever sets
function POR:UnlockDefMet(def)
    if def.Requires and not POR:UnlockMet(def.Requires) then return false end
    if def.RequiresAchievement and not (POR.AchievementUnlocked and POR.AchievementUnlocked(def.RequiresAchievement)) then return false end
    return true
end

--#region Collectible / trinket unlocks; ids are looked up by name so this file has no load order dependency

-- Item -> unlock requirement (AND of flags); locked items are pulled from the pool at the start of every run until every requirement is met
POR.ItemUnlocks = {
    -- Nehemiah Unlocks; the _Hard suffix reads Nehemiah's own marks, earned on hard
    [Isaac.GetItemIdByName("Happy Hour")]        = { Requires = { "Isaac_Hard" },      Achievement = "POR_HappyHour" },
    [Isaac.GetItemIdByName("Golden Apple")]      = { Requires = { "Satan_Hard" },      Achievement = "POR_GoldenApple" },
    [Isaac.GetItemIdByName("Holy Smokes!")]      = { Requires = { "BlueBaby_Hard" },   Achievement = "POR_HolySmokes" },
    [Isaac.GetItemIdByName("Woolen Blanket")]    = { Requires = { "TheLamb_Hard" },    Achievement = "POR_WoolenBlanket" },
    [Isaac.GetItemIdByName("Nehemiah's Hammer")] = { Requires = { "MegaSatan_Hard" },  Achievement = "POR_NehemiahsHammer" },
    [Isaac.GetItemIdByName("The Memoir")]        = { Requires = { "Delirium_Hard" },   Achievement = "POR_Memoir" },
    [Isaac.GetItemIdByName("Old Brick")]         = { Requires = { "Beast_Hard" },      Achievement = "POR_OldBrick" },
    [Isaac.GetItemIdByName("Gold Brick")]        = { Requires = { "UltraGreed_Hard" }, Achievement = "POR_GoldBrick" },
    [Isaac.GetItemIdByName("The Masons")]        = { Requires = { "Mom_Hard" },        Achievement = "POR_Masons" },

    -- Tainted Nehemiah Unlocks; the _Any suffix reads The Condemned's marks, also earned on hard
    [Isaac.GetItemIdByName("Cursed Ring")] = { Requires = { "Isaac_Any", "BlueBaby_Any", "Satan_Any", "TheLamb_Any" }, Achievement = "POR_CursedRing" },
    [Isaac.GetItemIdByName("Book of Ezra")] = { Requires = { "Delirium_Any" }, Achievement = "POR_BookEzra" },
    -- Pool gate only; the guaranteed start of run grant for Tainted Nehemiah bypasses the pool in nehemiah.lua
    [Isaac.GetItemIdByName("Pistanthrophobia")] = { Requires = { "Beast_Any" }, Achievement = "POR_Piss" },

    -- Challenge reward, gated on the achievement the challenge awards rather than on a mark, so no Achievement field grants it back
    [Isaac.GetItemIdByName("Spike")] = { RequiresAchievement = "POR_Spike" },
}

POR.TrinketUnlocks = {
    [Isaac.GetTrinketIdByName("Windflower")]      = { Requires = { "BossRush_Hard" }, Achievement = "POR_DumbLuck" },
    [Isaac.GetTrinketIdByName("Oily Branch")]     = { Requires = { "Hush_Hard" },   Achievement = "POR_OilyBranch" },
    [Isaac.GetTrinketIdByName("Butterfly Wings")] = { Requires = { "Mother_Hard" }, Achievement = "POR_ButterflyWings" },
}

-- Grants every achievement whose requirement is already met, reading the same tables that gate the pools so the two can never disagree
function POR.SyncUnlockAchievements()
    if not POR.UnlockAchievement then return end

    for _, def in pairs(POR.ItemUnlocks) do
        if def.Achievement and POR:UnlockDefMet(def) then POR.UnlockAchievement(def.Achievement) end
    end
    for _, def in pairs(POR.TrinketUnlocks) do
        if def.Achievement and POR:UnlockDefMet(def) then POR.UnlockAchievement(def.Achievement) end
    end
    for _, def in pairs(POR.CardUnlockAchievements or {}) do
        if def.Achievement and def.Requires and POR:UnlockMet(def.Requires) then POR.UnlockAchievement(def.Achievement) end
    end

    if POR:IsNehemiahTrackComplete() then POR.UnlockAchievement("POR_Cement") end
end

-- Removes every still-locked item/trinket from the pools at the start of each run
function POR.OnGameStartedApplyUnlockGates()
    local pool = game:GetItemPool()
    for itemId, def in pairs(POR.ItemUnlocks) do
        if itemId and itemId ~= 0 and not POR:UnlockDefMet(def) then
            pool:RemoveCollectible(itemId)
        end
    end
    for trinketId, def in pairs(POR.TrinketUnlocks) do
        if trinketId and trinketId ~= 0 and not POR:UnlockDefMet(def) then
            pool:RemoveTrinket(trinketId)
        end
    end
end
--#endregion

--#region "Complete the Nehemiah track" master reward; every _Hard flag from the Nehemiah Unlocks list; Mom's Heart is explicitly excluded per spec
local NEHEMIAH_COMPLETION_FLAGS = {
    "Mom_Hard", "Isaac_Hard", "Satan_Hard", "BlueBaby_Hard", "TheLamb_Hard", "MegaSatan_Hard",
    "BossRush_Hard", "Hush_Hard", "Delirium_Hard", "Mother_Hard", "Beast_Hard",
    "UltraGreed_Hard", "UltraGreedier_Hard",
}

-- True once every Nehemiah-track unlock above has been earned; drives the Cement Heart Soul Heart replacement chance in cement_heart.lua
function POR:IsNehemiahTrackComplete()
    return POR:UnlockMet(NEHEMIAH_COMPLETION_FLAGS)
end
--#endregion

return POR.ItemUnlocks
