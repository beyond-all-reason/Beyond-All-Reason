local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new({
	Game = { maxUnits = 32000, squareSize = 8, footprintScale = 2 },
	Engine = { FeatureSupport = { noOffsetForFeatureID = true } },
})

GG["MissionAPI"] = {
	trackedUnitIDs = {},
	trackedUnitNames = {},
	trackedFeatureIDs = {},
	trackedFeatureNames = {},
}
local missionAPI = GG["MissionAPI"]
local modules = MissionSpecEnv.registerModules(env)
modules.Tracking = MissionSpecEnv.include(env, "luarules/mission_api/tracking.lua")

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")
local tracking = modules.Tracking

local function clearTracked()
	for _, tracked in ipairs({
		missionAPI.trackedUnitIDs,
		missionAPI.trackedUnitNames,
		missionAPI.trackedFeatureIDs,
		missionAPI.trackedFeatureNames,
	}) do
		for key in pairs(tracked) do
			tracked[key] = nil
		end
	end
end

describe("mission_api.loadout orders targeting names", function()
	before_each(function()
		clearTracked()
	end)

	it("gives no orders for a name no unit carries any more", function()
		tracking.TrackUnit("squad", 5)
		tracking.UntrackUnitID(5)

		local converted = loadout.ConvertOrdersTargetingNames({ { env.CMD.ATTACK, { unitName = "squad" }, {} } })

		assert.are.same({}, converted)
	end)

	it("gives no orders for a feature name with nothing behind it", function()
		local converted = loadout.ConvertOrdersTargetingNames({ { env.CMD.RECLAIM, { featureName = "wreck" }, {} } })

		assert.are.same({}, converted)
	end)

	it("gives the next order as written when the skipped order was queued", function()
		local move = { env.CMD.MOVE, { 1, 0, 2 }, {} }

		local converted = loadout.ConvertOrdersTargetingNames({
			{ env.CMD.ATTACK, { unitName = "squad" }, { "shift" } },
			move,
		})

		assert.are.same({ move }, converted)
	end)

	it("lets the next order replace the queue when a skipped order would have", function()
		local converted = loadout.ConvertOrdersTargetingNames({
			{ env.CMD.ATTACK, { unitName = "squad" }, {} },
			{ env.CMD.MOVE, { 1, 0, 2 }, { "shift", "alt" } },
			{ env.CMD.MOVE, { 3, 0, 4 }, { "shift" } },
		})

		assert.are.same({
			{ env.CMD.MOVE, { 1, 0, 2 }, { "alt" } },
			{ env.CMD.MOVE, { 3, 0, 4 }, { "shift" } },
		}, converted)
	end)

	it("passes the replacing on past further skipped orders", function()
		tracking.TrackUnit("target", 5)

		local converted = loadout.ConvertOrdersTargetingNames({
			{ env.CMD.ATTACK, { unitName = "squad" }, {} },
			{ env.CMD.ATTACK, { unitName = "wreckers" }, { "shift" } },
			{ env.CMD.ATTACK, { unitName = "target" }, { "shift" } },
		})

		assert.are.same({ { env.CMD.ATTACK, 5, {} } }, converted)
	end)

	it("queues the order on every unit of the name after the first", function()
		tracking.TrackUnit("pair", 5)
		tracking.TrackUnit("pair", 6)

		local converted = loadout.ConvertOrdersTargetingNames({ { env.CMD.ATTACK, { unitName = "pair" }, {} } })

		assert.are.equal(2, #converted)
		assert.are.same({}, converted[1][3])
		assert.are.same({ "shift" }, converted[2][3])
	end)


	it("leaves the mission's own order unchanged when it takes over replacing the queue", function()
		local move = { env.CMD.MOVE, { 1, 0, 2 }, { "shift" } }

		loadout.ConvertOrdersTargetingNames({ { env.CMD.ATTACK, { unitName = "squad" }, {} }, move })

		assert.are.same({ env.CMD.MOVE, { 1, 0, 2 }, { "shift" } }, move)
	end)

	it("does not queue the first order when the same orders run again", function()
		tracking.TrackUnit("target", 5)
		local orders = { { env.CMD.ATTACK, { unitName = "target" }, {} } }

		loadout.ConvertOrdersTargetingNames(orders)
		local converted = loadout.ConvertOrdersTargetingNames(orders)

		assert.are.same({ { env.CMD.ATTACK, 5, {} } }, converted)
	end)
end)
