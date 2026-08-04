-- Positions are map fractions so the mission plays on any test map.
local corllt = UnitDef("corllt")
local corsolar = UnitDef("corsolar")

-- Neutral because gaia is hostile to everyone, and an abandoned base would open
-- fire on the player sent to discover it.
local outpost = Group("outpost_auto")
local hub = Spawn(UnitDef("corlab"), "gaia").At(0.42, 0.42).Named("outpost_command_hub").Grouped(outpost).Neutral()
Spawn(corllt, "gaia").At(0.39, 0.40).Grouped(outpost).Neutral()
Spawn(corllt, "gaia").At(0.45, 0.40).Grouped(outpost).Neutral()
Spawn(UnitDef("corrad"), "gaia").At(0.42, 0.39).Grouped(outpost).Neutral()
Spawn(corsolar, "gaia").At(0.39, 0.44).Grouped(outpost).Neutral()
Spawn(corsolar, "gaia").At(0.45, 0.44).Grouped(outpost).Neutral()

local beacon = Spawn(UnitDef("armrad"), "enemy").At(0.72, 0.72).Named("enclave_beacon")
local device = Spawn(UnitDef("armfus"), "enemy").At(0.75, 0.75).Named("tenebrium_device")
-- Claimed, not spawned: in a skirmish the enemy seat already has a commander,
-- and a second one leaves the mission with the wrong one to kill.
local armadaCommander = Claim(UnitDef("armcom"), "enemy").Named("armada_commander").OrSpawnAt(0.77, 0.77)
local playerCommander = Claim(UnitDef("corcom"), "player").Named("player_commander").OrSpawnAt(0.15, 0.15)
Spawn(UnitDef("armllt"), "enemy").At(0.73, 0.75)
Spawn(UnitDef("armllt"), "enemy").At(0.75, 0.73)

return {
	corllt = corllt,
	outpost = outpost,
	hub = hub,
	beacon = beacon,
	device = device,
	armadaCommander = armadaCommander,
	playerCommander = playerCommander,
}
