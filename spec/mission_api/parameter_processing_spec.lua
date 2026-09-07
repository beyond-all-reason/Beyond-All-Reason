require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

local parameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
local schemaUtils = VFS.Include("luarules/mission_api/schema_utils.lua")
local Types = parameterTypes.Types

local TEAMS = { thePlayerTeam = 0, theEnemyTeam = 5 }
local ALLY_TEAMS = { thePlayerAllyTeam = 0, theEnemyAllyTeam = 1 }

local function newSchema()
	return {
		Single = {
			{ name = "teamName", required = true, type = Types.TeamName },
			{ name = "sensorAllyTeamName", required = false, type = Types.AllyTeamName },
			{ name = "unitName", required = false, type = Types.UnitName },
		},
		Many = {
			{ name = "allyTeamNames", required = true, type = Types.AllyTeamNames },
		},
	}
end

---Rebuilds the module against a schema given value keys the way the loaders give theirs.
---parameter_processing reads the schemas, the team maps and the parameter types at
---include time, so GG has to be in place beforehand.
local function loadProcessing(schemaParameters)
	GG["MissionAPI"] = {
		Modules = { ParameterTypes = parameterTypes },
		ActionDefinitions = { Parameters = schemaParameters },
		TriggerDefinitions = { Parameters = schemaParameters },
		Teams = TEAMS,
		AllyTeams = ALLY_TEAMS,
		soundFiles = {},
	}
	RegisterMissionApiModules()
	schemaUtils.AssignValueKeys(schemaParameters)
	return VFS.Include("luarules/mission_api/parameter_processing.lua")
end

describe("mission_api.parameter_processing", function()
	describe("team and ally team parameters", function()
		it("stores the resolved team ID under the derived key", function()
			local processing = loadProcessing(newSchema())
			local actions = { a = { type = "Single", parameters = { teamName = "theEnemyTeam" } } }

			processing.ProcessActionParameters(actions)

			assert.are.equal(5, actions.a.parameters.teamID)
		end)

		it("leaves the authored name in place, for validation and error messages", function()
			local processing = loadProcessing(newSchema())
			local actions = { a = { type = "Single", parameters = { teamName = "theEnemyTeam" } } }

			processing.ProcessActionParameters(actions)

			assert.are.equal("theEnemyTeam", actions.a.parameters.teamName)
		end)

		it("resolves team ID 0, the default player team, and not to a nil or a sentinel", function()
			local processing = loadProcessing(newSchema())
			local actions = { a = { type = "Single", parameters = { teamName = "thePlayerTeam" } } }

			processing.ProcessActionParameters(actions)

			assert.are.equal(0, actions.a.parameters.teamID)
		end)

		it("resolves an ally team name to its ally team ID", function()
			local processing = loadProcessing(newSchema())
			local triggers = {
				t = { type = "Single", parameters = { sensorAllyTeamName = "theEnemyAllyTeam" } },
			}

			processing.ProcessTriggerParameters(triggers)

			assert.are.equal(1, triggers.t.parameters.sensorAllyTeamID)
		end)

		it("resolves a list of ally team names, preserving order", function()
			local processing = loadProcessing(newSchema())
			local actions = {
				a = { type = "Many", parameters = { allyTeamNames = { "theEnemyAllyTeam", "thePlayerAllyTeam" } } },
			}

			processing.ProcessActionParameters(actions)

			assert.are.same({ 1, 0 }, actions.a.parameters.allyTeamIDs)
		end)

		it("applies to triggers and actions alike", function()
			local processing = loadProcessing(newSchema())
			local triggers = { t = { type = "Single", parameters = { teamName = "theEnemyTeam" } } }

			processing.ProcessTriggerParameters(triggers)

			assert.are.equal(5, triggers.t.parameters.teamID)
		end)

		it("leaves an omitted optional team parameter absent", function()
			local processing = loadProcessing(newSchema())
			local actions = { a = { type = "Single", parameters = { teamName = "thePlayerTeam" } } }

			processing.ProcessActionParameters(actions)

			assert.is_nil(actions.a.parameters.sensorAllyTeamID)
		end)

		it("leaves parameters of other types untouched", function()
			local processing = loadProcessing(newSchema())
			local actions = {
				a = { type = "Single", parameters = { teamName = "thePlayerTeam", unitName = "scout" } },
			}

			processing.ProcessActionParameters(actions)

			assert.are.equal("scout", actions.a.parameters.unitName)
		end)
	end)

	describe("unit loadouts", function()
		local previousUnitDefNames

		before_each(function()
			previousUnitDefNames = _G.UnitDefNames
			_G.UnitDefNames = { armflash = { id = 42 } }
		end)

		after_each(function()
			_G.UnitDefNames = previousUnitDefNames
		end)

		local function loadoutSchema()
			return {
				Spawn = {
					{ name = "unitLoadout", required = true, type = Types.UnitLoadout },
				},
			}
		end

		it("resolves an entry's team name to a team ID", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = { { unitDefName = "armflash", teamName = "theEnemyTeam", x = 1, z = 2 } }

			processing.ProcessUnitLoadout(loadout)

			assert.are.equal(5, loadout[1].teamID)
		end)

		it("resolves team ID 0, the default player team, and not to a nil or a sentinel", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = { { unitDefName = "armflash", teamName = "thePlayerTeam", x = 1, z = 2 } }

			processing.ProcessUnitLoadout(loadout)

			assert.are.equal(0, loadout[1].teamID)
		end)

		it("keeps the authored team name in place", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = { { unitDefName = "armflash", teamName = "theEnemyTeam", x = 1, z = 2 } }

			processing.ProcessUnitLoadout(loadout)

			assert.are.equal("theEnemyTeam", loadout[1].teamName)
		end)

		-- Loadout orders are held to the same validator as an IssueOrders action's, so a build order
		-- naming a unitDef has to resolve the same way there too.
		it("resolves a build order's unitDefName to a negative unitDefID", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = {
				{
					unitDefName = "armflash",
					teamName = "thePlayerTeam",
					x = 1,
					z = 2,
					orders = { { "armflash", { 10, 0, 10 } } },
				},
			}

			processing.ProcessUnitLoadout(loadout)

			assert.are.equal(-42, loadout[1].orders[1][1])
		end)

		it("leaves a numeric command in an order alone", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = {
				{
					unitDefName = "armflash",
					teamName = "thePlayerTeam",
					x = 1,
					z = 2,
					orders = { { CMD.MOVE, { 10, 0, 10 } } },
				},
			}

			processing.ProcessUnitLoadout(loadout)

			assert.are.equal(CMD.MOVE, loadout[1].orders[1][1])
		end)

		it("processes a loadout passed as an action parameter", function()
			local processing = loadProcessing(loadoutSchema())
			local actions = {
				a = {
					type = "Spawn",
					parameters = {
						unitLoadout = { { unitDefName = "armflash", teamName = "theEnemyTeam", x = 1, z = 2 } },
					},
				},
			}

			processing.ProcessActionParameters(actions)

			assert.are.equal(5, actions.a.parameters.unitLoadout[1].teamID)
		end)

		it("leaves the loadout table itself in place rather than replacing it", function()
			local processing = loadProcessing(loadoutSchema())
			local loadout = { { unitDefName = "armflash", teamName = "theEnemyTeam", x = 1, z = 2 } }
			local actions = { a = { type = "Spawn", parameters = { unitLoadout = loadout } } }

			processing.ProcessActionParameters(actions)

			assert.are.equal(loadout, actions.a.parameters.unitLoadout)
		end)

		it("tolerates a mission with no loadout at all", function()
			local processing = loadProcessing(loadoutSchema())

			assert.has_no.errors(function()
				processing.ProcessUnitLoadout(nil)
			end)
		end)
	end)
end)
