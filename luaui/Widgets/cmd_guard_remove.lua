
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

-- Minimum time between checks per-builder. Increase to improve performance.
local safeguardDuration = 0.1 ---@type number in seconds

include("keysym.h.lua")

local spGetUnitCommands = Spring.GetUnitCommands
local spGetCmdDescIndex = Spring.GetCmdDescIndex
local spGetActiveCmdDesc = Spring.GetActiveCmdDesc
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE
local CMD_GUARD = CMD.GUARD
local CMD_PATROL = CMD.PATROL

local removableCommand = {
	[CMD_GUARD] = true,
	[CMD_PATROL] = true,
}

-- Performance safeguard: When certain commands are spammed, like reclaim, `UnitCommand` can cause
-- extreme performance issues by parsing all of those commands. So we skip units recently touched.
local recentUnits = {}
local updateTime = 0
local gameTime = 0
-- Regardless of the preference above, we don't need to go any lower than the double-click speed.
safeguardDuration = math.max(safeguardDuration, Spring.GetConfigInt("DoubleClickTime", 200) / 1000)

local validUnit = {}
for udid, ud in pairs(UnitDefs) do
	validUnit[udid] = ud.isBuilder and ud.canRepair and not ud.isFactory
end

local function clearRecentUnits()
	local release = gameTime - safeguardDuration
	for unitID, seconds in pairs(recentUnits) do
		if seconds <= release then
			recentUnits[unitID] = nil
		end
	end
	updateTime = safeguardDuration * 0.5
end

local function isStateToggle(cmdID)
	local cmdIndex = spGetCmdDescIndex(cmdID)
	if cmdIndex then
		local cmdDescription = spGetActiveCmdDesc(cmdIndex)
		if cmdDescription and cmdDescription.type == CMDTYPE_ICON_MODE then
			return true
		end
	end
	return false
end

function widget:UnitCommand(unitID, unitDefID, _, cmdID, _, cmdOpts)
	if not cmdOpts.shift or recentUnits[unitID] then
		return false
	end

	if validUnit[unitDefID] and not isStateToggle(cmdID) then
		recentUnits[unitID] = gameTime
		local cmd = spGetUnitCommands(unitID, 2)
		if cmd then
			for c = 1, #cmd do
				if removableCommand[cmd[c].id] then
					spGiveOrderToUnit(unitID, CMD.REMOVE, {cmd[c].tag}, 0)
				end
			end
		end
	end

	return false
end

function widget:Update(dt)
	gameTime = gameTime + dt
	updateTime = updateTime - dt
	if updateTime <= 0 then
		clearRecentUnits()
	end
end
