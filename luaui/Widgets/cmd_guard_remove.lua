
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Guard Remove",
		desc      = "Removes non-terminating orders (guard/patrol) on builders when more commands are given with shift",
		author    = "Google Frog, Born2Crawl (adapted for BAR)",
		date      = "13 July 2017",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

include("keysym.h.lua")

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCommands = Spring.GetUnitCommands

local CMD_GUARD = CMD.GUARD
local CMD_PATROL = CMD.PATROL

local removableCommand = {
	[CMD_GUARD] = true,
	[CMD_PATROL] = true,
}

-- performance safeguard, when certain commands are spammed, like reclaim, `UnitCommand` can cause
-- extreme performance issues by parsing all of those commands. So we track units that have recieved
-- commands in the last 5 frames and skip any that are touched
local recentUnits = {}
local updateTime = 0

local validUnit = {}
for udid, ud in pairs(UnitDefs) do
	validUnit[udid] = ud.isBuilder and ud.canRepair and not ud.isFactory
end

function widget:UnitCommand(unitID, unitDefID, _, _, _, cmdOpts, _, _, _, _)

	if not cmdOpts.shift then
		return false
	end

	if recentUnits[unitID] then
		return false
	end

	if validUnit[unitDefID] then
		recentUnits[unitID] = spGetGameFrame()
		local cmd = spGetUnitCommands(unitID, 2)
		if cmd then
			for c = 1, #cmd do
				if removableCommand[cmd[c].id] then
					Spring.GiveOrderToUnit(unitID, CMD.REMOVE, {cmd[c].tag}, 0)
				end
			end
		end
	end

	return false
end

function widget:Update(dt)
	updateTime = updateTime + dt
	if updateTime < 0.25 then
		return
	end

	-- Clear all recent units that are outside of the time window
	for i, t in pairs(recentUnits) do
		if t < spGetGameFrame() - 5 then
			recentUnits[i] = nil;
		end
	end

	updateTime = 0
end
