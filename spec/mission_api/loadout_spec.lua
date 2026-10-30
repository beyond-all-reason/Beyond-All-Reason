local MissionSpecEnv = require("mission_api.spec_helper")

local HEADING_EAST = 16384
local HEADING_NORTH = -32768

---@type table<integer, table>
local createdFeatures
---@type table<integer, string>
local resurrectFacings

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
	},
})
env.UnitDefs = { { name = "armwar", corpse = "armwar_dead" } }
env.FeatureDefNames = { armwar_dead = { id = 1 } }
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

GG["MissionAPI"] = {
	trackedUnitIDs = {},
	trackedUnitNames = {},
	trackedFeatureIDs = {},
	trackedFeatureNames = {},
}
local modules = MissionSpecEnv.registerModules(env)
modules.Tracking = MissionSpecEnv.include(env, "luarules/mission_api/tracking.lua")

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function spawnedHeading(entry)
	entry.featureDefName = "armwar_dead"
	entry.x, entry.z = 100, 100
	loadout.SpawnFeatureLoadout({ entry })
	return createdFeatures[#createdFeatures].heading
end

local function assertNear(expected, actual)
	assert.is_true(math.abs(expected - actual) <= 1, "expected " .. expected .. ", got " .. actual)
end

describe("mission_api.loadout feature direction", function()
	before_each(function()
		createdFeatures, resurrectFacings = {}, {}
	end)

	it("turns a feature to its facing", function()
		assert.are.equal(HEADING_EAST, spawnedHeading({ facing = "e" }))
	end)

	it("faces a feature south without a facing or direction", function()
		assert.are.equal(0, spawnedHeading({}))
	end)

	it("turns a feature to a compass angle", function()
		assert.are.equal(0, spawnedHeading({ direction = { angle = 180 } }))
		assert.are.equal(HEADING_EAST, spawnedHeading({ direction = { angle = 90 } }))
		assert.are.equal(HEADING_EAST / 2, spawnedHeading({ direction = { angle = 135 } }))
		assert.are.equal(-HEADING_EAST, spawnedHeading({ direction = { angle = 270 } }))
	end)

	it("keeps due north inside the engine's heading range", function()
		assert.are.equal(HEADING_NORTH, spawnedHeading({ direction = { angle = 0 } }))
		assert.are.equal(HEADING_NORTH, spawnedHeading({ direction = { angle = 360 } }))

		assert.are.equal("n", resurrectFacings[1])
	end)

	it("turns a feature towards a point", function()
		assertNear(HEADING_EAST, spawnedHeading({ direction = { x = 200, z = 100 } }))
		assertNear(0, spawnedHeading({ direction = { x = 100, z = 300 } }))
		assertNear(-HEADING_EAST, spawnedHeading({ direction = { x = 0, z = 100 } }))
		assertNear(HEADING_NORTH, spawnedHeading({ direction = { x = 100, z = 0 } }))
	end)

	it("faces a feature south when the point is the feature's own position", function()
		assert.are.equal(0, spawnedHeading({ direction = { x = 100, z = 100 } }))
	end)

	it("resurrects a wreck on the nearest facing to its direction", function()
		spawnedHeading({ direction = { angle = 100 } })

		assert.are.equal("e", resurrectFacings[1])
	end)
end)
