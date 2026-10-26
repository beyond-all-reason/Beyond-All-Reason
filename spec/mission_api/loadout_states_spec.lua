local MissionSpecEnv = require("mission_api.spec_helper")

---@type table<integer, table>
local given

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	UnitDefNames = { bot = { id = 1, xsize = 4, zsize = 4 } },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		CreateUnit = function()
			return 7
		end,
		GiveOrderToUnit = function(unitID, commandID, params, options)
			given[#given + 1] = {
				unitID = unitID,
				commandID = commandID,
				params = params,
				options = options,
				fenced = GG["MissionAPI"].issuingOrders,
			}
		end,
		GiveOrderArrayToUnit = function(unitID, orders)
			given[#given + 1] = { unitID = unitID, orders = orders, fenced = GG["MissionAPI"].issuingOrders }
		end,
	},
})
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

describe("mission_api.loadout move and fire states", function()
	before_each(function()
		given = {}
	end)

	it("gives the states as the engine's numbers, inside the order fence, before the entry's orders", function()
		local move = { env.CMD.MOVE, { 1, 0, 2 }, {} }

		loadout.SpawnUnitLoadout({
			{
				unitDefName = "bot",
				x = 0,
				z = 0,
				team = 0,
				moveState = "HoldPosition",
				fireState = "FireAtNeutral",
				orders = { move },
			},
		})

		assert.are.same({
			{
				unitID = 7,
				commandID = env.CMD.MOVE_STATE,
				params = { 0 },
				options = 0,
				fenced = true,
			},
			{
				unitID = 7,
				commandID = env.CMD.FIRE_STATE,
				params = { 3 },
				options = 0,
				fenced = true,
			},
			{ unitID = 7, orders = { move }, fenced = true },
		}, given)
	end)

	it("gives no state the entry leaves out", function()
		loadout.SpawnUnitLoadout({ { unitDefName = "bot", x = 0, z = 0, team = 0, fireState = "HoldFire" } })

		assert.are.equal(2, #given)
		assert.are.equal(env.CMD.FIRE_STATE, given[1].commandID)
		assert.are.same({ 0 }, given[1].params)
		assert.is_nil(given[2].commandID)
	end)
end)
