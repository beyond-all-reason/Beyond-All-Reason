local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new({
	Game = { maxUnits = 32000, squareSize = 8, footprintScale = 2 },
	Engine = { FeatureSupport = { noOffsetForFeatureID = true } },
})

-- loadout.lua keeps the tracking tables it finds at load, and every Install() refills those same tables.
MissionApiBuilder.new():Install()
local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function trackUnits(name, ...)
	local builder = MissionApiBuilder.new()
	for _, unitID in ipairs({ ... }) do
		builder:WithTrackedUnit(name, unitID)
	end
	return builder:Install()
end

describe("mission_api.loadout orders targeting names", function()
	before_each(function()
		MissionApiBuilder.new():Install()
	end)

	it("gives no orders for a name no unit carries any more", function()
		trackUnits("squad", 5).Modules.Tracking.UntrackUnitID(5)

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

	it("gives the next order as written when the skipped order would have replaced the queue", function()
		local move = { env.CMD.MOVE, { 1, 0, 2 }, { "shift" } }

		local converted = loadout.ConvertOrdersTargetingNames({
			{ env.CMD.ATTACK, { unitName = "squad" }, {} },
			move,
		})

		assert.are.same({ move }, converted)
	end)

	it("leaves a skipped order out the same way in the middle and at the end", function()
		trackUnits("target", 5)

		local converted = loadout.ConvertOrdersTargetingNames({
			{ env.CMD.MOVE, { 1, 0, 2 }, {} },
			{ env.CMD.ATTACK, { unitName = "squad" }, {} },
			{ env.CMD.ATTACK, { unitName = "target" }, { "shift" } },
			{ env.CMD.ATTACK, { unitName = "wreckers" }, {} },
		})

		assert.are.same({
			{ env.CMD.MOVE, { 1, 0, 2 }, {} },
			{ env.CMD.ATTACK, 5, { "shift" } },
		}, converted)
	end)

	it("queues the order on every unit of the name after the first", function()
		trackUnits("pair", 5, 6)

		local converted = loadout.ConvertOrdersTargetingNames({ { env.CMD.ATTACK, { unitName = "pair" }, {} } })

		assert.are.equal(2, #converted)
		assert.are.same({}, converted[1][3])
		assert.are.same({ "shift" }, converted[2][3])
	end)

	it("does not queue the first order when the same orders run again", function()
		trackUnits("target", 5)
		local orders = { { env.CMD.ATTACK, { unitName = "target" }, {} } }

		loadout.ConvertOrdersTargetingNames(orders)
		local converted = loadout.ConvertOrdersTargetingNames(orders)

		assert.are.same({ { env.CMD.ATTACK, 5, {} } }, converted)
	end)
end)
