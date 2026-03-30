---- Path of Ruin ---
-- By Team Ruin

-- Setup
if not REPENTOGON then
    error("This Mod Requires REPENTAGON!!")
end
POR = RegisterMod("Path of Ruin", 1)
local game = Game()

-- Includes
-- -- Nehemiah
-- -- -- Characters
local NehemiahCharacter = require("nehemiahscripts.characters.nehemiah")

-- -- -- Compat
local NehemiahCompat = require("nehemiahscripts.compat.eid")

-- -- -- Entities
local MoonlightEntity = require("nehemiahscripts.entities.ezras_moonlight")
local NehemiahRockEntity = require("nehemiahscripts.entities.nehemiahs_rocks")

local ROCKTABLE = NehemiahRockEntity.ROCKTABLE
local ROCK_VARIANT = ROCKTABLE.PICKUP_EFFECT_VARIANT

-- -- -- Items
local BookofEzra = require("nehemiahscripts.items.book_of_ezra")
local NehemiahsHammer = require("nehemiahscripts.items.nehemiahs_hammer")


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
--Custom Incrementors

local function varSubtypeCheck(ent, variant, subtype)
	local entSubtype = ent:ToPlayer() and ent:ToPlayer():GetPlayerType() or ent.SubType
	return (not variant or ent.Variant == variant) and (not subtype or entSubtype == subtype)
end

local function forEach(ent, i, func, searchParams, variant, subtype)
	if varSubtypeCheck(ent, variant, subtype) then
		local castEnt = searchParams and searchParams.EntityOnly and ent or doCast(ent)
		if searchParams and searchParams.NPCOnly and not ent:ToNPC() then
			castEnt = nil
		end
		if castEnt and (not searchParams or not searchParams.UseEnemySearchParams or isValidEnemyTarget(castEnt, searchParams)) then
			local index = REPENTOGON and castEnt:ToPlayer() and castEnt:GetPlayerIndex() or i
			local result = func(castEnt, index)
			if result ~= nil then
				return result
			end
		end
	end
end

local function iforeach(loopTable, func, searchParams, variant, subtype)
	for i, ent in ipairs(loopTable) do
		local result = forEach(ent, i, func, searchParams, variant, subtype)
		if result ~= nil then
			return result
		end
	end
end
-------------------------------------------------------------------------------------------------------------------------------
-- Save Manager
---@diagnostic disable: missing-fields

---@enum DefaultSaveKeys
POR.DefaultSaveKeys = {
	PLAYER = "__DEFAULT_PLAYER",
	FAMILIAR = "__DEFAULT_FAMILIAR",
	PICKUP = "__DEFAULT_PICKUP",
	SLOT = "__DEFAULT_SLOT",
	BOMB = "__DEFAULT_BOMB",
	GLOBAL = "__DEFAULT_GLOBAL",
}

---@class SaveData
---@field game GameSave @Data that is persistent to the run. Starting a new run wipes this data. Affected by Glowing Hourglass.
---@field gameNoBackup GameSave @Data that is persistent to the run. Starting a new run wipes this data. IS NOT AFFECTED by Glowing Hourglass.
---@field hourglassBackup GameSave @A backup of `game` that is not to be edited.
---@field file FileSave @Data that is persistent to the save file. This data is never wiped.

---@class GameSave
---@field run table @Things in this table are persistent throughout the entire run.
---@field floor table @Things in this table are persistent only for the current floor.
---@field room table @Things in this table are persistent for the current floor and separates data by array of ListIndex.
---@field temp table @Things in this table are persistent only for the current room.
---@field pickupRoom table @Identical to the room save data, but meant specifically for pickups when outside of the room they're stored for.
---@field movingBox table Things in this table are persistent for the entire run, meant for storing pickups that are carried through Moving Box.
---@field treasureRoom table @Things in this table are persistent for the entire run, meant for when you re-visit Treasure Room in the Ascent.
---@field bossRoom table @Things in this table are persistent for the entire run, meant for when you re-visit Boss Room in the Ascent.

---@class PickupSave
---@field InitSeed integer
---@field InitSeedBackup integer
---@field RerollSave table
---@field NoRerollSave table
---@field NoRerollSaveBackup table

---@class FileSave
---@field unlockApi table @Built in compatibility for UnlockAPI (https://github.com/dsju/unlockapi)
---@field deadSeaScrolls table @Built in support for Dead Sea Scrolls (https://github.com/Meowlala/DeadSeaScrollsMenu)
---@field minimapAPI table @Built in support for MinimapAPI(https://github.com/TazTxUK/MinimapAPI)
---@field settings table @Miscellaneous table for anything settings-related.
---@field other table @Miscellaneous table for if you want to use your own unlock system or just need to store random data to the file.

---@alias DataDuration "run" | "floor" | "room" | "temp"
---@class SaveData
local dataCache = {}

---@param ent? Entity | integer
---@param noHourglass false|boolean?
---@param initDataIfNotPresent? boolean
---@param saveType DataDuration
---@param listIndex? integer
---@param allowSoulSave? boolean
---@return table
local function getRespectiveSave(ent, noHourglass, initDataIfNotPresent, saveType, listIndex, allowSoulSave)
	if not POR.Utility.IsDataInitialized(not initDataIfNotPresent)
		---@diagnostic disable-next-line: undefined-field
		or (ent and type(ent) == "userdata" and not POR.Utility.IsDataTypeAllowed(ent.Type, saveType))
	then
		---@diagnostic disable-next-line: missing-return-value
		return
	end
	noHourglass = noHourglass or false

	local getAltSave = allowSoulSave
		and ent
		and type(ent) == "userdata"
		---@cast ent Entity
		and ent:ToPlayer()
		and ent:ToPlayer():GetPlayerType() == PlayerType.PLAYER_THESOUL
		and ent:ToPlayer():GetSubPlayer() ~= nil
	local saveTableBackup = dataCache.game[saveType]
	local saveTableNoBackup = dataCache.gameNoBackup[saveType]
	local saveTable = noHourglass and saveTableNoBackup or saveTableBackup

	if not saveTable then return saveTable end
	local numberListIndex = listIndex or tonumber(POR.Utility.GetListIndex())
	local stringListIndex = tostring(numberListIndex)
	if saveType == "room" then
		if not saveTable[stringListIndex] then
			POR.Utility.DebugLog("Created index", stringListIndex)
			saveTable[stringListIndex] = {}
		end
		saveTable = saveTable[stringListIndex]
	end
	local saveIndex = POR.Utility.GetSaveIndex(ent, getAltSave)
	local data = saveTable[saveIndex]

	if data == nil and initDataIfNotPresent then
		local gameSave = noHourglass and "gameNoBackup" or "game"
		local defaultKey = POR.Utility.GetDefaultSaveKey(ent)
		local defaultSave = POR.DEFAULT_SAVE[gameSave][saveType][defaultKey] or {}
		if ent and type(ent) ~= "number" and ent.Type == EntityType.ENTITY_PICKUP then
			local pickupData = {
				InitSeed = ent.InitSeed,
				RerollSave = POR.Utility.PatchSaveFile({}, defaultSave),
				NoRerollSave = POR.Utility.PatchSaveFile({}, defaultSave)
			}
			saveTable[saveIndex] = pickupData
		else
			saveTable[saveIndex] = POR.Utility.PatchSaveFile({}, defaultSave)
		end
		POR.Utility.DebugLog("Created new", saveType, "data for", saveIndex)
	end
	data = saveTable[saveIndex]

	return data
end

---@param ent? Entity @If an entity is provided, returns an entity specific save within the run save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass false|boolean? @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table
---@function
function POR:RunSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, true, "run", nil, allowSoulSave)
end

-------------------------------------------------------------------------------------------------------------------------------
-- Callbacks
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.NehemiahInit)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.TaintedNehemiahInit)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.NehemiahHammerUse, NEHEMIAHSHAMMER_ITEM_ID)
POR:AddCallback(ModCallbacks.MC_USE_ITEM, POR.BookofEzraUse, BOOKOFEZRA_ITEM_ID)

POR:AddCallback(ModCallbacks.MC_PRE_PICKUP_COLLISION, ROCKTABLE.BedSleptCheck, PickupVariant.PICKUP_BED)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, POR.ManageBoulderPickupSprite, ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_EFFECT_UPDATE, POR.BoulderBeastFalling, ROCK_VARIANT)
POR:AddCallback(ModCallbacks.MC_POST_PLAYER_UPDATE, ROCKTABLE.PostPlayerUpdate)

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
