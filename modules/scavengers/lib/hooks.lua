--- The flavor half of the seam: what the director calls when it reaches a
--- moment only scavengers have an opinion about.
---
--- Shared by both paths on purpose. The multiplayer gadget and a mission's
--- scripted pressure run the SAME director with the SAME hooks — the only
--- difference between them is which spec was handed over and who asked. A
--- mission that got a quieter version of the scavengers would not be a test
--- of the scavengers.
---
--- Everything reachable through GG is checked before use: the boss gadget and
--- the spawn-effect gadget are present in a scavengers game and absent in a
--- mission, and a hook that assumed either would take the mission path down.

local Hooks = {}

---@param config table what defs_build produced
---@param behaviourByID table<integer, WaveBehaviour>
---@param counters { commanders: integer, decoys: integer }|nil population tallies the caller keeps
---@return WaveHooks
function Hooks.New(config, behaviourByID, counters)
	return {
		---@param defID integer
		behaviourOf = function(defID)
			return behaviourByID[defID]
		end,

		---A fresh beacon is an event: the flash and the crater are how a
		---player learns where the next wave will come from.
		onBurrowSpawned = function(_, x, y, z)
			Spring.SpawnCEG("commander-spawn-alwaysvisible", x, y, z, 0, 0, 0)
			if GG.SpawnEnvironmentalLightning then
				GG.SpawnEnvironmentalLightning("commanderspawn", x, y, z)
			end
			Spring.PlaySoundFile("commanderspawn-mono", 0.15, x, y, z, 0, 0, 0, "sfx")
			if GG.ComSpawnDefoliate then
				GG.ComSpawnDefoliate(x, y, z)
			end
		end,

		---A unit reached the field. Firestate, cloak and the spawn effect are
		---what make a scavenger look and behave like one whatever spawned it.
		---@param unitID integer
		---@param defName UnitDefName
		onUnitSpawned = function(unitID, defName)
			local unitDef = UnitDefNames[defName]
			if unitDef == nil then
				return
			end
			Spring.GiveOrderToUnit(unitID, CMD.FIRE_STATE, { config.defaultScavFirestate }, 0)
			if GG.ScavengersSpawnEffectUnitID then
				GG.ScavengersSpawnEffectUnitID(unitID)
			end
			if unitDef.canCloak then
				-- CMD_CLOAK_SHIELD, from customcmds.
				Spring.GiveOrderToUnit(unitID, 37382, { 1 }, 0)
			end
			if counters == nil then
				return
			end
			if config.squadSpawnOptionsTable.commanders[defName] then
				counters.commanders = counters.commanders + 1
			elseif config.squadSpawnOptionsTable.decoyCommanders[defName] then
				counters.decoys = counters.decoys + 1
			end
		end,

		---A boss landed. The boss gadget is dormant until this fires; a
		---mission without one simply has a boss with no stagger machine.
		onBossSpawned = function(bossID)
			if GG.Scavengers and GG.Scavengers.OnBossSpawned then
				GG.Scavengers.OnBossSpawned(bossID)
			end
		end,

		---Endless mode moved a rung: the next cycle's boss, its resistance
		---multiplier and its stagger bank all change with it.
		onCycleComplete = function(state)
			config.bossName = state.params.bossName
			config.bossResistanceMult = state.params.bossResistanceMult
			config.bossStagger = state.params.bossStagger
			if GG.Scavengers and GG.Scavengers.OnCycleComplete then
				GG.Scavengers.OnCycleComplete()
			end
		end,

		---Minions: a spawner unit occasionally throws out a handful of its
		---own. The chance is divided by how many of that def are already
		---alive, so a swarm of spawners does not multiply.
		---@param unitID integer
		---@param defID integer
		---@param state WaveDirectorState
		onUnitTick = function(unitID, defID, state)
			local minions = config.scavMinions[UnitDefs[defID].name]
			if minions == nil or GG.Waves == nil then
				return
			end
			local team = Spring.GetUnitTeam(unitID)
			local alive = math.max(1, Spring.GetTeamUnitDefCount(team, defID))
			if math.random(1, math.ceil(33 * alive)) == 1 and math.random() < config.spawnChance then
				GG.Waves.SpawnNamed(state.name, unitID, minions[math.random(1, #minions)], 4)
			end
		end,
	}
end

return Hooks
