require("spec_helper")

local SpringUnsyncedBuilder = VFS.Include("spec/builders/spring_unsynced_builder.lua")

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
		loaded.env.widget:GameFrame(1)

		assert.are.same({}, loaded.WG.missionBattleLog.GetMessages())
	end)

	it("translates the log published so far, oldest first", function()
		publish(1, "Message", "mission.intro", { name = "Cmdr" })
		publish(2, "Objective", "mission.escort")

		local loaded = loadWidget()

		assert.are.same({
			{ messageType = "Message", message = "en: mission.intro" },
			{ messageType = "Objective", message = "en: mission.escort" },
		}, loaded.WG.missionBattleLog.GetMessages())
		assert.are.same({
			{ key = "mission.intro", data = { name = "Cmdr" } },
			{ key = "mission.escort" },
		}, i18nCalls)
	end)

	it("adds the messages published since, on game frame", function()
		local loaded = loadWidget()
		publish(1, "Message", "mission.intro")
		loaded.env.widget:GameFrame(1)
		publish(2, "Objective", "mission.escort")
		loaded.env.widget:GameFrame(2)
		loaded.env.widget:GameFrame(3)

		assert.are.same({
			{ messageType = "Message", message = "en: mission.intro" },
			{ messageType = "Objective", message = "en: mission.escort" },
		}, loaded.WG.missionBattleLog.GetMessages())
		assert.are.equal(2, #i18nCalls)
	end)

	it("rebuilds the text in the new language", function()
		publish(1, "Message", "mission.intro", { name = "Cmdr" })
		local loaded = loadWidget()

		language = "fr"
		loaded.env.widget:LanguageChanged()

		assert.are.same(
			{ { messageType = "Message", message = "fr: mission.intro" } },
			loaded.WG.missionBattleLog.GetMessages()
		)
		assert.are.same({
			{ key = "mission.intro", data = { name = "Cmdr" } },
			{ key = "mission.intro", data = { name = "Cmdr" } },
		}, i18nCalls)
	end)
end)
