require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/camera/play_camera_sequence.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.play_camera_sequence", function()
	---@type table[]
	local sent

	before_each(function()
		sent = {}
		Builders.MissionApi
			.new()
			:WithModule("Camera", {
				BuildKeyframes = function(keyframes)
					return { built = keyframes }
				end,
			})
			:Install()
		_G.SendToUnsynced = function(...) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "PlayCameraSequence",
			keyframes = "CameraKeyframes!",
			onEnd = "CameraSequenceEnd",
			restoreSlot = "String",
			restoreDuration = "Quantity",
			restoreEasing = "CameraEasing",
			releaseDuration = "Quantity",
			releaseEasing = "CameraEasing",
		}, summarizeSchema(action))
	end)

	it("sends the built keyframes with the ending", function()
		local keyframes = { { position = { x = 0, y = 0, z = 0 } } }
		action.actionFunction(keyframes, "restore", "intro", 2, "linear", 0.5, "inOutSine")

		assert.are.same({
			{
				"MissionCameraPlay",
				{
					keyframes = { built = keyframes },
					onEnd = "restore",
					restoreSlot = "intro",
					restoreDuration = 2,
					restoreEasing = "linear",
					releaseDuration = 0.5,
					releaseEasing = "inOutSine",
				},
			},
		}, sent)
	end)
end)
