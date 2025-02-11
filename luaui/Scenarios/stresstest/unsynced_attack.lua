VFS.Include("luaui/Scenarios/stresstest/multi_attack.lua")

function radius_attack(attackers, targetsCenter)
	local y = Spring.GetGroundHeight(targetsCenter[1], targetsCenter[2])
	local targetPosition = {targetsCenter[1], y+5, targetsCenter[2], targetsCenter[3]}

	local CMD_ATTACK = CMD.ATTACK
	local spGiveOrderToUnit = Spring.GiveOrderToUnit

	Spring.SelectUnitArray(attackers)
	Spring.GiveOrder(CMD_ATTACK, targetPosition, 0)
end

function test()
	local t0 = os.clock()

	local nattackers = 100*Scenario.stressLevel
	local ntargets = 100*Scenario.stressLevel
	local attackerDef = Scenario.attackerDef
	local targetDef = Scenario.targetDef
	local radarDef = Scenario.radarDef

	local attackers, targetsCenter = SyncedRun(synced_setup)

	Test.waitFrames(1)

	radius_attack(attackers, targetsCenter)

	Spring.Echo("total time:", os.clock()-t0)
end

