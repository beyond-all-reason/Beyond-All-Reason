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
		Builders.MissionApi
			.new()
			:WithModule("ClientActions", {
				Send = function(kind, params, teamID)
					sent[#sent + 1] = { kind = kind, params = params, teamID = teamID }
				end,
			})
			:Install()
	end)

	it("declares the three actions", function()
		assert.are.same({ type = "SaveCamera", slot = "String", teamID = "TeamID" }, summarizeSchema(saveAction))
		assert.are.same(
			{ type = "RestoreCamera", slot = "String", duration = "Quantity", easing = "Easing", teamID = "TeamID" },
			summarizeSchema(restoreAction)
		)
		assert.are.same({ type = "StopCamera", teamID = "TeamID" }, summarizeSchema(stopAction))
	end)

	it("saves under a slot", function()
		saveAction.actionFunction("intro", 0)
		assert.are.same({ { kind = "save", params = { slot = "intro" }, teamID = 0 } }, sent)
	end)

	it("restores a slot with a blend", function()
		restoreAction.actionFunction("intro", 2, "linear")
		assert.are.same({ { kind = "restore", params = { slot = "intro", duration = 2, easing = "linear" } } }, sent)
	end)

	it("stops", function()
		stopAction.actionFunction()
		assert.are.same({ { kind = "stop", params = {} } }, sent)
	end)
end)
