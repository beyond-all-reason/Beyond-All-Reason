VFS.Include("luaui/Scenarios/stresstest/multi_attack.lua")

function test()
	local t0 = os.clock()

	local nattackers = 100*Scenario.stressLevel
	local ntargets = 100*Scenario.stressLevel
	local attackerDef = Scenario.attackerDef
	local targetDef = Scenario.targetDef
	local radarDef = Scenario.radarDef

	SyncedRun(synced_setup)
	Spring.Echo("init time preinit:", os.clock()-t0)

	Test.waitFrames(1)

	run_commands(nattackers, ntargets, attackerDef, targetDef)

	Spring.Echo("total time:", os.clock()-t0)
end

