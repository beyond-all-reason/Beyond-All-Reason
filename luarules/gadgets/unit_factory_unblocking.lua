
if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
    name      = "Factory Unblocking",
    desc      = "This prevents exiting units get stuck on the newly initiated (big) unit",
    author    = "Floris",
    date      = "September 2020",
    layer     = 0,
    enabled   = true --  loaded by default?
  }
end

local setBlockingOnFinished = {}
local factoryUnits = {}
local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = true
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		factoryUnits[unitID] = isFactory[unitDefID]
	end
	if setBlockingOnFinished[unitID] then
		Spring.SetUnitBlocking(unitID, true)
		setBlockingOnFinished[unitID] = nil
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if factoryUnits[builderID] then
		Spring.SetUnitBlocking(unitID, false)
		setBlockingOnFinished[unitID] = true
	end
end

function gadgetHandler:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
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
