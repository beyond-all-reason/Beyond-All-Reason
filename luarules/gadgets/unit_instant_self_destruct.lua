--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "Instant Self Destruct",
    desc      = "Replaces engine self-d behaviour for a set of units such that they self-destruct instantly.",
    author    = "Google Frog",
    date      = "21 September, 2013",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (not gadgetHandler:IsSyncedCode()) then
  return false  --  no unsynced code
end

local selfddefs = {}
for i=1,#UnitDefs do
	if UnitDefs[i].customParams and UnitDefs[i].customParams.instantselfd then
		selfddefs[i] = true
	end
end

local CMD_SELFD = CMD.SELFD
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spDestroyUnit = Spring.DestroyUnit

function gadget:AllowCommand_GetWantedCommand()
	return {[CMD_SELFD] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return selfddefs
end

local toDestroy = {}
local toDestroyCount = 0

local function QueueUnitDestruction(unitID, skipChecks)
	if skipChecks or not spGetUnitIsStunned(unitID) then
		toDestroyCount = toDestroyCount + 1
		toDestroy[toDestroyCount] = unitID
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	-- accepts: CMD.SELFD
	if selfddefs[unitDefID] and cmdOptions.coded == 0 then
		QueueUnitDestruction(unitID)
	end
	return true
end

function gadget:GameFrame(n)
	if toDestroyCount > 0 then
		for i = 1, toDestroyCount do
			spDestroyUnit(toDestroy[i], true)
		end
		toDestroyCount = 0
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_SELFD)
	GG.QueueUnitDestruction = QueueUnitDestruction
end
