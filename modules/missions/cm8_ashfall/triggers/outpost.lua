-- CM8 "Ashfall", Beat 2 — the automated outpost: no pilots, story-critical hub.
-- The player inherits the failing base; the command hub cannot die before the
-- enclave reveal or the mission breaks.
--
-- So the hub's protection starts with the MATCH, not with the discovery:
-- waves fight through this valley long before anyone looks at it, and
-- neutrality only stops the aiming, never the splash. The rest of the base
-- stays mortal on purpose — a failing outpost is allowed to be failing, it
-- is only the story that must survive.
When(MatchFlow.Started()).Do(
	Combat.Protect(Unit("outpost_command_hub")).Until(Objective("find_the_enclave").IsComplete())
)

-- Inheriting it waits on seeing it. A base that changes hands while still
-- under fog arrives as a scoreboard change and a pile of units the player
-- never went to find, which is the opposite of the beat: the outpost is meant
-- to be a discovery. IsSpotted latches, so this fires once, on the frame the
-- hub first enters the player's vision, and stays fired afterwards.
When(MatchFlow.Started())
	.When(Unit("outpost_command_hub").IsSpotted(Team.Player))
	.Do(Transfer.Give("outpost_auto", Team.Player))
