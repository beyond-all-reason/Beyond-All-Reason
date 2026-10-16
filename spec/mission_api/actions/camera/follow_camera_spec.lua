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
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "CameraEasing",
			smoothing = "Quantity",
			onEnd = "CameraSequenceEnd",
			requiresOneOf = { "unitName", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target and the shot settings", function()
		action.actionFunction("hero", nil, 500, 30, 180, 8, 1, "linear", 0.5, "hold")

		assert.are.same({
			{
				"MissionCameraFollow",
				{
					target = { unitName = "hero" },
					distance = 500,
					pitch = 30,
					yaw = 180,
					duration = 8,
					transitionDuration = 1,
					easing = "linear",
					smoothing = 0.5,
					onEnd = "hold",
				},
			},
		}, sent)
	end)

	it("leaves optional settings to the widget", function()
		action.actionFunction(nil, { x = 1, y = 2, z = 3 })

		assert.are.same({ { "MissionCameraFollow", { target = { position = { x = 1, y = 2, z = 3 } } } } }, sent)
	end)
end)
