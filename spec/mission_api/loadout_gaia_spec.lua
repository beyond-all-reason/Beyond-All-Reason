local MissionSpecEnv = require("mission_api.spec_helper")

local GAIA_TEAM_ID = 2

---@type table<integer, table>
local created

local env = MissionSpecEnv.new({
	Game = { squareSize = 8, footprintScale = 2 },
	UnitDefNames = { bot = { id = 1, xsize = 4, zsize = 4 } },
	Spring = {
		GetGroundHeight = function()
			return 0
		end,
		CreateUnit = function(unitDefName, _, _, _, _, team)
			created[#created + 1] = { unitDefName = unitDefName, team = team }
			return #created
		end,
		GiveOrderArrayToUnit = function() end,
	},
})
env.BAR = { Utilities = MissionSpecEnv.include(env, "common/springUtilities/facingFunctions.lua") }

GG["MissionAPI"] = {
	Teams = { rebels = 1, [1] = "rebels", gaia = GAIA_TEAM_ID, [GAIA_TEAM_ID] = "gaia" },
	trackedUnitIDs = {},
	trackedUnitNames = {},
	trackedFeatureIDs = {},
	trackedFeatureNames = {},
}
local modules = MissionSpecEnv.registerModules(env)
modules.Tracking = MissionSpecEnv.include(env, "luarules/mission_api/tracking.lua")

local loadout = MissionSpecEnv.include(env, "luarules/mission_api/loadout.lua")

describe("mission_api.loadout teams", function()
	before_each(function()
		created = {}
	end)

	it("creates a unit on its team ID", function()
		loadout.SpawnUnitLoadout({ { unitDefName = "bot", x = 0, z = 0, team = 1 } })

		assert.are.same({ { unitDefName = "bot", team = 1 } }, created)
	end)

	it("creates a unit on a team given by name", function()
		loadout.SpawnUnitLoadout({ { unitDefName = "bot", x = 0, z = 0, team = "rebels" } })

		assert.are.same({ { unitDefName = "bot", team = 1 } }, created)
	end)

	it("creates a unit on Gaia's team by its name", function()
		loadout.SpawnUnitLoadout({ { unitDefName = "bot", x = 0, z = 0, team = "gaia" } })

		assert.are.same({ { unitDefName = "bot", team = GAIA_TEAM_ID } }, created)
	end)
end)
