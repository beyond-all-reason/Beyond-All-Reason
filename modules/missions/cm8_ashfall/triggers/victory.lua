-- CM8 "Ashfall", Beat 6 — staged objectives; the verdict flows through matchflow.
-- Trimmed to the modules in tree: the lava tiers and the scripted reveal still
-- wait on theirs. The wave pressure these objectives drive lives in waves.lua.

When(Team.Player.Has(UnitDef("corllt"), 4))
	.Do(Objective("relieve_the_outpost").Complete())

When(Objective("relieve_the_outpost").IsComplete())
	.When(Unit("tenebrium_device").IsSpotted(Team.Player))
	.Do(Objective("find_the_enclave").Complete())

When(Unit("armada_commander").IsDestroyed())
	.Do(Objective("kill_the_commander").Complete())

When(Objective("kill_the_commander").IsComplete())
	.Do(MatchFlow.Victory(Team.Player))
