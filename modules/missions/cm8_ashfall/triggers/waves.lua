-- CM8 "Ashfall", the pressure. Scavengers push in from the northeast for the
-- whole mission, and every objective the player closes makes them worse.
--
-- The pack is Skirmish: pressure with no ending of its own. It has no boss
-- and no win condition, because the mission already has one — the last
-- statement here is what turns it off, and the commander's death is what
-- reaches it.

-- A minute of quiet first. The player inherits a failing base and needs
-- long enough to read it before anything comes over the ridge; the director's
-- own grace period is about spawner placement, not about the opening beat.
When(MatchFlow.Started())
	.After(60)
	.Do(Waves.Begin(Scavengers.Skirmish).Against(Team.Player).From(0.85, 0.15).Intensity(0.3))

-- Beat 3: the outpost holds. Something notices.
When(Objective("relieve_the_outpost").IsComplete()).Do(Waves.Intensify(Scavengers.Skirmish, 0.6))

-- Beat 4: the enclave is found. One wave arrives immediately — the reveal
-- costs the player their footing — and the pressure stays up afterwards.
When(Objective("find_the_enclave").IsComplete())
	.Do(Waves.Surge(Scavengers.Skirmish))
	.Do(Waves.Intensify(Scavengers.Skirmish, 1.0))

-- Beat 6: with the Armada commander dead there is nothing left to fight over.
-- Units already on the field stay; only the spawner stops.
When(Objective("kill_the_commander").IsComplete()).Do(Waves.End(Scavengers.Skirmish))
