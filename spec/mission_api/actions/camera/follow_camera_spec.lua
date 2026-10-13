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
			type = "FollowCamera",
			unitName = "UnitName",
			unitNames = "UnitNames",
			position = "Position",
			distance = "Quantity",
			pitch = "Number",
			yaw = "Number",
			duration = "Quantity",
			transitionDuration = "Quantity",
			easing = "Easing",
			smoothing = "Quantity",
			onEnd = "CameraSequenceEnd",
			teamID = "TeamID",
			requiresOneOf = { "unitName", "unitNames", "position" },
		}, summarizeSchema(action))
	end)

	it("sends the target and the shot settings", function()
		action.actionFunction("hero", { "raiders" }, nil, 500, 30, 180, 8, 1, "linear", 0.5, "hold", 0)

		assert.are.same({
			{
				kind = "follow",
				params = {
					target = { unitName = "hero", unitNames = { "raiders" } },
					distance = 500,
					pitch = 30,
					yaw = 180,
					duration = 8,
					transitionDuration = 1,
					easing = "linear",
					smoothing = 0.5,
					onEnd = "hold",
				},
				teamID = 0,
			},
		}, sent)
	end)

	it("leaves optional settings to the widget", function()
		action.actionFunction(nil, nil, { x = 1, y = 2, z = 3 })

		assert.are.same({ { kind = "follow", params = { target = { position = { x = 1, y = 2, z = 3 } } } } }, sent)
	end)
end)
