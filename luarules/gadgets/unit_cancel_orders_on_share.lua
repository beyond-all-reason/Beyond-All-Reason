local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Cancel orders on share",
		desc = "Prevents units carrying on with orders once shared/taken and turns on mexes and targeting facilities that have been captured",
		author = "Bluestone, Beherith",
		date = "Jan 2015",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		-- give all shared units a stop command
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)

		-- remove their build queue
		local buildQ = Spring.GetFullBuildQueue(unitID) or {}
		for _, buildOrder in pairs(buildQ) do
			for uDID, count in pairs(buildOrder) do
				for i = 1, count do
					Spring.GiveOrderToUnit(unitID, -uDID, {}, { "right" })
				end
			end
		end
	end
else -- SYNCED
	local unitsToTurnOn = {}

	local isTargetingFacility = {}
	local turnsOnWhenGiven = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if unitDef.isTargetingUpgrade then
			isTargetingFacility[unitDefID] = true
		end
		if unitDef.isTargetingUpgrade or unitDef.extractsMetal > 0 then
			turnsOnWhenGiven[unitDefID] = true
		end
	end

	function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
		-- the engine turns captured units off under the new team, which would charge that team the radar credit
		if
			isTargetingFacility[unitDefID]
			and Spring.GetUnitIsActive(unitID)
			and Spring.GetTeamAllyTeamID(unitTeam) ~= Spring.GetTeamAllyTeamID(newTeam)
		then
			Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 0 }, 0)
		end
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam)
		if turnsOnWhenGiven[unitDefID] then
			unitsToTurnOn[#unitsToTurnOn + 1] = unitID
		end
	end

	function gadget:GameFrame(n)
		if n % 37 == 0 and #unitsToTurnOn > 0 then
			for _, unitID in ipairs(unitsToTurnOn) do
				if Spring.ValidUnitID(unitID) then
					Spring.GiveOrderToUnit(unitID, CMD.ONOFF, { 1 }, 0)
				end
			end
			unitsToTurnOn = {}
		end
	end
end
