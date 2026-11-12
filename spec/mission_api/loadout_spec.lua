local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local HEADING_EAST = 16384
local HEADING_NORTH = 32768

---@type table<integer, table>
local createdFeatures
---@type table<integer, string>
local resurrectFacings
---@type table<integer, table>
local createdUnits
---@type table<integer, integer>
local turnedUnits
---@type table<integer, number[]>
local turnedUpDirs

-- A created unit stands on a slope, as CreateUnit leaves a vehicle on uneven ground.
local SLOPE_UP_DIR = { 0.1, 0.99, 0 }

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		GetHeadingFromFacing = function(facing)
			return facing * HEADING_EAST
		end,
		GetFacingFromHeading = function(heading)
			return math.floor((heading + HEADING_EAST / 2) % (4 * HEADING_EAST) / HEADING_EAST)
		end,
		CreateFeature = function(featureDefName, _, _, _, heading)
			createdFeatures[#createdFeatures + 1] = { featureDefName = featureDefName, heading = heading }
			return #createdFeatures
		end,
		SetFeatureResurrect = function(featureID, _, facing)
			resurrectFacings[featureID] = facing
		end,
		CreateUnit = function(unitDefName, _, _, _, facing)
			createdUnits[#createdUnits + 1] = { unitDefName = unitDefName, facing = facing }
			return #createdUnits
		end,
		GetUnitVectors = function()
			return { 0, 0, 1 }, SLOPE_UP_DIR, { 1, 0, 0 }
		end,
		SetUnitHeadingAndUpDir = function(unitID, heading, upX, upY, upZ)
			turnedUnits[unitID] = heading
			turnedUpDirs[unitID] = { upX, upY, upZ }
		end,
		GiveOrderArrayToUnit = function() end,
		Pos2BuildPos = function(_, x, y, z)
			return x, y, z
		end,
	},
})
env.UnitDefs = { { name = "armwar", corpse = "armwar_dead" } }
env.UnitDefNames = {
	armwar = { xsize = 2, zsize = 2 },
	armllt = { xsize = 2, zsize = 2, isImmobile = true },
}
env.FeatureDefNames = { armwar_dead = { id = 1 } }
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

MissionApiBuilder.new():Install(env)

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function spawnedHeading(entry)
	entry.featureDefName = "armwar_dead"
	entry.position = { x = 100, z = 100 }
	loadout.SpawnFeatureLoadout({ entry })
	return createdFeatures[#createdFeatures].heading
end

local function assertNear(expected, actual)
	assert.is_true(math.abs(expected - actual) <= 1, "expected " .. expected .. ", got " .. actual)
end

describe("mission_api.loadout feature orientation", function()
	before_each(function()
		createdFeatures, resurrectFacings = {}, {}
	end)

	it("turns a feature to its facing", function()
		assert.are.equal(HEADING_EAST, spawnedHeading({ orientation = "e" }))
	end)

	it("faces a feature south without an orientation", function()
		assert.are.equal(0, spawnedHeading({}))
	end)

	it("turns a feature to a compass angle", function()
		assert.are.equal(0, spawnedHeading({ orientation = { angle = 180 } }))
		assert.are.equal(HEADING_EAST, spawnedHeading({ orientation = { angle = 90 } }))
		assert.are.equal(HEADING_EAST / 2, spawnedHeading({ orientation = { angle = 135 } }))
		assert.are.equal(-HEADING_EAST, spawnedHeading({ orientation = { angle = 270 } }))
	end)

	it("turns a feature due north", function()
		assert.are.equal(HEADING_NORTH, spawnedHeading({ orientation = { angle = 0 } }))
		assert.are.equal(HEADING_NORTH, spawnedHeading({ orientation = { angle = 360 } }))

		assert.are.equal("n", resurrectFacings[1])
	end)

	it("turns a feature towards a point", function()
		assertNear(HEADING_EAST, spawnedHeading({ orientation = { x = 200, z = 100 } }))
		assertNear(0, spawnedHeading({ orientation = { x = 100, z = 300 } }))
		assertNear(-HEADING_EAST, spawnedHeading({ orientation = { x = 0, z = 100 } }))
		assertNear(HEADING_NORTH, spawnedHeading({ orientation = { x = 100, z = 0 } }))
	end)

	it("faces a feature south when the point is the feature's own position", function()
		assert.are.equal(0, spawnedHeading({ orientation = { x = 100, z = 100 } }))
	end)

	it("resurrects a wreck on the nearest of the four facings", function()
		spawnedHeading({ orientation = { angle = 100 } })

		assert.are.equal("e", resurrectFacings[1])
	end)
end)

describe("mission_api.loadout unit orientation", function()
	before_each(function()
		createdUnits, turnedUnits, turnedUpDirs = {}, {}, {}
	end)

	local function spawnUnits(entry)
		entry.teamName = 0
		entry.position = { x = 100, z = 100 }
		loadout.SpawnUnitLoadout({ entry })
	end

	it("creates a unit on its facing and turns it no further", function()
		spawnUnits({ unitDefName = "armwar", orientation = "w" })

		assert.are.same({ { unitDefName = "armwar", facing = "w" } }, createdUnits)
		assert.are.same({}, turnedUnits)
	end)

	it("creates a unit facing south without an orientation", function()
		spawnUnits({ unitDefName = "armwar" })

		assert.are.equal(0, createdUnits[1].facing)
	end)

	it("turns a unit that moves to a compass angle, after creating it on the nearest facing", function()
		spawnUnits({ unitDefName = "armwar", orientation = { angle = 135 } })

		assert.are.equal("e", createdUnits[1].facing)
		assert.are.same({ HEADING_EAST / 2 }, turnedUnits)
	end)

	it("keeps the slope a turned unit was created standing on", function()
		spawnUnits({ unitDefName = "armwar", orientation = { angle = 45 } })

		assert.are.same(SLOPE_UP_DIR, turnedUpDirs[1])
	end)

	it("keeps a building on the nearest of the four facings", function()
		spawnUnits({ unitDefName = "armllt", orientation = { angle = 135 } })

		assert.are.equal("e", createdUnits[1].facing)
		assert.are.same({}, turnedUnits)
	end)

	it("turns every unit of an entry the same way, towards a point from the entry's position", function()
		spawnUnits({ unitDefName = "armwar", quantity = 2, orientation = { x = 300, z = 100 } })

		assert.are.equal(2, #createdUnits)
		assertNear(HEADING_EAST, turnedUnits[1])
		assertNear(HEADING_EAST, turnedUnits[2])
	end)
end)
