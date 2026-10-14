require("spec_helper")

local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")
local MessageTypes = VFS.Include("luarules/mission_api/parameter_types.lua").Enums.MessageType

local WIDGET_PATH = "luaui/Widgets/api_mission_battle_log.lua"

describe("luaui.Widgets.api_mission_battle_log", function()
	---@type table<string, any>
	local rulesParams
	---@type { key: string, data: table? }[]
	local i18nCalls
	---@type string
	local language

	-- Stands in for BAR.I18N, which is what turns a key into text.
	local function i18n(key, data)
		i18nCalls[#i18nCalls + 1] = { key = key, data = data }
		return language .. ": " .. key
	end

	-- As luarules/mission_api/battle_log.lua publishes an entry.
	local function publish(index, messageType, messageKey, messageData)
		rulesParams["missionBattleLog_" .. index] =
			Json.encode({ messageType = messageType, messageKey = messageKey, messageData = messageData })
		rulesParams.missionBattleLogCount = index
	end

	local function loadWidget()
		return SpringUnsyncedBuilder.new()
			:WithSpringFn("GetGameRulesParam", function(name)
				return rulesParams[name]
			end)
			:LoadWidget(WIDGET_PATH)
	end

	before_each(function()
		rulesParams = {}
		i18nCalls = {}
		language = "en"
		_G.BAR = { I18N = i18n } ---@diagnostic disable-line: global-in-non-module
	end)

	it("keeps an empty log outside a mission", function()
		local loaded = loadWidget()

		assert.are.same({}, loaded.WG.MissionAPI.BattleLog)
	end)

	it("translates the log published so far, oldest first", function()
		publish(1, MessageTypes.Message, "mission.intro", { name = "Cmdr" })
		publish(2, MessageTypes.Objective, "mission.escort")

		local loaded = loadWidget()

		assert.are.same({
			{ messageType = MessageTypes.Message, message = "en: mission.intro" },
			{ messageType = MessageTypes.Objective, message = "en: mission.escort" },
		}, loaded.WG.MissionAPI.BattleLog)
		assert.are.same({
			{ key = "mission.intro", data = { name = "Cmdr" } },
			{ key = "mission.escort" },
		}, i18nCalls)
	end)

	it("adds a message when told the log changed", function()
		local loaded = loadWidget()
		publish(1, MessageTypes.Message, "mission.intro")
		loaded.env.MissionBattleLogChanged()
		publish(2, MessageTypes.Objective, "mission.escort")
		loaded.env.MissionBattleLogChanged()

		assert.are.same({
			{ messageType = MessageTypes.Message, message = "en: mission.intro" },
			{ messageType = MessageTypes.Objective, message = "en: mission.escort" },
		}, loaded.WG.MissionAPI.BattleLog)
		assert.are.equal(2, #i18nCalls)
	end)

	it("rebuilds the text in the new language", function()
		publish(1, MessageTypes.Message, "mission.intro", { name = "Cmdr" })
		local loaded = loadWidget()

		language = "fr"
		loaded.env.widget:LanguageChanged()

		assert.are.same(
			{ { messageType = MessageTypes.Message, message = "fr: mission.intro" } },
			loaded.WG.MissionAPI.BattleLog
		)
		assert.are.same({
			{ key = "mission.intro", data = { name = "Cmdr" } },
			{ key = "mission.intro", data = { name = "Cmdr" } },
		}, i18nCalls)
	end)
end)
