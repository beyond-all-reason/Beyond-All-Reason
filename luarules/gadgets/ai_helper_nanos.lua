function gadget:GetInfo()
	return {
		name 	= "Registers Nanos positions",
		desc	= "Used for AI retreat scripts",
		author	= "Doo",
		date	= "Sept 19th 2017",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled = true,
	}
end

if gadgetHandler:IsSyncedCode() then

local isNanoTC = {}
local NanoTC = {}

for unitDefID, defs in pairs(UnitDefs) do
	if string.find(defs.name, "nanotc") then
		isNanoTC[unitDefID] = true
	end
end

function gadget:Initialize()
	for ct, unitID in pairs(Spring.GetAllUnits()) do
	local unitDefID = Spring.GetUnitDefID(unitID)
	local unitTeam = Spring.GetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, unitTeam)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if isNanoTC[unitDefID] then
		if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
		NanoTC[unitTeam][unitID] = {Spring.GetUnitPosition(unitID)}
		GG.NanoTC = NanoTC
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
		if not NanoTC[unitTeam] then NanoTC[unitTeam] = {} end
		NanoTC[unitTeam][unitID] = nil
		GG.NanoTC = NanoTC
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
		gadget:UnitDestroyed(unitID, unitDefID, oldTeam)
		gadget:UnitCreated(unitID, unitDefID, newTeam)	
		GG.NanoTC = NanoTC
end
end
