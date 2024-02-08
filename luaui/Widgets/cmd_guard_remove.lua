
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

local CMD_GUARD = CMD.GUARD
local CMD_PATROL = CMD.PATROL

local removableCommand = {
	[CMD_GUARD] = true,
	[CMD_PATROL] = true,
}

local validUnit = {}
for udid, ud in pairs(UnitDefs) do
	validUnit[udid] = ud.isBuilder and not ud.isFactory
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdId, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if not cmdOpts.shift then
		return false
	end

	if validUnit[unitDefID] then
		local cmd = Spring.GetCommandQueue(unitID, -1)
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
