GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local actions = VFS.Include("luarules/mission_api/actions/environment/set_map_time_of_day.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.set_map_time_of_day", function()
	local calls

	before_each(function()
		calls = {}
		GG.MapLighting = {
			SetTimeOfDay = function(hour, duration, dayLength)
				calls[#calls + 1] = { hour, duration, dayLength }
			end,
		}
	end)

	after_each(function()
		GG.MapLighting = nil
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SetMapTimeOfDay",
			hour = "TimeOfDay!",
			transitionDuration = "Quantity",
			dayLength = "Quantity",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("passes the hour, the transition duration and the day length", function()
			action.actionFunction(18, 30, 600)

			assert.are.same({ { 18, 30, 600 } }, calls)
		end)

		it("passes no duration or day length when none are given", function()
			action.actionFunction(6)

			assert.are.same({ { 6 } }, calls)
		end)
	end)
end)
