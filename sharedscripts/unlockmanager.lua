-- Unlock Manager: ties vanilla boss deaths (and Boss Rush completion) to POR item/trinket/card unlocks, persisted across the whole game via Mod:SaveData/LoadData (not per-run). Each boss-kill flag is tracked as <Name>_Any (any difficulty) and <Name>_Hard (Hard mode or Greed/Greedier); "Nehemiah Unlocks" require _Hard, "Tainted Nehemiah Unlocks" require only _Any, and POR:UnlockMet(requiresList) is the single AND-check every consumer (including card_pool.lua) uses

local game = POR.game
local json = require("json")

-- Boss-kill definitions, keyed by unlock name. Variant is optional -- omit it to match any variant of
-- that EntityType.
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

-- Mother needs a LevelStage check alongside her true second phase (Variant 10)
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
    end
end

-- AND-checks a list of unlock flag names (e.g. {"Isaac_Hard"} or {"Hush_Any", "BossRush_Any"}) against UnlockData
-- Used by this file's own item/trinket consumer and by card_pool.lua's pool-gating.
function POR:UnlockMet(requiresList)
    for _, flag in ipairs(requiresList) do
        if not UnlockData[flag] then return false end
    end
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

--#region Collectible / trinket unlocks
-- Item/trinket ids are looked up directly by name here (not via the other item files' global POR_xxx_ITEM_ID variables) so this file has no dependency on include order in main.lua

-- Item -> unlock requirement (AND of flags); locked items are pulled from the pool at the start of every run until every required flag is set
POR.ItemUnlocks = {
    -- Nehemiah Unlocks (Hard mode / Greed / Greedier only)
    [Isaac.GetItemIdByName("Happy Hour")]        = { Requires = { "Isaac_Hard" } },
    [Isaac.GetItemIdByName("Golden Apple")]      = { Requires = { "Satan_Hard" } },
    [Isaac.GetItemIdByName("Holy Smokes!")]      = { Requires = { "BlueBaby_Hard" } },
    [Isaac.GetItemIdByName("Woolen Blanket")]    = { Requires = { "TheLamb_Hard" } },
    [Isaac.GetItemIdByName("Nehemiah's Hammer")] = { Requires = { "MegaSatan_Hard" } },
    [Isaac.GetItemIdByName("The Memoir")]        = { Requires = { "Delirium_Hard" } },
    [Isaac.GetItemIdByName("Old Brick")]         = { Requires = { "Beast_Hard" } },
    [Isaac.GetItemIdByName("Gold Brick")]        = { Requires = { "UltraGreed_Hard" } },

    -- Tainted Nehemiah Unlocks (any difficulty)
    [Isaac.GetItemIdByName("Cursed Ring")] = { Requires = { "Isaac_Any", "BlueBaby_Any", "Satan_Any", "TheLamb_Any" } },
    [Isaac.GetItemIdByName("Book of Ezra")] = { Requires = { "Delirium_Any" } },
    -- Pool-availability gate only -- Tainted Nehemiah's guaranteed start-of-run grant bypasses the pool directly (nehemiah.lua's TaintedNehemiahInit); this just keeps it out of other draws until the Beast is dead
    [Isaac.GetItemIdByName("Pistanthrophobia")] = { Requires = { "Beast_Any" } },
}

POR.TrinketUnlocks = {
    [Isaac.GetTrinketIdByName("Windflower")]      = { Requires = { "BossRush_Hard" } },
    [Isaac.GetTrinketIdByName("Oily Branch")]     = { Requires = { "Hush_Hard" } },
    [Isaac.GetTrinketIdByName("Butterfly Wings")] = { Requires = { "Mother_Hard" } },
}

-- Removes every still-locked item/trinket from its pools at the start of each run
function POR.OnGameStartedApplyUnlockGates()
    local pool = game:GetItemPool()
    for itemId, def in pairs(POR.ItemUnlocks) do
        if itemId and itemId ~= 0 and not POR:UnlockMet(def.Requires) then
            pool:RemoveCollectible(itemId)
        end
    end
    for trinketId, def in pairs(POR.TrinketUnlocks) do
        if trinketId and trinketId ~= 0 and not POR:UnlockMet(def.Requires) then
            pool:RemoveTrinket(trinketId)
        end
    end
end
--#endregion

--#region "Complete the Nehemiah track" master reward
-- Every _Hard flag from the Nehemiah Unlocks list; Mom's Heart is explicitly excluded per spec
local NEHEMIAH_COMPLETION_FLAGS = {
    "Mom_Hard", "Isaac_Hard", "Satan_Hard", "BlueBaby_Hard", "TheLamb_Hard", "MegaSatan_Hard",
    "BossRush_Hard", "Hush_Hard", "Delirium_Hard", "Mother_Hard", "Beast_Hard",
    "UltraGreed_Hard", "UltraGreedier_Hard",
}

-- True once every Nehemiah-track unlock above has been earned; drives Cement Heart's Soul Heart replacement chance in cement_heart.lua
function POR:IsNehemiahTrackComplete()
    return POR:UnlockMet(NEHEMIAH_COMPLETION_FLAGS)
end
--#endregion

return POR.ItemUnlocks
