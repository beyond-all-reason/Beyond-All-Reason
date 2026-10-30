local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

-- What MetaUnitAdded would read at each Spring.CreateUnit, by unit ID.
---@type table<integer, table>
local seenAtCreate = {}
-- The orders each spawned unit is given, by unit ID.
---@type table<integer, table>
local givenOrders = {}
local lastUnitID = 0

local env = MissionSpecEnv.new({
	Game = { squareSize = 8 },
	UnitDefNames = { bot = { xsize = 4, zsize = 4 } },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		CreateUnit = function()
			lastUnitID = lastUnitID + 1
			seenAtCreate[lastUnitID] = {
				name = GG["MissionAPI"].nameOfUnitBeingSpawned,
				alsoNamed = GG["MissionAPI"].alsoNamedOfUnitBeingSpawned,
			}
			return lastUnitID
		end,
		GiveOrderArrayToUnit = function(unitID, orders)
			givenOrders[unitID] = orders
		end,
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

-- loadout.lua keeps the tracking tables it finds at load, and every Install() refills those same tables.
---@type table
local missionApi = MissionApiBuilder.new():Install()
local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

local function bot(fields)
	local unit = { unitDefName = "bot", x = 0, z = 0, team = 0 }
	for key, value in pairs(fields) do
		unit[key] = value
	end
	return unit
end

describe("mission_api.loadout alsoNamed", function()
	before_each(function()
		MissionApiBuilder.new():Install()
		seenAtCreate = {}
		givenOrders = {}
	end)

	it("tracks the unit under its unitName and every name in alsoNamed", function()
		loadout.SpawnUnitLoadout({ bot({ unitName = "squad", alsoNamed = { "Lab1", "Hq" } }) })

		assert.are.same({ squad = true, Lab1 = true, Hq = true }, missionApi.trackedUnitNames[lastUnitID])
	end)

	it("shows alsoNamed to MetaUnitAdded while the unit is created, and clears it after", function()
		loadout.SpawnUnitLoadout({ bot({ unitName = "squad", alsoNamed = { "Lab1" } }) })

		assert.are.same({ name = "squad", alsoNamed = { "Lab1" } }, seenAtCreate[lastUnitID])
		assert.is_nil(missionApi.alsoNamedOfUnitBeingSpawned)
	end)

	it("gives the names to every unit of a quantity", function()
		loadout.SpawnUnitLoadout({ bot({ unitName = "squad", alsoNamed = { "Lab1" }, quantity = 2 }) })

		assert.are.same({ [lastUnitID - 1] = true, [lastUnitID] = true }, missionApi.trackedUnitIDs.Lab1)
	end)

	it("tracks alsoNamed without a unitName", function()
		loadout.SpawnUnitLoadout({ bot({ alsoNamed = { "Lab1" } }) })

		assert.are.same({ Lab1 = true }, missionApi.trackedUnitNames[lastUnitID])
	end)

	it("lets a later entry's orders target a unit by a name from alsoNamed", function()
		loadout.SpawnUnitLoadout({
			bot({ unitName = "squad", alsoNamed = { "Lab1" } }),
			bot({ unitName = "squad", orders = { { env.CMD.GUARD, { unitName = "Lab1" }, {} } } }),
		})
		local labID, guardID = lastUnitID - 1, lastUnitID

		assert.are.same({ { env.CMD.GUARD, labID, {} } }, givenOrders[guardID])
	end)
end)
