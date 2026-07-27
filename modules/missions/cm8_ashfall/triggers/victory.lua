-- CM8 "Ashfall", Beat 6 — staged objectives; the verdict flows through matchflow.
-- Trimmed to the modules in tree (combat, matchflow): the lava tiers, the
-- scripted reveal, and the raptor waves wait on their modules.

When(Team.Player.Has(UnitDef("corllt"), 4))
	.Do(Objective("relieve_the_outpost").Complete())

When(Objective("relieve_the_outpost").IsComplete())
	.When(Unit("tenebrium_device").IsSpotted(Team.Player))
	.Do(Objective("find_the_enclave").Complete())

When(Unit("armada_commander").IsDestroyed())
	.Do(Objective("kill_the_commander").Complete())

When(Objective("kill_the_commander").IsComplete())
	.Do(MatchFlow.Victory(Team.Player))
