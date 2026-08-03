-- Cards no longer declare a pocketitems.xml "type", so they're never auto-mixed into vanilla's
-- tarot/reverse-tarot pools. Instead we manually roll a replacement chance whenever the game
-- selects a vanilla Tarot Card (0.5%) or Reverse Tarot Card (10%) to spawn.

local CARD_POOL = {}
POR.CardPool = CARD_POOL

local TAROT_CHANCE         = 0.005 -- 0.5%
local REVERSE_TAROT_CHANCE = 0.10  -- 10%

-- Vanilla CardType ranges (see CardType.NULL's spawn-weight docs)
local TAROT_MIN, TAROT_MAX                 = 1, 22
local REVERSE_TAROT_MIN, REVERSE_TAROT_MAX = 56, 77

-- Every custom card id, pulled from the already-registered Radiant/Other card tables
local ALL_CARD_IDS = {}
for _, id in ipairs({
    POR.RadiantCards.FOOL_ID, POR.RadiantCards.MAGICIAN_ID, POR.RadiantCards.PRIESTESS_ID, POR.RadiantCards.EMPRESS_ID,
    POR.RadiantCards.EMPEROR_ID, POR.RadiantCards.HIEROPHANT_ID, POR.RadiantCards.LOVERS_ID, POR.RadiantCards.CHARIOT_ID,
    POR.RadiantCards.JUSTICE_ID, POR.RadiantCards.HERMIT_ID, POR.RadiantCards.FORTUNE_ID, POR.RadiantCards.STRENGTH_ID,
    POR.RadiantCards.HANGED_ID, POR.RadiantCards.DEATH_ID, POR.RadiantCards.TEMPERANCE_ID, POR.RadiantCards.DEVIL_ID,
    POR.RadiantCards.TOWER_ID, POR.RadiantCards.STAR_ID, POR.RadiantCards.MOON_ID, POR.RadiantCards.SUN_ID,
    POR.RadiantCards.JUDGEMENT_ID, POR.RadiantCards.WORLD_ID,
    POR.OtherCards.MISPRINTED_HIEROPHANT_ID, POR.OtherCards.MISPRINTED_JUSTICE_ID,
    POR.OtherCards.SUICIDE_KING_ID, POR.OtherCards.KING_OF_CLUBS_ID, POR.OtherCards.JACK_OF_DIAMONDS_ID,
    POR.OtherCards.GRACEFUL_CHARITY_ID, POR.OtherCards.DISGRACEFUL_CHARITY_ID,
}) do
    if id and id ~= 0 then
        table.insert(ALL_CARD_IDS, id)
    end
end

-- On a vanilla Tarot/Reverse Tarot selection, rolls a chance to swap in a random custom card instead
function CARD_POOL.OnPickupSelection(_, pickup, variant, subType)
    if variant ~= PickupVariant.PICKUP_TAROTCARD or #ALL_CARD_IDS == 0 then return end

    local isReverseTarot = subType >= REVERSE_TAROT_MIN and subType <= REVERSE_TAROT_MAX
    local isTarot = subType >= TAROT_MIN and subType <= TAROT_MAX
    if not isReverseTarot and not isTarot then return end

    local chance = isReverseTarot and REVERSE_TAROT_CHANCE or TAROT_CHANCE
    if math.random() >= chance then return end

    local replacement = ALL_CARD_IDS[math.random(#ALL_CARD_IDS)]
    return { variant, replacement }
end

POR:AddCallback(ModCallbacks.MC_POST_PICKUP_SELECTION, CARD_POOL.OnPickupSelection)

return CARD_POOL
