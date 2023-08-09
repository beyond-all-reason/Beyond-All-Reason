function widget:GetInfo()
  return {
    name      = "Unity Move Towards Transport",
    desc      = "If a unit is set to be loaded, but is to far away from a sea, hover, or land transport, move the unit into range",
    author    = "Sefi",
    date      = "Jul 10, 2023",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

-------------------------------------------------------------------------------
-------------------------------------------------------------------------------
local spGetMyTeamID = Spring.GetMyTeamID
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitSeparation = Spring.GetUnitSeparation
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitPosition =Spring.GetUnitPosition


local CMD_MOVE = CMD.MOVE

local CMD_INSERT = CMD.INSERT
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_OPT_ALT = CMD.OPT_ALT
local isTransport = {} -- isTransport[uDefID] = UnitDefs[uDefID].isTransport
for uDefID, uDef in pairs(UnitDefs) do
	if uDef.isTransport  then
		if uDef.canFly == false then

		isTransport[uDefID] = true
		end
	end
end

local watchList = {} -- watchList[uID] = tID


function widget:UnitCommand(uID, uDefID, uTeam)
	if isTransport[uDefID] and uTeam == spGetMyTeamID() and GetTransportTarget(uID) then
		watchList[uID] = true
	end
end

function widget:UnitCmdDone(uID, uDefID, uTeam)
	widget:UnitCommand(uID, uDefID, uTeam)
end


function widget:Initialize()
	Spring.Log(gadget:GetInfo().name, LOG.INFO, "UNIT MOVER SCRIPTTTTTT")

end

function widget:Shutdown()
end


local function GetTransportTarget(uID)

	local uCmd, _, _, cmdParam1, cmdParam2 = spGetUnitCurrentCommand(uID)
	if not uCmd then return end
	if uCmd == CMD_LOAD_UNITS and cmdParam2 == nil then
		if spGetUnitTeam(cmdParam1) == spGetMyTeamID() then
			return cmdParam1
		end
	end
end

function widget:GameFrame(n)

	-- Limit command rate to 3/sec (Sufficient for coms)
	if n % 10 > 0 then return end

	for uID, _ in pairs(watchList) do

		-- Re-get transports target
		local tID = GetTransportTarget(uID)

        local pos1 = spGetUnitPosition(tId);
		if tID then

        			-- Only issue if transport is far away from unit
        			if spGetUnitSeparation(uID, tID, true) > 50 then
        				-- Move to the transport.
        				SendToUnsynced("Move to transport", uId)
        					spGiveOrderToUnit(uID, CMD_MOVE,  pos1, 0)
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


function widget:Update()

end


