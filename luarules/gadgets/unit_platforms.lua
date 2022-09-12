function gadget:GetInfo()
	return {
		name = "Sea bed Platforms",
		desc = "Handles buildings surfacing from sea bed behaviours",
		author = "[Fx]Doo",
		date = "25 of June 2017",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if (gadgetHandler:IsSyncedCode()) then

	local toUpdateList = {}

	local isUwMex = {}
	for udid, ud in pairs(UnitDefs) do
		if string.find(ud.name, 'armuwmex') or string.find(ud.name, 'coruwmex') then       -- liche is classified as one somehow
			isUwMex[udid] = true
		end
	end

	function gadget:UnitCreated(unitID, unitDefID)
		local x,y,z = Spring.GetUnitPosition(unitID)
		if isUwMex[unitDefID] then
			local GroundHeight = Spring.GetGroundHeight(x,z)
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
		if f % 15 == 0 then
			for unitID, piecenum in pairs(toUpdateList) do
				local px,py,pz = Spring.GetUnitPiecePosition(unitID, piecenum)
				Spring.SetUnitMidAndAimPos(unitID, px,py,pz,px,py,pz, true)
			end
		end
	end
end
