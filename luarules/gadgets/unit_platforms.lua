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
	toUpdateList = {}
	
	function gadget:UnitCreated(unitID)
		unitDefID = Spring.GetUnitDefID(unitID)
		unitName = UnitDefs[unitDefID].name
		x,y,z = Spring.GetUnitPosition(unitID)
		if (unitName == "armuwmex" or unitName == "coruwmex") then
			GroundHeight = Spring.GetGroundHeight(x,z)
			Spring.CallCOBScript(unitID, "HidePieces", 0, -GroundHeight)
			Spring.SetUnitRadiusAndHeight (unitID, 8, 0 )
			for piecenum, name in pairs(Spring.GetUnitPieceList(unitID)) do
				if name == "arms" then
					toUpdateList[unitID] = piecenum
				end
			end
			Spring.SetUnitMidAndAimPos(unitID, 0, 10, 0, 0, 10, 0, true)
		end
	end
	
	function gadget:UnitDestroyed(unitID)
		toUpdateList[unitID] = nil
	end
	
	function gadget:GameFrame(f)
		if f%15 == 0 then
			for unitID, piecenum in pairs(toUpdateList) do
				local px,py,pz = Spring.GetUnitPiecePosition(unitID, piecenum)
				Spring.SetUnitMidAndAimPos(unitID, px,py,pz,px,py,pz, true)
			end
		end
	end
end
