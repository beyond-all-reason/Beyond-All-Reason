
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

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local CMD_INSERT = CMD.INSERT
local COMMAND_CANCEL_DIST = 17 -- see CommandAI.cpp

local removableCommand = {
	[CMD.GUARD] = true,
	[CMD.PATROL] = true,
}

-- performance safeguard, when certain commands are spammed, like reclaim, `UnitCommand` can cause
-- extreme performance issues by parsing all of those commands. So we track units that have recieved
-- commands in the last 5 frames and skip any that are touched
local recentUnits = {}
local updateTime = 0

local validUnit = {}
for udid, ud in pairs(UnitDefs) do
	validUnit[udid] = ud.isBuilder and not ud.isFactory
end

local function shouldCancelParams(c1, c2, c3, p1, p2, p3)
	if c1 == p1 and c2 == p2 and c3 == p3 then
		return true
	elseif c3 == nil and p3 == nil then
		return false
	else
		return math.distance3dSquared(c1, c2, c3, p1, p2, p3) <= COMMAND_CANCEL_DIST * COMMAND_CANCEL_DIST
	end
end

local function removeDedupedCommands(unitID, cmdID, c1, c2, c3)
	local tags = {}
	local index = Spring.GetUnitCommandCount(unitID)
	local first = true

	-- The engine cancels the first dupe from the end. See `CommandAI:GetCancelQueued`.
	-- From there, search exhaustively for all non-duplicate, non-terminating commands.
	while index > 0 do
		local command, _, tag, p1, p2, p3 = spGetUnitCurrentCommand(unitID, index)
		index = index - 1

		if command >= 0 and removableCommand[command] then
			if first and cmdID == command and shouldCancelParams(c1, c2, c3, p1, p2, p3) then
				first = false
			else
				tags[#tags + 1] = tag
			end
		end
	end

	if tags[1] ~= nil then
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, tags)
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not cmdOpts.shift or recentUnits[unitID] or not validUnit[unitDefID] then
		return
	else
		recentUnits[unitID] = spGetGameFrame()
	end

	local fromInsert = cmdID == CMD_INSERT

	if fromInsert then
		cmdID = cmdParams[2]
	end

	if not removableCommand[cmdID] then
		return
	end

	local skip = fromInsert and 3 or 0
	local p1, p2, p3 = cmdParams[1 + skip], cmdParams[2 + skip], cmdParams[3 + skip]

	removeDedupedCommands(unitID, cmdID, p1, p2, p3)
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
