-- CM8 "Ashfall" — the objective board: identity, wording, completion and
-- cadence, one declaration per line. Declaration order is the tracker's
-- display order and the reveal cadence (first line at arm, each next when
-- its predecessor completes). The completion gates below are explicit on
-- purpose: the sequence decides what the player SEES, never what counts.

Objective("protect_the_commander").Title("Protect your Commander").RevealedWhen(MatchFlow.Started())

Objective("relieve_the_outpost")
	.Title("Relieve the outpost")
	-- "Relieve" means you found it and then fortified: the spotted latch
	-- gates the stand-in build condition, so four towers at home no longer
	-- count as a rescue. Still a placeholder for a real proximity condition —
	-- the DSL has no "Near" yet, and this beat wants one.
	.CompletedWhen(Unit("outpost_command_hub").IsSpotted(Team.Player))
	.When(Team.Player.Has(UnitDef("corllt"), 4))

Objective("find_the_enclave")
	.Title("Find the Enclave")
	-- The enclave announces itself at its rim: the beacon is the first thing
	-- a scout sees, and seeing it is finding the place. Gated on the relief
	-- so a latched early sighting cannot finish a line the story has not
	-- asked yet.
	.CompletedWhen(Unit("enclave_beacon").IsSpotted(Team.Player))
	.When(Objective("relieve_the_outpost").IsComplete())
	-- The hard way also counts: a radar-dot bombardment never enters LOS,
	-- and what you blew up, you found. Same story gate.
	.CompletedWhen(Unit("enclave_beacon").IsDestroyed())
	.When(Objective("relieve_the_outpost").IsComplete())

Objective("find_the_tenebrium_device")
	.Title("Find the Tenebrium device")
	-- The device is deeper in — finding the place and finding the prize are
	-- separate pushes, which is what makes them separate lines.
	.CompletedWhen(Unit("tenebrium_device").IsSpotted(Team.Player))
	.When(Objective("find_the_enclave").IsComplete())
	-- Destroyed-unspotted counts here too, or the line dangles forever.
	.CompletedWhen(Unit("tenebrium_device").IsDestroyed())
	.When(Objective("find_the_enclave").IsComplete())

Objective("kill_the_commander")
	.Title("Kill the enemy commander")
	-- Ungated: an early commander snipe counts the moment it happens — the
	-- board catches up (Complete implies Reveal).
	.CompletedWhen(Unit("armada_commander").IsDestroyed())
