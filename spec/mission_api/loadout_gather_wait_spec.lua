local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local CMD_GATHERWAIT = 9

---@type table<integer, table>
local givenOrders
local lastUnitID = 0

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	UnitDefNames = {
		bot = { xsize = 2, zsize = 2, canMove = true },
		lab = { xsize = 6, zsize = 6, canMove = true, isFactory = true },
	},
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		CreateUnit = function()
			lastUnitID = lastUnitID + 1
			return lastUnitID
		end,
		GiveOrderArrayToUnit = function(unitID, orders)
			givenOrders[unitID] = orders
		end,
	},
})
env.CMD.GATHERWAIT = CMD_GATHERWAIT
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

MissionApiBuilder.new():Install()
local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

describe("mission_api.loadout GATHERWAIT", function()
	local added, taggedOrders

	before_each(function()
		givenOrders, added = {}, nil
		taggedOrders = { { env.CMD.MOVE, { 1, 0, 1 }, {} }, { 5, { 4, -1 }, { "shift" } } }
		MissionApiBuilder.new()
			:WithModule("GatherWaits", {
				TagOrders = function()
					return taggedOrders, { -1 }
				end,
				CanGather = function(unitDef)
					return unitDef.canMove and not unitDef.isFactory
				end,
				Add = function(keys, unitIDs)
					added = { keys = keys, unitIDs = unitIDs }
				end,
			})
			:Install()
	end)

	it("gives every unit of an entry the tagged orders, and they wait for each other", function()
		loadout.SpawnUnitLoadout({
			{
				unitDefName = "bot",
				x = 0,
				z = 0,
				teamName = 0,
				quantity = 2,
				orders = { { env.CMD.MOVE, { 1, 0, 1 }, {} }, { CMD_GATHERWAIT, {}, {} } },
			},
		})

		assert.are.same(taggedOrders, givenOrders[lastUnitID - 1])
		assert.are.same(taggedOrders, givenOrders[lastUnitID])
		assert.are.same({ keys = { -1 }, unitIDs = { [lastUnitID - 1] = true, [lastUnitID] = true } }, added)
	end)

	it("gives a factory entry its orders as written, with nothing to wait for", function()
		local orders = { { env.CMD.MOVE, { 1, 0, 1 }, {} }, { CMD_GATHERWAIT, {}, {} } }
		loadout.SpawnUnitLoadout({ { unitDefName = "lab", x = 0, z = 0, teamName = 0, orders = orders } })

		assert.are.same(orders, givenOrders[lastUnitID])
		assert.are.same({ keys = {}, unitIDs = { [lastUnitID] = true } }, added)
	end)
end)
