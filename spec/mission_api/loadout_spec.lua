local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
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

MissionApiBuilder.new():Install(env)

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

describe("mission_api.loadout feature facing", function()
	before_each(function()
		createdFeatures, resurrectFacings = {}, {}
	end)

	it("turns a feature to its facing", function()
		assert.are.equal(HEADING_EAST, spawnedHeading({ facing = "e" }))
	end)

	it("faces a feature south without a facing", function()
		assert.are.equal(0, spawnedHeading({}))
	end)

	it("turns a feature to a compass angle", function()
		assert.are.equal(0, spawnedHeading({ facing = { angle = 180 } }))
		assert.are.equal(HEADING_EAST, spawnedHeading({ facing = { angle = 90 } }))
		assert.are.equal(HEADING_EAST / 2, spawnedHeading({ facing = { angle = 135 } }))
		assert.are.equal(-HEADING_EAST, spawnedHeading({ facing = { angle = 270 } }))
	end)

	it("keeps due north inside the engine's heading range", function()
		assert.are.equal(HEADING_NORTH, spawnedHeading({ facing = { angle = 0 } }))
		assert.are.equal(HEADING_NORTH, spawnedHeading({ facing = { angle = 360 } }))

		assert.are.equal("n", resurrectFacings[1])
	end)

	it("turns a feature towards a point", function()
		assertNear(HEADING_EAST, spawnedHeading({ facing = { x = 200, z = 100 } }))
		assertNear(0, spawnedHeading({ facing = { x = 100, z = 300 } }))
		assertNear(-HEADING_EAST, spawnedHeading({ facing = { x = 0, z = 100 } }))
		assertNear(HEADING_NORTH, spawnedHeading({ facing = { x = 100, z = 0 } }))
	end)

	it("faces a feature south when the point is the feature's own position", function()
		assert.are.equal(0, spawnedHeading({ facing = { x = 100, z = 100 } }))
	end)

	it("resurrects a wreck on the nearest of the four facings", function()
		spawnedHeading({ facing = { angle = 100 } })

		assert.are.equal("e", resurrectFacings[1])
	end)
end)
