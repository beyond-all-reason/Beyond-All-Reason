require("spec_helper")

local Builders = VFS.Include("spec/builders/index.lua")

Builders.MissionApi.new():Install()

local actions = VFS.Include("luarules/mission_api/actions/camera/shake_camera.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.shake_camera", function()
	---@type table[]
	local sent

	before_each(function()
		sent = {}
		_G.SendToUnsynced = function(...) ---@diagnostic disable-line: global-in-non-module
			sent[#sent + 1] = { ... }
		end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "ShakeCamera",
			magnitude = "Quantity!",
			duration = "Quantity",
			rampUp = "Quantity",
			falloff = "Quantity",
			frequency = "Quantity",
			rotationMagnitude = "Quantity",
		}, summarizeSchema(action))
	end)

	it("sends the shake as given", function()
		action.actionFunction(20, 3, 0.5, 1, 8, 2)

		assert.are.same({
			{
				"MissionCameraShake",
				{
					magnitude = 20,
					duration = 3,
					rampUp = 0.5,
					falloff = 1,
					frequency = 8,
					rotationMagnitude = 2,
				},
			},
		}, sent)
	end)
end)
