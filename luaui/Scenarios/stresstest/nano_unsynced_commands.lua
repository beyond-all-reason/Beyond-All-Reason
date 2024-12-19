VFS.Include("luaui/Scenarios/stresstest/nano_commands.lua")

function test()
	local t0 = os.clock()

	local nturrets = 50*Scenario.stressLevel
	local ntargets = 50*Scenario.stressLevel
	local turretDef = Scenario.builderDef
	local targetDef = Scenario.targetDef

	SyncedRun(synced_nano_setup)
	Spring.Echo("init time preinit:", os.clock()-t0)

	Test.waitFrames(1)

	run_nano_commands(nturrets, ntargets, turretDef, targetDef)

	Spring.Echo("total time:", os.clock()-t0)
end


