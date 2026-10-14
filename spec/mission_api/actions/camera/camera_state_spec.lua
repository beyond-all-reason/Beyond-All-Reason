require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/camera/camera_state.lua")
local saveAction, restoreAction, stopAction = actions[1], actions[2], actions[3]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.camera_state", function()
	---@type table[]
	local sent

	before_each(function()
		sent = {}
		_G.SendToUnsynced = function(...) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares the three actions", function()
		assert.are.same({ type = "SaveCamera", slot = "String" }, summarizeSchema(saveAction))
		assert.are.same(
			{ type = "RestoreCamera", slot = "String", duration = "Quantity", easing = "CameraEasing" },
			summarizeSchema(restoreAction)
		)
		assert.are.same({ type = "StopCamera" }, summarizeSchema(stopAction))
	end)

	it("saves under a slot", function()
		saveAction.actionFunction("intro")
		assert.are.same({ { "MissionCameraSave", { slot = "intro" } } }, sent)
	end)

	it("restores a slot with a blend", function()
		restoreAction.actionFunction("intro", 2, "linear")
		assert.are.same({ { "MissionCameraRestore", { slot = "intro", duration = 2, easing = "linear" } } }, sent)
	end)

	it("stops", function()
		stopAction.actionFunction()
		assert.are.same({ { "MissionCameraStop" } }, sent)
	end)
end)
