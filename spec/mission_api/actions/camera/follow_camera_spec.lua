require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/camera/follow_camera.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.follow_camera", function()
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
			type = "FollowCamera",
			unitName = "UnitName",
			position = "Position",
			distance = "Quantity",
			pitch = "Number",
			yaw = "Number",
			fov = "Number",
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "CameraEasing",
			smoothing = "Quantity",
			onEnd = "CameraSequenceEnd",
			restoreSlot = "String",
			restoreDuration = "Quantity",
			restoreEasing = "CameraEasing",
			releaseDuration = "Quantity",
			releaseEasing = "CameraEasing",
			requiresOneOf = { "unitName", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target, the shot settings and the ending", function()
		action.actionFunction(
			"hero",
			nil,
			500,
			30,
			180,
			40,
			8,
			1,
			"linear",
			0.5,
			"restore",
			"intro",
			2,
			"inOutSine",
			1,
			"linear"
		)

		assert.are.same({
			{
				"MissionCameraFollow",
				{
					target = { unitName = "hero" },
					distance = 500,
					pitch = 30,
					yaw = 180,
					fov = 40,
					duration = 8,
					transitionDuration = 1,
					easing = "linear",
					smoothing = 0.5,
					onEnd = "restore",
					restoreSlot = "intro",
					restoreDuration = 2,
					restoreEasing = "inOutSine",
					releaseDuration = 1,
					releaseEasing = "linear",
				},
			},
		}, sent)
	end)

	it("leaves optional settings to the widget", function()
		action.actionFunction(nil, { x = 1, y = 2, z = 3 })

		assert.are.same({ { "MissionCameraFollow", { target = { position = { x = 1, y = 2, z = 3 } } } } }, sent)
	end)
end)
