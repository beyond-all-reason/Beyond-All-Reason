local triggerTypes = GG['MissionAPI'].TriggerDefinitions.Types
local actionTypes = GG['MissionAPI'].ActionDefinitions.Types

--- Covers UnitDetected and UnitUndetected across every sensor level and filter.
---
--- Detection levels escalate: unseen -> seismic -> radar -> vision, and a unit sits at
--- exactly one of them per allyTeam. A trigger without sensorTypes watches all of them,
--- so it reports first contact and total loss. A trigger with sensorTypes watches a
--- subset, so a unit that *improves* from radar to vision leaves a radar-only trigger
--- and reads as undetected there. Both behaviours are exercised below.
---
--- Player sensors (allyTeam 0), placed ~2900 apart so no target sits in two at once:
---   armsd  at (1800, 1800)  seismic 2000, sight 240, no radar
---   armrad at (4700, 2000)  radar 2100, sight  680
--- A fusion plant backs each side: armsd draws upkeep, and the spy needs energy to
--- stay cloaked while it moves.
---
--- Targets (team 1):
---   spy          armspy, cloaked. stealth = true keeps it off radar and cloak keeps it
---                out of vision, so seismic is the only level that can ever see it. This
---                is what armsd exists for. cornecro is also stealth = true, but its
---                seismicsignature is 0, so armsd would never hear it.
---   radarTarget  corfast, parked inside radar range but outside armrad's sight.
---   visionTarget corfast, driven all the way into armrad's sight.
---   deathTarget  corak, spawned inside radar and destroyed there without ever moving.
---
--- Triggers whose message starts with "BUG:" are canaries and must never fire.

local triggers = {

	----------------------------------------------------------------
	--- Setup ------------------------------------------------------

	placeSensors = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 1 },
		actions = { 'spawnSensors', 'spawnEnergy' },
	},

	-- Targets start outside every sensor, so each one produces a real unseen -> detected edge.
	placeTargets = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 3 },
		actions = { 'spawnTargets' },
	},

	-- Each target drives in and straight back out on one queued pair of moves, so the
	-- detect and undetect edges come from travel rather than from a second timer.
	sendTargets = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 6 },
		actions = { 'moveSpy', 'moveRadarTarget', 'moveVisionTarget' },
	},

	-- Late enough that deathTarget has certainly been detected, early enough that it dies
	-- while still held on radar rather than after drifting off sensors.
	killDeathTarget = {
		type = triggerTypes.TimeElapsed,
		parameters = { seconds = 25 },
		actions = { 'destroyDeathTarget' },
	},

	----------------------------------------------------------------
	--- Any sensor: sensorTypes omitted ----------------------------

	-- Watches every level but unseen, so this is first contact and total loss.
	anyDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageAnyDetected' },
	},

	anyUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'radarTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageAnyUndetected' },
	},

	----------------------------------------------------------------
	--- Radar ------------------------------------------------------

	radarDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'radar' },
		},
		actions = { 'messageRadarDetected' },
	},

	-- The target never enters armrad's sight, so this is a genuine loss of contact and
	-- should land in the same frame as anyUndetected.
	radarUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'radarTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'radar' },
		},
		actions = { 'messageRadarUndetected' },
	},

	----------------------------------------------------------------
	--- Vision -----------------------------------------------------

	visionDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'vision' },
		},
		actions = { 'messageVisionDetected' },
	},

	-- Fires as the target leaves armrad's sight, while it is still on radar. "Undetected by
	-- vision" means "no longer at the vision level", not "gone".
	visionUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'vision' },
		},
		actions = { 'messageVisionUndetected' },
	},

	----------------------------------------------------------------
	--- Seismic ----------------------------------------------------

	-- Seismic pings need a *moving* ground unit, which the drive in and out provides.
	-- Falloff is scored over half-second intervals, so the undetect lands a few seconds
	-- after the spy leaves the ring.
	seismicDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'spy',
			sensorAllyTeam = 0,
			sensorTypes = { 'seismic' },
		},
		actions = { 'messageSeismicDetected' },
	},

	seismicUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'spy',
			sensorAllyTeam = 0,
			sensorTypes = { 'seismic' },
		},
		actions = { 'messageSeismicUndetected' },
	},

	----------------------------------------------------------------
	--- A mask of several sensors ----------------------------------

	-- The target enters radar and then improves to vision. Both levels are inside this
	-- mask, so the improvement is not a boundary: this fires once going in and once going
	-- out, unlike the vision-only pair above.
	radarOrVisionDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'radar', 'vision' },
		},
		actions = { 'messageRadarOrVisionDetected' },
	},

	radarOrVisionUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'radar', 'vision' },
		},
		actions = { 'messageRadarOrVisionUndetected' },
	},

	-- A mask with a hole in it. The target passes through radar on its way to vision and
	-- again on its way out, and radar sits between the two watched levels. If the mask were
	-- ever treated as a range rather than a set, these would behave like the omitted pair
	-- below; instead they must match the vision-only pair, ignoring both radar crossings.
	seismicOrVisionDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'seismic', 'vision' },
		},
		actions = { 'messageSeismicOrVisionDetected' },
	},

	seismicOrVisionUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'seismic', 'vision' },
		},
		actions = { 'messageSeismicOrVisionUndetected' },
	},

	----------------------------------------------------------------
	--- Climbing and dropping inside one mask ----------------------

	-- The same target as the pairs above, but watching every level. Omitting sensorTypes
	-- watches seismic, radar and vision at once, so the climb from radar to vision and the
	-- drop back to radar are both movement *within* the mask and neither is an edge. This
	-- pair must fire exactly twice for the whole run: once on first contact and once when
	-- the target leaves every sensor. A drop to a lower level is not an undetection.
	anyLevelDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageAnyLevelDetected' },
	},

	anyLevelUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'visionTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageAnyLevelUndetected' },
	},

	----------------------------------------------------------------
	--- Death is not a loss of detection ---------------------------

	-- Spawned already inside radar and never moved, so it is detected on the first sweep.
	deathDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'deathTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageDeathDetected' },
	},

	-- Canary: the unit is destroyed while still detected. The engine treats death as death,
	-- not as a sensor edge, so the latch is dropped without reporting and this must not fire.
	-- messageDeathDetected proves the unit really was detected, so this silence means
	-- something.
	deathUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'deathTarget',
			sensorAllyTeam = 0,
		},
		actions = { 'messageDeathUndetected' },
	},

	----------------------------------------------------------------
	--- Filters ----------------------------------------------------

	-- No sensorAllyTeam: any allyTeam other than the unit's own may detect it. The owner is
	-- skipped, because an allyTeam always has vision of its own units. For an enemy target
	-- that leaves the player's sensors, so these should agree with the anyDetected pair.
	unscopedDetected = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
		},
		actions = { 'messageUnscopedDetected' },
	},

	unscopedUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'radarTarget',
		},
		actions = { 'messageUnscopedUndetected' },
	},

	owningTeamMatches = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			owningTeamID = 1,
			sensorAllyTeam = 0,
		},
		actions = { 'messageOwningTeamMatches' },
	},

	-- The filters apply to UnitUndetected exactly as they do to UnitDetected.
	owningTeamUndetected = {
		type = triggerTypes.UnitUndetected,
		parameters = {
			unitName = 'radarTarget',
			owningTeamID = 1,
			sensorAllyTeam = 0,
		},
		actions = { 'messageOwningTeamUndetected' },
	},

	-- Canary: the target belongs to team 1, so filtering on team 0 must never fire.
	owningTeamExcludes = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			owningTeamID = 0,
			sensorAllyTeam = 0,
		},
		actions = { 'messageOwningTeamExcludes' },
	},

	-- Both name filters at once: they must agree on the same unit.
	bothNameFilters = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			unitDefName = 'corfast',
			sensorAllyTeam = 0,
		},
		actions = { 'messageBothNameFilters' },
	},

	-- requiresOneOf is satisfied by unitDefName alone. Both corfast targets match, so this
	-- reports whichever of them is detected first.
	unitDefNameOnly = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitDefName = 'corfast',
			sensorAllyTeam = 0,
		},
		actions = { 'messageUnitDefNameOnly' },
	},

	-- Canary: no armpw is ever spawned, so a unitDefName filter on one must never match.
	unitDefNameExcludes = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitDefName = 'armpw',
			sensorAllyTeam = 0,
		},
		actions = { 'messageUnitDefNameExcludes' },
	},

	-- Canary: the radar target never comes within 3300 of armsd, whose ring is 2000, and it
	-- holds radar the whole time it is on any sensor at all. A sensorTypes set must reject
	-- the levels it does not name, so watching seismic alone must never see this unit.
	wrongSensorExcludes = {
		type = triggerTypes.UnitDetected,
		parameters = {
			unitName = 'radarTarget',
			sensorAllyTeam = 0,
			sensorTypes = { 'seismic' },
		},
		actions = { 'messageWrongSensorExcludes' },
	},
}

local actions = {

	----------------------------------------------------------------
	--- Setup ------------------------------------------------------

	spawnSensors = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armsd', x = 1800, z = 1800, team = 0 },
				{ unitDefName = 'armrad', x = 4700, z = 2000, team = 0 },
			},
		},
	},

	spawnEnergy = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armfus', x = 1800, z = 1600, team = 0 },
				{ unitDefName = 'armfus', x = 3900, z = 6000, team = 1 },
			},
		},
	},

	spawnTargets = {
		type = actionTypes.SpawnUnits,
		parameters = {
			unitLoadout = {
				{ unitDefName = 'armspy', x = 1800, z = 4600, team = 1, unitName = 'spy' },
				{ unitDefName = 'corfast', x = 4500, z = 4900, team = 1, unitName = 'radarTarget' },
				{ unitDefName = 'corfast', x = 4900, z = 4900, team = 1, unitName = 'visionTarget' },
				-- 1600 from armrad: inside radar 2100, outside sight 680, and 3400 from
				-- armsd so it is out of seismic. Detected where it stands, then destroyed.
				{ unitDefName = 'corak', x = 4700, z = 3600, team = 1, unitName = 'deathTarget' },
			},
		},
	},

	destroyDeathTarget = {
		type = actionTypes.DestroyUnits,
		parameters = { unitName = 'deathTarget' },
	},

	----------------------------------------------------------------
	--- Movement ---------------------------------------------------

	-- Spawned 2800 from armsd, turns at 1500: inside seismic 2000, far outside its
	-- sight of 240. Cloak is a state command, so it does not take a queue slot.
	moveSpy = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'spy',
			orders = {
				{ CMD.CLOAK, 1 },
				{ CMD.MOVE, { 1800, 0, 3300 } },
				{ CMD.MOVE, { 1800, 0, 4600 }, { 'shift' } },
			},
		},
	},

	-- Spawned 2900 from armrad, turns at 1400: inside radar 2100 but outside sight 680,
	-- so it never reaches the vision level.
	moveRadarTarget = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'radarTarget',
			orders = {
				{ CMD.MOVE, { 4700, 0, 3400 } },
				{ CMD.MOVE, { 4500, 0, 4900 }, { 'shift' } },
			},
		},
	},

	-- Spawned 2900 from armrad, turns at 500: crosses radar on the way in and ends up
	-- inside sight 680, so it reaches the vision level and drops back through radar.
	moveVisionTarget = {
		type = actionTypes.IssueOrders,
		parameters = {
			unitName = 'visionTarget',
			orders = {
				{ CMD.MOVE, { 4700, 0, 2500 } },
				{ CMD.MOVE, { 4900, 0, 4900 }, { 'shift' } },
			},
		},
	},

	----------------------------------------------------------------
	--- Messages ---------------------------------------------------

	messageAnyDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by any sensor: radar target made first contact." },
	},

	messageAnyUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by any sensor: radar target contact lost entirely." },
	},

	messageRadarDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by radar." },
	},

	messageRadarUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by radar: left radar range." },
	},

	messageVisionDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by vision." },
	},

	messageVisionUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by vision: dropped to radar, still on sensors." },
	},

	messageSeismicDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by seismic: cloaked spy heard while moving." },
	},

	messageSeismicUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by seismic: spy left the ring and fell off." },
	},

	messageRadarOrVisionDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by radar or vision: entered the mask at radar." },
	},

	messageRadarOrVisionUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by radar or vision: left both, not merely one." },
	},

	messageSeismicOrVisionDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by seismic or vision: a mask with radar missing from the middle." },
	},

	messageSeismicOrVisionUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected by seismic or vision: dropped into the unwatched radar level." },
	},

	messageAnyLevelDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected watching every level: first contact at radar." },
	},

	messageAnyLevelUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected watching every level: only after leaving all of them." },
	},

	messageDeathDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected the target that will be destroyed while detected." },
	},

	messageDeathUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "BUG: destroying a detected unit reported a loss of detection." },
	},

	messageUnscopedDetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected without a sensorAllyTeam: seen by a non-owning allyTeam." },
	},

	messageUnscopedUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected without a sensorAllyTeam." },
	},

	messageOwningTeamMatches = {
		type = actionTypes.SendMessage,
		parameters = { message = "owningTeamID matched the target's team." },
	},

	messageOwningTeamUndetected = {
		type = actionTypes.SendMessage,
		parameters = { message = "Undetected with an owningTeamID filter." },
	},

	messageOwningTeamExcludes = {
		type = actionTypes.SendMessage,
		parameters = { message = "BUG: owningTeamID filter let through a unit of another team." },
	},

	messageBothNameFilters = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected with unitName and unitDefName both filtering." },
	},

	messageUnitDefNameOnly = {
		type = actionTypes.SendMessage,
		parameters = { message = "Detected by unitDefName alone, without a unitName." },
	},

	messageUnitDefNameExcludes = {
		type = actionTypes.SendMessage,
		parameters = { message = "BUG: unitDefName filter matched a unit def that was never spawned." },
	},

	messageWrongSensorExcludes = {
		type = actionTypes.SendMessage,
		parameters = { message = "BUG: a seismic-only trigger reported a unit held on radar." },
	},
}

return {
	Triggers = triggers,
	Actions = actions,
}
