require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- mirror eager module loading in api_missions.lua
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
RegisterMissionApiModules() -- handles some load order
GG["MissionAPI"].ActionDefinitions = VFS.Include("luarules/mission_api/actions_loader.lua").LoadActionDefinitions()
GG["MissionAPI"].TriggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

local parameterProcessing = VFS.Include("luarules/mission_api/parameter_processing.lua")
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

describe("mission_api.parameter_processing", function()
	local savedUnitDefNames

	before_each(function()
		savedUnitDefNames = _G.UnitDefNames
		_G.UnitDefNames = { armsolar = { id = 42 }, armck = { id = 7 } }
	end)

	after_each(function()
		_G.UnitDefNames = savedUnitDefNames
	end)

	describe("UnitDefID", function()
		it("converts unit def names to unit def ids", function()
			local actions = {
				a = {
					type = actionTypes.AddBuildOption,
					parameters = { builtUnitDefID = "armsolar", builderUnitDefID = "armck", buildMenuPosition = 2 },
				},
			}

			parameterProcessing.ProcessActionParameters(actions)

			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7, buildMenuPosition = 2 }, actions.a.parameters)
		end)

		it("leaves numeric unit def ids as they are", function()
			local actions = {
				a = { type = actionTypes.RemoveBuildOption, parameters = { builtUnitDefID = 42, builderUnitDefID = 7 } },
			}

			parameterProcessing.ProcessActionParameters(actions)

			assert.are.same({ builtUnitDefID = 42, builderUnitDefID = 7 }, actions.a.parameters)
		end)

		it("skips an optional unit def id that was not given", function()
			local actions = {
				a = { type = actionTypes.DisableBuildOption, parameters = { builtUnitDefID = "armsolar", teamID = 0 } },
			}

			parameterProcessing.ProcessActionParameters(actions)

			assert.are.same({ builtUnitDefID = 42, teamID = 0 }, actions.a.parameters)
		end)
	end)
end)
