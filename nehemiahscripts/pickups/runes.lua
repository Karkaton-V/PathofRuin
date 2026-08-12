-- Rune effects
local game = POR.game

-- Isaac.GetCardIdByName looks the rune up by pocketitems.xml's hud="SoulOfNehemiah" attribute, not the display name
local SOUL_OF_NEHEMIAH_ID = Isaac.GetCardIdByName("SoulOfNehemiah")

-- HUD icon: explicitly loads a "SoulOfNehemiah" animation into ModdedCardFront, same mechanism as the 22 radiant tarot cards (see radiant_cards.lua's SetCardFront)
local function SetSoulOfNehemiahCardFront()
    if not SOUL_OF_NEHEMIAH_ID or SOUL_OF_NEHEMIAH_ID == 0 then return end
    local cardConfig = Isaac.GetItemConfig():GetCard(SOUL_OF_NEHEMIAH_ID)
    if not cardConfig or not cardConfig.ModdedCardFront then
        Isaac.DebugString(string.format(
            "[POR DEBUG] SetSoulOfNehemiahCardFront: cardConfig=%s ModdedCardFront=%s -- skipped",
            tostring(cardConfig), tostring(cardConfig and cardConfig.ModdedCardFront)))
        return
    end
    cardConfig.ModdedCardFront:Load("gfx/ui_cardfronts.anm2", true)
    cardConfig.ModdedCardFront:Play("SoulOfNehemiah", true)
    Isaac.DebugString("[POR DEBUG] SetSoulOfNehemiahCardFront: applied")
end
SetSoulOfNehemiahCardFront()

-- Debug: dumps what the engine resolved for this card id at mod-load time (log.txt, "[POR DEBUG]")
do
    local cfg = Isaac.GetItemConfig():GetCard(SOUL_OF_NEHEMIAH_ID)
    if cfg then
        Isaac.DebugString(string.format(
            "[POR DEBUG] Soul of Nehemiah card config -- ID=%d HudAnim=%s PickupSubtype=%d IsRune=%s IsCard=%s IsAvailable=%s",
            SOUL_OF_NEHEMIAH_ID, tostring(cfg.HudAnim), cfg.PickupSubtype, tostring(cfg:IsRune()), tostring(cfg:IsCard()), tostring(cfg:IsAvailable())))
    else
        Isaac.DebugString(string.format(
            "[POR DEBUG] Soul of Nehemiah card config -- GetCard(%d) returned NIL", SOUL_OF_NEHEMIAH_ID))
    end
end

local SOUL_MAX_BOULDERS = 3
local SOUL_GOLDEN_CHANCE = 0.75
local SOUL_TINTED_CHANCE = 0.50 -- rolled independently, only checked if the golden roll fails

-- Uses ToRock() to catch all rock subtypes (same check as nehemiahs_hammer.lua's canDestroyGridEntity, kept local here since it's a one-liner)
local function canDestroyGridEntity(gridEntity)
    return gridEntity:ToRock() ~= nil
        and gridEntity.CollisionClass ~= GridCollisionClass.COLLISION_NONE
end

-- Rolls a boulder kind for Soul of Nehemiah's boulders: 75% golden, else 50% tinted, else normal
local function rollSoulKind()
    if math.random() < SOUL_GOLDEN_CHANCE then
        return POR.ROCKTABLE.KIND_GOLDEN
    elseif math.random() < SOUL_TINTED_CHANCE then
        return POR.ROCKTABLE.KIND_TINTED
    end
    return POR.ROCKTABLE.KIND_NORMAL
end

-- Soul of Nehemiah //rune: destroys every rock in the room, then spawns up to 3 boulders (capped by the room limit) at much better odds than a hammer-dropped boulder
function POR:SoulOfNehemiahUse(card, player, useFlags)
    Isaac.DebugString(string.format(
        "[POR DEBUG] SoulOfNehemiahUse fired -- card=%s expected=%s match=%s",
        tostring(card), tostring(SOUL_OF_NEHEMIAH_ID), tostring(card == SOUL_OF_NEHEMIAH_ID)))
    local room = game:GetRoom()

    for i = 0, room:GetGridSize() - 1 do
        local gridEntity = room:GetGridEntity(i)
        if gridEntity and canDestroyGridEntity(gridEntity) then
            gridEntity:Destroy(true)
        end
    end

    local existingBoulders = POR.ROCKTABLE:CountBoulders()
    local roomCap = POR:GetMaxRocksInRoom(player)
    local boulderCount = math.min(SOUL_MAX_BOULDERS, math.max(0, roomCap - existingBoulders))

    for _ = 1, boulderCount do
        local pos = POR:FindFreeRockPosition(POR:GetRandomRoomTile())
        POR.ROCKTABLE:SpawnBoulderOfKind(pos, player, rollSoulKind())
    end
end
