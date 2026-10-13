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
			:WithModule("ClientActions", {
				BuildTarget = function(unitName, unitNames, position)
					return { unitName = unitName, unitNames = unitNames, position = position }
				end,
				Send = function(kind, params, teamID)
					sent[#sent + 1] = { kind = kind, params = params, teamID = teamID }
				end,
			})
			:Install()
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "OrbitCamera",
			unitName = "UnitName",
			unitNames = "UnitNames",
			position = "Position",
			distance = "Quantity",
			pitch = "Number",
			startYaw = "Number",
			degrees = "Number",
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "Easing",
			onEnd = "CameraSequenceEnd",
			teamID = "TeamID",
			requiresOneOf = { "unitName", "unitNames", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target and the orbit settings", function()
		action.actionFunction("hero", nil, nil, 400, 35, 90, -180, 6, 2, "inOutSine", "release", 1)

		assert.are.same({
			{
				kind = "orbit",
				params = {
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
				teamID = 1,
			},
		}, sent)
	end)
end)
