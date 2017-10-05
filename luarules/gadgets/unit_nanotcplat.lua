function gadget:GetInfo()
	return {
		name = "NanoTC Platforms",
		desc = "Handles nanotc Platforms behaviours",
		author = "[Fx]Doo",
		date = "25 of June 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
GroundHeight = {}
function gadget:UnitFinished(unitID)
unitDefID = Spring.GetUnitDefID(unitID)
unitName = UnitDefs[unitDefID].name
x,y,z = Spring.GetUnitPosition(unitID)
if unitName == "armnanotcplat" or unitName == "cornanotcplat" then
GroundHeight = Spring.GetGroundHeight(x,z)
Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight)
Spring.SetUnitRadiusAndHeight (unitID, 24, 0 )
Spring.SetUnitMidAndAimPos(unitID, 0, 10, 0, 0, 0, 0, true)
end
end
end