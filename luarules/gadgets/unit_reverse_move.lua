function gadget:GetInfo()
	return {
		name = "ReverseMovementHandler",
		desc = "Sets reverse speeds/angles/distances",
		author = "[Fx]Doo",
		date = "27 of July 2017",
		license = "Free",
		layer = 0,
		enabled = true
	}
end


if (gadgetHandler:IsSyncedCode()) then
	Tanks = {
	[UnitDefNames["armmanni"].id] = true,
	[UnitDefNames["armart"].id] = true,
	[UnitDefNames["armmart"].id] = true,
	[UnitDefNames["cormart"].id] = true,
	[UnitDefNames["corban"].id] = true,
	[UnitDefNames["cortrem"].id] = true,
	[UnitDefNames["corwolv"].id] = true,
	}

	function gadget:UnitCreated(unitID)
		unitDefID = Spring.GetUnitDefID(unitID)
		if Tanks[unitDefID] == true then
			-- Spring.Echo("Setting for "..unitID)
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "maxReverseDist", 512)
			Spring.MoveCtrl.SetGroundMoveTypeData(unitID, "minReverseAngle", 140)
		end
	end
end