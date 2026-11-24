local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Stop means Stop",
		desc = "Cancels Self D orders when unit is given a stop command",
		author = "enotseulB",
		date = "GPL v3 or later",
		license = "Feb 2015",
		layer = 0,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetMyTeamID = Spring.GetLocalTeamID

local CMD_STOP = CMD.STOP
local myTeamID = spGetMyTeamID()

function widget:PlayerChanged(playerID)
	myTeamID = spGetMyTeamID()
end

function widget:Initialize()
	widgetHandler:RegisterUnitCommand(CMD_STOP)
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, playerID, fromSynced, fromLua)
	if cmdID ~= CMD_STOP then
		return
	end
	if not unitID then
		return
	end
	if teamID ~= myTeamID then
		return
	end

	-- nil when not counting down (engine 2026.09+) or when the unit is gone
	if (Spring.GetUnitSelfDTime(unitID) or 0) > 0 then
		Spring.GiveOrderToUnit(unitID, CMD.SELFD, {}, 0)
	end
end
