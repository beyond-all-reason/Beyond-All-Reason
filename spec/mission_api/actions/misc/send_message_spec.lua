require("spec_helper")

GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")
GG["MissionAPI"].Modules.BattleLog = VFS.Include("luarules/mission_api/battle_log.lua")

local actions = VFS.Include("luarules/mission_api/actions/misc/send_message.lua")
local action = actions[1]
local summarizeSchema = require("mission_api.schema_spec_helper")

describe("mission_api.actions.send_message", function()
	before_each(function()
		GG["MissionAPI"].BattleLogRaw = {}
		Spring.SetGameRulesParam = function() end
	end)

	it("declares its type and parameters", function()
		assert.are.same({
			type = "SendMessage",
			messageKey = "String!",
			messageData = "Table",
		}, summarizeSchema(action))
	end)

	describe("actionFunction", function()
		it("logs the message with its data", function()
			action.actionFunction("mission.intro", { name = "Cmdr" })

			assert.are.same({
				{ messageType = "Message", messageKey = "mission.intro", messageData = { name = "Cmdr" } },
			}, GG["MissionAPI"].BattleLogRaw)
		end)
	end)
end)
