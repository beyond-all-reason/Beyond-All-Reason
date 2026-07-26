-- CM8 "Ashfall" roster — stand-in defs until Teizer V and its assets exist;
-- the trigger files are the acceptance shape, this makes them arm. Positions
-- are map fractions so the mission plays on any test map. Named/Grouped are
-- the definition sites the trigger files' Unit/Units references are
-- validated against.

-- Beat 2, the automated outpost: spawns pilotless (gaia) and is handed to
-- the player at mission start by Units.Transfer("outpost_auto", Team.Player).
-- The command hub is the story-critical protected structure.

Spawn(UnitDef("corlab"), "gaia")
	.At(0.42, 0.42)
	.Named("outpost_command_hub")
	.Grouped("outpost_auto")

Spawn(UnitDef("corllt"), "gaia")
	.At(0.39, 0.40)
	.Grouped("outpost_auto")

Spawn(UnitDef("corllt"), "gaia")
	.At(0.45, 0.40)
	.Grouped("outpost_auto")

Spawn(UnitDef("corrad"), "gaia")
	.At(0.42, 0.39)
	.Grouped("outpost_auto")

Spawn(UnitDef("corsolar"), "gaia")
	.At(0.39, 0.44)
	.Grouped("outpost_auto")

Spawn(UnitDef("corsolar"), "gaia")
	.At(0.45, 0.44)
	.Grouped("outpost_auto")

-- Beats 4 and 6, the Armada enclave: spotting the device closes
-- find_the_enclave; killing the commander wins through matchflow.

Spawn(UnitDef("armfus"), "enemy")
	.At(0.75, 0.75)
	.Named("tenebrium_device")

Spawn(UnitDef("armcom"), "enemy")
	.At(0.77, 0.77)
	.Named("armada_commander")

Spawn(UnitDef("armllt"), "enemy")
	.At(0.73, 0.75)

Spawn(UnitDef("armllt"), "enemy")
	.At(0.75, 0.73)
