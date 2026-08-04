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

		onCaptureProgress = function(unitID, x, y, z)
			Spring.SpawnCEG("scaspawn-trail", x, y, z, 0, 0, 0)
			if GG.ScavengersSpawnEffectUnitID then
				GG.ScavengersSpawnEffectUnitID(unitID)
			end
			if math.random() <= 0.1 then
				Spring.SpawnCEG("scavmist", x, y + 100, z, 0, 0, 0)
			end
		end,

		onCapturing = function(_, x, y, z)
			Spring.SpawnCEG("scavmist", x, y + 100, z, 0, 0, 0)
			Spring.SpawnCEG("scavradiation", x, y + 100, z, 0, 0, 0)
			if GG.SpawnEnvironmentalLightning then
				GG.SpawnEnvironmentalLightning("scavradiation", x, y + 100, z)
			else
				Spring.SpawnCEG("scavradiation-lightning", x, y + 100, z, 0, 0, 0)
			end
		end,

		onCaptured = function(unitID)
			if GG.ScavengersSpawnEffectUnitID then
				GG.ScavengersSpawnEffectUnitID(unitID)
			end
		end,

		onCycleComplete = function(state)
			config.bossName = state.params.bossName
			config.bossResistanceMult = state.params.bossResistanceMult
			config.bossStagger = state.params.bossStagger
		end,

		-- divided by how many of that def are alive, so a swarm of spawners does not multiply
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
