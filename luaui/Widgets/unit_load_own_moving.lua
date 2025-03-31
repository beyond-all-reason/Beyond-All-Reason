
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Load Own Moving",
		desc      = "Enables loading of your own units when they're moving",
		author    = "Niobium",
		version   = "1.0",
		date      = "June 18, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

-------------------------------------------------------------------
-- Globals
-------------------------------------------------------------------
local watchList = {} -- watchList[uID] = tID

local isTransport = {} -- isTransport[uDefID] = UnitDefs[uDefID].isTransport
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.isTransport and uDef.canFly then
		isTransport[uDefID] = true
	end
end

-------------------------------------------------------------------
-- Speedups
-------------------------------------------------------------------
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitVelocity = Spring.GetUnitVelocity

local CMD_INSERT = CMD.INSERT
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_OPT_ALT = CMD.OPT_ALT

local gameStarted

-------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------
local function GetTransportTarget(uID)

	local uCmd, _, _, cmdParam1, cmdParam2 = spGetUnitCurrentCommand(uID)
	if not uCmd then return end
	if uCmd == CMD_LOAD_UNITS and cmdParam2 == nil then
		if spGetUnitTeam(cmdParam1) == spGetMyTeamID() then
			return cmdParam1
		end
	end
end

-------------------------------------------------------------------
-- Callins
-------------------------------------------------------------------
function widget:UnitCommand(uID, uDefID, uTeam)
	if isTransport[uDefID] and uTeam == spGetMyTeamID() and GetTransportTarget(uID) then
		watchList[uID] = true
	end
end
function widget:UnitCmdDone(uID, uDefID, uTeam)
	widget:UnitCommand(uID, uDefID, uTeam)
end

function widget:GameFrame(n)

	-- Limit command rate to 3/sec (Sufficient for coms)
	if n % 10 > 0 then return end

	for uID, _ in pairs(watchList) do

		-- Re-get transports target
		local tID = GetTransportTarget(uID)
		if tID then

			-- Only issue if transport is close
			if spGetUnitSeparation(uID, tID, true) < 100 then

				-- Only issue if target is moving
				local vx, _, vz = spGetUnitVelocity(tID)
				if vx ~= 0 or vz ~= 0 then
					spGiveOrderToUnit(uID, CMD_INSERT, {0, CMD_LOAD_UNITS, 0, tID}, CMD_OPT_ALT)
				end
			end
		else
			-- No trans or no valid target, stop watching
			watchList[uID] = nil
		end
	end
end

function widget:UnitTaken(uID)
	watchList[uID] = nil
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (Spring.GetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end
