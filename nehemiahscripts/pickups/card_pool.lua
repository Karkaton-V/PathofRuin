-- Manually swaps in unlocked custom cards on vanilla Tarot/Reverse Tarot/Suit/Special/Rune rolls, since custom cards no longer declare a pocketitems.xml "type".

local CARD_POOL = {}
POR.CardPool = CARD_POOL

local TAROT_CHANCE         = 0.005 -- 0.5%
local REVERSE_TAROT_CHANCE = 0.10  -- 10%
local SUIT_CHANCE          = 0.05  -- 5%
local SPECIAL_CHANCE       = 0.05  -- 5%
local RUNE_CHANCE          = 0.05  -- 5%

-- Vanilla Card id ranges (see the Card enum)
local TAROT_MIN, TAROT_MAX                 = 1, 22   -- CARD_FOOL .. CARD_WORLD
local SUIT_MIN, SUIT_MAX                   = 23, 31  -- CARD_CLUBS_2 .. CARD_JOKER
local RUNE_MIN, RUNE_MAX                   = 32, 41  -- RUNE_HAGALAZ .. RUNE_BLACK
local SPECIAL_MIN, SPECIAL_MAX             = 42, 54  -- CARD_CHAOS .. CARD_ERA_WALK
local REVERSE_TAROT_MIN, REVERSE_TAROT_MAX = 56, 77  -- CARD_REVERSE_FOOL .. CARD_REVERSE_WORLD

-- Looked up directly (not via the local in runes.lua) so this file has no load-order dependency on it
local SOUL_OF_NEHEMIAH_ID = Isaac.GetCardIdByName("SoulOfNehemiah")

-- Custom cards eligible for the Tarot/Reverse Tarot swap (King of Clubs and Disgraceful Charity are excluded -- they use the dedicated pools below)
local ALL_CARD_IDS = {}
for _, id in ipairs({
    POR.RadiantCards.FOOL_ID, POR.RadiantCards.MAGICIAN_ID, POR.RadiantCards.PRIESTESS_ID, POR.RadiantCards.EMPRESS_ID,
    POR.RadiantCards.EMPEROR_ID, POR.RadiantCards.HIEROPHANT_ID, POR.RadiantCards.LOVERS_ID, POR.RadiantCards.CHARIOT_ID,
    POR.RadiantCards.JUSTICE_ID, POR.RadiantCards.HERMIT_ID, POR.RadiantCards.FORTUNE_ID, POR.RadiantCards.STRENGTH_ID,
    POR.RadiantCards.HANGED_ID, POR.RadiantCards.DEATH_ID, POR.RadiantCards.TEMPERANCE_ID, POR.RadiantCards.DEVIL_ID,
    POR.RadiantCards.TOWER_ID, POR.RadiantCards.STAR_ID, POR.RadiantCards.MOON_ID, POR.RadiantCards.SUN_ID,
    POR.RadiantCards.JUDGEMENT_ID, POR.RadiantCards.WORLD_ID,
    POR.OtherCards.MISPRINTED_HIEROPHANT_ID, POR.OtherCards.MISPRINTED_JUSTICE_ID,
    POR.OtherCards.SUICIDE_KING_ID, POR.OtherCards.JACK_OF_DIAMONDS_ID, POR.OtherCards.GRACEFUL_CHARITY_ID,
}) do
    if id and id ~= 0 then
        table.insert(ALL_CARD_IDS, id)
    end
end

-- Dedicated candidate pools for the Suit/Special/Rune ranges, which nothing previously hooked
local SUIT_CARD_IDS, SPECIAL_CARD_IDS, RUNE_CARD_IDS = {}, {}, {}
if POR.OtherCards.KING_OF_CLUBS_ID and POR.OtherCards.KING_OF_CLUBS_ID ~= 0 then
    table.insert(SUIT_CARD_IDS, POR.OtherCards.KING_OF_CLUBS_ID)
end
if POR.OtherCards.DISGRACEFUL_CHARITY_ID and POR.OtherCards.DISGRACEFUL_CHARITY_ID ~= 0 then
    table.insert(SPECIAL_CARD_IDS, POR.OtherCards.DISGRACEFUL_CHARITY_ID)
end
if SOUL_OF_NEHEMIAH_ID and SOUL_OF_NEHEMIAH_ID ~= 0 then
    table.insert(RUNE_CARD_IDS, SOUL_OF_NEHEMIAH_ID)
end

-- Unlock requirements for individually-gated cards; anything not listed here is always available
local CARD_REQUIRES = {
    [POR.RadiantCards.MAGICIAN_ID]          = { "Mother_Any" },
    [POR.OtherCards.GRACEFUL_CHARITY_ID]    = { "UltraGreedier_Hard" },
    [POR.OtherCards.KING_OF_CLUBS_ID]       = { "MegaSatan_Any" },
    [POR.OtherCards.DISGRACEFUL_CHARITY_ID] = { "UltraGreedier_Any" },
    [SOUL_OF_NEHEMIAH_ID]                   = { "Hush_Any", "BossRush_Any" },
}
-- Every Radiant Card without a gate of its own falls back to the bulk Mom-lock; the Magician, Chariot and Hermit each carry their own instead
local RADIANT_BULK_REQUIRES = { "MomHard" }

-- Achievement each card unlock awards, published so unlockmanager.lua can grant them from the same flags gating the pool
POR.CardUnlockAchievements = {
    [POR.RadiantCards.MAGICIAN_ID]          = { Requires = CARD_REQUIRES[POR.RadiantCards.MAGICIAN_ID],          Achievement = "POR_Magician" },
    [POR.OtherCards.GRACEFUL_CHARITY_ID]    = { Requires = CARD_REQUIRES[POR.OtherCards.GRACEFUL_CHARITY_ID],    Achievement = "POR_Graceful" },
    [POR.OtherCards.KING_OF_CLUBS_ID]       = { Requires = CARD_REQUIRES[POR.OtherCards.KING_OF_CLUBS_ID],       Achievement = "POR_KClubs" },
    [POR.OtherCards.DISGRACEFUL_CHARITY_ID] = { Requires = CARD_REQUIRES[POR.OtherCards.DISGRACEFUL_CHARITY_ID], Achievement = "POR_Disgraceful" },
    [SOUL_OF_NEHEMIAH_ID]                   = { Requires = CARD_REQUIRES[SOUL_OF_NEHEMIAH_ID],                   Achievement = "POR_SoulNehemiah" },
    RadiantBulk                             = { Requires = RADIANT_BULK_REQUIRES,                                Achievement = "POR_RCards" },
}
for _, id in ipairs({
    POR.RadiantCards.FOOL_ID, POR.RadiantCards.PRIESTESS_ID, POR.RadiantCards.EMPRESS_ID,
    POR.RadiantCards.EMPEROR_ID, POR.RadiantCards.HIEROPHANT_ID, POR.RadiantCards.LOVERS_ID,
    POR.RadiantCards.JUSTICE_ID, POR.RadiantCards.FORTUNE_ID, POR.RadiantCards.STRENGTH_ID,
    POR.RadiantCards.HANGED_ID, POR.RadiantCards.DEATH_ID, POR.RadiantCards.TEMPERANCE_ID, POR.RadiantCards.DEVIL_ID,
    POR.RadiantCards.TOWER_ID, POR.RadiantCards.STAR_ID, POR.RadiantCards.MOON_ID, POR.RadiantCards.SUN_ID,
    POR.RadiantCards.JUDGEMENT_ID, POR.RadiantCards.WORLD_ID,
}) do
    if id and id ~= 0 then
        CARD_REQUIRES[id] = RADIANT_BULK_REQUIRES
    end
end

-- Cards a challenge reward gates, keyed to the achievement that challenge awards since no boss kill flag ever covers them
local CARD_ACHIEVEMENT_REQUIRES = {
    [POR.RadiantCards.CHARIOT_ID]             = "POR_Chariot",
    [POR.RadiantCards.HERMIT_ID]              = "POR_Hermit",
    [POR.OtherCards.MISPRINTED_JUSTICE_ID]    = "POR_MJustice",
    [POR.OtherCards.MISPRINTED_HIEROPHANT_ID] = "POR_MHierophant",
}

-- True if `id` clears both gates: every required flag set, and the prerequisite achievement earned where it names one
local function isCardUnlocked(id)
    local achievement = CARD_ACHIEVEMENT_REQUIRES[id]
    if achievement and not (POR.AchievementUnlocked and POR.AchievementUnlocked(achievement)) then return false end

    local requires = CARD_REQUIRES[id]
    return not requires or POR:UnlockMet(requires)
end

-- Picks a random currently-unlocked candidate from `candidates`, or nil if every candidate is locked
local function pickUnlockedCandidate(candidates)
    local pool = {}
    for _, id in ipairs(candidates) do
        if isCardUnlocked(id) then
            table.insert(pool, id)
        end
    end
    if #pool == 0 then return nil end
    return pool[math.random(#pool)]
end

-- Rolls a chance to swap in a random unlocked custom card matching the category of the vanilla pickup
function CARD_POOL.OnPickupSelection(_, pickup, variant, subType)
    if variant ~= PickupVariant.PICKUP_TAROTCARD then return end

    local chance, candidates
    if subType >= TAROT_MIN and subType <= TAROT_MAX then
        chance, candidates = TAROT_CHANCE, ALL_CARD_IDS
    elseif subType >= REVERSE_TAROT_MIN and subType <= REVERSE_TAROT_MAX then
        chance, candidates = REVERSE_TAROT_CHANCE, ALL_CARD_IDS
    elseif subType >= SUIT_MIN and subType <= SUIT_MAX then
        chance, candidates = SUIT_CHANCE, SUIT_CARD_IDS
    elseif subType >= SPECIAL_MIN and subType <= SPECIAL_MAX then
        chance, candidates = SPECIAL_CHANCE, SPECIAL_CARD_IDS
    elseif subType >= RUNE_MIN and subType <= RUNE_MAX then
        chance, candidates = RUNE_CHANCE, RUNE_CARD_IDS
    else
        return
    end

    if #candidates == 0 or math.random() >= chance then return end

    local replacement = pickUnlockedCandidate(candidates)
    if not replacement then return end

    return { variant, replacement }
end

return CARD_POOL
