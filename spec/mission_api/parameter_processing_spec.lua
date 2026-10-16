require("spec_helper")

local RegisterMissionApiModules = require("mission_api.spec_helper")

-- mirror eager module loading in api_missions.lua
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
RegisterMissionApiModules()
GG["MissionAPI"].ActionDefinitions = VFS.Include("luarules/mission_api/actions_loader.lua").LoadActionDefinitions()
GG["MissionAPI"].TriggerDefinitions = VFS.Include("luarules/mission_api/triggers_loader.lua").LoadTriggerDefinitions()

local processing = VFS.Include("luarules/mission_api/parameter_processing.lua")
local actionTypes = GG["MissionAPI"].ActionDefinitions.Types

describe("mission_api.parameter_processing", function()
	before_each(function()
		Spring.GetGroundHeight = function(x, z)
			return x + z
		end
	end)

	describe("CameraKeyframes", function()
		it("fills the ground height into keyframe positions that have none", function()
			local actions = {
				shot = {
					type = actionTypes.PlayCameraSequence,
					parameters = {
						keyframes = {
							{ position = { x = 10, z = 20 }, lookAtPosition = { x = 1, z = 2 } },
							{ position = { x = 10, y = 500, z = 20 } },
							{ unitName = "hero", lookAtUnitName = "boss" },
						},
					},
				},
			}

			processing.ProcessActionParameters(actions)

			local keyframes = actions.shot.parameters.keyframes
			assert.are.same({ x = 10, y = 30, z = 20 }, keyframes[1].position)
			assert.are.same({ x = 1, y = 3, z = 2 }, keyframes[1].lookAtPosition)
			assert.are.equal(500, keyframes[2].position.y)
			assert.are.same({ unitName = "hero", lookAtUnitName = "boss" }, keyframes[3])
		end)
	end)
end)
