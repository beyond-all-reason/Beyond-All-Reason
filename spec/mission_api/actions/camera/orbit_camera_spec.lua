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
			fov = "Number",
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "CameraEasing",
			onEnd = "CameraSequenceEnd",
			restoreSlot = "String",
			restoreDuration = "Quantity",
			restoreEasing = "CameraEasing",
			releaseDuration = "Quantity",
			releaseEasing = "CameraEasing",
			requiresOneOf = { "unitName", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target, the orbit settings and the ending", function()
		action.actionFunction(
			"hero",
			nil,
			400,
			35,
			90,
			-180,
			50,
			6,
			2,
			"inOutSine",
			"release",
			"intro",
			2,
			"linear",
			0.5,
			"inOutCubic"
		)

		assert.are.same({
			{
				"MissionCameraOrbit",
				{
					target = { unitName = "hero" },
					distance = 400,
					pitch = 35,
					startYaw = 90,
					degrees = -180,
					fov = 50,
					duration = 6,
					transitionDuration = 2,
					easing = "inOutSine",
					onEnd = "release",
					restoreSlot = "intro",
					restoreDuration = 2,
					restoreEasing = "linear",
					releaseDuration = 0.5,
					releaseEasing = "inOutCubic",
				},
			},
		}, sent)
	end)
end)
