--- Placement's last resort, which is the part that decides whether a director
--- runs at all on a map that is small, crowded, or watched.
---
--- placement.lua is a port and takes Spring through deps, so the cascade can be
--- driven here without a game: the checks are injected, and a fake that refuses
--- anything demanding is exactly the map that broke it.

local Placement = VFS.Include("modules/waves/spring/placement.lua")

--- A map where nothing generous is available: every test passes at a small
--- radius and fails at a large one. That is a cramped map, and it is what a
--- last resort exists for.
---@param generousRadius number the radius above which everything is refused
local function crampedMap(generousRadius)
	local seen = { flat = {}, occupancy = {} }
	return seen, {
		FlatAreaCheck = function(_x, _y, _z, radius)
			seen.flat[#seen.flat + 1] = radius
			return radius <= generousRadius
		end,
		OccupancyCheck = function(_x, _y, _z, radius)
			seen.occupancy[#seen.occupancy + 1] = radius
			return radius <= generousRadius
		end,
		-- The players can see everywhere: a small map with a base on it.
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

--- placement.lua is spring/ code: it reads ground height directly. Flat map.
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

--- The shape findBurrowSpot reads: a director mid-game on "avoid".
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
		-- 216 is 1.5x the burrow: spacing, not fit. A map that cannot offer
		-- that much clear flat ground can still hold a burrow, and before the
		-- last resort relaxed the ground it placed nothing at all.
		local seen, checks = crampedMap(100)
		local placement = newPlacement(checks)
		local state, spec = stateAndSpec()

		local found = placement.SpawnBurrow(spec, state, 100, 1)
		-- SpawnBurrow returns nil when it cannot place: the def list is empty
		-- here, so what is asserted is that it got PAST finding a spot.
		assert.is_nil(found)

		local smallest = math.huge
		for _, radius in ipairs(seen.occupancy) do
			smallest = math.min(smallest, radius)
		end
		assert.is_true(smallest <= 100,
			"the cascade never tried a radius the map could satisfy; smallest was " .. tostring(smallest))
		assert.are.equal(72, smallest, "the last resort should ask for the burrow's footprint, not its spacing")
	end)

	it("reports which test refused the spots, not a guess", function()
		-- Everything is refused, so the tally has to be able to say why. A
		-- message that blames crowding on a map that is merely steep sends the
		-- reader to the wrong place.
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
		-- A watery map: the first samples land on shoreline that is neither
		-- land nor sea, and only some are clear. The surface test used to run
		-- once AFTER the probe returned, so one wet sample ended the cadence
		-- with nothing placed — on a map like Shallow Straits, nearly every
		-- cadence.
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
		assert.is_true(asked >= 5,
			"the probe stopped at the first wet sample instead of taking another")
		assert.are.equal(4, tally.wetOrDeadly, "wet samples should be counted, and counted separately")
	end)

	it("prefers the deterministic sweep, and takes the same spot every time", function()
		-- The random probes above can miss a spot that exists; the sweep cannot.
		-- More importantly two clients running the same game must agree on
		-- where the burrow went, and dice do not guarantee that — a fixed walk
		-- outward does.
		local calls = {}
		local function sweep(cx, cz, opts)
			calls[#calls + 1] = { cx = cx, cz = cz, surface = opts.surface }
			return 1234, 77, 5678
		end
		local _, checks = crampedMap(-1)          -- every random probe refuses
		local placement = newPlacement(checks, sweep)
		local state, spec = stateAndSpec()

		placement.SpawnBurrow(spec, state, 100, 1)
		assert.are.equal(1, #calls, "the sweep should be asked once, from the box centre")
		assert.are.equal(2048, calls[1].cx)
		assert.are.equal(2048, calls[1].cz)
		-- A burrow may sit on land or under water, never across the line.
		assert.are.equal("solid", calls[1].surface)

		-- and again, from scratch: same request, same answer
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
		-- A Placement built without it — a spec, an older caller — must not
		-- silently lose the fallback that stops a director placing nothing.
		local seen, checks = crampedMap(100)
		local placement = newPlacement(checks)          -- no sweep
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

--- A mission that says "from the northeast" is describing what the player will
--- see, and the player sees where beacons LAND — not what the request carried.
--- The DSL spec already asserted the origin reaches the director; that passed
--- the whole time the beacons were arriving next to the player's base, because
--- the retry path widened the named box until it covered the map.
describe("a named origin, when the ground refuses", function()
	local MAP = 8192
	local ORIGIN_REACH = 0.125          -- matches scavengers/api.lua

	--- The box scavengers builds for Waves.Begin(...).From(fx, fz).
	local function originBox(fx, fz)
		local x, z = fx * MAP, fz * MAP
		return {
			x1 = math.max(0, x - MAP * ORIGIN_REACH),
			z1 = math.max(0, z - MAP * ORIGIN_REACH),
			x2 = math.min(MAP, x + MAP * ORIGIN_REACH),
			z2 = math.min(MAP, z + MAP * ORIGIN_REACH),
		}
	end

	--- A map that refuses every spot, which is what drives the retry path.
	local function barrenMap()
		return {
			FlatAreaCheck = function() return false end,
			OccupancyCheck = function() return false end,
			VisibilityCheckEnemy = function() return false end,
			VisibilityCheck = function() return false end,
			LandOrSeaCheck = function() return "land" end,
			MapEdgeCheck = function() return true end,
		}
	end

	--- CM8's own numbers: pressure from the northeast, a compressed grace
	--- period, and the outpost the player inherits at the middle of the map.
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
		-- Twenty failed cadences is far past anything a real map produces; if
		-- the bound holds here it holds. Before the bound, six reached the
		-- whole map and beacons arrived wherever they liked.
		local placement, spec, state = northeastDirector()
		for _ = 1, 20 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
		end
		local box = state.spawnBox
		assert.is_true(box.x2 - box.x1 <= MAP * 0.5 + 1,
			"the box grew past half the map: " .. tostring((box.x2 - box.x1) / MAP))
		assert.is_true(box.z2 - box.z1 <= MAP * 0.5 + 1,
			"the box grew past half the map: " .. tostring((box.z2 - box.z1) / MAP))
	end)

	it("never widens onto the base the player inherits", function()
		-- CM8's outpost sits at the middle of the map. A beacon there is not
		-- pressure from the northeast, it is a beacon in the player's lap.
		local placement, spec, state = northeastDirector()
		for _ = 1, 20 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
			local box = state.spawnBox
			local coversOutpost = 0.42 * MAP >= box.x1 and 0.42 * MAP <= box.x2
				and 0.42 * MAP >= box.z1 and 0.42 * MAP <= box.z2
			assert.is_false(coversOutpost, "the spawn box reached the player's base")
		end
	end)

	it("still reads as northeast after every retry it will ever make", function()
		-- The bound is not merely "smaller than the map": the direction has to
		-- survive. The centre never moves, so what this pins is that the box
		-- stays wholly in the map's northeast quadrant-ish half.
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
		-- A mission's grace period is a fraction of multiplayer's, which made
		-- the retry budget zero and widened on the opening failure.
		local placement, spec, state = northeastDirector()
		local opening = state.spawnBox.x1
		placement.TrySpawnBurrow(spec, state, 30, 1)
		assert.are.equal(opening, state.spawnBox.x1,
			"the very first failure widened the box; the corner was never really tried")
	end)

	it("stops widening the moment a burrow actually lands", function()
		-- Widening is permanent, so it must stop being applied as soon as the
		-- box is proven good.
		local placement, spec, state = northeastDirector()
		for _ = 1, 6 do
			placement.TrySpawnBurrow(spec, state, 30, 1)
		end
		local settled = state.spawnAreaMultiplier
		state.burrows[999] = { def = "x" }        -- one burrow now exists
		state.firstSpawn = false
		state.spawnRetries = 0
		placement.TrySpawnBurrow(spec, state, 30, 1)
		assert.are.equal(settled, state.spawnAreaMultiplier,
			"kept widening after the director had something on the field")
	end)
end)
