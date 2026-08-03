
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

---@param ent? Entity @Entity-specific save, or run-wide data if omitted
---@param noHourglass false|boolean? @Use the save unaffected by Glowing Hourglass
---@param allowSoulSave? boolean @Give The Soul its own save instead of sharing with The Forgotten
---@return table
---@function
function POR:RunSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetRunSave(ent, noHourglass, allowSoulSave)
end

---@param ent? Entity @Entity-specific save, or floor-wide data if omitted
---@param noHourglass false|boolean? @Use the save unaffected by Glowing Hourglass
---@param allowSoulSave? boolean @Give The Soul its own save instead of sharing with The Forgotten
---@return table
---@function
function POR:FloorSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetFloorSave(ent, noHourglass, allowSoulSave)
end

---@param ent? Entity | integer @Entity or grid-index specific save within this floor's per-room data
---@param noHourglass false|boolean? @Use the save unaffected by Glowing Hourglass
---@param listIndex? integer @Use this room's index instead of the current one
---@param allowSoulSave? boolean @Give The Soul its own save instead of sharing with The Forgotten
---@return table
---@function
function POR:RoomSave(ent, noHourglass, listIndex, allowSoulSave)
	return POR.SaveCompiler.GetRoomSave(ent, noHourglass, listIndex, allowSoulSave)
end

---@param ent? Entity | integer @Entity or grid-index specific save within the current room
---@param noHourglass false|boolean? @Use the save unaffected by Glowing Hourglass
---@param allowSoulSave? boolean @Give The Soul its own save instead of sharing with The Forgotten
---@return table
---@function
function POR:TempSave(ent, noHourglass, allowSoulSave)
	return POR.SaveCompiler.GetTempSave(ent, noHourglass, allowSoulSave)
end

--#endregion

-- ===========================================
-- Re-Scrapped Epiphany Pickup Utility Saving functions --
-- ===========================================

--- Gets (or creates) a pickup's persistent data table.
---@param pickup EntityPickup
---@return table
---@function
function POR:GetPickupData(pickup)
	return POR.SaveCompiler.GetNoRerollPickupSave(pickup)
end

--- Like GetPickupData, but read-only: returns nil instead of creating a table.
---@param pickup EntityPickup
---@return table|nil
---@function
function POR:TryGetPickupData(pickup)
	return POR.SaveCompiler.TryGetNoRerollPickupSave(pickup)
end

--- Gets (or creates) a pickup's reroll-persistent data table.
---@param pickup EntityPickup
---@return table
function POR:GetRerollPersistentData(pickup)
	return POR.SaveCompiler.GetRerollPickupSave(pickup)
end

--- Like GetRerollPersistentData, but read-only: returns nil instead of creating a table.
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

--- Gets (or creates) a pickup's persistent data table.
---@param pickup EntityPickup
---@return table
---@function
---@scope POR.PersistentDataHelper
function pData:GetPickupData(pickup)
	local msg = "POR.PersistentDataHelper was used. This is a legacy function. Use POR:GetPickupData(pickup) instead!\n"
	POR:Log(msg)
	return POR:GetPickupData(pickup)
end
