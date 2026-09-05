-- Ties vanilla boss deaths and Boss Rush completion to POR unlocks, persisted for the whole game via Mod:SaveData rather than per run

local game = POR.game
local json = require("json")

-- Boss-kill definitions keyed by unlock name; Variant is optional and omitting it matches any variant of that EntityType
local BOSS_KILLS = {
    Mom           = { Type = EntityType.ENTITY_MOM,         Variant = 0 },
    Isaac         = { Type = EntityType.ENTITY_ISAAC,       Variant = 0 },
    BlueBaby      = { Type = EntityType.ENTITY_ISAAC,       Variant = 1 },
    Satan         = { Type = EntityType.ENTITY_SATAN },
    TheLamb       = { Type = EntityType.ENTITY_THE_LAMB,    Variant = 10 },
    MegaSatan     = { Type = EntityType.ENTITY_MEGA_SATAN_2 },
    Hush          = { Type = EntityType.ENTITY_HUSH },
    Delirium      = { Type = EntityType.ENTITY_DELIRIUM },
    Beast         = { Type = EntityType.ENTITY_BEAST },
    UltraGreed    = { Type = EntityType.ENTITY_ULTRA_GREED, Variant = 0 },
    UltraGreedier = { Type = EntityType.ENTITY_ULTRA_GREED, Variant = 1 },
}

-- Mother needs a LevelStage check alongside the true second phase (Variant 10)
local function isMotherKill(npc)
    if npc.Type ~= EntityType.ENTITY_MOTHER or npc.Variant ~= 10 then return false end
    local stage = game:GetLevel():GetStage()
    return stage == LevelStage.STAGE4_1 or stage == LevelStage.STAGE4_2
end

-- True if the current run is Hard mode or Greed/Greedier mode
local function isHardOrGreedRun()
    return game.Difficulty == Difficulty.DIFFICULTY_HARD or game:IsGreedMode()
end

local UnlockData = {}

-- Loaded once at mod load, since unlocks persist across the whole game
if POR:HasData() then
    local ok, loaded = pcall(json.decode, POR:LoadData())
    if ok and loaded then
        UnlockData = loaded
    end
end
POR.UnlockData = UnlockData

-- Sets <name>_Any (and <name>_Hard, if the current run qualifies) the first time each is earned
local function grantUnlock(name)
    local changed = false
    if not UnlockData[name .. "_Any"] then
        UnlockData[name .. "_Any"] = true
        changed = true
    end
    if isHardOrGreedRun() and not UnlockData[name .. "_Hard"] then
        UnlockData[name .. "_Hard"] = true
        changed = true
    end
    if changed then
        POR:SaveData(json.encode(UnlockData))
        POR.SyncUnlockAchievements()
    end
end

-- AND-checks a list of unlock flag names against UnlockData, used by the item/trinket consumer in this file and by the pool gating in card_pool.lua
function POR:UnlockMet(requiresList)
    for _, flag in ipairs(requiresList) do
        if not UnlockData[flag] then return false end
    end
    return true
end

-- AND-checks the boss flags on a definition and the prerequisite achievement together, since a challenge reward is gated on an achievement no boss kill ever sets
function POR:UnlockDefMet(def)
    if def.Requires and not POR:UnlockMet(def.Requires) then return false end
    if def.RequiresAchievement and not (POR.AchievementUnlocked and POR.AchievementUnlocked(def.RequiresAchievement)) then return false end
    return true
end

function POR.OnNpcDeathGrantBossUnlock(_, npc)
    if isMotherKill(npc) then
        grantUnlock("Mother")
        return
    end

    for name, def in pairs(BOSS_KILLS) do
        if npc.Type == def.Type and (def.Variant == nil or npc.Variant == def.Variant) then
            grantUnlock(name)
        end
    end
end

-- Boss Rush checks whether the room has been cleared instead of number of bosses killed
local bossRushCleared = false
function POR.OnUpdateCheckBossRushClear()
    local room = game:GetRoom()
    if room:GetType() ~= RoomType.ROOM_BOSSRUSH then
        bossRushCleared = false
        return
    end
    if bossRushCleared or not room:IsClear() then return end

    bossRushCleared = true
    grantUnlock("BossRush")
end

--#region Collectible / trinket unlocks; ids are looked up by name so this file has no load order dependency

-- Item -> unlock requirement (AND of flags); locked items are pulled from the pool at the start of every run until every required flag is set
POR.ItemUnlocks = {
    -- Nehemiah Unlocks (Hard mode / Greed / Greedier only)
    [Isaac.GetItemIdByName("Happy Hour")]        = { Requires = { "Isaac_Hard" },      Achievement = "POR_HappyHour" },
    [Isaac.GetItemIdByName("Golden Apple")]      = { Requires = { "Satan_Hard" },      Achievement = "POR_GoldenApple" },
    [Isaac.GetItemIdByName("Holy Smokes!")]      = { Requires = { "BlueBaby_Hard" },   Achievement = "POR_HolySmokes" },
    [Isaac.GetItemIdByName("Woolen Blanket")]    = { Requires = { "TheLamb_Hard" },    Achievement = "POR_WoolenBlanket" },
    [Isaac.GetItemIdByName("Nehemiah's Hammer")] = { Requires = { "MegaSatan_Hard" },  Achievement = "POR_NehemiahsHammer" },
    [Isaac.GetItemIdByName("The Memoir")]        = { Requires = { "Delirium_Hard" },   Achievement = "POR_Memoir" },
    [Isaac.GetItemIdByName("Old Brick")]         = { Requires = { "Beast_Hard" },      Achievement = "POR_OldBrick" },
    [Isaac.GetItemIdByName("Gold Brick")]        = { Requires = { "UltraGreed_Hard" }, Achievement = "POR_GoldBrick" },

    -- Tainted Nehemiah Unlocks (any difficulty)
    [Isaac.GetItemIdByName("Cursed Ring")] = { Requires = { "Isaac_Any", "BlueBaby_Any", "Satan_Any", "TheLamb_Any" }, Achievement = "POR_CursedRing" },
    [Isaac.GetItemIdByName("Book of Ezra")] = { Requires = { "Delirium_Any" }, Achievement = "POR_BookEzra" },
    -- Pool gate only; the guaranteed start of run grant for Tainted Nehemiah bypasses the pool in nehemiah.lua
    [Isaac.GetItemIdByName("Pistanthrophobia")] = { Requires = { "Beast_Any" }, Achievement = "POR_Piss" },

    -- Challenge reward, gated on the achievement the challenge awards rather than on a boss kill, so no Achievement field grants it back
    [Isaac.GetItemIdByName("Spike")] = { RequiresAchievement = "POR_Spike" },
}

POR.TrinketUnlocks = {
    [Isaac.GetTrinketIdByName("Windflower")]      = { Requires = { "BossRush_Hard" }, Achievement = "POR_DumbLuck" },
    [Isaac.GetTrinketIdByName("Oily Branch")]     = { Requires = { "Hush_Hard" },   Achievement = "POR_OilyBranch" },
    [Isaac.GetTrinketIdByName("Butterfly Wings")] = { Requires = { "Mother_Hard" }, Achievement = "POR_ButterflyWings" },
}

-- Grants every achievement whose unlock flags are already set, reading the same tables that gate the pools so the two can never disagree
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

--#region "Complete the Nehemiah track" master reward; Every _Hard flag from the Nehemiah Unlocks list; Mom's Heart is explicitly excluded per spec
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
