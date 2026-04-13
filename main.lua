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
POR_CustomSaveCompiler = include("nehemiahscripts.custom_save_compiler")
POR.SaveCompiler.Init(POR)
POR.SaveCallbacks = POR.SaveCompiler.SaveCallbacks
POR_CustomSaveCreator = include("nehemiahscripts.custom_save_creator")
POR_ScrumMaster = include("nehemiahscripts.custom_scrum_master_schedule")
POR_Incrementor = include("nehemiahscripts.custom_incrementor")

-- -- Nehemiah
-- -- -- Characters
POR_NehemiahCharacter = include("nehemiahscripts.characters.nehemiah")

-- -- -- Compat
POR_NehemiahCompat = include("nehemiahscripts.compat.eid")

-- -- -- Entities
POR_MoonlightEntity = include("nehemiahscripts.entities.ezras_moonlight")
POR_NehemiahRockEntity = include("nehemiahscripts.entities.nehemiahs_rocks")

-- -- -- Items
POR_BookofEzra = include("nehemiahscripts.items.book_of_ezra")
POR_NehemiahsHammer = include("nehemiahscripts.items.nehemiahs_hammer")

-------------------------------------------------------------------------------------------------------------------------------
---Initializes Save Handler
function POR:Init(folder, table)
	for _, string in ipairs(table) do
		include("nehemiahscripts/" .. folder .. "." .. string)
	end
end

POR.SaveCompiler:Init()
POR.scrum_master_schedule:Init()
-------------------------------------------------------------------------------------------------------------------------------
--  -- Stuff Needed Around

--[[
function mod:PostRender()
    for _, entity in ipairs(Isaac.GetRoomEntities()) do
        local pos = Isaac.WorldToScreen(entity.Position)
        Isaac.RenderText(
            tostring(entity.Type) .. "." .. tostring(entity.Variant) .. "." .. tostring(entity.SubType),
            pos.X,
            pos.Y,
            1,1,1,1)
    end
end
mod:AddCallback(ModCallbacks.MC_POST_RENDER, mod.PostRender)
]]--

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.NehemiahHammerUse, NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.BookofEzraUse, BOOKOFEZRA_ITEM_ID)

POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, POR.ROCKTABLE.BedSleptCheck, PickupVariant.PICKUP_BED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, POR.ManageRockPickupSprite, POR.ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, POR.RockBeastFalling, POR.ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, POR.ROCKTABLE.PostPlayerUpdate)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE, POR.ROCKTABLE.OnUpdate)
POR:AddCallback(ModCallbacks.MC_POST_TEAR_UPDATE, POR.ROCKTABLE.RockUpdate, POR.ROCK_TEAR_VARIANT)
POR:AddCallback(ModCallbacks.MC_PRE_TEAR_COLLISION, POR.ROCKTABLE.RockCollide, POR.ROCK_TEAR_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_UPDATE, POR.ROCKTABLE.HideRocksOnTrapdoor)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingRock, CollectibleType.COLLECTIBLE_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingRock, CollectibleType.COLLECTIBLE_RED_CANDLE)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingRock, CollectibleType.COLLECTIBLE_BOBS_ROTTEN_HEAD)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingRock, CollectibleType.COLLECTIBLE_BAG_OF_CRAFTING)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingHideAnim, CollectibleType.COLLECTIBLE_URN_OF_SOULS)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.stopHoldingHideAnim, CollectibleType.COLLECTIBLE_NOTCHED_AXE)

-------------------------------------------------------------------------------------------------------------------------------
-- Custom Callbacks


---@param id string
---@param priority integer
---@param func function
---@param ... any
function POR.SaveCompiler.Callbacks.AddPriorityCallback(id, priority, func, ...)
	local callbacks = POR.SaveCompiler.Callbacks.RegisteredCallbacks[id]
	local callback = {
		Priority = priority,
		Function = func,
		Args = { ... },
	}

	if #callbacks == 0 then
		callbacks[#callbacks + 1] = callback
	else
		for i = #callbacks, 1, -1 do
			if callbacks[i].Priority <= priority then
				table.insert(callbacks, i + 1, callback)
				return
			end
		end
		table.insert(callbacks, 1, callback)
	end
end


---@param id string
---@param func function
---@param ... any
function POR.SaveCompiler.Callbacks.AddCallback(id, func, ...)
	POR.SaveCompiler.Callbacks.AddPriorityCallback(id, POR.SaveCompiler.CallbackPriority.NORMAL, func, ...)
end

---@param id string
---@param func function
function POR.SaveCompiler.Callbacks.RemoveCallback(id, func)
	local callbacks = POR.SaveCompiler.Callbacks.RegisteredCallbacks[id]
	for i = #callbacks, 1, -1 do
		if callbacks[i].Function == func then
			table.remove(callbacks, i)
		end
	end
end


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
    -- Called when a rock has died
	-- `player` - hitter player
	-- `entity` - entity hit by the player
	-- `Amount` - Damage amount dealth
	-- `Flags` - damage flags
	NEHEMIAH_ROCK_DEAD = {
		Name = "NEHEMIAH_ROCK_DEAD",
		Functions = {},
		Handler = function(callbacks, player, tear, collider)
			for i = 1, #callbacks do
				callbacks[i].func(player, tear, collider)
			end
		end,
	},

    -- Called before Nehemiah's hitbox is generated. Used to add new hitboxes
	-- - `player` - hitter player
	-- - `hitbox` - generated hitbox
	-- - `incubus` - this is an Incubus EntityFamiliar if an Incubus executed the attack
	-- - Return an array of dictionaries ({Hitbox = hitbox, Direction = Vector}) for hitboxes to use in addition to the original one.
	-- - Optionally, return true as the second value to prevent the original hitbox from being used.
	NEHEMIAH_PRE_HITBOX_GENERATE = {
		Name = "NEHEMIAH_PRE_HITBOX_GENERATE",
		Functions = {},
		Handler = function(callbacks, player, hitbox, incubus)
			local hitboxes = {}
			local shouldUseOriginal = true
			for i = 1, #callbacks do
				local val, deleteOriginal = callbacks[i].func(player, hitbox, incubus)
				if val and type(val) == "table" then
					for _, v in ipairs(val) do
						table.insert(hitboxes, v)
					end
				end

				if deleteOriginal == true then
					shouldUseOriginal = false
				end
			end

			return hitboxes, shouldUseOriginal
		end,
	},

    -- Called after Nehemiah throws a rock
	-- - `player` - rock-throwing player
	-- - `rock` - rock entity
	NEHEMIAH_POST_THROW_ROCK = {
		Name = "NEHEMIAH_POST_THROW_ROCK",
		Functions = {},
		Handler = function(callbacks, player, tear)
			for i = 1, #callbacks do
				callbacks[i].func(player, tear)
			end
		end,
	},

    -- Called after `NEHEMIAH_PRE_HITBOX_GENERATE` separately for each hitbox. Optionally return the new hitbox
	-- - `player` - hitter player
	-- - `incubus` - this is an Incubus EntityFamiliar if an Incubus executed the attack
	-- - `hitbox` - generated hitbox
	NEHEMIAH_POST_HITBOX_GENERATE = {
		Name = "NEHEMIAH_POST_HITBOX_GENERATE",
		Functions = {},
		Handler = function(callbacks, player, incubus, hitbox)
			for i = 1, #callbacks do
				hitbox = callbacks[i].func(player, incubus, hitbox) or hitbox
			end
			return hitbox
		end
	},

    -- Called before a stationary or thrown rock has its sprite initialized
	-- - `player` - player who caused the rock to be initialized
	-- - `variant` - the variant the rock was gonna be. 1, 2, or 3
	-- - `tag` - A special tag applied
	-- - `entity` - The effect or tear of the rock
	--
	-- Return a RockSpriteModifier table to alter the sprite, or nil to use the original sprite
	--
	--<hr>
	--
	-- A RockSpriteModifier table may have the following fields:
	-- - `Anm2` - a path to the anm2 to use for the rock, or nil to use the default
	-- - `ThrownAnm2` - a path to the anm2 to use for the rock when it's thrown, or nil to use the default
	-- - `Spritesheet` - a path to the spritesheet to use for the rock
	-- - `Priority` - a number denoting how important this sprite is. Higher numbers override lower numbers
	-- - `DontUpdate` - don't update the spritesheet animations at all
	NEHEMIAH_PRE_ROCK_SPRITE_INIT = {
		Name = "NEHEMIAH_PRE_ROCK_SPRITE_INIT",
		Functions = {},
		Handler = function(callbacks, player, variant, tag, entity)
			local highestPriority, highestModifier = 0, nil
			for i = 1, #callbacks do
				local result = callbacks[i].func(player, variant, tag, entity)
				if result then
					if result.Priority > highestPriority then
						highestPriority = result.Priority
						highestModifier = result
					end
				end
			end

			return highestModifier
		end
	},

}

---@enum ExtraCallbackPriority
POR.ExtraCallbackPriority = {
	EARLIEST = 0,
	EARLY = 1,
	NORMAL = 2,
	LATE = 3,
	LATEST = 4,
}

--- Returns a transposed table with keys equal to given table's values and values set to true
---@param list any[]
---@return {[any]: boolean?}
---@function
function POR:Set(list)
	local set = {}
	for _, l in ipairs(list) do
		set[l] = true
	end
	return set
end


-------------------------------------------------------------------------------------------------------------------------------

-- For Reference

--[[
local GOLDEN_DAMAGE = 1
function POR:GoldenAppleCache(player, cacheFlags)
    if cacheFlags & CacheFlag.CACHE_DAMAGE == CacheFlag.CACHE_DAMAGE then
        local itemcount = player:GetCollectibleNum(GOLDENAPPLE_ITEM_ID)
        local damagetoAdd = GOLDEN_DAMAGE * itemcount
        player.Damage = player.Damage + damagetoAdd
    end
end


local HS_POISON_CHANCE = 0.4            -- Incrimental damage in Isaac happens at 3 ticks, and then concatonates every 20 ticks, ex: 3 23, 43, 63,...
local HS_POISON_LENGTH = 3
local ONE_INTERVAL_OF_POISON = 20       -- This variable and the one before are here to vizualize the previous comment

function POR:HolySmokesNewRoom()
    local playerCount = game:GetNumPlayers()

    for playerIndex = 0, playerCount - 1 do
        local player = Isaac.GetPlayer(playerIndex)
        local copyCount = player:GetCollectibleNum(HOLYSMOKES_ITEM_ID)

        if copyCount > 0 then 
            local rng = player:GetCollectibleRNG(HOLYSMOKES_ITEM_ID)
            local entities = Isaac.GetRoomEntities()

            for _, entity in ipairs(entities) do
                if entity:IsActiveEnemy() and entity:IsVulnerableEnemy() then
                    if rng:RandomFloat() < HS_POISON_CHANCE then
                        -- source, duration, damage
                        entity:AddPoison(EntityRef(player), HS_POISON_LENGTH + (ONE_INTERVAL_OF_POISON * copyCount), player.Damage)
                    end
                end
            end
        end
    end
end
--]]
