-- CM8 "Ashfall", Beat 2 — the automated outpost: no pilots, story-critical hub.
-- The player inherits the failing base; the command hub cannot die before the
-- enclave reveal or the mission breaks.

When(MatchFlow.Started())
	.Do(Units.Transfer("outpost_auto", Team.Player))
	.Do(Combat.Protect(Unit("outpost_command_hub"))
		.Until(Objective("find_the_enclave").IsComplete()))
