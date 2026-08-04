
local Drain = {}

local MAX_SPAWN_TRIES = 30

---@class WaveBehaviour
---@field role string|nil the squad role this def forces
---@field minLife integer|nil a floor on the squad's lifetime, in waves
---@field regroup boolean|nil false keeps the squad from bunching up

---@param deps { squads: table }
---@return table
function Drain.New(deps)
	local Squads = deps.squads
	local mRandom = math.random
	local MAPSIZEX = Game.mapSizeX
	local MAPSIZEZ = Game.mapSizeZ

	local drain = {}

	---The square grows every failed try, so the twentieth unit of a wave stands further out than the
	---first — which is the visual of a wave pouring out.
	---@param spec WaveSpec
	---@param burrowID integer
	---@param unitDefID integer
	---@return number|nil x, number|nil y, number|nil z
	drain.SpawnLocation = function(spec, burrowID, unitDefID)
		local bx, by, bz = Spring.GetUnitPosition(burrowID)
		if not bx or not bz then
			return nil
		end
		local size = spec.burrows.spawnSquare
		local tries = 0
		local x, z
		repeat
			x = mRandom(bx - size, bx + size)
			z = mRandom(bz - size, bz + size)
			size = size + spec.burrows.spawnSquareIncrement
			tries = tries + 1
			if x >= MAPSIZEX then
				x = MAPSIZEX - mRandom(1, 40)
			elseif x <= 0 then
				x = mRandom(1, 40)
			end
			if z >= MAPSIZEZ then
				z = MAPSIZEZ - mRandom(1, 40)
			elseif z <= 0 then
				z = mRandom(1, 40)
			end
		until (Spring.TestBuildOrder(unitDefID, x, by, z, 1) == 2 and not Spring.GetGroundBlocked(x, z))
			or tries > MAX_SPAWN_TRIES
		return x, Spring.GetGroundHeight(x, z), z
	end

	---Veterancy, scaled by how close the boss is: the last wave before the
	---boss arrives already fights like it.
	---@param state WaveDirectorState
	---@param unitID integer
	drain.SetExperience = function(state, unitID)
		local ceiling = math.ceil((state.anger.bossAnger * 0.01) * state.params.maxXP * 1000)
		Spring.SetUnitExperience(unitID, mRandom(0, math.max(0, ceiling)) * 0.001)
	end

	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param defName UnitDefName
	local function applyBehaviour(spec, state, defName)
		local pending = state.pendingSquad
		local unitDef = UnitDefNames[defName]
		if unitDef == nil then
			return
		end
		local pace = state.params.spawnTimeMultiplier or 1
		---@param waves number unscaled lifetime floor, in waves
		local function raiseLife(waves)
			local floor = math.ceil(waves * pace)
			if pending.life < floor then
				pending.life = floor
			end
		end

		local behaviour = spec.hooks.behaviourOf and spec.hooks.behaviourOf(unitDef.id) or nil
		if behaviour ~= nil and behaviour.role ~= nil then
			pending.role = behaviour.role
			if behaviour.regroup == false then
				pending.regroupEnabled = false
			end
			if behaviour.minLife ~= nil then
				raiseLife(behaviour.minLife)
			end
		end

		-- Aircraft is not a flavor decision: an air squad that regroups on the
		-- ground is a dead air squad, whatever roster it came from.
		if unitDef.canFly then
			pending.role = "aircraft"
			pending.regroupEnabled = false
			raiseLife(100)
		end
	end

	---Pop the queue until one squad is finished, then stop. Called on the
	---fast cadence; "one squad per call" is what paces the trickle.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param onSpawned fun(unitID: integer, entry: WaveQueueEntry)
	drain.Run = function(spec, state, onSpawned)
		local squadDone = false
		repeat
			local entry = state.spawnQueue[1]
			if entry == nil then
				-- Queue empty: whatever is half-assembled becomes a squad now,
				-- or it would sit there until the next wave adopted it.
				if #state.pendingSquad.units > 0 then
					if mRandom(1, 5) == 1 then
						state.pendingSquad.regroupEnabled = false
					end
					local squadID = Squads.Create(spec, state, state.pendingSquad)
					Squads.Refresh(spec, state, squadID)
				end
				return
			end
			table.remove(state.spawnQueue, 1)

			local unitDef = UnitDefNames[entry.unitName]
			if unitDef == nil then
				Spring.Log("waves", LOG.WARNING, "no such unit def: " .. tostring(entry.unitName))
			else
				local x, y, z = drain.SpawnLocation(spec, entry.burrow, unitDef.id)
				if x ~= nil then
					local unitID = Spring.CreateUnit(entry.unitName, x, y, z, mRandom(0, 3), entry.team)
					if unitID then
						-- squadID 1 closes the previous squad. Without this the
						-- whole wave would be one squad with one target.
						if entry.squadID == nil or entry.squadID == 1 then
							if #state.pendingSquad.units > 0 then
								Squads.Create(spec, state, state.pendingSquad)
								squadDone = true
							end
						end
						local pending = state.pendingSquad
						if entry.burrow and pending.burrow == nil then
							pending.burrow = entry.burrow
						end
						pending.units[#pending.units + 1] = unitID
						applyBehaviour(spec, state, entry.unitName)
						if entry.alwaysVisible then
							Spring.SetUnitAlwaysVisible(unitID, true)
						end
						drain.SetExperience(state, unitID)
						onSpawned(unitID, entry)
					end
				end
			end
		until squadDone
	end

	return drain
end

return Drain
