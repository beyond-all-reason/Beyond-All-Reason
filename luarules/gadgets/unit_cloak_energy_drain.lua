--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Cloak Energy Drain",
    desc      = "Handles energy drain from cloak",
    author    = "Floris",
    date      = "February 2018",
    license   = "GNU GPL, v2 or later",
    layer     = 5,
    enabled   = true  --  loaded by default?
  }
end

local engineVersion = 100 -- just filled this in here incorrectly but old engines arent used anyway
if Engine and Engine.version then
	local function Split(s, separator)
		local results = {}
		for part in s:gmatch("[^"..separator.."]+") do
			results[#results + 1] = part
		end
		return results
	end
	engineVersion = Split(Engine.version, '-')
	if engineVersion[2] ~= nil and engineVersion[3] ~= nil then
		engineVersion = tonumber(string.gsub(engineVersion[1], '%.', '')..engineVersion[2])
	else
		engineVersion = tonumber(Engine.version)
	end
elseif Game and Game.version then
	engineVersion = tonumber(Game.version)
end

if (engineVersion < 1000 and engineVersion >= 105) or engineVersion > 10401151 then

	if (not gadgetHandler:IsSyncedCode()) then
	  return false  --  no unsynced code
	end

	local cloakedMoveCostUnits = {}

	local cloakMoveCostUnitDefIDs = {}
	for udid, unitDef in pairs(UnitDefs) do
		if unitDef.cloakCost > 0 and unitDef.cloakCost ~= unitDef.cloakCostMoving then
			cloakMoveCostUnitDefIDs[udid] = unitDef.cloakCostMoving
		end
	end

	function gadget:UnitCloaked(unitID, unitDefID, teamID)
		Spring.SetUnitResourcing(unitID, "uue",  UnitDefs[unitDefID].cloakCost)
		if cloakMoveCostUnitDefIDs[unitDefID] then
			cloakedMoveCostUnits[unitID] = {{Spring.GetUnitPosition(unitID)}, UnitDefs[unitDefID].cloakCost, UnitDefs[unitDefID].cloakCostMoving}
		end
	end
	function gadget:UnitDecloaked(unitID, unitDefID, teamID)
		Spring.SetUnitResourcing(unitID, "uue", 0)
		if cloakMoveCostUnitDefIDs[unitDefID] then
			cloakedMoveCostUnits[unitID] = nil
		end
	end

	function gadget:UnitDestroyed(unitID, unitDefID, teamID)
		if cloakedMoveCostUnits[unitID] then
			cloakedMoveCostUnits[unitID] = nil
		end
	end

	function gadget:Initialize()
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			if Spring.GetUnitIsCloaked(unitID) then
				gadget:UnitCloaked(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
			end
		end
	end

	function gadget:GameFrame(gf)
		if gf % 5 == 1 then
			for unitID, unitParams in pairs(cloakedMoveCostUnits) do
				local ux,uy,uz = Spring.GetUnitPosition(unitID)
				if ux == unitParams[1][1] and uz == unitParams[1][3] then
					Spring.SetUnitResourcing(unitID, "uue", unitParams[2])
				else
					cloakedMoveCostUnits[unitID][1] = {ux,uy,uz}
					Spring.SetUnitResourcing(unitID, "uue", unitParams[3])
				end
			end
		end
	end

end