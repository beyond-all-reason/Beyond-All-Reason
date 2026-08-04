
local Placement = {}

local MAX_TRIES = 30
-- A director that cannot place says so a few times, then stops: this runs on
-- the slow tick and the retry widens the box under it.
local MAX_PLACEMENT_WARNINGS = 3
local FLAT_TOLERANCE = 30
local MIN_BOX_SIDE = 512
-- How far a NAMED origin may be widened, as a fraction of the map per side.
-- A quarter per side is half the map: enough slack that a corner of bad
-- ground does not stop the pressure, and still firmly the half the mission
-- pointed at. Past this the box would reach the far side of the map and
-- "from the northeast" would be describing beacons arriving from anywhere.
local MAX_ORIGIN_HALF = 0.25
-- Failed cadences to sit through before widening at all, whatever the grace
-- period works out to. Placement failures are often transient — a unit walks
-- out of the spot, a scout's LOS moves on — and widening is permanent.
local MIN_ORIGIN_RETRIES = 2

---@param deps { positionChecks: table, enemyLib: table, mapSizeX: number, mapSizeZ: number, nearestValid: fun(x: number, z: number, opts: table): number|nil, number|nil, number|nil, string|nil }
---@return table
function Placement.New(deps)
	local checks = deps.positionChecks
	local enemyLib = deps.enemyLib
	local nearestValid = deps.nearestValid
	local MAPSIZEX = deps.mapSizeX
	local MAPSIZEZ = deps.mapSizeZ
	local mRandom = math.random

	local placement = {}

	---team with no box at all (or one covering the map) falls back to "avoid
	---players", because "spawn in your box" and "the box is the map" would put
	---burrows on top of the people playing.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	placement.InitialBox = function(spec, state)
		local x1, z1, x2, z2
		if state.startBox ~= nil then
			-- Already resolved, and possibly WIDENED by a caller that could
			-- not place anything. Re-deriving here would quietly undo that and
			-- leave the retry probing the same ground forever.
			local box = state.startBox
			x1, z1, x2, z2 = box.x1, box.z1, box.x2, box.z2
		elseif spec.burrows.box ~= nil then
			-- An explicit box: a mission says where its pressure comes from,
			-- and a mission's director has no start box to be adjusted.
			local box = spec.burrows.box
			x1, z1, x2, z2 = box.x1, box.z1, box.x2, box.z2
		else
			x1, z1, x2, z2 = enemyLib.GetAdjustedStartBox(spec.allyTeamID, spec.burrows.size * 1.5)
		end
		state.startBox = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }

		local mode = state.params.placement
		if mode == "initialbox" or mode == "alwaysbox" or mode == "initialbox_post" then
			local noBox = not x1 or not z1 or not x2 or not z2
			local wholeMap = not noBox and x1 == 0 and z1 == 0 and x2 == MAPSIZEX and z2 == MAPSIZEX
			if noBox or wholeMap then
				state.params.placement = "avoid"
				state.noStartBox = true
			end
		end

		state.spawnBox = {
			x1 = x1 or 0,
			z1 = z1 or 0,
			x2 = x2 or MAPSIZEX,
			z2 = z2 or MAPSIZEZ,
		}
	end

	---@param box { x1: number, z1: number, x2: number, z2: number }
	---@param multiplier number the retry round; 2 is the first widening
	---@return { x1: number, z1: number, x2: number, z2: number }
	placement.WidenBox = function(box, multiplier)
		local centreX = (box.x1 + box.x2) * 0.5
		local centreZ = (box.z1 + box.z2) * 0.5
		local halfX = (box.x2 - box.x1) * 0.5 * math.max(1, multiplier - 1)
		local halfZ = (box.z2 - box.z1) * 0.5 * math.max(1, multiplier - 1)
		halfX = math.min(halfX, MAPSIZEX * MAX_ORIGIN_HALF)
		halfZ = math.min(halfZ, MAPSIZEZ * MAX_ORIGIN_HALF)
		return {
			x1 = math.max(0, centreX - halfX),
			z1 = math.max(0, centreZ - halfZ),
			x2 = math.min(MAPSIZEX, centreX + halfX),
			z2 = math.min(MAPSIZEZ, centreZ + halfZ),
		}
	end

	---The growing box: one percent of the map per point of anger, out of the
	---start box in every direction. It is the pacing device that keeps early
	---burrows close to home and late ones anywhere.
	---@param state WaveDirectorState
	---@param techAnger number
	placement.UpdateBox = function(state, techAnger)
		local mode = state.params.placement
		if mode ~= "initialbox_post" and mode ~= "initialbox" then
			return
		end
		local start = state.startBox
		if start == nil or start.x1 == nil then
			return
		end
		local reach = techAnger + 15
		local box = {
			x1 = math.max(start.x1 - ((MAPSIZEX * 0.01) * reach), 0),
			z1 = math.max(start.z1 - ((MAPSIZEZ * 0.01) * reach), 0),
			x2 = math.min(start.x2 + ((MAPSIZEX * 0.01) * reach), MAPSIZEX),
			z2 = math.min(start.z2 + ((MAPSIZEZ * 0.01) * reach), MAPSIZEZ),
		}
		-- A degenerate box places nothing at all; widen it around its centre.
		if box.x2 - box.x1 < MIN_BOX_SIDE then
			box.x1 = math.max(0, math.floor((box.x1 + box.x2) / 2) - MIN_BOX_SIDE / 2)
			box.x2 = box.x1 + MIN_BOX_SIDE
		end
		if box.z2 - box.z1 < MIN_BOX_SIDE then
			box.z1 = math.max(0, math.floor((box.z1 + box.z2) / 2) - MIN_BOX_SIDE / 2)
			box.z2 = box.z1 + MIN_BOX_SIDE
		end
		state.spawnBox = box
	end

	---@param x number
	---@param y number
	---@param z number
	---@param spread number
	---@param allyTeamID integer
	---@param wantScum boolean
	---@return boolean
	---@param tally table|nil counts why spots were refused, for the warning
	local function goodGround(x, y, z, spread, allyTeamID, wantScum, tally)
		if not checks.FlatAreaCheck(x, y, z, spread, FLAT_TOLERANCE, true) then
			if tally then
				tally.steep = tally.steep + 1
			end
			return false
		end
		if not checks.OccupancyCheck(x, y, z, spread) then
			if tally then
				tally.occupied = tally.occupied + 1
			end
			return false
		end
		if wantScum and GG.IsPosInRaptorScum and not GG.IsPosInRaptorScum(x, y, z) then
			if tally then
				tally.noScum = tally.noScum + 1
			end
			return false
		end
		return true
	end

	---@return boolean found, number|nil x, number|nil y, number|nil z
	local function probe(box, spread, attempts, allyTeamID, wantScum, visibility, tally, accept)
		if box == nil or box.x1 + spread >= box.x2 - spread or box.z1 + spread >= box.z2 - spread then
			if tally then
				tally.tooSmall = true
			end
			return false
		end
		for _ = 1, attempts do
			local x = mRandom(box.x1 + spread, box.x2 - spread)
			local z = mRandom(box.z1 + spread, box.z2 - spread)
			local y = Spring.GetGroundHeight(x, z)
			if goodGround(x, y, z, spread, allyTeamID, wantScum, tally) then
				if accept and not accept(x, y, z) then
					-- counted inside accept; just keep sampling
				elseif visibility(x, y, z, spread) then
					return true, x, y, z
				else
					if tally then
						tally.seen = tally.seen + 1
					end
				end
			end
		end
		return false
	end

	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number game seconds
	---@return boolean found, number|nil x, number|nil y, number|nil z
	local function findBurrowSpot(spec, state, t)
		local spread = spec.burrows.size * 1.5
		local allyTeamID = spec.allyTeamID
		local found, x, y, z
		local tally = { steep = 0, occupied = 0, seen = 0, noScum = 0, wetOrDeadly = 0, tooSmall = false }
		state.lastPlacementTally = tally

		local function accept(px, py, pz)
			local surface = checks.LandOrSeaCheck(px, py, pz, spec.burrows.size)
			if surface == "mixed" or surface == "death" then
				tally.wetOrDeadly = tally.wetOrDeadly + 1
				return false
			end
			-- During grace, burrows must SPREAD: refusing existing creep is
			-- what makes the opening map-wide instead of one fat nest.
			if t < state.params.gracePeriod * 0.9 and GG.IsPosInRaptorScum and GG.IsPosInRaptorScum(px, py, pz) then
				tally.noScum = tally.noScum + 1
				return false
			end
			return true
		end

		if state.params.placement ~= "avoid" then
			-- Creep placement is skipped entirely when the flavor has no creep to speak of.
			if spec.burrows.useScum and GG.IsPosInRaptorScum and t >= state.params.gracePeriod then
				found, x, y, z = probe(
					{ x1 = 0, z1 = 0, x2 = MAPSIZEX, z2 = MAPSIZEZ },
					spread,
					1000,
					allyTeamID,
					true,
					function(px, py, pz, s)
						return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
					end,
					tally,
					accept
				)
			end

			if not found then
				found, x, y, z = probe(state.spawnBox, spread, 1000, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
						and checks.VisibilityCheck(px, py, pz, s, allyTeamID, true, false, false)
				end, tally, accept)
			end

			-- with no box for this team, keep the enemy-sensor test — that is
			-- the only thing stopping a burrow landing on someone's factory.
			if not found then
				local noBox = state.noStartBox
				found, x, y, z = probe(state.startBox, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return (not noBox) or checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
				end, tally, accept)
			end
		else
			-- one sensor class, so a heavily radared map still gets burrows.
			local box = state.spawnBox
			found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
				return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, true)
			end, tally, accept)
			if not found then
				found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, true, false)
				end, tally, accept)
			end
			if not found then
				found, x, y, z = probe(box, spread, 100, allyTeamID, false, function(px, py, pz, s)
					return checks.VisibilityCheckEnemy(px, py, pz, s, allyTeamID, true, false, false)
				end, tally, accept)
			end
		end

		if not found and nearestValid then
			-- Deterministic sweep, not another hundred dice rolls. Every probe
			-- above samples at random and can miss a spot that exists; this
			-- walks outward from the middle of the box and takes the first
			-- ground a burrow fits on, so if there is anywhere at all it finds
			-- it — and finds the SAME one on every client and in a replay.
			local fits = spec.burrows.size * 0.5
			for _, box in ipairs({ state.spawnBox, state.startBox }) do
				if not found and box ~= nil and box.x1 ~= nil then
					local cx = (box.x1 + box.x2) * 0.5
					local cz = (box.z1 + box.z2) * 0.5
					local reach = math.max(box.x2 - box.x1, box.z2 - box.z1) * 0.5
					local px, py, pz = nearestValid(cx, cz, {
						radius = reach,
						step = fits,
						footprint = fits,
						-- A burrow may sit on land or under water, but not
						-- across the line: half its spawns would drown.
						surface = "solid",
					})
					if px ~= nil then
						found, x, y, z = true, px, py, pz
					end
				end
			end
		end

		if not found then
			local fits = spec.burrows.size * 0.5
			found, x, y, z = probe(state.spawnBox, fits, 100, allyTeamID, false, function()
				return true
			end, tally, accept)
			if not found then
				found, x, y, z = probe(state.startBox, fits, 100, allyTeamID, false, function()
					return true
				end, tally, accept)
			end
		end

		if not found then
			return false
		end

		return true, x, y, z
	end

	---Which def appears is the first in-bracket candidate whose coin lands, so a hot map fields the higher-tier beacon.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number
	---@param techAnger number
	---@return integer|nil burrowID, number|nil x, number|nil y, number|nil z
	placement.SpawnBurrow = function(spec, state, t, techAnger)
		local found, x, y, z = findBurrowSpot(spec, state, t)
		if not found then
			local said = (state.warnedNoPlacement or 0) + 1
			state.warnedNoPlacement = said
			if said <= MAX_PLACEMENT_WARNINGS then
				local box = state.spawnBox or {}
				local why = state.lastPlacementTally or {}
				local because = why.tooSmall and "the box is smaller than a burrow needs"
					or string.format(
						"%d too steep, %d too close to something, %d half in the water, %d in the players' sight",
						why.steep or 0,
						why.occupied or 0,
						why.wetOrDeadly or 0,
						why.seen or 0
					)
				Spring.Log(
					"waves",
					LOG.WARNING,
					string.format(
						"%s: no ground for a spawner in [%d,%d]-[%d,%d] (placement=%s). Refused: %s. %s",
						spec.name,
						box.x1 or -1,
						box.z1 or -1,
						box.x2 or -1,
						box.z2 or -1,
						tostring(state.params.placement),
						because,
						said == MAX_PLACEMENT_WARNINGS and "(further attempts stay quiet)" or "Widening and retrying."
					)
				)
			end
			state.timeOfLastBurrow = t
			return nil
		end

		local anger = math.max(1, techAnger)
		local names = {}
		for name in pairs(spec.burrows.defs) do
			names[#names + 1] = name
		end
		table.sort(names)
		for _, name in ipairs(names) do
			local data = spec.burrows.defs[name]
			-- CreateUnit RAISES on an unknown def name, and this runs inside
			-- GameFrame: a spec naming a def this game does not have would
			-- otherwise take the callin down every cadence, forever.
			if UnitDefNames[name] == nil then
				Spring.Log("waves", LOG.WARNING, "no such burrow def: " .. name)
			elseif mRandom() <= state.params.spawnChance and data.minAnger < anger and data.maxAnger > anger then
				local burrowID = Spring.CreateUnit(name, x, y, z, mRandom(0, 3), spec.teamID)
				if burrowID then
					return burrowID, x, y, z
				end
			end
		end
		return nil
	end

	---Every failed round pushes the box out by another burrow width, so a cramped start box does not starve the director.
	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@param t number
	---@param techAnger number
	---@return integer|nil burrowID, number|nil x, number|nil y, number|nil z
	placement.TrySpawnBurrow = function(spec, state, t, techAnger)
		local maxRetries = math.max(MIN_ORIGIN_RETRIES, math.floor((state.params.gracePeriod - t) / 20))
		local burrowID, x, y, z = placement.SpawnBurrow(spec, state, t, techAnger)
		state.timeOfLastBurrow = t

		if not state.fullySpawned then
			local count = 0
			for _ in pairs(state.burrows) do
				count = count + 1
			end
			if count > 1 then
				state.fullySpawned = true
			elseif burrowID ~= nil then
				-- It worked. Whatever box we are on is a good box: do not widen
				-- away from an origin the author named while it is producing.
				state.spawnRetries = 0
			elseif state.spawnRetries >= (state.firstSpawn and MIN_ORIGIN_RETRIES or maxRetries) then
				state.spawnAreaMultiplier = state.spawnAreaMultiplier + 1
				if spec.burrows.box == nil then
					local x1, z1, x2, z2 = enemyLib.GetAdjustedStartBox(
						spec.allyTeamID,
						spec.burrows.size * 1.5 * state.spawnAreaMultiplier
					)
					state.startBox = { x1 = x1, z1 = z1, x2 = x2, z2 = z2 }
				else
					state.startBox = placement.WidenBox(spec.burrows.box, state.spawnAreaMultiplier)
				end
				placement.InitialBox(spec, state)
				state.spawnRetries = 0
			else
				state.spawnRetries = state.spawnRetries + 1
			end
		end

		if state.firstSpawn and burrowID then
			-- The first burrow gives the opening wave a fixed appointment: ten
			-- seconds after grace, whatever the cadence or the intensity dial
			-- would otherwise make of it. A mission that asks for background
			-- pressure should still get its first wave when the grace period
			-- ends, not a third as soon.
			state.firstWaveDue = state.params.gracePeriod + 10
			state.firstSpawn = false
		end
		return burrowID, x, y, z
	end

	---@param spec WaveSpec
	---@param state WaveDirectorState
	---@return number|nil x, number|nil y, number|nil z
	placement.BossPosition = function(spec, state)
		local best, bx, by, bz = 0, nil, nil, nil
		for burrowID in pairs(state.burrows) do
			local x, y, z = Spring.GetUnitPosition(burrowID)
			if x and y and z and not state.boss.ids[burrowID] then
				local score = mRandom(1, 1000)
				if score > best then
					best, bx, by, bz = score, x, y, z
				end
			end
		end
		if bx then
			return bx, by, bz
		end

		local box = state.startBox
		if box == nil or box.x1 == nil then
			return nil
		end

		local tries = 0
		repeat
			tries = tries + 1
			local x = mRandom(box.x1, box.x2)
			local z = mRandom(box.z1, box.z2)
			local y = Spring.GetGroundHeight(x, z)
			local ok = checks.FlatAreaCheck(x, y, z, 128, FLAT_TOLERANCE, true)
			if ok then
				-- Past a third of the budget, stop demanding radar silence.
				local strict = tries < MAX_TRIES * 3
				ok = checks.VisibilityCheckEnemy(x, y, z, spec.burrows.size, spec.allyTeamID, true, true, strict)
			end
			if ok then
				ok = checks.OccupancyCheck(x, y, z, spec.burrows.size * 0.25)
			end
			if ok then
				ok = checks.MapEdgeCheck(x, y, z, 256)
			end
			if ok then
				return x, y, z
			end
		until tries >= MAX_TRIES * 6

		for _ = 1, 100 do
			local x = mRandom(box.x1, box.x2)
			local z = mRandom(box.z1, box.z2)
			local y = Spring.GetGroundHeight(x, z)
			if
				checks.StartboxCheck(x, y, z, spec.allyTeamID)
				and checks.FlatAreaCheck(x, y, z, 128, FLAT_TOLERANCE, true)
				and checks.MapEdgeCheck(x, y, z, 128)
				and checks.OccupancyCheck(x, y, z, 128)
			then
				return x, y, z
			end
		end
		return nil
	end

	---@param state WaveDirectorState
	---@return integer|nil burrowID, number distance
	placement.NearestBurrow = function(state, tx, ty, tz)
		local nearest, nearestDistance = nil, 999999
		for burrowID in pairs(state.burrows) do
			local bx, by, bz = Spring.GetUnitPosition(burrowID)
			if bx and by and bz then
				local distance = math.ceil((math.abs(tx - bx) + math.abs(ty - by) + math.abs(tz - bz)) * 0.5)
				if distance < nearestDistance then
					nearest, nearestDistance = burrowID, distance
				end
			end
		end
		return nearest, nearestDistance
	end

	return placement
end

return Placement
