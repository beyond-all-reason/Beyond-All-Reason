
function widget:GetInfo()
	return {
		name      = "Load Own Moving",
		desc      = "Enables loading of your own units when they're moving",
		author    = "Niobium",
		version   = "1.0",
		date      = "June 18, 2010",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true -- loaded by default?
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
local spGetUnitCommands = Spring.GetUnitCommands
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitVelocity = Spring.GetUnitVelocity

local CMD_INSERT = CMD.INSERT
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_OPT_ALT = CMD.OPT_ALT

-------------------------------------------------------------------
-- Local functions
-------------------------------------------------------------------
local function GetTransportTarget(uID)
	
	local uCmds = spGetUnitCommands(uID, 1)
	if not uCmds then return end
	
	local uCmd = uCmds[1]
	if uCmd and uCmd.id == CMD_LOAD_UNITS and #uCmd.params == 1 then
		local tID = uCmd.params[1]
		if spGetUnitTeam(tID) == spGetMyTeamID() then
			return tID
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
