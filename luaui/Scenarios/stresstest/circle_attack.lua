VFS.Include("luaui/Scenarios/stresstest/multi_attack.lua")

function radius_attack(targetsCenter, nattackers)
	local y = Spring.GetGroundHeight(targetsCenter[1], targetsCenter[2])
	local targetPosition = {targetsCenter[1], y+5, targetsCenter[2], targetsCenter[3]}

	local CMD_ATTACK = CMD.ATTACK

	-- get units
	local spGetUnitDefID = Spring.GetUnitDefID

	local attackers = table.new and table.new(nattackers) or {}
	local attackerDefID = UnitDefNames[Scenario.attackerDef].id

	local all_units = Spring.GetAllUnits()
	for _, unitID in ipairs(all_units) do
		local unitDefID = spGetUnitDefID(unitID)
		if unitDefID == attackerDefID then
			attackers[#attackers+1] = unitID
		end
	end

	-- give order
	Spring.SelectUnitArray(attackers)
	Spring.GiveOrder(CMD_ATTACK, targetPosition, 0)
	Spring.SelectUnitArray({})
end

function test()
	local t0 = os.clock()

	local nattackers = 100*Scenario.stressLevel
	local ntargets = 100*Scenario.stressLevel
	local attackerDef = Scenario.attackerDef
	local targetDef = Scenario.targetDef
	local radarDef = Scenario.radarDef
	local doCircle = true

	local circle = SyncedRun(synced_setup)
	Spring.Echo("init time preinit:", os.clock()-t0)

	Test.waitFrames(1)

	radius_attack(circle, nattackers)

	Spring.Echo("total time:", os.clock()-t0)
end

