local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- mirror eager module loading in api_missions.lua
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua")
MissionSpecEnv.registerModules(env)
GG["MissionAPI"].ActionDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/actions_loader.lua")
	.LoadActionDefinitions()
GG["MissionAPI"].TriggerDefinitions = MissionSpecEnv.include(env, "luarules/mission_api/triggers_loader.lua")
	.LoadTriggerDefinitions()

local processing = MissionSpecEnv.include(env, "luarules/mission_api/parameter_processing.lua")
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

describe("mission_api.parameter_processing", function()
	describe("Color", function()
		it("turns { r, g, b } fields into the engine's array", function()
			local actions = {
				a = {
					type = actionTypes.SetMapLighting,
					parameters = {
						tint = { r = 1, g = 0.5, b = 0 },
						groundDiffuseColor = { r = 0.2, g = 0.3, b = 0.9 },
					},
				},
			}

			processing.ProcessActionParameters(actions)

			assert.are.same({ 1, 0.5, 0 }, actions.a.parameters.tint)
			assert.are.same({ 0.2, 0.3, 0.9 }, actions.a.parameters.groundDiffuseColor)
		end)
	end)
end)
