local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

local MessageTypes = MissionSpecEnv.include(env, "luarules/mission_api/parameter_types.lua").Enums.MessageType
local battleLog = MissionSpecEnv.include(env, "luarules/mission_api/battle_log.lua")

describe("mission_api.battle_log", function()
	---@type table<string, any>
	local rulesParams
	---@type string[]
	local syncActions
	---@type string[]
	local echoes

	before_each(function()
		GG["MissionAPI"] = { BattleLogRaw = {} }
		rulesParams = {}
		syncActions = {}
		echoes = {}
		env.Spring.SetGameRulesParam = function(name, value)
			rulesParams[name] = value
		end
		env.SendToUnsynced = function(action)
			syncActions[#syncActions + 1] = action
		end
		env.Spring.Echo = function(message)
			echoes[#echoes + 1] = message
		end
	end)

	describe("AddMessage", function()
		it("appends to the raw log, newest last", function()
			battleLog.AddMessage(MessageTypes.Message, "mission.intro", { name = "Cmdr" })
			battleLog.AddMessage(MessageTypes.Objective, "mission.escort")

			assert.are.same({
				{ messageType = MessageTypes.Message, messageKey = "mission.intro", messageData = { name = "Cmdr" } },
				{ messageType = MessageTypes.Objective, messageKey = "mission.escort" },
			}, GG["MissionAPI"].BattleLogRaw)
		end)

		it("publishes each entry and the count as game rules params", function()
			battleLog.AddMessage(MessageTypes.Message, "mission.intro", { name = "Cmdr" })
			battleLog.AddMessage(MessageTypes.Objective, "mission.escort")

			assert.are.equal(2, rulesParams.missionBattleLogCount)
			assert.are.same(
				{ messageType = MessageTypes.Message, messageKey = "mission.intro", messageData = { name = "Cmdr" } },
				Json.decode(rulesParams.missionBattleLog_1)
			)
			assert.are.same(
				{ messageType = MessageTypes.Objective, messageKey = "mission.escort" },
				Json.decode(rulesParams.missionBattleLog_2)
			)
		end)

		it("tells unsynced once per message", function()
			battleLog.AddMessage(MessageTypes.Message, "mission.intro")
			battleLog.AddMessage(MessageTypes.Objective, "mission.escort")

			assert.are.same({ "MissionBattleLogChanged", "MissionBattleLogChanged" }, syncActions)
		end)

		it("echoes the message key until a widget displays the log", function()
			battleLog.AddMessage(MessageTypes.Message, "mission.intro")

			assert.are.same({ "mission.intro" }, echoes)
		end)
	end)
end)
