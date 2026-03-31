local game = POR.game
local scrum_master_schedule = {}
scrum_master_schedule.ScheduleData = {}
---
---@param delay integer
---@param func function
---@param args any
---@function
---@scope POR_ScrumMaster
function scrum_master_schedule.Schedule(delay, func, args)
	table.insert(scrum_master_schedule.ScheduleData, {
		Time = game:GetFrameCount(),
		Delay = delay,
		Call = func,
		Args = args or {},
	})
end

---Like `Schedule`, but scheduled function gets cancelled if the player moves to a different room.
---@param delay integer
---@param func function
---@param args any
---@function
---@scope POR_ScrumMaster
function scrum_master_schedule.ScheduleForRoom(delay, func, args)
	table.insert(scrum_master_schedule.ScheduleData, {
		Time = game:GetFrameCount(),
		Delay = delay,
		Call = func,
		Args = args or {},
		PerRoom = true,
	})
end

POR:AddCallback(ModCallbacks.MC_POST_UPDATE, function()
	local time = game:GetFrameCount()
	for i = #scrum_master_schedule.ScheduleData, 1, -1 do
		local data = scrum_master_schedule.ScheduleData[i]
		if data.Time + data.Delay <= time then
			table.remove(scrum_master_schedule.ScheduleData, i)
			data.Call(table.unpack(data.Args))
		end
	end
end)

POR:AddCallback(ModCallbacks.MC_POST_NEW_ROOM, function ()
	for i = #scrum_master_schedule.ScheduleData, 1, -1 do
		local data = scrum_master_schedule.ScheduleData[i]
		if data.PerRoom then
			table.remove(scrum_master_schedule.ScheduleData, i)
		end
	end
end)

POR:AddCallback(ModCallbacks.MC_PRE_GAME_EXIT, function()
	scrum_master_schedule.ScheduleData = {}
end)

return scrum_master_schedule
