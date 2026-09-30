require("spec_helper")

local battleLog = VFS.Include("luarules/mission_api/battle_log.lua")

describe("mission_api.battle_log", function()
	---@type table<string, any>
	local rulesParams
	---@type string[]
	local echoes
	local realEcho = Spring.Echo

	before_each(function()
		GG["MissionAPI"] = { BattleLogRaw = {} }
		rulesParams = {}
		echoes = {}
		Spring.SetGameRulesParam = function(name, value)
			rulesParams[name] = value
		end
		Spring.Echo = function(message)
			echoes[#echoes + 1] = message
		end
	end)

	after_each(function()
		Spring.Echo = realEcho
	end)

	it("names the kinds of message", function()
		assert.are.same({
			Briefing = "Briefing",
			Message = "Message",
			Objective = "Objective",
			Notification = "Notification",
			Dialogue = "Dialogue",
		}, battleLog.MessageTypes)
	end)

	describe("AddMessage", function()
		it("appends to the raw log, newest last", function()
			battleLog.AddMessage("Message", "mission.intro", { name = "Cmdr" })
			battleLog.AddMessage("Objective", "mission.escort")

			assert.are.same({
				{ messageType = "Message", messageKey = "mission.intro", messageData = { name = "Cmdr" } },
				{ messageType = "Objective", messageKey = "mission.escort" },
			}, GG["MissionAPI"].BattleLogRaw)
		end)

		it("publishes each entry and the count as game rules params", function()
			battleLog.AddMessage("Message", "mission.intro", { name = "Cmdr" })
			battleLog.AddMessage("Objective", "mission.escort")

			assert.are.equal(2, rulesParams.missionBattleLogCount)
			assert.are.same(
				{ messageType = "Message", messageKey = "mission.intro", messageData = { name = "Cmdr" } },
				Json.decode(rulesParams.missionBattleLog_1)
			)
			assert.are.same(
				{ messageType = "Objective", messageKey = "mission.escort" },
				Json.decode(rulesParams.missionBattleLog_2)
			)
		end)

		it("echoes the message key until a widget displays the log", function()
			battleLog.AddMessage("Message", "mission.intro")

			assert.are.same({ "mission.intro" }, echoes)
		end)
	end)
end)
