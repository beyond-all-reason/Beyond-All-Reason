-- CM8 "Ashfall" roster — stand-in defs until Teizer V and its assets exist;
-- the trigger files are the acceptance shape, this makes them arm. Positions
-- are map fractions so the mission plays on any test map. Named/Grouped are
-- the definition sites the trigger files' Unit/Units references are
-- validated against.

-- Beat 2, the automated outpost: spawns pilotless (gaia) and is handed to
-- the player at mission start by Transfer.Give("outpost_auto", Team.Player).
-- Give, not Units: gaia is nobody's ally, so no sharing mode can permit it —
-- this is the game handing the base over, not a team choosing to share.
-- The command hub is the story-critical protected structure.
--
-- Every piece of it is Neutral. Gaia is hostile to everyone, so an abandoned
-- base opens fire on whoever walks up to it — including the player the mission
-- sends to discover it, which turns the beat from "you inherit this" into "you
-- are shot by this". Handing the group over clears it, and the towers start
-- earning their keep against the waves.

Spawn(UnitDef("corlab"), "gaia")
	.At(0.42, 0.42)
	.Named("outpost_command_hub")
	.Grouped("outpost_auto")
	.Neutral()

Spawn(UnitDef("corllt"), "gaia")
	.At(0.39, 0.40)
	.Grouped("outpost_auto")
	.Neutral()

Spawn(UnitDef("corllt"), "gaia")
	.At(0.45, 0.40)
	.Grouped("outpost_auto")
	.Neutral()

Spawn(UnitDef("corrad"), "gaia")
	.At(0.42, 0.39)
	.Grouped("outpost_auto")
	.Neutral()

Spawn(UnitDef("corsolar"), "gaia")
	.At(0.39, 0.44)
	.Grouped("outpost_auto")
	.Neutral()

Spawn(UnitDef("corsolar"), "gaia")
	.At(0.45, 0.44)
	.Grouped("outpost_auto")
	.Neutral()

-- Beats 4 and 6, the Armada enclave: spotting the device closes
-- find_the_enclave; killing the commander wins through matchflow.

Spawn(UnitDef("armfus"), "enemy")
	.At(0.75, 0.75)
	.Named("tenebrium_device")

-- The enclave's commander is CLAIMED, not spawned. Dropped into a skirmish the
-- enemy seat already has one, and adding a second leaves that team with two
-- commanders and this mission with the wrong one to kill. In CM8's own game the
-- seat is empty, so one gets built at the enclave.
Claim(UnitDef("armcom"), "enemy")
	.Named("armada_commander")
	.OrSpawnAt(0.77, 0.77)

Spawn(UnitDef("armllt"), "enemy")
	.At(0.73, 0.75)

Spawn(UnitDef("armllt"), "enemy")
	.At(0.75, 0.73)
