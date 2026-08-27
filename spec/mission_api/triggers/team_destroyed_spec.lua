require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local teamDestroyed = VFS.Include("luarules/mission_api/triggers/team_destroyed.lua")
local onTeamDied = teamDestroyed.callins.TeamDied

describe("mission_api.triggers.team_destroyed", function()
	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function()
				fired = fired + 1
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	it("declares its type and required teamID parameter", function()
		assert.are.equal("TeamDestroyed", teamDestroyed.type)
		assert.are.equal("teamID", teamDestroyed.parameters[1].name)
		assert.is_true(teamDestroyed.parameters[1].required)
	end)

	it("fires when the matching team dies", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamID = 5 }), triggerID, context, 5)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a different team", function()
		local context, fired = newContext()
		onTeamDied(trigger({ teamID = 5 }), triggerID, context, 6)
		assert.are.equal(0, fired())
	end)
end)
