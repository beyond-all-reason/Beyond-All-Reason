local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Hint",
		desc = "The running mission's hint (ShowHint / HideHint), a box at the top centre",
		author = "PtaQ",
		date = "2026",
		license = "GNU GPL, v2 or later",
		layer = 6,
		enabled = true,
	}
end

-- Reads luarules/mission_api/actions/misc/hints.lua's game rules params; the text goes through
-- BAR.I18N as the battle log's does. WG.MissionHintUI.text() is the read side for tests.

local MODEL_NAME = "mission_hint"
local RML_PATH = "luaui/RmlWidgets/gui_mission_hint/gui_mission_hint.rml"
local PARAM_PREFIX = "mission_hint_"
local POLL_SECONDS = 0.1

local modOptions = Spring.GetModOptions() or {}

local context, document, dm
local lastSerial = nil
local pollClock = 0
local untilFrame = 0
local shownText = ""

local function textOf(messageKey, dataText)
	local data = nil
	if type(dataText) == "string" and dataText ~= "" then
		local ok, decoded = pcall(Json.decode, dataText)
		data = ok and decoded or nil
	end
	local translated = BAR and BAR.I18N and BAR.I18N(messageKey, data)
	return type(translated) == "string" and translated ~= "" and translated or messageKey
end

local function show(text)
	shownText = text
	dm.text = text
	dm.shown = text ~= ""
end

local function refresh()
	local serial = Spring.GetGameRulesParam(PARAM_PREFIX .. "serial")
	if serial ~= lastSerial then
		lastSerial = serial
		local key = Spring.GetGameRulesParam(PARAM_PREFIX .. "key")
		untilFrame = tonumber((Spring.GetGameRulesParam(PARAM_PREFIX .. "until"))) or 0
		if type(key) == "string" and key ~= "" then
			show(textOf(key, Spring.GetGameRulesParam(PARAM_PREFIX .. "data")))
		else
			show("")
		end
	end
	if shownText ~= "" and untilFrame > 0 and Spring.GetGameFrame() >= untilFrame then
		show("")
	end
end

function widget:Update(dt)
	if not dm then
		return
	end
	pollClock = pollClock + (dt or 0)
	if pollClock >= POLL_SECONDS then
		pollClock = 0
		refresh()
	end
end

function widget:Initialize()
	if not modOptions.missionoptions then
		widgetHandler:RemoveWidget(self)
		return
	end
	context = RmlUi.GetContext("shared")
	if not context then
		widgetHandler:RemoveWidget(self)
		return
	end
	dm = context:OpenDataModel(MODEL_NAME, { shown = false, text = "" }, self)
	if not dm then
		widgetHandler:RemoveWidget(self)
		return
	end
	document = context:LoadDocument(RML_PATH, self)
	if not document then
		widget:Shutdown()
		widgetHandler:RemoveWidget(self)
		return
	end
	document:Show()
	WG.MissionHintUI = {
		-- The hint on screen, "" when none.
		text = function()
			return shownText
		end,
	}
end

function widget:Shutdown()
	WG.MissionHintUI = nil
	if document then
		document:Close()
		document = nil
	end
	if context and dm then
		context:RemoveDataModel(MODEL_NAME)
	end
	dm = nil
end
