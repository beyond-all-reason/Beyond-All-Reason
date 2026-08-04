
local Structures = {}

local PLACEMENT_ATTEMPTS = 5
local BUILD_ATTEMPTS = 10
local FLAT_TOLERANCE = 30

---@param deps { positionChecks: table }
---@return table
function Structures.New(deps)
	local checks = deps.positionChecks
	local mRandom = math.random
	local MAPSIZEX = Game.mapSizeX
	local MAPSIZEZ = Game.mapSizeZ

	local structures = {}

	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param defName UnitDefName
	---@param entry WaveStructureEntry
	---@param spread number
	---@return integer|nil unitID, number|nil x, number|nil y, number|nil z
	structures.SpawnOne = function(spec, state, defName, entry, spread)
		local ok = false
		local x, y, z
		spread = spread or 128

		if spec.burrows.useScum and GG.IsPosInRaptorScum then
			-- Creep is the footprint: structures mark territory the director
			-- already holds, they do not claim new ground.
			if spread < MAPSIZEX - spread and spread < MAPSIZEZ - spread then
				for _ = 1, PLACEMENT_ATTEMPTS do
					x = mRandom(spread, MAPSIZEX - spread)
					z = mRandom(spread, MAPSIZEZ - spread)
					y = Spring.GetGroundHeight(x, z)
					ok = checks.FlatAreaCheck(x, y, z, spread, FLAT_TOLERANCE, true)
						and checks.OccupancyCheck(x, y, z, spread)
						and GG.IsPosInRaptorScum(x, y, z)
						and checks.VisibilityCheckEnemy(x, y, z, spread, spec.allyTeamID, true, true, true)
					if ok then
						break
					end
				end
			end
		else
			-- No creep: the director's own vision is the territory, and the
			-- players' sensors are the safety zone.
			local box = state.spawnBox
			for _ = 1, PLACEMENT_ATTEMPTS do
				x = mRandom(box.x1 + spread, box.x2 - spread)
				z = mRandom(box.z1 + spread, box.z2 - spread)
				y = Spring.GetGroundHeight(x, z)
				-- The last check is reversed on purpose: that one must be INSIDE
				-- the director's line of sight, and the check answers "not in".
				ok = checks.FlatAreaCheck(x, y, z, spread, FLAT_TOLERANCE, true)
					and checks.OccupancyCheck(x, y, z, spread)
					and checks.VisibilityCheckEnemy(x, y, z, spread, spec.allyTeamID, true, true, true)
					and not checks.VisibilityCheck(x, y, z, spread, spec.allyTeamID, true, false, false)
				if ok then
					break
				end
			end
		end

		if ok and ((entry.surface == "land" and y <= 0) or (entry.surface == "sea" and y > 0)) then
			ok = false
		end
		if not ok then
			return nil
		end

		local unitID = Spring.CreateUnit(defName, x, y, z, mRandom(0, 3), spec.teamID)
		if unitID then
			Spring.SetUnitBlocking(unitID, false, false)
			return unitID, x, y, z
		end
		return nil
	end

	---Weighted by grace progress so the map does not sprout turrets in the first minute.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number game seconds
	---@param onSpawned fun(unitID: integer)|nil
	structures.SpawnWave = function(spec, state, t, onSpawned)
		if spec.structures == nil then
			return
		end
		local anger = state.shape.techAnger
		local names = {}
		for name in pairs(spec.structures) do
			names[#names + 1] = name
		end
		table.sort(names)

		for _, defName in ipairs(names) do
			local entry = spec.structures[defName]
			local maxAnger = entry.maxAnger or (entry.minAnger + 100)
			local unitDef = UnitDefNames[defName]
			if unitDef ~= nil and entry.minAnger <= anger and maxAnger >= anger then
				local perWave = Structures.PerPlayer(entry.spawnedPerWave, state.params, 8)
				local maxExisting = Structures.PerPlayer(entry.maxExisting, state.params, 8)
				local allowed = Structures.Allowance(maxExisting, anger, entry.minAnger, maxAnger)
				local gate = state.params.spawnChance * math.min(t / state.params.gracePeriod, 1)

				for i = 1, math.ceil(perWave) do
					local fractional = i <= perWave or mRandom() <= perWave % 1
					if
						fractional
						and mRandom() < gate
						and Spring.GetTeamUnitDefCount(spec.teamID, unitDef.id) <= allowed
					then
						-- The engine's xsize/zsize are in half-footprints; the
						-- *4 is that conversion, plus a margin.
						local footprint = 128
						if unitDef.xsize and unitDef.zsize then
							footprint = (unitDef.xsize + unitDef.zsize) * 4
						end
						local attempts = 0
						local unitID
						repeat
							attempts = attempts + 1
							local id, x, y, z = structures.SpawnOne(spec, state, defName, entry, footprint + 32)
							unitID = id
							if unitID then
								if onSpawned then
									onSpawned(unitID)
								end
								-- Factories rally out; everything else patrols
								-- its own patch so it does not stand blind.
								if unitDef.isFactory then
									Spring.GiveOrderToUnit(
										unitID,
										CMD.FIGHT,
										{ x + mRandom(-256, 256), y, z + mRandom(-256, 256) },
										{ "meta" }
									)
								else
									Spring.GiveOrderToUnit(
										unitID,
										CMD.PATROL,
										{ x + mRandom(-128, 128), y, z + mRandom(-128, 128) },
										{ "meta" }
									)
								end
							end
						until unitID or attempts > BUILD_ATTEMPTS
					end
				end
			end
		end
	end

	return structures
end
---@param base number
---@param params WaveParams
---@param cap integer
---@return number
function Structures.PerPlayer(base, params, cap)
	local teams = math.min(params.teamCount, cap)
	return (base * (1 - params.perPlayerMultiplier)) + (base * params.perPlayerMultiplier) * teams
end

---@param maxExisting number
---@param anger number
---@param minAnger number
---@param maxAnger number
---@return integer
function Structures.Allowance(maxExisting, anger, minAnger, maxAnger)
	if anger > 100 then
		return math.ceil(maxExisting * (anger * 0.01))
	end
	local span = math.min(100 - minAnger, maxAnger - minAnger)
	if span <= 0 then
		return math.ceil(maxExisting)
	end
	return math.ceil(maxExisting * ((anger - minAnger) / span))
end

return Structures
