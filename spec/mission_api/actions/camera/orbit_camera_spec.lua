require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/camera/orbit_camera.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.orbit_camera", function()
	---@type table[]
	local sent

	before_each(function()
		sent = {}
		Builders.MissionApi
			.new()
			:WithModule("Camera", {
				BuildTarget = function(unitName, position)
					return { unitName = unitName, position = position }
				end,
			})
			:Install()
		_G.SendToUnsynced = function(...) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "OrbitCamera",
			unitName = "UnitName",
			position = "Position",
			distance = "Quantity",
			pitch = "Number",
			startYaw = "Number",
			degrees = "Number",
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "CameraEasing",
			onEnd = "CameraSequenceEnd",
			requiresOneOf = { "unitName", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target and the orbit settings", function()
		action.actionFunction("hero", nil, 400, 35, 90, -180, 6, 2, "inOutSine", "release")

		assert.are.same({
			{
				"MissionCameraOrbit",
				{
					target = { unitName = "hero" },
					distance = 400,
					pitch = 35,
					startYaw = 90,
					degrees = -180,
					duration = 6,
					transitionDuration = 2,
					easing = "inOutSine",
					onEnd = "release",
				},
			},
		}, sent)
	end)
end)
