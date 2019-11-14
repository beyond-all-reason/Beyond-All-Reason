function gadget:GetInfo()
  return {
    name      = "TurnRadius",
    desc      = "Fixes TurnRadius Dynamically for bombers",
    author    = "Doo",
    date      = "Sept 19th 2017",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if gadgetHandler:IsSyncedCode() then
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local isBomb = {}
	local isBomber = {}
	local Bombers = {}
	local fighters = {
		[UnitDefNames["armsfig"].id] = true,
		[UnitDefNames["corsfig"].id] = true,
		[UnitDefNames["armfig"].id] = true,
		[UnitDefNames["corveng"].id] = true,
		[UnitDefNames["armhawk"].id] = true,
		[UnitDefNames["corvamp"].id] = true,
	}

	for id, wDef in pairs(WeaponDefs) do
		if wDef.type == "AircraftBomb" then
			isBomb[id] = true
		end
	end

	for id, uDef in pairs(UnitDefs) do
		if (uDef["weapons"] and uDef["weapons"][1] and isBomb[uDef["weapons"][1].weaponDef] == true) or (uDef.name == "armlance" or uDef.name == "cortitan") then
			isBomber[id] = true
		end
	end

	function gadget:Initialize()
		for ct, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
		end
	end

	function gadget:UnitCreated(unitID, unitDefID)
		if isBomber[Spring.GetUnitDefID(unitID)] then
			Bombers[unitID] = true
		end
		if fighters[unitDefID] then
			local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
			if curMoveCtrl then
				Spring.MoveCtrl.Disable(unitID)
			end
			Spring.MoveCtrl.SetAirMoveTypeData(unitID, "attackSafetyDistance", 300)
			if curMoveCtrl then
				Spring.MoveCtrl.Enable(unitID)
			end
		end
	end

	function gadget:UnitDestroyed(unitID)
		if Bombers[unitID] then
			Bombers[unitID] = nil
		end
	end

	function gadget:GameFrame(n)
		if n % 5 == 1 then
			for unitID, isbomber in pairs (Bombers) do
				local nextCmdID = spGetUnitCurrentCommand(unitID)
				if not nextCmdID or nextCmdID == CMD.ATTACK then
					local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
					if curMoveCtrl then
						Spring.MoveCtrl.Disable(unitID)
					end
					Spring.MoveCtrl.SetAirMoveTypeData(unitID, "turnRadius", 500)
					if curMoveCtrl then
						Spring.MoveCtrl.Enable(unitID)
					end
				elseif Spring.GetUnitMoveTypeData(unitID).turnRadius then
					local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
					if curMoveCtrl then
						Spring.MoveCtrl.Disable(unitID)
					end
					Spring.MoveCtrl.SetAirMoveTypeData(unitID, "turnRadius", UnitDefs[Spring.GetUnitDefID(unitID)].turnRadius)
					if curMoveCtrl then
						Spring.MoveCtrl.Enable(unitID)
					end
				end
			end
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if Bombers[unitID] and not Spring.GetUnitMoveTypeData(unitID).aircraftState == "crashing" then
			if cmdID == CMD.ATTACK then
				local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
				if curMoveCtrl then
					Spring.MoveCtrl.Disable(unitID)
				end
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, "turnRadius", 500)
				if curMoveCtrl then
					Spring.MoveCtrl.Enable(unitID)
				end
			else
				local curMoveCtrl = Spring.MoveCtrl.IsEnabled(unitID)
				if curMoveCtrl then
					Spring.MoveCtrl.Disable(unitID)
				end
				Spring.MoveCtrl.SetAirMoveTypeData(unitID, "turnRadius", UnitDefs[Spring.GetUnitDefID(unitID)].turnRadius)
				if curMoveCtrl then
					Spring.MoveCtrl.Enable(unitID)
				end
			end
		end
		return true
	end
end		