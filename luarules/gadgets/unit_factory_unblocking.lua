
if not gadgetHandler:IsSyncedCode() then
	return
end

function gadget:GetInfo()
  return {
    name      = "Factory Unblocking",
    desc      = "Set new factory unit unblocking when factory is footprint is occupied ",
    author    = "Floris",
    date      = "September 2020",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true --  loaded by default?
  }
end

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInBox  = Spring.GetUnitsInBox
local boxHeight = 30
local setBlockingOnFinished = {}
local factoryUnits = {}
local isFactory = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = {unitDef.xsize, unitDef.zsize}
	end
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if isFactory[unitDefID] then
		factoryUnits[unitID] = isFactory[unitDefID]
		local x,y,z = spGetUnitPosition(unitID)
		factoryUnits[unitID][3] = x
		factoryUnits[unitID][4] = y
		factoryUnits[unitID][5] = z
	end
	if setBlockingOnFinished[unitID] then
		Spring.SetUnitBlocking(unitID, true)
		setBlockingOnFinished[unitID] = nil
	end
end


function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if factoryUnits[builderID] then
		local units = spGetUnitsInBox(factoryUnits[builderID][3]-(factoryUnits[builderID][1]/2), factoryUnits[builderID][4]-boxHeight, factoryUnits[builderID][5]-(factoryUnits[builderID][2]/2), factoryUnits[builderID][3]+(factoryUnits[builderID][1]/2), factoryUnits[builderID][4]+boxHeight, factoryUnits[builderID][5]+(factoryUnits[builderID][2]/2))
		if #units > 1 then
			Spring.SetUnitBlocking(unitID, false)
			setBlockingOnFinished[unitID] = true
		end
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
