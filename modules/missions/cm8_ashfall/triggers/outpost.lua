-- CM8 "Ashfall", Beat 2 — the automated outpost: no pilots, story-critical hub.
-- The player inherits the failing base; the command hub cannot die before the
-- enclave reveal or the mission breaks.
--
-- Inheriting it waits on seeing it. A base that changes hands while still
-- under fog arrives as a scoreboard change and a pile of units the player
-- never went to find, which is the opposite of the beat: the outpost is meant
-- to be a discovery. IsSpotted latches, so this fires once, on the frame the
-- hub first enters the player's vision, and stays fired afterwards.

When(MatchFlow.Started())
	.When(Unit("outpost_command_hub").IsSpotted(Team.Player))
	.Do(Transfer.Give("outpost_auto", Team.Player))
	.Do(Combat.Protect(Unit("outpost_command_hub"))
		.Until(Objective("find_the_enclave").IsComplete()))
