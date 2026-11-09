local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
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
		GiveOrderArrayToUnit = function(unitID, orders)
			given[#given + 1] = { unitID = unitID, orders = orders, fenced = GG["MissionAPI"].issuingOrders }
		end,
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

MissionApiBuilder.new():Install(env)

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

describe("mission_api.loadout move and fire states", function()
	before_each(function()
		given = {}
	end)

	it("gives the states ahead of the entry's orders, in one array inside the order fence", function()
		local move = { env.CMD.MOVE, { 1, 0, 2 }, {} }

		loadout.SpawnUnitLoadout({
			{
				unitDefName = "bot",
				position = { x = 0, z = 0 },
				teamName = 0,
				moveState = env.CMD.MOVESTATE_HOLDPOS,
				fireState = env.CMD.FIRESTATE_FIREATNEUTRAL,
				orders = { move },
			},
		})

		assert.are.same({
			{
				unitID = 7,
				orders = {
					{ env.CMD.MOVE_STATE, { 0 }, 0 },
					{ env.CMD.FIRE_STATE, { 3 }, 0 },
					move,
				},
				fenced = true,
			},
		}, given)
	end)

	it("gives no state the entry leaves out", function()
		loadout.SpawnUnitLoadout({
			{ unitDefName = "bot", position = { x = 0, z = 0 }, teamName = 0, fireState = env.CMD.FIRESTATE_HOLDFIRE },
		})

		assert.are.same({ { unitID = 7, orders = { { env.CMD.FIRE_STATE, { 0 }, 0 } }, fenced = true } }, given)
	end)

	it("leaves the entry's own orders as written", function()
		local orders = { { env.CMD.MOVE, { 1, 0, 2 }, {} } }

		loadout.SpawnUnitLoadout({
			{
				unitDefName = "bot",
				position = { x = 0, z = 0 },
				teamName = 0,
				moveState = env.CMD.MOVESTATE_ROAM,
				orders = orders,
			},
		})

		assert.are.same({ { env.CMD.MOVE, { 1, 0, 2 }, {} } }, orders)
	end)
end)
