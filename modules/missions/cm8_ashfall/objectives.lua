local Units = VFS.Include("modules/missions/cm8_ashfall/units.lua")

-- Declaration order decides what the player SEES (reveal cadence), never what
-- counts: a completion is gated only where a When says so.
local protect = Objective("protect_the_commander").Title("Protect your Commander").RevealedWhen(MatchFlow.Started())

-- Spotting gates the build condition so four towers at home do not count as a
-- rescue. Placeholder until the DSL has a proximity condition.
local relieve = Objective("relieve_the_outpost")
	.Title("Relieve the outpost")
	.CompletedWhen(Units.hub.IsSpotted(Team.Player))
	.When(Team.Player.Has(Units.corllt, 4))

-- Gated on the relief so a latched early sighting cannot finish a line the
-- story has not asked yet. A radar-dot bombardment never enters LOS, and what
-- you blew up, you found.
local enclave = Objective("find_the_enclave")
	.Title("Find the Enclave")
	.CompletedWhen(Units.beacon.IsSpotted(Team.Player))
	.CompletedWhen(Units.beacon.IsDestroyed())
	.When(relieve.IsComplete())

local device = Objective("find_the_tenebrium_device")
	.Title("Find the Tenebrium device")
	.CompletedWhen(Units.device.IsSpotted(Team.Player))
	.CompletedWhen(Units.device.IsDestroyed())
	.When(enclave.IsComplete())

-- Ungated: an early commander snipe counts the moment it happens.
local kill =
	Objective("kill_the_commander").Title("Kill the enemy commander").CompletedWhen(Units.armadaCommander.IsDestroyed())

return { protect = protect, relieve = relieve, enclave = enclave, device = device, kill = kill }
