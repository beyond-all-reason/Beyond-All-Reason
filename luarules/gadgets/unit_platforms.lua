function gadget:GetInfo()
	return {
		name = "Sea bed Platforms",
		desc = "Handles buildings surfacing from sea bed behaviours",
		author = "[Fx]Doo",
		date = "25 of June 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
GroundHeight = {}
surfacemex = ((Spring.GetModOptions().seamex or "underwater") == "surface")
function gadget:UnitCreated(unitID)
unitDefID = Spring.GetUnitDefID(unitID)
unitName = UnitDefs[unitDefID].name
x,y,z = Spring.GetUnitPosition(unitID)
if (unitName == "armuwmex" or unitName == "coruwmex") and surfacemex then
GroundHeight = Spring.GetGroundHeight(x,z)
Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight)
Spring.SetUnitRadiusAndHeight (unitID, 24, 0 )
Spring.SetUnitMidAndAimPos(unitID, 0, 10, 0, 0, 0, 0, true)
end
end
end
