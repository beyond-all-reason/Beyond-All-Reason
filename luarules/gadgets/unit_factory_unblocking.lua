
if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
  return {
    name      = "Factory Unblocking",
    desc      = "This prevents exiting units get stuck on the newly initiated (big) unit",
    author    = "Floris",
    date      = "September 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

local setBlockingOnFinished = {}
local factoryUnits = {}
local isFactory = {}
local canFly = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = true
	end
	if unitDef.canFly then
		canFly[unitDefID] = true
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		factoryUnits[unitID] = isFactory[unitDefID]
	end
	if setBlockingOnFinished[unitID] then
		if canFly[unitDefID] then
			-- to make sure air units do not set their ground to blocking
			-- to prevent rare case of aircraft already in takeoff state perma-blocking a factory

			-- also the second false is to clear CSTATE_BIT_SOLIDOBJECTS, so landing aircraft do not claim dumb spots as blocking
			-- TODO, engine fix to prevent this nonsense
			Spring.SetUnitBlocking(unitID, false, false)
		else
			Spring.SetUnitBlocking(unitID, true)
		end
		setBlockingOnFinished[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if factoryUnits[builderID] then
		-- first false is to set blocking on ground
		Spring.SetUnitBlocking(unitID, false)
		setBlockingOnFinished[unitID] = true
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
	factoryUnits[unitID] = nil
	setBlockingOnFinished[unitID] = nil
end

function gadget:Initialize()
	local allUnits = Spring.GetAllUnits()
	for _, unitID in ipairs(allUnits) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		local unitTeamID = Spring.GetUnitTeam(unitID)
		gadget:UnitFinished(unitID, unitDefID, unitTeamID)
	end
end
