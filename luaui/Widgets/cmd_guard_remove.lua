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

-- Remove non-terminating commands
local removableCommand = {
	[CMD.GUARD] = true,
	[CMD.PATROL] = true,
}
-- Keep commands when in sequence
local sequentialCommand = {
	[CMD.PATROL] = true,
}

local math_distsq = math.distance3dSquared

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand

local CANCEL_DIST_SQUARED = (Game.squareSize * Game.footprintScale + 1) ^ 2 -- see also CommandAI.cpp

-- performance safeguard, when certain commands are spammed, like reclaim, `UnitCommand` can cause
-- extreme performance issues by parsing all of those commands. So we track units that have recieved
-- commands in the last 5 frames and skip any that are touched
local recentUnits = {}
local updateTime = 0

local validUnit = {}
for udid, ud in pairs(UnitDefs) do
	validUnit[udid] = ud.isBuilder and not ud.isFactory
end

-- Non-exhaustively determines whether the engine will cancel a command.
-- The edge cases are not interesting to us given a limited remove list.
local function willCancel(p1, p2, p3, q1, q2, q3)
	if p1 == q1 and p2 == q2 and p3 == q3 then
		return true
	elseif p3 ~= nil and q3 ~= nil then
		return math_distsq(p1, p2, p3, q1, q2, q3) < CANCEL_DIST_SQUARED
	else
		return false
	end
end

-- See `CCommandAI:GiveAllowedCommand`.
-- The engine cancels the first duplicate command, starting from the end,
-- then cancels overlapping commands by distance and BuildInfo footprint.
--
-- We want to remove non-duplicate, non-overlapping commands, then, that
-- otherwise would prevent reaching our newer, higher-precedence command.
local function removeCommands(unitID, command, params)
	local p1, p2, p3 = params[1], params[2], params[3]

	local tags = {}
	local hasCanceled = false
	local isReachable = sequentialCommand[command]

	for i = Spring.GetUnitCommandCount(unitID), 1, -1 do
		local queued, _, qid, q1, q2, q3 = spGetUnitCurrentCommand(unitID, i)
		if queued >= 0 and removableCommand[queued] then
			if not hasCanceled and willCancel(p1, p2, p3, q1, q2, q3) then
				hasCanceled = true
			elseif not isReachable or not sequentialCommand[queued] then
				isReachable = false
				tags[#tags + 1] = qid
			end
		end
	end

	if tags[1] ~= nil then
		Spring.GiveOrderToUnit(unitID, CMD.REMOVE, tags)
	end
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if not cmdOpts.shift or not validUnit[unitDefID] or recentUnits[unitID] then
		return
	else
		recentUnits[unitID] = spGetGameFrame()
	end

	if removableCommand[cmdID] then
		removeCommands(unitID, cmdID, cmdParams)
	end
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
