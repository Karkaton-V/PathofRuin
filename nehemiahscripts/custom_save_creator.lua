
-- ===========================================
-- Re-Scrapped Epiphany Utility Saving functions ---------
-- ===========================================

--#region save functions

---@param player EntityPlayer
---@return string
---@function
function POR:GetPlayerString(player)
	return POR.SaveCompiler.Utility.GetSaveIndex(player)
end

---Returns complete save data
---@return table
---@function
function POR:GameSave()
	return POR.SaveCompiler.GetPersistentSave() ---@type table
end

---@param ent? Entity @If an entity is provided, returns an entity specific save within the run save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass false|boolean? @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table
---@function
function POR:RunSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetRunSave(ent, noHourglass, allowSoulSave)
end

---@param ent? Entity  @If an entity is provided, returns an entity specific save within the floor save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass false|boolean? @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table
---@function
function POR:FloorSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetFloorSave(ent, noHourglass, allowSoulSave)
end

---@param ent? Entity | integer @If an entity is provided, returns an entity specific save within the roomFloor save, which is a floor-lasting save that has unique data per-room. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass false|boolean? @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param listIndex? integer @Returns data for the provided `listIndex` instead of the index of the current room.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table
---@function
function POR:RoomSave(ent, noHourglass, listIndex, allowSoulSave)
	return POR.SaveCompiler.GetRoomSave(ent, noHourglass, listIndex, allowSoulSave)
end

---@param ent? Entity | integer  @If an entity is provided, returns an entity specific save within the room save. If a grid index is provided, returns a grid index specific save. Otherwise, returns arbitrary data in the save not attached to an entity.
---@param noHourglass false|boolean? @If true, it'll look in a separate game save that is not affected by the Glowing Hourglass.
---@param allowSoulSave? boolean @If true, if the `ent` is The Soul attached to The Forgotten, will return a differently indexed save, as opposed to a shared save between the two.
---@return table
---@function
function POR:TempSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetTempSave(ent, noHourglass, allowSoulSave)
end

--#endregion

-- ===========================================
-- Re-Scrapped Epiphany Pickup Utility Saving functions --
-- ===========================================

--- Gets given pickup's persistent data table or creates an empty one if it doesn't exist.
--- Use this if you intend to add persistent data to a pickup.
---@param pickup EntityPickup
---@return table
---@function
function POR:GetPickupData(pickup)
	return POR.SaveCompiler.GetNoRerollPickupSave(pickup)
end

--- Gets given pickup's persistent data table.
--- Unlike GetPickupData, this function may return nil,
--- and doesn't create a persistent table.
--- Use this if you intend to read, but not add any persistent data.
---@param pickup EntityPickup
---@return table|nil
---@function
function POR:TryGetPickupData(pickup)
	return POR.SaveCompiler.TryGetNoRerollPickupSave(pickup)
end

---Gets given pickup's reroll persistent data table or creates an empty one if it doesn't exist.
---@param pickup EntityPickup
---@return table
function POR:GetRerollPersistentData(pickup)
	return POR.SaveCompiler.GetRerollPickupSave(pickup)
end

--- Gets given pickup's reroll persistent data table.
--- Unlike GetRerollPersistentData, this function may return nil,
--- and doesn't create a persistent table.
--- Use this if you intend to read, but not add any persistent data.
---@param pickup EntityPickup
---@return table?
function POR:TryGetRerollPersistentData(pickup)
	return POR.SaveCompiler.TryGetRerollPickupSave(pickup)
end

-- ===========================================
-- Cache functions ---------------------------
-- ===========================================

---@function
function POR:SetCacheNextFloor(cacheFlags)
	local run_save = POR:RunSave()
	if not run_save.CacheFlagsFloor then
		run_save.CacheFlagsFloor = 0
	end

	run_save.CacheFlagsFloor = run_save.CacheFlagsFloor | cacheFlags
end

-- ===========================================
-- Callback functions ------------------------
-- ===========================================

-- Cache Flag trigger on New floor
POR:AddPriorityCallback(ModCallbacks.MC_POST_NEW_LEVEL, CallbackPriority.LATE, function()
	local run_save = POR:RunSave()
    if run_save == nil then return end
	if not run_save.CacheFlagsFloor then
		return
	end
	local cacheFlags = run_save.CacheFlagsFloor
	local num_players = POR.Game:GetNumPlayers()
	for i = 0, (num_players - 1) do
		local player = Isaac.GetPlayer(i)
		player:AddCacheFlags(cacheFlags)
		player:EvaluateItems()
	end
	run_save.CacheFlagsFloor = nil
end)

-- ===========================================
-- Legacy functions ------------------------
-- ===========================================
-- For backwards compatibility

POR.PersistentDataHelper = {}
local pData = POR.PersistentDataHelper

--- Gets given pickup's persistent data table or creates an empty one if it doesn't exist.
--- Use this if you intend to add persistent data to a pickup.
---@param pickup EntityPickup
---@return table
---@function
---@scope POR.PersistentDataHelper
function pData:GetPickupData(pickup)
	local msg = "POR.PersistentDataHelper was used. This is a legacy function. Use POR:GetPickupData(pickup) instead!\n"
	POR:Log(msg)
	return POR:GetPickupData(pickup)
end
