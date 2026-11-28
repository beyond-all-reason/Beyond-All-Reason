GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local action = VFS.Include("luarules/mission_api/actions/misc/raise_event.lua")[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.raise_event", function()
	it("declares its type and parameters", function()
		assert.are.same({
			type = "RaiseEvent",
			triggerID = "TriggerID!",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("activates the named trigger", function()
			local activated = {}
			GG["MissionAPI"].Triggers = { reinforcementsDue = { type = "Event" } }
			GG["MissionAPI"].ActivateTrigger = function(trigger)
				activated[#activated + 1] = trigger
			end

			action.actionFunction("reinforcementsDue")

			assert.are.same({ GG["MissionAPI"].Triggers.reinforcementsDue }, activated)
		end)
	end)
end)
