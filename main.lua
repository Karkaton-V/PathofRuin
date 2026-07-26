---- Path of Ruin ---
-- By Team Ruin

-- Setup
if not REPENTOGON then
    error("This Mod Requires REPENTAGON!!")
end
POR = RegisterMod("Path of Ruin", 1)
POR.game = Game()

-- Includes
-- -- Base Case
-- -- -- Helpers
-- NOTE: custom_save_compiler must be first; it sets POR.SaveCompiler as a side effect
POR_CustomSaveCompiler = include("nehemiahscripts.custom_save_compiler")
POR.SaveCallbacks      = POR.SaveCompiler.SaveCallbacks
POR_CustomSaveCreator  = include("nehemiahscripts.custom_save_creator")
POR_ScrumMaster        = include("nehemiahscripts.custom_scrum_master_schedule")
POR_Incrementor        = include("nehemiahscripts.custom_incrementor")

-- -- Nehemiah
-- -- -- Characters
-- NOTE: nehemiah.lua must load before all other scripts; it sets NEHEMIAH_TYPE, TAINTED_NEHEMIAH_TYPE, NEHEMIAHSHAMMER_ITEM_ID, and BOOKOFEZRA_ITEM_ID used by callbacks below
POR_NehemiahCharacter  = include("nehemiahscripts.characters.nehemiah")

-- -- -- Compat
POR_NehemiahCompat     = include("nehemiahscripts.compat.eid")

-- -- -- Entities
POR_MoonlightEntity    = include("nehemiahscripts.entities.ezras_moonlight")
-- NOTE: nehemiahs_boulder.lua sets POR.ROCKTABLE, POR.ROCK_VARIANT, POR.ROCK_PROJECTILE_VARIANT, POR.stopHoldingRock, and POR.stopHoldingHideAnim
POR_NehemiahRockEntity = include("nehemiahscripts.entities.nehemiahs_boulder")

-- -- -- Items
POR_BookofEzra         = include("nehemiahscripts.items.book_of_ezra")
POR_NehemiahsHammer    = include("nehemiahscripts.items.nehemiahs_hammer")

-------------------------------------------------------------------------------------------------------------------------------
-- Initializes Save Handler
function POR:Init(folder, table)
    for _, string in ipairs(table) do
        include("nehemiahscripts/" .. folder .. "." .. string)
    end
end

POR.SaveCompiler.Init(POR)

-------------------------------------------------------------------------------------------------------------------------------
--[[
function mod:PostRender()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pos = Isaac.WorldToScreen(entity.Position)
        Isaac.RenderText(
            tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType),
            pos.X, pos.Y, 1,1,1,1)
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.PostRender)
]]--

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,  POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT,  POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.NehemiahHammerUse,  NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,          POR.BookofEzraUse,      BOOKOFEZRA_ITEM_ID)

-- Rock / Boulder
POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, POR.ROCKTABLE.BedSleptCheck,      PickupVariant.PICKUP_BED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.PickupUpdate,        POR.ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE,   POR.ROCKTABLE.ProjectileUpdate,    POR.ROCK_PROJECTILE_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE,   POR.ROCKTABLE.PostPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE,          POR.ROCKTABLE.HideRocksOnTrapdoor)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_RED_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingRock,               CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingHideAnim,           CollectibleType.COLLECTIBLE_URN_OF_SOULS)
POR:AddCallback(ModCallbacks.MC_USE_ITEM,             POR.stopHoldingHideAnim,           CollectibleType.COLLECTIBLE_NOTCHED_AXE)

-------------------------------------------------------------------------------------------------------------------------------
-- Custom Callbacks

---@class ExtraCallback
---@field func fun(...: any)
---@field priority ExtraCallbackPriority
---@field limiters any

---@class ExtraCallbacks
---@field Name string
---@field Functions ExtraCallback[]
---@field Handler fun(functions: ExtraCallback[], ...: any): ...
---@display POR.ExtraCallbacks
POR.ExtraCallbacks = {
    -- Called when a rock has died; args: player, tear, collider
    NEHEMIAH_ROCK_DEAD = {
        Name = "NEHEMIAH_ROCK_DEAD",
        Functions = {},
        Handler = function(callbacks, player, tear, collider)
            for i = 1, #callbacks do callbacks[i].func(player, tear, collider) end
        end,
    },

    -- Called before Nehemiah's hitbox is generated; return {Hitbox, Direction} array + optional true to suppress original
    NEHEMIAH_PRE_HITBOX_GENERATE = {
        Name = "NEHEMIAH_PRE_HITBOX_GENERATE",
        Functions = {},
        Handler = function(callbacks, player, hitbox, incubus)
            local hitboxes, shouldUseOriginal = {}, true
            for i = 1, #callbacks do
                local val, deleteOriginal = callbacks[i].func(player, hitbox, incubus)
                if val and type(val) == "table" then
                    for _, v in ipairs(val) do table.insert(hitboxes, v) end
                end
                if deleteOriginal == true then shouldUseOriginal = false end
            end
            return hitboxes, shouldUseOriginal
        end,
    },

    -- Called after Nehemiah throws a rock; args: player, rock
    NEHEMIAH_POST_THROW_ROCK = {
        Name = "NEHEMIAH_POST_THROW_ROCK",
        Functions = {},
        Handler = function(callbacks, player, tear)
            for i = 1, #callbacks do callbacks[i].func(player, tear) end
        end,
    },

    -- Called after PRE_HITBOX_GENERATE for each hitbox; optionally return modified hitbox
    NEHEMIAH_POST_HITBOX_GENERATE = {
        Name = "NEHEMIAH_POST_HITBOX_GENERATE",
        Functions = {},
        Handler = function(callbacks, player, incubus, hitbox)
            for i = 1, #callbacks do hitbox = callbacks[i].func(player, incubus, hitbox) or hitbox end
            return hitbox
        end
    },

    -- Called before a rock sprite is initialized; return a RockSpriteModifier (Anm2, ThrownAnm2, Spritesheet, Priority, DontUpdate) or nil to use default
    NEHEMIAH_PRE_ROCK_SPRITE_INIT = {
        Name = "NEHEMIAH_PRE_ROCK_SPRITE_INIT",
        Functions = {},
        Handler = function(callbacks, player, variant, tag, entity)
            local highestPriority, highestModifier = 0, nil
            for i = 1, #callbacks do
                local result = callbacks[i].func(player, variant, tag, entity)
                if result and result.Priority > highestPriority then
                    highestPriority, highestModifier = result.Priority, result
                end
            end
            return highestModifier
        end
    },
}

---@enum ExtraCallbackPriority
POR.ExtraCallbackPriority = {
    EARLIEST = 0,
    EARLY    = 1,
    NORMAL   = 2,
    LATE     = 3,
    LATEST   = 4,
}

-- Returns a set table with keys equal to the given list's values, all set to true
---@param list any[]
---@return {[any]: boolean?}
---@function
function POR:Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end