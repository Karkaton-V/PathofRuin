---@diagnostic disable: missing-fields
-- Thank you catinsured for the save manager: https://github.com/catinsurance/IsaacSaveCompiler/

local game = POR.game
POR.SaveCompiler = {}
POR.SaveCompiler.VERSION = "1.0.0"
POR.SaveCompiler.Utility = {}

POR.SaveCompiler.Debug = false

POR.SaveCompiler.AutoCreateRoomSaves = true

local mFloor = math.floor

-- Used in the DEFAULT_SAVE table as a key with the value being the default save data for a player in this save type.

---@enum DefaultSaveKeys
POR.SaveCompiler.DefaultSaveKeys = {
	PLAYER = "__DEFAULT_PLAYER",
	FAMILIAR = "__DEFAULT_FAMILIAR",
	PICKUP = "__DEFAULT_PICKUP",
	SLOT = "__DEFAULT_SLOT",
	BOMB = "__DEFAULT_BOMB",
	GLOBAL = "__DEFAULT_GLOBAL",
}

local modReference
local minimapAPIReference
local json = require("json")
local loadedData = false
local dontSaveModData = game:GetFrameCount() == 0
local skipFloorReset = false
local skipRoomReset = false
local shouldRestoreOnUse = true
local usedHourglass = false
local myosotisCheck = false
local movingBoxCheck = false
local currentListIndex = 0
local checkLastIndex = false
local inRunButNotLoaded = true
local retainFamiliarSaveOnFlip = false
local tLazInitPlayer
local tLazInitSeeds
local dupeTaggedPickups = {}
local allowedAscentRooms = {}

local isLazB = {
	[PlayerType.PLAYER_LAZARUS_B] = true,
	[PlayerType.PLAYER_LAZARUS2_B] = true
}

---@class SaveData
local dataCache = {}

---@type {["0"]: GameSave, ["1"]: GameSave}
local hourglassBackup = {
	["0"] = {},
	["1"] = {}
}
local lastUsedHourglassSlot = "1"

POR.SaveCompiler.Utility.ERROR_MESSAGE_FORMAT = "[IsaacSaveCompiler:%s] ERROR: %s (%s)\n"
POR.SaveCompiler.Utility.WARNING_MESSAGE_FORMAT = "[IsaacSaveCompiler:%s] WARNING: %s (%s)\n"
POR.SaveCompiler.Utility.ErrorMessages = {
	NOT_INITIALIZED = "The save compiler cannot be used without initializing it first!",
	DATA_NOT_LOADED = "An attempt to use save data was made before it was loaded!",
	BAD_DATA = "An attempt to save invalid data was made!",
	BAD_DATA_WARNING = "Data type saved with warning!",
	COPY_ERROR =
	"An error was made when copying from cached data to what would be saved! This could be due to a circular reference.",
	INVALID_ENTITY_TYPE = "Error using entity type \"%s\": The save manager cannot support non-persistent entities!",
	INVALID_TYPE_WITH_SAVE =
	"An error was made using entity type \"%s\": This entity type does not support this save data as it does not persist between floors or move between rooms."
}
POR.SaveCompiler.Utility.JsonIncompatibilityType = {
	SPARSE_ARRAY = "Sparse arrays, or arrays with gaps between indexes, will fill gaps with null when encoded.",
	INVALID_KEY_TYPE = "Error at index \"%s\" with value \"%s\", type \"%s\": Tables that have non-string or non-integer (decimal or non-number) keys cannot be encoded.",
	MIXED_TABLES = "Index \"%s\" with value \"%s\", type \"%s\", found in table with initial type \"%s\": Tables with mixed key types cannot be encoded.",
	NAN_VALUE = "Tables with invalid numbers (NaN, -inf, inf) cannot be encoded.",
	INVALID_VALUE = "Error at index \"%s\" with value \"%s\", type \"%s\": Tables containing anything other than strings, numbers, booleans, or other tables cannot be encoded.",
	CIRCULAR_TABLE = "Tables that contain themselves cannot be encoded.",
}

---@enum SaveCallbacks
POR.SaveCompiler.SaveCallbacks = {
	---(SaveData saveData): SaveData - Called before validating the save data to store into the mod's save file. This will not run if there happens to be an issue with copying the contents of the save data or its hourglass backup. Modify the existing contents of the table or return a new table to overwrite the provided save data. As this is a copy, it will not affect the save data currently accessible
	PRE_DATA_SAVE = "ISAACSAVECOMPILER_PRE_DATA_SAVE",
	---(SaveData saveData) - Called after storing save data into the mod's save file
	POST_DATA_SAVE = "ISAACSAVECOMPILER_POST_DATA_SAVE",
	---(SaveData saveData, boolean isLuamod): SaveData - Called after loading the data from the mod's save file but before loading it into the local save data. Modify the existing contents of the table or return a new table to overwrite the provided save data. `isLuamod` will return `true` if the mod's data was reloaded via the luamod command
	PRE_DATA_LOAD = "ISAACSAVECOMPILER_PRE_DATA_LOAD",
	---(SaveData saveData, boolean isLuamod) - Called after loading the mod's save file and storing it in local save data
	POST_DATA_LOAD = "ISAACSAVECOMPILER_POST_DATA_LOAD",
	---(Entity entity), Optional Arg: EntityType - Called after finishing initializing an entity
	POST_ENTITY_DATA_LOAD = "ISAACSAVECOMPILER_POST_ENTITY_DATA_LOAD",
	---() - Called on POST_PLAYER_INIT for the first player, the earliest data can load, to load arbitrary data
	POST_GLOBAL_DATA_LOAD = "ISAACSAVECOMPILER_POST_GLOBAL_DATA_LOAD",
	---(EntityPickup originalPickup, EntityPickup dupedPickup, PickupSave originalSave): boolean, Optional Arg: PickupVariant - Called when a pickup is initialized with the same InitSeed as an existing pickup in the room that has existing save data. Should not run twice for the same pickup. Return `true` to stop data from being copied.
	DUPE_PICKUP_DATA_LOAD = "ISAACSAVECOMPILER_DUPE_PICKUP_DATA_LOAD",
	---(EntityPickup pickup, NoRerollSave saveData), Optional Arg: PickupVariant - Called when the pickup is detected to have an InitSeed change before save data is updated
	PRE_PICKUP_INITSEED_MORPH = "ISAACSAVECOMPILER_PRE_PICKUP_INITSEED_MORPH",
	---(EntityPickup pickup, NoRerollSave saveData), Optional Arg: PickupVariant - Called when the pickup is detected to have an InitSeed change after save data is updated
	POST_PICKUP_INITSEED_MORPH = "ISAACSAVECOMPILER_POST_PICKUP_INITSEED_MORPH",
	---() - Called before all list-indexed room data is reset when changing floors
	PRE_ROOM_DATA_RESET = "ISAACSAVECOMPILER_PRE_ROOM_DATA_RESET",
	---() - Called after all list-indexed room data is reset when changing floors
	POST_ROOM_DATA_RESET = "ISAACSAVECOMPILER_POST_ROOM_DATA_RESET",
	---() - Called before all temporary room data is reset when changing rooms
	PRE_TEMP_DATA_RESET = "ISAACSAVECOMPILER_PRE_TEMP_DATA_RESET",
	---() - Called after all temporary room data is reset when changing rooms
	POST_TEMP_DATA_RESET = "ISAACSAVECOMPILER_POST_TEMP_DATA_RESET",
	---() - Called before all floor data is reset when changing floors
	PRE_FLOOR_DATA_RESET = "ISAACSAVECOMPILER_PRE_FLOOR_DATA_RESET",
	---() - Called after all floor data is reset when changing floors
	POST_FLOOR_DATA_RESET = "ISAACSAVECOMPILER_POST_FLOOR_DATA_RESET",
	---() - Called when Glowing Hourglass is detected to have activated and is queued to reset all save data to the hourglass save
	PRE_GLOWING_HOURGLASS_RESET = "ISAACSAVECOMPILER_PRE_GLOWING_HOURGLASS_RESET",
	---() - Called after Glowing Hourglass reverts all save data has to the hourglass save
	POST_GLOWING_HOURGLASS_RESET = "ISAACSAVECOMPILER_POST_GLOWING_HOURGLASS_RESET"
}

POR.SaveCompiler.Utility.CustomCallback = {}

for name, value in pairs(POR.SaveCompiler.SaveCallbacks) do
	POR.SaveCompiler.Utility.CustomCallback[name] = value
end

POR.SaveCompiler.Utility.CallbackPriority = {
	IMPORTANT = -1000,
	EARLY = -199,
	LATE = 1000
}

POR.SaveCompiler.Utility.ValidityState = {
	VALID = 0,
	VALID_WITH_WARNING = 1,
	INVALID = 2,
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

---You can edit what is inside of these tables, but changing the overall structure of this table will break things.
---@class SaveData
POR.SaveCompiler.DEFAULT_SAVE = {
	game = {
		run = {},
		floor = {},
		room = {},
		temp = {},
		pickupRoom = {},
		movingBox = {},
		treasureRoom = {},
		bossRoom = {},
	},
	gameNoBackup = {
		run = {},
		floor = {},
		room = {},
		temp = {}
	},
	file = {
		unlockApi = {},
		deadSeaScrolls = {},
		minimapAPI = {},
		settings = {},
		other = {}
	}
}

--#region utility methods

---@param ent Entity | EntityType
function POR.SaveCompiler.Utility.CanHavePersistentData(ent)
	local defaultAllowedTypes = {
		[EntityType.ENTITY_PLAYER] = true,
		[EntityType.ENTITY_FAMILIAR] = true,
		[EntityType.ENTITY_PICKUP] = true,
		[EntityType.ENTITY_SLOT] = true,
		[EntityType.ENTITY_BOMB] = true
	}
	local entType = type(ent) == "number" and ent or ent.Type
	if defaultAllowedTypes[entType] then
		return true
	elseif type(ent) == "userdata" then
		---@cast ent Entity
		return ent:ToNPC() and ent:HasEntityFlags(EntityFlag.FLAG_PERSISTENT)
	elseif entType >= 10 then
		return true
	end
	return false
end

function POR.SaveCompiler.Utility.SendError(msg)
	local _, traceback = pcall(error, "", 5) -- 5 because it is 5 layers deep
	Isaac.ConsoleOutput(POR.SaveCompiler.Utility.ERROR_MESSAGE_FORMAT:format(modReference and modReference.Name or "???", msg,
		traceback))
	Isaac.DebugString(POR.SaveCompiler.Utility.ERROR_MESSAGE_FORMAT:format(modReference and modReference.Name or "???", msg,
		traceback))
end

function POR.SaveCompiler.Utility.SendWarning(msg)
	local _, traceback = pcall(error, "", 4) -- 4 because it is 4 layers deep
	Isaac.ConsoleOutput(POR.SaveCompiler.Utility.WARNING_MESSAGE_FORMAT:format(modReference and modReference.Name or "???",
		msg, traceback))
	Isaac.DebugString(POR.SaveCompiler.Utility.WARNING_MESSAGE_FORMAT:format(modReference and modReference.Name or "???", msg,
		traceback))
end

---A wrap for `print` that only triggers if `POR.SaveCompiler.Debug` is set to `true`.
function POR.SaveCompiler.Utility.DebugLog(...)
	if POR.SaveCompiler.Debug then
		print(...)
	end
end

function POR.SaveCompiler.Utility.IsCircular(tab, traversed)
	traversed = traversed or {}

	if traversed[tab] then
		return true
	end

	traversed[tab] = true

	for _, v in pairs(tab) do
		if type(v) == "table" then
			if POR.SaveCompiler.Utility.IsCircular(v, traversed) then
				return true
			end
		end
	end

	return false
end

function POR.SaveCompiler.Utility.DeepCopy(tab)
	if type(tab) ~= "table" then
		return tab
	end

	local final = setmetatable({}, getmetatable(tab))
	for i, v in pairs(tab) do
		final[i] = POR.SaveCompiler.Utility.DeepCopy(v)
	end

	return final
end

---Checks if the provided string is a default key
---@param key string
function POR.SaveCompiler.Utility.IsDefaultSaveKey(key)
	for _, keyName in pairs(POR.SaveCompiler.DefaultSaveKeys) do
		if keyName == key then
			return true
		end
	end
	return false
end

---Gets the default save key matching with the entity's type.
---@param ent? Entity | integer
function POR.SaveCompiler.Utility.GetDefaultSaveKey(ent)
	if type(ent) == "number" then return "" end
	local typeToName = {
		[EntityType.ENTITY_PLAYER] = "__DEFAULT_PLAYER",
		[EntityType.ENTITY_FAMILIAR] = "__DEFAULT_FAMILIAR",
		[EntityType.ENTITY_PICKUP] = "__DEFAULT_PICKUP",
		[EntityType.ENTITY_SLOT] = "__DEFAULT_SLOT",
		[EntityType.ENTITY_BOMB] = "__DEFAULT_BOMB"
	}
	local key
	if ent then
		if getmetatable(ent).__type:find("Entity") then
			key = typeToName[ent.Type]
		end
	else
		key = "__DEFAULT_GLOBAL"
	end
	return key
end

---Gets a unique string as an identifier for the entity in the save data.
---@param ent? Entity | integer
---@param allowSoulSave? boolean
function POR.SaveCompiler.Utility.GetSaveIndex(ent, allowSoulSave)
	local typeToName = {
		[EntityType.ENTITY_PLAYER] = "PLAYER_",
		--[EntityType.ENTITY_TEAR] = "TEAR_",
		[EntityType.ENTITY_FAMILIAR] = "FAMILIAR_",
		[EntityType.ENTITY_BOMB] = "BOMB_",
		[EntityType.ENTITY_PICKUP] = "PICKUP_",
		[EntityType.ENTITY_SLOT] = "SLOT_",
		--[EntityType.ENTITY_LASER] = "LASER_",
		--[EntityType.ENTITY_KNIFE] = "KNIFE_",
		--[EntityType.ENTITY_PROJECTILE] = "PROJECTILE_"
	}
	local name
	local identifier
	if ent and type(ent) == "userdata" then
		---@cast ent Entity
		if typeToName[ent.Type] then
			name = typeToName[ent.Type]
		else
			name = "NPC_"
		end
		if ent:ToPlayer() then
			local player = ent:ToPlayer() ---@cast player EntityPlayer
			local id = 1
			if allowSoulSave then
				player = player:GetSubPlayer() or player
			end
			if player:GetPlayerType() == PlayerType.PLAYER_LAZARUS2_B then
				id = 2
				if player.FrameCount == 0 then
					identifier = tostring(Isaac.GetPlayer(game:GetNumPlayers() - 1):GetCollectibleRNG(2):GetSeed())
				end
			end
			if game:GetFrameCount() > 0 and tLazInitSeeds then
				identifier = tostring(tLazInitSeeds[id])
			elseif not identifier then
				local laz = player:GetData().__SAVECOMPILER_ALIVE_LAZ
				if laz and laz:ToPlayer() then
					player = laz:ToPlayer()
				end
				if player ~= nil then
					identifier = tostring(player:GetCollectibleRNG(id):GetSeed())
				end
			end
		elseif ent.Type == EntityType.ENTITY_PICKUP then
			identifier = GetPtrHash(ent)
		else
			identifier = ent.InitSeed
		end
	elseif ent and type(ent) == "number" then
		name = "GRID_"
		identifier = ent
	elseif not ent then
		name = "GLOBAL"
		identifier = ""
	end
	return name .. identifier
end

function POR.SaveCompiler.Utility.GetListIndex()
	--Myosotis for checking last floor's ListIndex or for checking the pre-saved ListIndex on continue
	local roomDesc = game:GetLevel():GetCurrentRoomDesc()
	local listIndex = roomDesc.ListIndex
	local isStartOrContinue = (Isaac.GetPlayer() and Isaac.GetPlayer().FrameCount == 0)
	local shouldCheckLastIndex = checkLastIndex or isStartOrContinue or usedHourglass
	if shouldCheckLastIndex then
		listIndex = currentListIndex
	end
	local listIndexString = tostring(listIndex)

	if not shouldCheckLastIndex then
		--Curse of the Maze can swap rooms around
		local SPAWN_SEED = roomDesc.SpawnSeed
		if dataCache.game.room[listIndexString]
			and dataCache.game.room[listIndexString].__SAVECOMPILER_SPAWN_SEED
			and dataCache.game.room[listIndexString].__SAVECOMPILER_SPAWN_SEED ~= SPAWN_SEED
		then
			POR.SaveCompiler.Utility.DebugLog("Spawn seed doesn't match! Locating correct room..")
			for savedListindex, data in pairs(dataCache.game.room) do
				if data.__SaveCompiler_SPAWN_SEED == SPAWN_SEED then
					POR.SaveCompiler.Utility.DebugLog("Spawn seed located! Swapping room data..")
					local currentData = dataCache.game.room[listIndexString]
					dataCache.game.room[savedListindex] = currentData
					dataCache.game.room[listIndexString] = data
					if dataCache.game.pickupRoom[listIndexString] then
						local currentPickupData = dataCache.game.pickupRoom[listIndexString]
						dataCache.game.pickupRoom[listIndexString] = dataCache.game.pickupRoom[savedListindex]
						dataCache.game.pickupRoom[savedListindex] = currentPickupData
					end
					listIndexString = savedListindex
					break
				end
			end
		end
	end
	return listIndexString
end

function POR.SaveCompiler.Utility.GetAscentSaveIndex()
	if checkLastIndex then
		local listIndex = tostring(currentListIndex)
		return dataCache.game.room[listIndex] and dataCache.game.room[listIndex].__SAVECOMPILER_ASCENT_INDEX
	elseif game:GetRoom():GetType() == RoomType.ROOM_TREASURE or game:GetRoom():GetType() == RoomType.ROOM_BOSS then
		local level = game:GetLevel()
		local stageType = level:GetStageType()
		stageType = stageType >= StageType.STAGETYPE_REPENTANCE and StageType.STAGETYPE_REPENTANCE or StageType.STAGETYPE_ORIGINAL
		return table.concat({level:GetStage(), stageType, level:GetCurrentRoomDesc().Data.Variant}, "_")
	end
end

---Returns a modified version of `deposit` that has the same data that `source` has. Data present in `deposit` but not `source` is unmodified.
---
---Is mostly used with `deposit` as an empty table and `source` the default save data to overrite existing data with the default data.
---@param deposit table
---@param source table
function POR.SaveCompiler.Utility.PatchSaveFile(deposit, source)
	for i, v in pairs(source) do
		if POR.SaveCompiler.Utility.IsDefaultSaveKey(i) then
			POR.SaveCompiler.Utility.PatchSaveFile(deposit, v)
		elseif type(v) == "table" then
			if type(deposit[i]) ~= "table" then
				deposit[i] = {}
			end

			deposit[i] = POR.SaveCompiler.Utility.PatchSaveFile(deposit[i] ~= nil and deposit[i] or {}, v)
		elseif deposit[i] == nil then
			deposit[i] = v
		end
	end

	return deposit
end

---Checks if the table is an array with gaps in their indexes
---@param tab table
local function isSparseArray(tab)
	local max = 0
	for i in pairs(tab) do
		if type(i) ~= "number" then
			return false
		end

		if i > max then
			max = i
		end
	end

	return max ~= #tab
end

-- Recursively validates if a table can be encoded into valid JSON.
-- Returns 0 if it can be encoded, 1 if it can but has a warning, and 2 if item cannot. If 1 or 2, it will also return a message.
function POR.SaveCompiler.Utility.ValidateForJson(tab)
	local hasWarning

	-- check for mixed table
	local indexType
	for index, value in pairs(tab) do
		if not indexType then
			indexType = type(index)
		end

		if type(index) ~= indexType then
			local valType = type(value) == "userdata" and getmetatable(value).__type or type(value)
			return POR.SaveCompiler.Utility.ValidityState.INVALID, POR.SaveCompiler.Utility.JsonIncompatibilityType.MIXED_TABLES:format(index, tostring(value), valType, indexType)
		end

		if type(index) ~= "string" and type(index) ~= "number" then
			local valType = type(value) == "userdata" and getmetatable(value).__type or type(value)
			return POR.SaveCompiler.Utility.ValidityState.INVALID,
				POR.SaveCompiler.Utility.JsonIncompatibilityType.INVALID_KEY_TYPE:format(index, tostring(value), valType)
		end

		if type(index) == "number" then
			if mFloor(index) ~= index then
				local valType = type(value) == "userdata" and getmetatable(value).__type or type(value)
				return POR.SaveCompiler.Utility.ValidityState.INVALID,
					POR.SaveCompiler.Utility.JsonIncompatibilityType.INVALID_KEY_TYPE:format(index, tostring(value), valType)
			elseif value == math.huge or value == -math.huge or value ~= value then
				return POR.SaveCompiler.Utility.ValidityState.INVALID, POR.SaveCompiler.Utility.JsonIncompatibilityType.NAN_VALUE
			end
		end

		-- check for NaN and infinite values
		-- http://lua-users.org/wiki/InfAndNanComparisons
		if type(value) == "number" then
			if value == math.huge or value == -math.huge or value ~= value then
				return POR.SaveCompiler.Utility.ValidityState.INVALID, POR.SaveCompiler.Utility.JsonIncompatibilityType.NAN_VALUE
			end
		elseif type(value) == "table" then
			local valid, error = POR.SaveCompiler.Utility.ValidateForJson(value)
			if valid == POR.SaveCompiler.Utility.ValidityState.INVALID then
				return valid, error
			elseif valid == POR.SaveCompiler.Utility.ValidityState.VALID_WITH_WARNING then
				hasWarning = error
			end
		elseif type(value) ~= "string" and type(value) ~= "boolean" then
			local valType = type(value) == "userdata" and getmetatable(value).__type or type(value)
			--if not POR.SaveCompiler.Utility.Serialize(tab, index, value) then
				return POR.SaveCompiler.Utility.ValidityState.INVALID, POR.SaveCompiler.Utility.JsonIncompatibilityType.INVALID_VALUE:format(index, tostring(value), valType)
			--end
		end
	end

	-- check for sparse array
	if isSparseArray(tab) then
		hasWarning = POR.SaveCompiler.Utility.JsonIncompatibilityType.SPARSE_ARRAY
	end

	if POR.SaveCompiler.Utility.IsCircular(tab) then
		return POR.SaveCompiler.Utility.ValidityState.INVALID, POR.SaveCompiler.Utility.JsonIncompatibilityType.CIRCULAR_TABLE
	end

	if hasWarning then
		return POR.SaveCompiler.Utility.ValidityState.VALID_WITH_WARNING, hasWarning
	end

	return POR.SaveCompiler.Utility.ValidityState.VALID
end

---@return table | nil
function POR.SaveCompiler.Utility.RunCallback(callbackId, ...)
	if not modReference then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.NOT_INITIALIZED)
		return
	end

	local id = modReference.__SAVECOMPILER_UNIQUE_KEY .. callbackId
	local returnVal = Isaac.RunCallback(id, ...)

	return returnVal
end

---@alias DataDuration "run" | "floor" | "room" | "temp"

---Checks if the entity type with the given save data's duration is permitted within the save manager.
---@param entType integer
---@param saveType DataDuration
function POR.SaveCompiler.Utility.IsDataTypeAllowed(entType, saveType)
	if type(entType) == "number"
		and not POR.SaveCompiler.Utility.CanHavePersistentData(entType)
	then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.INVALID_ENTITY_TYPE:format(entType))
		return false
	end
	if type(entType) == "number"
		and entType ~= EntityType.ENTITY_PLAYER
		and entType ~= EntityType.ENTITY_FAMILIAR
		and entType < 10
		and (
			saveType == "run"
			or saveType == "floor"
		)
	then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.INVALID_TYPE_WITH_SAVE:format(entType))
		return false
	end
	return true
end

---@param ignoreWarning? boolean
function POR.SaveCompiler.Utility.IsDataInitialized(ignoreWarning)
	if not modReference then
		if not ignoreWarning then
			POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.NOT_INITIALIZED)
		end
		return false
	end

	if not loadedData then
		if not ignoreWarning then
			POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.DATA_NOT_LOADED)
		end
		return false
	end

	return true
end

-- Returns the dimension ID the player is currently in.
-- 0: Normal Dimension
-- 1: Secondary dimension, used by Downpour mirror dimension and Mines escape sequence
-- 2: Death Certificate dimension
---@param room integer? @The room to check. If nil, the current room will be used. Not needed with REPENTOGON enabled
---@function
function POR.SaveCompiler.Utility.GetDimension(room)
	local level = game:GetLevel()
	if REPENTOGON then
		return level:GetDimension()
	end
	local roomIndex = room or level:GetCurrentRoomIndex()

	for i = 0, 2 do
		if GetPtrHash(level:GetRoomByIdx(roomIndex, i)) == GetPtrHash(level:GetRoomByIdx(roomIndex, -1)) then
			return i
		end
	end

	return nil
end

--#endregion

--#region default data

---@param saveKey string
---@param saveType DataDuration
---@param data table
---@param noHourglass? boolean
local function addDefaultData(saveKey, saveType, data, noHourglass)
	if not POR.SaveCompiler.Utility.IsDefaultSaveKey(saveKey) then
		return
	end
	local keyToType = {
		[POR.SaveCompiler.DefaultSaveKeys.PLAYER] = EntityType.ENTITY_PLAYER,
		[POR.SaveCompiler.DefaultSaveKeys.FAMILIAR] = EntityType.ENTITY_FAMILIAR,
		[POR.SaveCompiler.DefaultSaveKeys.PICKUP] = EntityType.ENTITY_PICKUP,
		[POR.SaveCompiler.DefaultSaveKeys.SLOT] = EntityType.ENTITY_SLOT,
		[POR.SaveCompiler.DefaultSaveKeys.BOMB] = EntityType.ENTITY_BOMB
	}
	if saveKey ~= POR.SaveCompiler.DefaultSaveKeys.GLOBAL
		and not POR.SaveCompiler.Utility.IsDataTypeAllowed(keyToType[saveKey], saveType)
	then
		return
	end

	local gameFile = noHourglass and POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup or POR.SaveCompiler.DEFAULT_SAVE.game
	local dataTable = gameFile[saveType]

	---@cast saveKey string
	if dataTable[saveKey] == nil then
		dataTable[saveKey] = {}
	end
	dataTable = dataTable[saveKey]

	POR.SaveCompiler.Utility.PatchSaveFile(dataTable, data)
	POR.SaveCompiler.Utility.DebugLog(saveKey, saveType)
end

---Adds data that will be automatically added when the run data is first initialized. Lasts for the duration of the entire run
---@param dataType DefaultSaveKeys @Only available to players and familiars
---@param data table
---@param noHourglass? boolean @If true, will load data in a separate game save that is not affected by Glowing Hourglass.
function POR.SaveCompiler.Utility.AddDefaultRunData(dataType, data, noHourglass)
	addDefaultData(dataType, "run", data, noHourglass)
end

---Adds data that will be automatically added when the floor data is first initialized. Lasts for the duration of the current floor
---@param dataType DefaultSaveKeys @Only available to players and familiars
---@param data table
---@param noHourglass? boolean @If true, will load data in a separate game save that is not affected by Glowing Hourglass.
function POR.SaveCompiler.Utility.AddDefaultFloorData(dataType, data, noHourglass)
	addDefaultData(dataType, "floor", data, noHourglass)
end

---Deprecated! Please use `AddDefaultTempData` instead. Default data cannot support actual floor-lasting per-room saves
---@deprecated
function POR.SaveCompiler.Utility.AddDefaultRoomData()
	print(("[%s IsaacSaveCompiler] AddDefaultRoomData is deprecated! Please use AddDefaultTempData instead."):format(modReference.Name))
end

---Adds data that will be automatically added when the temp data is first initialized. Lasts for the duration of the current room, being reset once you exit the room
---@param dataType DefaultSaveKeys
---@param data table
---@param noHourglass? boolean @If true, will load data in a separate game save that is not affected by Glowing Hourglass.
function POR.SaveCompiler.Utility.AddDefaultTempData(dataType, data, noHourglass)
	addDefaultData(dataType, "temp", data, noHourglass)
end

--#endregion

--#region core methods

function POR.SaveCompiler.IsLoaded()
	return loadedData
end

---@deprecated
---@param callbackId SaveCallbacks
---@param callback function
function POR.SaveCompiler.AddCallback(callbackId, callback)
	if not modReference then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.NOT_INITIALIZED)
		return
	end

	local key = modReference.__SAVECOMPILER_UNIQUE_KEY
	modReference:AddCallback(key .. callbackId, callback)
end

-- Saves save data to the file.
function POR.SaveCompiler.Save()
	if not POR.SaveCompiler.Utility.IsDataInitialized() then return end

	-- Create backup
	-- pcall deep copies the data to prevent errors from being thrown
	-- errors thrown in unload callback crash isaac

	local success, finalData = pcall(POR.SaveCompiler.Utility.DeepCopy, dataCache)

	if success then
		finalData = POR.SaveCompiler.Utility.PatchSaveFile(finalData, POR.SaveCompiler.DEFAULT_SAVE)
	else
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.COPY_ERROR)
		return
	end

	local success2, backupData = pcall(POR.SaveCompiler.Utility.DeepCopy, hourglassBackup)

	if success2 then
		finalData.hourglassBackup = backupData
	else
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.COPY_ERROR)
		return
	end

	local newFinalData = POR.SaveCompiler.Utility.RunCallback(POR.SaveCompiler.Utility.CustomCallback.PRE_DATA_SAVE, finalData)
	if newFinalData then
		finalData = newFinalData
	end
	if game:GetFrameCount() > 0 then
		finalData.__SAVECOMPILER_LIST_INDEX = currentListIndex
	end

	-- validate data
	local valid, msg = POR.SaveCompiler.Utility.ValidateForJson(finalData)
	if valid == POR.SaveCompiler.Utility.ValidityState.INVALID then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.BAD_DATA)
		POR.SaveCompiler.Utility.SendError(msg)
		return
	elseif valid == POR.SaveCompiler.Utility.ValidityState.VALID_WITH_WARNING then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.BAD_DATA_WARNING)
		POR.SaveCompiler.Utility.SendWarning(msg)
	end

	modReference:SaveData(json.encode(finalData))

	POR.SaveCompiler.Utility.RunCallback(POR.SaveCompiler.Utility.CustomCallback.POST_DATA_SAVE, finalData)
end

-- Restores the game save with the data in the hourglass backup.
function POR.SaveCompiler.QueueHourglassRestore()
	if shouldRestoreOnUse then
		usedHourglass = true
		skipRoomReset = true
		skipFloorReset = true
		POR.SaveCompiler.Utility.DebugLog("Activated glowing hourglass. Data will be reset on new room.")
		Isaac.RunCallback(POR.SaveCompiler.SaveCallbacks.PRE_GLOWING_HOURGLASS_RESET)
	end
end

-- Restores the game save with the data in the hourglass backup.
function POR.SaveCompiler.TryHourglassRestore(slot)
	if usedHourglass then
		local newData = POR.SaveCompiler.Utility.DeepCopy(hourglassBackup[slot])
		dataCache.game = POR.SaveCompiler.Utility.PatchSaveFile(newData, POR.SaveCompiler.DEFAULT_SAVE.game)
		usedHourglass = false
		POR.SaveCompiler.Utility.DebugLog("Restored data from Glowing Hourglass from slot", slot)
		Isaac.RunCallback(POR.SaveCompiler.SaveCallbacks.POST_GLOWING_HOURGLASS_RESET)
	end
end

-- Loads save data from the file, overwriting what is already loaded.
---@param isLuamod? boolean
function POR.SaveCompiler.Load(isLuamod)
	if not modReference then
		POR.SaveCompiler.Utility.SendError(POR.SaveCompiler.Utility.ErrorMessages.NOT_INITIALIZED)
		return
	end

	local saveData = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE)

	if modReference:HasData() then
		local data = json.decode(modReference:LoadData())
		saveData = POR.SaveCompiler.Utility.PatchSaveFile(data, POR.SaveCompiler.DEFAULT_SAVE)
	end

	local newSaveData = POR.SaveCompiler.Utility.RunCallback(POR.SaveCompiler.Utility.CustomCallback.PRE_DATA_LOAD, saveData,
		isLuamod)
	if newSaveData then
		saveData = newSaveData
	end

	if game:GetFrameCount() > 0 then
		currentListIndex = saveData.__SAVECOMPILER_LIST_INDEX or Game():GetLevel():GetCurrentRoomDesc().ListIndex
		saveData.__SAVECOMPILER_LIST_INDEX = nil
	end

	dataCache = saveData
	--Would only fail to exist if you continued a run before creating save data for the first time
	if dataCache.hourglassBackup then
		if not dataCache.hourglassBackup["0"] then
			local hourglass_backup = POR.SaveCompiler.Utility.DeepCopy(dataCache.hourglassBackup)
			hourglassBackup["0"] = hourglass_backup
			hourglassBackup["1"] = hourglass_backup
		else
			hourglassBackup = POR.SaveCompiler.Utility.DeepCopy(dataCache.hourglassBackup)
		end
	else
		hourglassBackup["0"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		hourglassBackup["1"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
	end

	loadedData = true
	inRunButNotLoaded = false

	POR.SaveCompiler.Utility.RunCallback(POR.SaveCompiler.Utility.CustomCallback.POST_DATA_LOAD, saveData, isLuamod)
end

---Gets a unique string as an identifier for the pickup when outside of the room it's present in.
---@param pickup EntityPickup
---@return string, string? @Returns a second string for the ListIndex the pickup index was found in if the Myosotis check is active
function POR.SaveCompiler.Utility.GetPickupIndex(pickup)
	local index = table.concat(
		{ "PICKUP_ROOMDATA",
			mFloor(pickup.Position.X),
			mFloor(pickup.Position.Y),
			pickup.InitSeed },
		"_")
	if myosotisCheck or movingBoxCheck then
		--Trick code to pulling previous floor's data only if initseed matches.
		--Even with dupe initseeds pickups spawning, it'll go through and init data for each one
		POR.SaveCompiler.Utility.DebugLog("Data active for a transferred pickup. Attempting to find data...")
		local targetTable = myosotisCheck and hourglassBackup[lastUsedHourglassSlot].pickupRoom or dataCache.game.movingBox
		local function tryFindPickupData(tableToLoop)
			for backupIndex, _ in pairs(tableToLoop) do
			local initSeed = pickup.InitSeed

				if string.sub(backupIndex, -string.len(tostring(initSeed)), -1) == tostring(initSeed) then
					index = backupIndex
					POR.SaveCompiler.Utility.DebugLog("Stored data found for", POR.SaveCompiler.Utility.GetSaveIndex(pickup) .. ".")
					return true
				end
			end
		end
		if myosotisCheck then
			for listIndexFound, dataTable in pairs(targetTable) do
				local foundPickup = tryFindPickupData(dataTable)
				if foundPickup then
					return index, listIndexFound
				end
			end
		else
			tryFindPickupData(targetTable)
		end
	end
	return index
end

---Gets the pickup's persistent data for the floor to keep track of it outside rooms.
---Also checks if was stored inside the boss or treasure room save data used for the Ascent.
---
---You won't use this yourself as the pickup's persistent data is immediately nulled once the pickup in the room is loaded in. Use `GetFloorSave` instead.
---@param pickup EntityPickup
---@return table?, string
function POR.SaveCompiler.Utility.GetPickupData(pickup)
	local pickupIndex, myosotisIndex = POR.SaveCompiler.Utility.GetPickupIndex(pickup)
	local listIndex = POR.SaveCompiler.Utility.GetListIndex()
	local pickupDataRoot = dataCache.game.pickupRoom[listIndex]
	if myosotisCheck then
		pickupDataRoot = hourglassBackup[lastUsedHourglassSlot].pickupRoom[myosotisIndex]
	elseif movingBoxCheck then
		pickupDataRoot = dataCache.game.movingBox
	end
	local pickupData = pickupDataRoot and pickupDataRoot[pickupIndex]

	if not pickupData and game:GetLevel():IsAscent() then
		POR.SaveCompiler.Utility.DebugLog("Was unable to locate pickup room data. Searching Ascent...")
		local roomType = game:GetRoom():GetType()
		local ascentIndex = POR.SaveCompiler.Utility.GetAscentSaveIndex()
		if not ascentIndex then return pickupData, pickupIndex end
		if roomType == RoomType.ROOM_BOSS then
			pickupData = dataCache.game.bossRoom[ascentIndex] and dataCache.game.bossRoom[ascentIndex][pickupIndex]
		elseif roomType == RoomType.ROOM_TREASURE then
			pickupData = dataCache.game.treasureRoom[ascentIndex] and dataCache.game.treasureRoom[ascentIndex][pickupIndex]
		end
	end
	return pickupData, pickupIndex
end

---When leaving the room, stores floor-persistent pickup data.
---@param pickup EntityPickup
local function storePickupData(pickup)
	local listIndex = POR.SaveCompiler.Utility.GetListIndex()
	local saveIndex = POR.SaveCompiler.Utility.GetSaveIndex(pickup)
	local pickupDataRoot = dataCache.game.room
	local roomPickupData = pickupDataRoot[listIndex] and pickupDataRoot[listIndex][saveIndex]
	if not roomPickupData then
		POR.SaveCompiler.Utility.DebugLog("Failed to find room data for", saveIndex,
			"in ListIndex", listIndex)
		return
	end
	local pickupIndex = POR.SaveCompiler.Utility.GetPickupIndex(pickup)
	if movingBoxCheck then
		dataCache.game.movingBox[pickupIndex] = roomPickupData
		POR.SaveCompiler.Utility.DebugLog("Stored Moving Box pickup data for", pickupIndex)
	else
		local pickupRoomSave = dataCache.game.pickupRoom[listIndex]
		if not pickupRoomSave then
			local newSave = {}
			dataCache.game.pickupRoom[listIndex] = newSave
			pickupRoomSave = newSave
		end
		pickupRoomSave[pickupIndex] = roomPickupData
		POR.SaveCompiler.Utility.DebugLog("Stored pickup data for", pickupIndex)
		dataCache.game.room[listIndex][saveIndex] = nil
	end
end

local bossAscentSaveIndexes = {}

local function tryPopulateAscentData(listIndex, saveIndex)
	local roomType = game:GetRoom():GetType()

	POR.SaveCompiler.Utility.DebugLog("Attempting to locate Ascent save data for", saveIndex)
	local ascentData = roomType == RoomType.ROOM_BOSS and dataCache.game.bossRoom or dataCache.game.treasureRoom
	local ascentIndex = POR.SaveCompiler.Utility.GetAscentSaveIndex()
	if not ascentIndex then return end
	local ascentRoomData = ascentData[ascentIndex]
	if not ascentRoomData then return end
	local ascentSaveData = ascentRoomData[saveIndex]

	if ascentSaveData then
		POR.SaveCompiler.Utility.DebugLog("Found Ascent data for", saveIndex, ". Populating...")
		local saveData = dataCache.game.room[listIndex]
		if not saveData then
			local newData = {}
			dataCache.game.room[listIndex] = newData
			saveData = newData
		end
		saveData[saveIndex] = ascentSaveData
		if roomType == RoomType.ROOM_BOSS then
			dataCache.game.bossRoom[ascentIndex][saveIndex] = nil
			table.insert(bossAscentSaveIndexes, saveIndex)
		elseif roomType == RoomType.ROOM_TREASURE then
			dataCache.game.treasureRoom[ascentIndex][saveIndex] = nil
		end
	else
		POR.SaveCompiler.Utility.DebugLog("Failed to find Ascent data for", ascentIndex, saveIndex)
	end
end

---When re-entering a room, gives back floor-persistent data to valid pickups.
---@param pickup EntityPickup
local function populatePickupData(pickup)
	local pickupData, pickupIndex = POR.SaveCompiler.Utility.GetPickupData(pickup)
	local listIndex = POR.SaveCompiler.Utility.GetListIndex()
	local saveIndex = POR.SaveCompiler.Utility.GetSaveIndex(pickup)

	if dataCache.game.room[listIndex] == nil then
		dataCache.game.room[listIndex] = {}
	end
	if pickupData then
		dataCache.game.room[listIndex][saveIndex] = pickupData
		POR.SaveCompiler.Utility.DebugLog("Successfully populated pickup data of index", saveIndex, "in ListIndex", listIndex)
		if movingBoxCheck then
			dataCache.game.movingBox[pickupIndex] = nil
		elseif dataCache.game.pickupRoom[listIndex] then
			dataCache.game.pickupRoom[listIndex][pickupIndex] = nil
		end
		if game:GetLevel():IsAscent() then
			local roomType = game:GetRoom():GetType()
			local ascentSaveIndex = POR.SaveCompiler.Utility.GetAscentSaveIndex()
			if not ascentSaveIndex then return end
			if roomType == RoomType.ROOM_BOSS and dataCache.game.bossRoom[ascentSaveIndex] then
				dataCache.game.bossRoom[ascentSaveIndex][pickupIndex] = nil
				table.insert(bossAscentSaveIndexes, saveIndex)
			elseif roomType == RoomType.ROOM_TREASURE and dataCache.game.treasureRoom[ascentSaveIndex] then
				dataCache.game.treasureRoom[ascentSaveIndex][pickupIndex] = nil
			end
		end
	else
		local dupedPickup = pickup
		local ptrHash1 = GetPtrHash(dupedPickup)
		dupeTaggedPickups[ptrHash1] = true
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP, dupedPickup.Variant)) do
			local originalPickup = ent:ToPickup() ---@cast originalPickup EntityPickup
			local ptrHash2 = GetPtrHash(originalPickup)

			if originalPickup.FrameCount > 0
				and originalPickup.InitSeed == dupedPickup.InitSeed
				and not dupeTaggedPickups[ptrHash2]
			then
				POR.SaveCompiler.Utility.DebugLog("Identified duplicate InitSeed pickup. Attempting to copy data...")
				dupeTaggedPickups[ptrHash2] = true
				local originalSaveIndex = POR.SaveCompiler.Utility.GetSaveIndex(originalPickup)
				local originalSaveData = dataCache.game.room[listIndex][originalSaveIndex]
				if originalSaveData then
					local result = Isaac.RunCallbackWithParam(POR.SaveCompiler.SaveCallbacks.DUPE_PICKUP_DATA_LOAD, originalPickup.Variant, originalPickup, dupedPickup, originalSaveData)
					if not result then
						POR.SaveCompiler.Utility.DebugLog("Duplicate data copied!")
						dataCache.game.room[listIndex][saveIndex] = POR.SaveCompiler.Utility.DeepCopy(originalSaveData)
					else
						POR.SaveCompiler.Utility.DebugLog("Duplicate data prevented from being copied")
					end
				end
				return
			end
		end
		POR.SaveCompiler.Utility.DebugLog("Failed to find pickup data for index", pickupIndex, "in ListIndex",
			listIndex)
	end
end

local function checkForMyosotis()
	if REPENTOGON then
		myosotisCheck = PlayerManager.AnyoneHasTrinket(TrinketType.TRINKET_MYOSOTIS)
	else
		for _, ent in ipairs(Isaac.FindByType(EntityType.ENTITY_PLAYER)) do
			local player = ent:ToPlayer()
			if player and player:HasTrinket(TrinketType.TRINKET_MYOSOTIS) then
				myosotisCheck = true
				break
			end
		end
	end
end

local function checkForAscentValidRooms()
	allowedAscentRooms = {}
	local rooms = game:GetLevel():GetRooms()

	for listIndex = 0, #rooms - 1 do
		local roomDesc = rooms:Get(listIndex)
		if (roomDesc.Data.Type == RoomType.ROOM_TREASURE
			or roomDesc.Data.Type == RoomType.ROOM_BOSS)
			and POR.SaveCompiler.Utility.GetDimension(roomDesc.SafeGridIndex) == 0
		then
			allowedAscentRooms[tostring(listIndex)] = true
		end
	end
end

local function storeAndPopulateAscent()
	local currentRoomDesc = game:GetLevel():GetCurrentRoomDesc()
	if not game:GetLevel():IsAscent() then
		if currentListIndex ~= game:GetLevel():GetCurrentRoomDesc().ListIndex then
			checkLastIndex = true
		end
		local listIndex = POR.SaveCompiler.Utility.GetListIndex()
		if not allowedAscentRooms[listIndex] then
			POR.SaveCompiler.Utility.DebugLog("Room at index", listIndex, "is not valid for Ascent")
			checkLastIndex = false
			return
		end
		local roomSaveData = dataCache.game.room[listIndex]

		if roomSaveData and roomSaveData.__SAVECOMPILER_ASCENT_ROOM_TYPE then
			local roomType = roomSaveData.__SAVECOMPILER_ASCENT_ROOM_TYPE
			POR.SaveCompiler.Utility.DebugLog("Index", listIndex, "is a Treasure/Boss room. Storing all room data")
			local targetTable = roomType == RoomType.ROOM_TREASURE and dataCache.game.treasureRoom or dataCache.game.bossRoom
			local ascentIndex = POR.SaveCompiler.Utility.GetAscentSaveIndex()
			if not ascentIndex then return end
			if not targetTable[ascentIndex] then
				targetTable[ascentIndex] = {}
			end
			local ascentRoomData = targetTable[ascentIndex]
			if roomSaveData then
				for saveIndex, saveData in pairs(roomSaveData) do
					if not string.find(saveIndex, "__") and not string.find(saveIndex, "PICKUP") then
						ascentRoomData[saveIndex] = saveData
					end
				end
			end
			local pickupSaveData = dataCache.game.pickupRoom[listIndex]
			if pickupSaveData then
				for saveIndex, saveData in pairs(pickupSaveData) do
					ascentRoomData[saveIndex] = saveData
				end
			end
		end
		checkLastIndex = false
	elseif currentRoomDesc.Data.Type == RoomType.ROOM_TREASURE
		or currentRoomDesc.Data.Type == RoomType.ROOM_BOSS
	then
		POR.SaveCompiler.Utility.DebugLog("Treasure/Boss Ascent room detected. Transferring all stored data...")
		local targetTable = currentRoomDesc.Data.Type == RoomType.ROOM_TREASURE and dataCache.game.treasureRoom or dataCache.game.bossRoom
		local ascentIndex = POR.SaveCompiler.Utility.GetAscentSaveIndex()
		if not ascentIndex then return end
		local ascentRoomData = targetTable[ascentIndex]
		if not ascentRoomData then return end
		local listIndex = POR.SaveCompiler.Utility.GetListIndex()
		local roomSaveData = dataCache.game.room[listIndex]
		if not roomSaveData then
			local newData = {}
			dataCache.game.room[listIndex] = newData
			roomSaveData = newData
		end
		if ascentRoomData then
			for saveIndex, saveData in pairs(ascentRoomData) do
				roomSaveData[saveIndex] = saveData
				if currentRoomDesc.Data.Type == RoomType.ROOM_BOSS then
					table.insert(bossAscentSaveIndexes, saveIndex)
				end
			end
			targetTable[ascentIndex] = nil
		else
			POR.SaveCompiler.Utility.DebugLog("Failed to find Ascent data for index", ascentIndex)
		end
	end
end

--#endregion

--#region game start/entity init

local function onGameLoad()
	if game:GetFrameCount() == 0 then
		skipFloorReset = true
	end
	skipRoomReset = true
	POR.SaveCompiler.Load(false)
	loadedData = true
	inRunButNotLoaded = false
	dontSaveModData = false
end

---@param ent? Entity
local function onEntityInit(_, ent)
	local newGame = game:GetFrameCount() == 0 and not ent
	local player = ent and ent:ToPlayer()
	local initLaz = false
	local defaultSaveIndex = POR.SaveCompiler.Utility.GetSaveIndex(ent)
	local altSaveIndex = POR.SaveCompiler.Utility.GetSaveIndex(ent, true)
	local defaultKey = POR.SaveCompiler.Utility.GetDefaultSaveKey(ent)

	if player and isLazB[player:GetPlayerType()] and not newGame and player.FrameCount == 0 then
		local playerType = player:GetPlayerType()
		if not tLazInitPlayer then
			tLazInitPlayer = player
			tLazInitSeeds = {player:GetCollectibleRNG(1):GetSeed(), player:GetCollectibleRNG(2):GetSeed()}
			initLaz = true
		--Uses EntityPlayer directly instead of EntityPtr as .Ref gets nil'd when adding then removing Birthright
		--This data is cleared when one of them dies anyways
		elseif playerType == PlayerType.PLAYER_LAZARUS2_B then
			player:GetData().__SAVECOMPILER_ALIVE_LAZ = tLazInitPlayer
		elseif playerType == PlayerType.PLAYER_LAZARUS_B then
			tLazInitPlayer:GetData().__SAVECOMPILER_ALIVE_LAZ = player
		end
	end
	if player and isLazB[player:GetPlayerType()] then
		POR.SaveCompiler.Utility.DebugLog(player:GetPlayerType(), player:GetCollectibleRNG(1):GetSeed(), player:GetCollectibleRNG(2):GetSeed(), defaultSaveIndex	)
	end

	if player and not initLaz then
		tLazInitPlayer = nil
		tLazInitSeeds = nil
	end
	checkLastIndex = false

	if not loadedData or inRunButNotLoaded then
		POR.SaveCompiler.Utility.DebugLog("Game Init")
		onGameLoad()
	end

	if newGame then
		dataCache.game = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		dataCache.gameNoBackup = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup)
		hourglassBackup["0"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		hourglassBackup["1"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
	end

	-- provide an array of keys to grab the target table from the original
	local function reconstructHistory(original, historyArray, iter)
		iter = iter or 1
		local key = historyArray[iter]
		if not key then
			return original
		end

		for i, v in pairs(original) do
			if i == key then
				if type(v) == "table" then
					return reconstructHistory(v, historyArray, iter + 1)
				end
			end
		end
	end

	-- go through the default save, look for appropriate default keys, and copy those in the same spot in the target save
	local function implementSaveKeys(tab, target, history, saveIndex)
		history = history or {}
		for i, v in pairs(tab) do
			if i == defaultKey then
				local targetTable = reconstructHistory(target, history)
				if targetTable and not targetTable[saveIndex] then
					POR.SaveCompiler.Utility.DebugLog("Attempting default data transfer")
					-- create or patch the target table with the default save
					local newData
					if i == POR.SaveCompiler.DefaultSaveKeys.PICKUP and ent then
						local pickupData = {
							InitSeed = ent.InitSeed,
							RerollSave = POR.SaveCompiler.Utility.PatchSaveFile(
								targetTable.RerollSave and targetTable.RerollSave[saveIndex] or {}, v),
							NoRerollSave = POR.SaveCompiler.Utility.PatchSaveFile(
								targetTable.NoRerollSave and targetTable.NoRerollSave[saveIndex] or {}, v)
						}
						target[saveIndex] = pickupData
						newData = pickupData
					else
						newData = POR.SaveCompiler.Utility.PatchSaveFile(targetTable[saveIndex] or {}, v)
					end
					-- Only creates data if it was filled with default data
					if next(newData) ~= nil then
						targetTable[saveIndex] = newData
						POR.SaveCompiler.Utility.DebugLog("Default data copied for", saveIndex)
					else
						POR.SaveCompiler.Utility.DebugLog("No default data found for", saveIndex)
					end
					targetTable[i] = nil
				else
					POR.SaveCompiler.Utility.DebugLog(
						"Was unable to fetch target table or data is already loaded for",
						saveIndex)
				end
			elseif type(v) == "table" then
				table.insert(history, i)
				implementSaveKeys(v, target, history, saveIndex)
				table.remove(history)
			end
		end
		return target
	end

	local listIndex = POR.SaveCompiler.Utility.GetListIndex()
	local function resetNoRerollData(targetTable, defaultTable, checkIndex)
		if checkIndex and targetTable[listIndex] then
			targetTable = targetTable[listIndex]
		end
		local data = targetTable[defaultSaveIndex]
		if data and ent and data.InitSeed and data.InitSeed ~= ent.InitSeed then
			Isaac.RunCallbackWithParam(POR.SaveCompiler.SaveCallbacks.PRE_PICKUP_INITSEED_MORPH, ent.Variant, ent, data.NoRerollSave)
			if data.InitSeedBackup and ent.InitSeed == data.InitSeedBackup then
				local backupSave = data.NoRerollSaveBackup
				local initSeed = data.InitSeedBackup
				data.NoRerollSaveBackup = POR.SaveCompiler.Utility.DeepCopy(data.NoRerollSave)
				data.InitSeedBackup = data.InitSeed
				data.NoRerollSave = backupSave
				data.InitSeed = initSeed
				POR.SaveCompiler.Utility.DebugLog("Detected flip in", defaultSaveIndex, "! Restored backup NoRerollSave.")
				Isaac.RunCallbackWithParam(POR.SaveCompiler.SaveCallbacks.POST_PICKUP_INITSEED_MORPH, ent.Variant, ent, data.NoRerollSave)
				return
			end
			data.NoRerollSaveBackup = POR.SaveCompiler.Utility.DeepCopy(data.NoRerollSave)
			data.InitSeedBackup = data.InitSeed
			data.NoRerollSave = POR.SaveCompiler.Utility.PatchSaveFile({}, defaultTable)
			data.InitSeed = ent.InitSeed
			POR.SaveCompiler.Utility.DebugLog("Detected init seed change in", defaultSaveIndex,
				"! NoRerollSave has been reset")
			Isaac.RunCallbackWithParam(POR.SaveCompiler.SaveCallbacks.POST_PICKUP_INITSEED_MORPH, ent.Variant, ent, data.NoRerollSave)
		end
	end
	if ent and ent.Type == EntityType.ENTITY_PICKUP then
		local pickup = ent:ToPickup()
		---@cast pickup EntityPickup
		populatePickupData(pickup)
	elseif game:GetLevel():IsAscent()
		and game:GetRoom():IsFirstVisit()
		and (game:GetRoom():GetType() == RoomType.ROOM_BOSS
		or game:GetRoom():GetType() == RoomType.ROOM_TREASURE
	) then
		tryPopulateAscentData(listIndex, defaultSaveIndex)
	end
	if defaultKey then
		implementSaveKeys(POR.SaveCompiler.DEFAULT_SAVE.game, dataCache.game, nil, defaultSaveIndex)
		implementSaveKeys(POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup, dataCache.gameNoBackup, nil, defaultSaveIndex)
	end
	if ent and ent:ToPlayer() and ent:ToPlayer():GetSubPlayer() then
		implementSaveKeys(POR.SaveCompiler.DEFAULT_SAVE.game, dataCache.game, nil, altSaveIndex)
		implementSaveKeys(POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup, dataCache.gameNoBackup, nil, altSaveIndex)
	end
	if ent and ent.Type == EntityType.ENTITY_PICKUP then
		resetNoRerollData(dataCache.game.temp, POR.SaveCompiler.DEFAULT_SAVE.game.temp)
		resetNoRerollData(dataCache.game.room, POR.SaveCompiler.DEFAULT_SAVE.game.room, true)
		resetNoRerollData(dataCache.gameNoBackup.temp, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup.temp)
		resetNoRerollData(dataCache.gameNoBackup.room, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup.room, true)
	end
	if not ent then
		Isaac.RunCallback(POR.SaveCompiler.SaveCallbacks.POST_GLOBAL_DATA_LOAD)
	else
		Isaac.RunCallbackWithParam(POR.SaveCompiler.SaveCallbacks.POST_ENTITY_DATA_LOAD, ent.Type, ent)
	end
end

--#endregion

--#region luamod

local function detectLuamod()
	if not loadedData and inRunButNotLoaded
		and (REPENTOGON and (not dontSaveModData and Isaac.GetFrameCount() > 0 and Console.GetHistory()[2] == "Success!")
			or game:GetFrameCount() > 0)
	then
		if game:GetFrameCount() > 0 then
			currentListIndex = game:GetLevel():GetCurrentRoomDesc().ListIndex
		end
		POR.SaveCompiler.Load(true)
		inRunButNotLoaded = false
		shouldRestoreOnUse = true
	end
end

--#endregion

--#region reset data

--A safety precaution to make sure data for entities that no longer exist are removed from room data.
local function tryRemoveLeftoverData()
	POR.SaveCompiler.Utility.DebugLog("leftover ent data check")
	local availableIndexes = {}
	for _, ent in ipairs(Isaac.GetRoomEntities()) do
		if POR.SaveCompiler.Utility.CanHavePersistentData(ent) then
			availableIndexes[POR.SaveCompiler.Utility.GetSaveIndex(ent)] = true
		end
	end
	local function removeLeftoverData(tab, isRoom)
		if isRoom then
			local listIndex = POR.SaveCompiler.Utility.GetListIndex()
			if tab[listIndex] then
				tab = tab[listIndex]
			else
				return
			end
		end
		for key, _ in pairs(tab) do
			local specialData = string.find(key, "__")
			if key ~= "GLOBAL"
				and not specialData
				and not availableIndexes[key]
				and not string.find(key, "GRID_")
			then
				POR.SaveCompiler.Utility.DebugLog("Leftover", isRoom and "room" or "temp", "data removed for", key)
				tab[key] = nil
			end
		end
	end
	removeLeftoverData(dataCache.game.temp)
	removeLeftoverData(dataCache.gameNoBackup.temp)
	removeLeftoverData(dataCache.game.room, true)
	removeLeftoverData(dataCache.gameNoBackup.room, true)
end

---@param saveType string
local function resetData(saveType)
	if (not skipRoomReset and saveType == "temp") or (not skipFloorReset and (saveType == "room" or saveType == "floor")) then
		local typeToCallback = {
			temp = {POR.SaveCompiler.SaveCallbacks.PRE_TEMP_DATA_RESET, POR.SaveCompiler.SaveCallbacks.POST_TEMP_DATA_RESET},
			room = {POR.SaveCompiler.SaveCallbacks.PRE_ROOM_DATA_RESET, POR.SaveCompiler.SaveCallbacks.POST_ROOM_DATA_RESET},
			floor = {POR.SaveCompiler.SaveCallbacks.PRE_FLOOR_DATA_RESET, POR.SaveCompiler.SaveCallbacks.POST_FLOOR_DATA_RESET}
		}
		Isaac.RunCallback(typeToCallback[saveType][1])
		local transferBossAscentData = {}
		local listIndex = POR.SaveCompiler.Utility.GetListIndex()
		if saveType ~= "temp" and game:GetLevel():IsAscent() then
			--Search for any data that was recently created on init before floor reset to put back into the room save
			for _, index in ipairs(bossAscentSaveIndexes) do
				local listIndexSave = dataCache.game.room[listIndex]
				if listIndexSave and listIndexSave[index] then
					POR.SaveCompiler.Utility.DebugLog("Found boss ascent backup data for", index,
						". Storing data for carry over after reset...")
					transferBossAscentData[index] = listIndexSave[index]
					listIndexSave[index] = nil
				else
					POR.SaveCompiler.Utility.DebugLog("No data found for", saveType, listIndex, index)
				end
			end
			bossAscentSaveIndexes = {}
		end
		if saveType == "temp" and listIndex ~= "509" then
			--room data from goto commands should be removed, as if it were a room save. It is not persistent.
			if dataCache.game.room["509"] then
				dataCache.game.room["509"] = nil
			end
			if dataCache.gameNoBackup.room["509"] then
				dataCache.gameNoBackup.room["509"] = nil
			end
		end
		dataCache.game[saveType] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game[saveType])
		dataCache.gameNoBackup[saveType] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup[saveType])
		if saveType == "floor" then
			dataCache.game.pickupRoom = {}
		end
		for index, data in pairs(transferBossAscentData) do
			if not dataCache.game.room[listIndex] then
				dataCache.game.room[listIndex] = {}
			end
			dataCache.game.room[listIndex][index] = data
			POR.SaveCompiler.Utility.DebugLog("Saved data from reset, index", index)
		end
		POR.SaveCompiler.Utility.DebugLog("reset", saveType, "data")
		shouldRestoreOnUse = true
		Isaac.RunCallback(typeToCallback[saveType][2])
	end
	if saveType == "temp" then
		skipRoomReset = false
	elseif saveType == "floor" or saveType == "room" then
		skipFloorReset = false
	end
end

local saveFileWait = 3

local function preGameExit(_, shouldSave)
	POR.SaveCompiler.Utility.DebugLog("pre game exit")

	if shouldSave then
		for _, pickup in ipairs(Isaac.FindByType(EntityType.ENTITY_PICKUP)) do
			if type(pickup) ~= "number" then
				---@cast pickup EntityPickup
				storePickupData(pickup)
			end
		end
	else
		dataCache.game = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		dataCache.gameNoBackup = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup)
		hourglassBackup["0"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		hourglassBackup["1"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
	end
	POR.SaveCompiler.Save()
	if shouldSave then
		dataCache.game = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		dataCache.gameNoBackup = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.gameNoBackup)
		hourglassBackup["0"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		hourglassBackup["1"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
	end
	inRunButNotLoaded = false
	shouldRestoreOnUse = false
	dontSaveModData = true
	saveFileWait = 0
end

---@param ent Entity
local function postEntityRemove(_, ent)
	if not dataCache.game
		or not POR.SaveCompiler.Utility.CanHavePersistentData(ent)
	then
		return
	end

	--If the game is paused via room transition, or saving pickups that disappear from Moving Box
	if (game:IsPaused() and game:GetRoom():GetFrameCount() == 0) or (ent.Type == EntityType.ENTITY_PICKUP and movingBoxCheck) then
		--Although entities are removed from the previous room and this happens before POST_NEW_ROOM...
		--Some data from the new room is already loaded, such as frame count and listindex.
		if currentListIndex ~= game:GetLevel():GetCurrentRoomDesc().ListIndex then
			checkLastIndex = true
		end
		if ent.Type == EntityType.ENTITY_PICKUP then
			---@cast ent EntityPickup
			storePickupData(ent)
		end
		return
	end
	if dontSaveModData or ent:ToFamiliar() and retainFamiliarSaveOnFlip then return end
	--Clear entity data if it's removed inside the room, such as collecting pickups
	local defaultSaveIndex = POR.SaveCompiler.Utility.GetSaveIndex(ent)
	---@param tab GameSave
	local function removeSaveData(tab, saveIndex)
		for saveType, dataTable in pairs(tab) do
			if saveType == "room" and dataTable[POR.SaveCompiler.Utility.GetListIndex()] then
				removeSaveData(dataTable, saveIndex)
			elseif dataTable[saveIndex] then
				POR.SaveCompiler.Utility.DebugLog("Removed data", saveIndex)
				dataTable[saveIndex] = nil
			end
		end
	end
	removeSaveData(dataCache.game, defaultSaveIndex)
	removeSaveData(dataCache.gameNoBackup, defaultSaveIndex)
	if ent:ToPlayer() and ent:ToPlayer():GetSubPlayer() then
		local altSaveIndex = POR.SaveCompiler.Utility.GetSaveIndex(ent, true)
		removeSaveData(dataCache.game, altSaveIndex)
		removeSaveData(dataCache.gameNoBackup, altSaveIndex)
	end
end

--#endregion

--#region core callbacks

local function postSlotInitNoRGON()
	for _, slot in ipairs(Isaac.FindByType(EntityType.ENTITY_SLOT)) do
		if type(slot) ~= "number" and slot.FrameCount <= 1 then
			onEntityInit(_, slot)
		end
	end
end

local function postNewRoom()
	POR.SaveCompiler.Utility.DebugLog("new room")
	if not REPENTOGON then
		postSlotInitNoRGON()
	end
	local currentRoomDesc = game:GetLevel():GetCurrentRoomDesc()
	storeAndPopulateAscent()
	currentListIndex = currentRoomDesc.ListIndex
	resetData("temp")
	tryRemoveLeftoverData()
	if not POR.SaveCompiler.AutoCreateRoomSaves then return end
	local roomSaveData = POR.SaveCompiler.GetRoomSave(nil, false, currentListIndex)
	--Always keep track of for Curse of the Maze
	roomSaveData.__SAVECOMPILER_SPAWN_SEED = currentRoomDesc.SpawnSeed
	local roomType = currentRoomDesc.Data.Type
	--For knowing what the last room was after travelling down a floor in the same room
	--Doesn't matter if its not boss/treasure
	if roomType == RoomType.ROOM_BOSS or roomType == RoomType.ROOM_TREASURE then
		roomSaveData.__SAVECOMPILER_ROOM_TYPE = currentRoomDesc.Data.Type
	end
	--To know which boss/treasure room is on what floor. Nil if not either room type
	roomSaveData.__SAVECOMPILER_ASCENT_INDEX = POR.SaveCompiler.Utility.GetAscentSaveIndex()
end

local function postNewLevel()
	POR.SaveCompiler.Utility.DebugLog("new level")
	resetData("room")
	resetData("floor")
	checkForMyosotis()
	checkForAscentValidRooms()
	POR.SaveCompiler.Save()
end

local function postUpdate()
	--Shockingly, this triggers for one frame when doing a room transition
	if not REPENTOGON and game:IsPaused() then
		if usedHourglass then
			POR.SaveCompiler.TryHourglassRestore("0")
		else
			hourglassBackup["0"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
			hourglassBackup["1"] = POR.SaveCompiler.Utility.PatchSaveFile({}, POR.SaveCompiler.DEFAULT_SAVE.game)
		end
	end
	myosotisCheck = false
	movingBoxCheck = false
	dupeTaggedPickups = {}
end

---With REPENTOGON, allows you to load data whenever you select a save slot.
---@param isSlotSelected boolean
local function postSaveSlotLoad(_, _, isSlotSelected, _)
	if not isSlotSelected then
		return
	end
	if saveFileWait < 3 then
		saveFileWait = saveFileWait + 1
	else
		POR.SaveCompiler.Load(false)
	end
end

--#endregion

--#region init logic

-- Initializes the save manager.
---@param mod table @The reference to your mod. This is the table that is returned when you call `RegisterMod`.
function POR.SaveCompiler.Init(mod)
	modReference = mod

	-- Priority callbacks put in place to load data early and save data late.

	--Global data
	modReference:AddPriorityCallback(ModCallbacks.MC_POST_PLAYER_INIT, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT,
		function(_, player)
			if GetPtrHash(player) == GetPtrHash(Isaac.GetPlayer()) then
				inRunButNotLoaded = true
			end
			onEntityInit()
		end
	)

	local initCallbacks = {
		ModCallbacks.MC_POST_PLAYER_INIT,
		ModCallbacks.MC_FAMILIAR_INIT,
		ModCallbacks.MC_POST_PICKUP_INIT,
		ModCallbacks.MC_POST_BOMB_INIT,
		ModCallbacks.MC_POST_NPC_INIT,
	}

	for _, initCallback in ipairs(initCallbacks) do
		modReference:AddPriorityCallback(initCallback, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT, onEntityInit)
	end

	modReference:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE, POR.SaveCompiler.Utility.CallbackPriority.EARLY, postUpdate)

	if REPENTOGON then
		modReference:AddPriorityCallback(ModCallbacks.MC_POST_SLOT_INIT, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT,
			onEntityInit)
		modReference:AddPriorityCallback(ModCallbacks.MC_POST_SAVESLOT_LOAD,
			POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT, postSaveSlotLoad)
		modReference:AddPriorityCallback(ModCallbacks.MC_MENU_INPUT_ACTION,
			POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT, function()
				local success, currentMenu = pcall(MenuManager.GetActiveMenu)
				if not success then return end
				dontSaveModData = currentMenu == MainMenuType.TITLE or
					currentMenu == MainMenuType.MODS
				detectLuamod()
			end)
		modReference:AddCallback(ModCallbacks.MC_POST_GLOWING_HOURGLASS_SAVE, function(_, slot)
			hourglassBackup[tostring(slot)] = POR.SaveCompiler.Utility.DeepCopy(dataCache.game)
			POR.SaveCompiler.Utility.DebugLog("Saved hourglass data to slot", slot)
			lastUsedHourglassSlot = tostring(slot)
		end)
		modReference:AddCallback(ModCallbacks.MC_PRE_GLOWING_HOURGLASS_LOAD, function(_, slot)
			POR.SaveCompiler.QueueHourglassRestore()
			POR.SaveCompiler.TryHourglassRestore(tostring(slot))
		end)
	else
		modReference:AddPriorityCallback(ModCallbacks.MC_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
			POR.SaveCompiler.QueueHourglassRestore,
			CollectibleType.COLLECTIBLE_GLOWING_HOUR_GLASS
		)
		modReference:AddPriorityCallback(ModCallbacks.MC_POST_UPDATE, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT,
			postSlotInitNoRGON)
	end

	if REPENTOGON then
		local function tryDetectLuamod()
			dontSaveModData = false
			detectLuamod()
			if loadedData then
				Isaac.RemoveCallback(modReference, ModCallbacks.MC_INPUT_ACTION, tryDetectLuamod)
			end
		end
		--load luamod as early as possible.
		modReference:AddPriorityCallback(ModCallbacks.MC_INPUT_ACTION, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT,
			tryDetectLuamod)
	else
		local deathCallbacks = {
			ModCallbacks.MC_POST_NPC_RENDER,
			ModCallbacks.MC_POST_EFFECT_RENDER,
			ModCallbacks.MC_POST_PICKUP_RENDER,
			ModCallbacks.MC_POST_PLAYER_RENDER
		}
		local function pleaseEndMe()
			dontSaveModData = false
			detectLuamod()
			if loadedData then
				for _, deathCallback in ipairs(deathCallbacks) do
					Isaac.RemoveCallback(modReference, deathCallback, pleaseEndMe)
				end
			end
		end
		for _, deathCallback in ipairs(deathCallbacks) do
			modReference:AddPriorityCallback(deathCallback, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT,	pleaseEndMe)
		end
	end

	modReference:AddPriorityCallback(ModCallbacks.MC_POST_NEW_ROOM, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
		postNewRoom)
	modReference:AddPriorityCallback(ModCallbacks.MC_POST_NEW_LEVEL, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
		postNewLevel)
	modReference:AddPriorityCallback(ModCallbacks.MC_PRE_GAME_EXIT, POR.SaveCompiler.Utility.CallbackPriority.LATE,
		preGameExit)
	modReference:AddPriorityCallback(ModCallbacks.MC_POST_ENTITY_REMOVE, POR.SaveCompiler.Utility.CallbackPriority.LATE,
		postEntityRemove)
	modReference:AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.LATE,
		function()
			movingBoxCheck = true
		end,
		CollectibleType.COLLECTIBLE_MOVING_BOX
	)

	modReference:AddPriorityCallback(ModCallbacks.MC_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
		function()
			movingBoxCheck = false
		end,
		CollectibleType.COLLECTIBLE_MOVING_BOX
	)

	modReference:AddPriorityCallback(ModCallbacks.MC_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.LATE,
		function()
			POR.SaveCompiler.Save()
		end,
		CollectibleType.COLLECTIBLE_GENESIS
	)

	modReference:AddPriorityCallback(ModCallbacks.MC_PRE_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.LATE,
		function (_, _, _, player)
			if isLazB[player:GetPlayerType()] then
				retainFamiliarSaveOnFlip = true
			end
		end,
		CollectibleType.COLLECTIBLE_FLIP
	)

	modReference:AddPriorityCallback(ModCallbacks.MC_USE_ITEM, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
		function (_, _, _, player)
			if isLazB[player:GetPlayerType()] then
				retainFamiliarSaveOnFlip = false
			end
		end,
		CollectibleType.COLLECTIBLE_FLIP
	)

	-- used to detect if an unloaded mod is this mod for when saving for luamod and for unique per-mod callbacks
	modReference.__SAVECOMPILER_UNIQUE_KEY = ("%s-%s"):format(Random(), Random())

	for name, value in pairs(POR.SaveCompiler.SaveCallbacks) do
		POR.SaveCompiler.SaveCallbacks[name] = modReference.__SAVECOMPILER_UNIQUE_KEY .. value
	end

	modReference:AddPriorityCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, POR.SaveCompiler.Utility.CallbackPriority.EARLY,
		function(_, modToUnload)
			if modToUnload.__SAVECOMPILER_UNIQUE_KEY and modToUnload.__SAVECOMPILER_UNIQUE_KEY == modReference.__SAVECOMPILER_UNIQUE_KEY
				and loadedData
				and not dontSaveModData
			then
				saveFileWait = 0
				POR.SaveCompiler.Save()
			end
		end
	)
end

--#endregion

--#region MinimapAI integration

-- Registers MinimapAPI as a dependent of POR.SaveCompiler.
---@param minimapAPI table @Reference to MinimapAPI.
---@param branchVersion table @The version of the branch you are using for MinimapAPI.
function POR.SaveCompiler.InitMinimapAPI(minimapAPI, branchVersion)
	if not POR.SaveCompiler.Utility.IsDataInitialized() then return end
	if minimapAPI.BranchVersion == branchVersion then
		minimapAPI.DisableSaving = true
		minimapAPIReference = minimapAPI
		modReference:AddPriorityCallback(ModCallbacks.MC_POST_GAME_STARTED, POR.SaveCompiler.Utility.CallbackPriority.IMPORTANT, function(_, isContinue)
			if modReference:HasData() and MinimapAPI.BranchVersion == branchVersion then
				MinimapAPI:LoadSaveTable(POR.SaveCompiler.GetMinimapAPISave(), isContinue)
			end
		end)
		modReference:AddPriorityCallback(ModCallbacks.MC_PRE_GAME_EXIT, POR.SaveCompiler.Utility.CallbackPriority.LATE - 1, function(_, shouldSave)
			if minimapAPIReference then
				dataCache.file.minimapAPI = minimapAPIReference:GetSaveTable(shouldSave)
			end
		end)
	end
end

--#endregion

--#region save methods

-- Returns the entire save table, including the file save.
function POR.SaveCompiler.GetEntireSave()
	return dataCache
end

---@param ent? Entity | integer
---@param noHourglass false|boolean?
---@param initDataIfNotPresent? boolean
---@param saveType DataDuration
---@param listIndex? integer
---@param allowSoulSave? boolean
---@return table
local function getRespectiveSave(ent, noHourglass, initDataIfNotPresent, saveType, listIndex, allowSoulSave)
	if not POR.SaveCompiler.Utility.IsDataInitialized(not initDataIfNotPresent)
		---@diagnostic disable-next-line: undefined-field
		or (ent and type(ent) == "userdata" and not POR.SaveCompiler.Utility.IsDataTypeAllowed(ent.Type, saveType))
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
	local numberListIndex = listIndex or tonumber(POR.SaveCompiler.Utility.GetListIndex())
	local stringListIndex = tostring(numberListIndex)
	if saveType == "room" then
		if not saveTable[stringListIndex] then
			POR.SaveCompiler.Utility.DebugLog("Created index", stringListIndex)
			saveTable[stringListIndex] = {}
		end
		saveTable = saveTable[stringListIndex]
	end
	local saveIndex = POR.SaveCompiler.Utility.GetSaveIndex(ent, getAltSave)
	local data = saveTable[saveIndex]

	if data == nil and initDataIfNotPresent then
		local gameSave = noHourglass and "gameNoBackup" or "game"
		local defaultKey = POR.SaveCompiler.Utility.GetDefaultSaveKey(ent)
		local defaultSave = POR.SaveCompiler.DEFAULT_SAVE[gameSave][saveType][defaultKey] or {}
		if ent and type(ent) ~= "number" and ent.Type == EntityType.ENTITY_PICKUP then
			local pickupData = {
				InitSeed = ent.InitSeed,
				RerollSave = POR.SaveCompiler.Utility.PatchSaveFile({}, defaultSave),
				NoRerollSave = POR.SaveCompiler.Utility.PatchSaveFile({}, defaultSave)
			}
			saveTable[saveIndex] = pickupData
		else
			saveTable[saveIndex] = POR.SaveCompiler.Utility.PatchSaveFile({}, defaultSave)
		end
		POR.SaveCompiler.Utility.DebugLog("Created new", saveType, "data for", saveIndex)
	end
	data = saveTable[saveIndex]

	return data
end

---Returns a save that lasts the duration of the entire run. Exclusive to players and familiars.
---@param ent? Entity @If an entity is provided, returns an entity specific save within the run save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetRunSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, true, "run", nil, allowSoulSave)
end

---Attempts to return a save that lasts the duration of the entire run. Exclusive to players and familiars.
---@param ent? Entity @If an entity is provided, returns an entity specific save within the run save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table? @Can return nil if data has not been loaded, the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetRunSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, false, "run", nil, allowSoulSave)
end

---Returns a save that lasts the duration of the current floor. Exclusive to players and familiars.
---@param ent? Entity  @If an entity is provided, returns an entity specific save within the floor save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetFloorSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, true, "floor", nil, allowSoulSave)
end

---Attempts to return a save that lasts the duration of the current floor. Exclusive to players and familiars.
---@param ent? Entity  @If an entity is provided, returns an entity specific save within the floor save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetFloorSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, false, "floor", nil, allowSoulSave)
end

---Returns a save that lasts the duration of the current floor, but data is separated per-room.
---**NOTE:** If your data is a pickup, use POR.SaveCompiler.GetRerollPickupSave/NoRerollPickupSave instead
---@param ent? Entity | integer @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param listIndex? integer @Returns data for the provided `listIndex` instead of the index of the current room.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetRoomSave(ent, noHourglass, listIndex, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, true, "room", listIndex, allowSoulSave)
end

---Attempts to return a save that lasts the duration of the current floor, but data is separated per-room.
---**NOTE:** If your data is a pickup, use POR.SaveCompiler.TryGetRerollPickupSave/TryGetNoRerollPickupSave instead
---@param ent? Entity | integer @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param listIndex? integer @Returns data for the provided `listIndex` instead of the index of the current room.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetRoomSave(ent, noHourglass, listIndex, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, false, "room", listIndex, allowSoulSave)
end

---Returns a save that lasts the duration of the current room, being reset once you exit the room.
---@param ent? Entity | integer  @If an entity is provided, returns an entity specific save within the room save. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetTempSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, true, "temp", nil, allowSoulSave)
end

---Attempts to return a save that lasts the duration of the current room, being reset once you exit the room.
---@param ent? Entity | integer  @If an entity is provided, returns an entity specific save within the room save. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetTempSave(ent, noHourglass, allowSoulSave)
	return getRespectiveSave(ent, noHourglass, false, "temp", nil, allowSoulSave)
end

---Returns a save for pickups that persists rerolls, such as through D20 or D6.
---@param pickup? EntityPickup @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetRerollPickupSave(pickup, noHourglass)
	return POR.SaveCompiler.GetRoomSave(pickup, noHourglass).RerollSave
end

---Attempts to return a save for pickups that persists rerolls, such as through D20 or D6.
---@param pickup? EntityPickup @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetRerollPickupSave(pickup, noHourglass)
	local pickup_save = POR.SaveCompiler.TryGetRoomSave(pickup, noHourglass)
	if pickup_save then
		return pickup_save.RerollSave
	end
end

---Returns a save for pickups that does not persist through rerolls, such as through D20 or D6.
---@param pickup? EntityPickup @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@return table @Can return nil if data has not been loaded, or the manager has not been initialized. Will create data if none exists.
function POR.SaveCompiler.GetNoRerollPickupSave(pickup, noHourglass)
	return POR.SaveCompiler.GetRoomSave(pickup, noHourglass).NoRerollSave
end

---Attempts to return a save for pickups that does not persist through rerolls, such as through D20 or D6.
---@param pickup? EntityPickup @If an entity is provided, returns an entity specific save within the room save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass? false|boolean @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized, or if no data already existed.
function POR.SaveCompiler.TryGetNoRerollPickupSave(pickup, noHourglass)
	local pickup_save = POR.SaveCompiler.TryGetRoomSave(pickup, noHourglass)
	if pickup_save then
		return pickup_save.NoRerollSave
	end
end

---Returns uniquely-saved data for pickups when outside of the room they're stored in. Indexed by ListIndex
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetOutOfRoomPickupSave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.game.pickupRoom
	end
end

---Please note that this is essentially a normal table with the connotation of being used with UnlockAPI.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetUnlockAPISave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.file.unlockApi
	end
end

---Please note that this is essentially a normal table with the connotation of being used with Dead Sea Scrolls (DSS).
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetDeadSeaScrollsSave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.file.deadSeaScrolls
 	end
end

---This will automatically be filled with save data handled by MinimapAPI
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetMinimapAPISave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.file.minimapAPI
	end
end

---Please note that this is essentially a normal table with the connotation of being used to store settings.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetSettingsSave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.file.settings
	end
end

---Gets the "type" save data within the file save. Basically just a table you can put anything it.
---@return table? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetPersistentSave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return dataCache.file.other
	end
end

---Returns the save table used for Glowing Hourglass backups. It holds two copies, indexed by 0 and 1 for the different hourglass slots provided by the REPENTOGON callbacks.
---
---If not using REPENTOGON, will only ever populate slot 0 instead
---@return {["0"]: table, ["1"]: table}? @Can return nil if data has not been loaded, or the manager has not been initialized.
function POR.SaveCompiler.GetGlowingHourglassSave()
	if POR.SaveCompiler.Utility.IsDataInitialized() then
		return hourglassBackup
	end
end

--#endregion

--#region Menu Provider for DSS

local MenuProvider = {}

-- The below functions are all required
---@function
function MenuProvider.SaveSaveData()
	POR.SaveCompiler.Save()
end

---@function
function MenuProvider.GetPaletteSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenuPalette or nil
end

---@function
function MenuProvider.SavePaletteSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenuPalette = var
end

---@function
function MenuProvider.GetHudOffsetSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	if not REPENTANCE and dssSave then
		return dssSave.HudOffset
	else
		return Options.HUDOffset * 10
	end
end

---@function
function MenuProvider.SaveHudOffsetSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	if not REPENTANCE then
		dssSave.HudOffset = var
	end
end

---@function
function MenuProvider.GetGamepadToggleSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenuControllerToggle or nil
end

---@function
function MenuProvider.SaveGamepadToggleSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenuControllerToggle = var
end

---@function
function MenuProvider.GetMenuKeybindSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenuKeybind or nil
end

---@function
function MenuProvider.SaveMenuKeybindSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenuKeybind = var
end

---@function
function MenuProvider.GetMenuHintSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenuHint or nil
end

---@function
function MenuProvider.SaveMenuHintSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenuHint = var
end

---@function
function MenuProvider.GetMenuBuzzerSetting()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenuBuzzer or nil
end

---@function
function MenuProvider.SaveMenuBuzzerSetting(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenuBuzzer = var
end

---@function
function MenuProvider.GetMenusNotified()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenusNotified or nil
end

---@function
function MenuProvider.SaveMenusNotified(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenusNotified = var
end

---@function
function MenuProvider.GetMenusPoppedUp()
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	return dssSave and dssSave.MenusPoppedUp or nil
end

---@function
function MenuProvider.SaveMenusPoppedUp(var)
	local dssSave = POR.SaveCompiler.GetDeadSeaScrollsSave()
	dssSave.MenusPoppedUp = var
end

POR.SaveCompiler.MenuProvider = MenuProvider

--#endregion

return POR.SaveCompiler
