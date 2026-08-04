
local Placement = VFS.Include("modules/waves/spring/placement.lua")

---@param generousRadius number the radius above which everything is refused
local function crampedMap(generousRadius)
	local seen = { flat = {}, occupancy = {} }
	return seen,
		{
			FlatAreaCheck = function(_x, _y, _z, radius)
				seen.flat[#seen.flat + 1] = radius
				return radius <= generousRadius
			end,
			OccupancyCheck = function(_x, _y, _z, radius)
				seen.occupancy[#seen.occupancy + 1] = radius
				return radius <= generousRadius
			end,
			VisibilityCheckEnemy = function()
				return false
			end,
			VisibilityCheck = function()
				return false
			end,
			LandOrSeaCheck = function()
				return "land"
			end,
			MapEdgeCheck = function()
				return true
			end,
		}
end

-- placement.lua reads ground height directly, so the map has to be faked
local savedGroundHeight
local function stubSpring()
	savedGroundHeight = Spring.GetGroundHeight
	Spring.GetGroundHeight = function()
		return 100
	end
end
local function restoreSpring()
	Spring.GetGroundHeight = savedGroundHeight
end

local function newPlacement(checks, nearestValid)
	return Placement.New({
		positionChecks = checks,
		nearestValid = nearestValid,
		enemyLib = {
			GetAdjustedStartBox = function()
				return 0, 0, 4096, 4096
			end,
		},
		mapSizeX = 4096,
		mapSizeZ = 4096,
	})
end

local function stateAndSpec()
	local box = { x1 = 0, z1 = 0, x2 = 4096, z2 = 4096 }
	return {
		spawnBox = box,
		startBox = box,
		params = { placement = "avoid", gracePeriod = 0 },
		burrows = {},
		boss = { ids = {} },
	}, {
		name = "test.pack",
		allyTeamID = 1,
		burrows = { size = 144, defs = {}, useScum = false },
	}
end

describe("burrow placement on a map with no room to spare", function()
	before_each(stubSpring)
	after_each(restoreSpring)

	it("still finds somewhere when only the burrow's own footprint fits", function()
		-- 216 is 1.5x the burrow: spacing, not fit
		local seen, checks = crampedMap(100)
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()

		local found = placement.SpawnBurrow(spec, state, 100, 1)
		-- the def list is empty, so nil here means it got past finding a spot
		assert.is_nil(found)

		local smallest = math.huge
		for _, radius in ipairs(seen.occupancy) do
			smallest = math.min(smallest, radius)
		end
		assert.is_true(
			smallest <= 100,
			"the cascade never tried a radius the map could satisfy; smallest was " .. tostring(smallest)
		)
		assert.are.equal(72, smallest, "the last resort should ask for the burrow's footprint, not its spacing")
	end)

	it("reports which test refused the spots, not a guess", function()
		local _, checks = crampedMap(-1)
		checks.FlatAreaCheck = function()
			return false
		end
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()

		placement.SpawnBurrow(spec, state, 100, 1)
		local tally = state.lastPlacementTally
		assert.is_table(tally)
		assert.is_true(tally.steep > 0, "steep ground should be counted")
		assert.are.equal(0, tally.occupied, "nothing was refused for crowding")
	end)

	it("keeps looking when a spot is half in the water, instead of giving up", function()
		-- regression: the surface test once ran after the probe returned, so one wet sample ended the cadence
		local _, checks = crampedMap(1e9)
		local asked = 0
		checks.LandOrSeaCheck = function()
			asked = asked + 1
			return asked < 5 and "mixed" or "land"
		end
		checks.VisibilityCheckEnemy = function()
			return true
		end
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()

		placement.SpawnBurrow(spec, state, 100, 1)
		local tally = state.lastPlacementTally
		assert.is_true(asked >= 5, "the probe stopped at the first wet sample instead of taking another")
		assert.are.equal(4, tally.wetOrDeadly, "wet samples should be counted, and counted separately")
	end)

	it("prefers the deterministic sweep, and takes the same spot every time", function()
		local calls = {}
		local function sweep(cx, cz, opts)
			calls[#calls + 1] = { cx = cx, cz = cz, surface = opts.surface }
			return 1234, 77, 5678
		end
		local _, checks = crampedMap(-1)
		local placement = newPlacement(checks, sweep)
		local state, spec = stateAndSpec()

		placement.SpawnBurrow(spec, state, 100, 1)
		assert.are.equal(1, #calls, "the sweep should be asked once, from the box centre")
		assert.are.equal(2048, calls[1].cx)
		assert.are.equal(2048, calls[1].cz)
		assert.are.equal("solid", calls[1].surface)

		local calls2 = {}
		local placement2 = newPlacement(select(2, crampedMap(-1)), function(cx, cz, opts)
			calls2[#calls2 + 1] = { cx = cx, cz = cz, surface = opts.surface }
			return 1234, 77, 5678
		end)
		local state2, spec2 = stateAndSpec()
		placement2.SpawnBurrow(spec2, state2, 100, 1)
		assert.are.same(calls, calls2)
	end)

	it("still has a last resort when no placement module was injected", function()
		local seen, checks = crampedMap(100)
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()
		placement.SpawnBurrow(spec, state, 100, 1)
		local smallest = math.huge
		for _, r in ipairs(seen.occupancy) do
			smallest = math.min(smallest, r)
		end
		assert.are.equal(72, smallest, "the relaxed probe should still ask for the footprint")
	end)

	it("counts crowding separately from steepness", function()
		local _, checks = crampedMap(-1)
		checks.FlatAreaCheck = function()
			return true
		end
		checks.OccupancyCheck = function()
			return false
		end
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()

		placement.SpawnBurrow(spec, state, 100, 1)
		local tally = state.lastPlacementTally
		assert.are.equal(0, tally.steep)
		assert.is_true(tally.occupied > 0, "crowding should be counted")
	end)
end)

describe("a named origin, when the ground refuses", function()
	local MAP = 8192
	local ORIGIN_REACH = 0.125 -- matches scavengers/api.lua

	local function originBox(fx, fz)
		local x, z = fx * MAP, fz * MAP
		return {
			x1 = math.max(0, x - MAP * ORIGIN_REACH),
			z1 = math.max(0, z - MAP * ORIGIN_REACH),
			x2 = math.min(MAP, x + MAP * ORIGIN_REACH),
			z2 = math.min(MAP, z + MAP * ORIGIN_REACH),
		}
	end

	local function barrenMap()
		return {
			FlatAreaCheck = function()
				return false
			end,
			OccupancyCheck = function()
				return false
			end,
			VisibilityCheckEnemy = function()
				return false
			end,
			VisibilityCheck = function()
				return false
			end,
			LandOrSeaCheck = function()
				return "land"
			end,
			MapEdgeCheck = function()
				return true
			end,
		}
	end

	local function northeastDirector()
		local placement = Placement.New({
			positionChecks = barrenMap(),
			enemyLib = {
				GetAdjustedStartBox = function()
					return 0, 0, MAP, MAP
				end,
			},
			mapSizeX = MAP,
			mapSizeZ = MAP,
		})
		local spec = {
			name = "scavengers.skirmish",
			allyTeamID = 1,
			burrows = { size = 144, defs = {}, useScum = false, box = originBox(0.85, 0.15) },
		}
		local state = {
			params = { placement = "avoid", gracePeriod = 24 },
			burrows = {},
			boss = { ids = {} },
			spawnAreaMultiplier = 2,
			firstSpawn = true,
			spawnRetries = 0,
		}
		placement.InitialBox(spec, state)
		return placement, spec, state
	end

	before_each(stubSpring)
	after_each(restoreSpring)

	it("opens in the corner the mission named", function()
		local _, _, state = northeastDirector()
		assert.is_true(state.spawnBox.x1 > MAP * 0.5, "should start east")
		assert.is_true(state.spawnBox.z2 < MAP * 0.5, "should start north")
	end)

	it("never widens far enough to reach the other side of the map", function()
		-- twenty failed cadences is far past anything a real map produces
		local placement, spec, state = northeastDirector()
		for _ = 1, 20 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
		end
		local box = state.spawnBox
		assert.is_true(
			box.x2 - box.x1 <= MAP * 0.5 + 1,
			"the box grew past half the map: " .. tostring((box.x2 - box.x1) / MAP)
		)
		assert.is_true(
			box.z2 - box.z1 <= MAP * 0.5 + 1,
			"the box grew past half the map: " .. tostring((box.z2 - box.z1) / MAP)
		)
	end)

	it("never widens onto the base the player inherits", function()
		local placement, spec, state = northeastDirector()
		for _ = 1, 20 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
			local box = state.spawnBox
			local coversOutpost = 0.42 * MAP >= box.x1
				and 0.42 * MAP <= box.x2
				and 0.42 * MAP >= box.z1
				and 0.42 * MAP <= box.z2
			assert.is_false(coversOutpost, "the spawn box reached the player's base")
		end
	end)

	it("still reads as northeast after every retry it will ever make", function()
		local placement, spec, state = northeastDirector()
		for _ = 1, 20 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
		end
		assert.is_true(state.spawnBox.x2 > MAP * 0.5, "lost the east")
		assert.is_true(state.spawnBox.z1 < MAP * 0.5, "lost the north")
		local centreX = (state.spawnBox.x1 + state.spawnBox.x2) * 0.5
		local centreZ = (state.spawnBox.z1 + state.spawnBox.z2) * 0.5
		assert.is_true(centreX > MAP * 0.5, "the centre drifted west of the map's middle")
		assert.is_true(centreZ < MAP * 0.5, "the centre drifted south of the map's middle")
	end)

	it("gives the named corner more than one attempt before bending it", function()
		-- regression: a mission's short grace period made the retry budget zero
		local placement, spec, state = northeastDirector()
		local opening = state.spawnBox.x1
		placement.TrySpawnBurrow(spec, state, 30, 1)
		assert.are.equal(
			opening,
			state.spawnBox.x1,
			"the very first failure widened the box; the corner was never really tried"
		)
	end)

	it("stops widening the moment a burrow actually lands", function()
		local placement, spec, state = northeastDirector()
		for _ = 1, 6 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
		end
		local settled = state.spawnAreaMultiplier
		state.burrows[999] = { def = "x" }
		state.firstSpawn = false
		state.spawnRetries = 0
		placement.TrySpawnBurrow(spec, state, 30, 1)
		assert.are.equal(
			settled,
			state.spawnAreaMultiplier,
			"kept widening after the director had something on the field"
		)
	end)
end)
