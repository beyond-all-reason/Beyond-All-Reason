local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Hint",
		desc = "The running mission's hint (ShowHint / HideHint), a box at the top center",
		author = "PtaQ",
		date = "2026-11-12",
		license = "GNU GPL, v2 or later",
		layer = 6,
		enabled = true,
	}
end

-- Written by luarules/mission_api/actions/misc/hints.lua.
local HINT_PARAM = "missionHint"
local MODEL_NAME = "mission_hint"

local context, document, dataModel
local hint -- the decoded entry on screen, nil when none

local function show()
	dataModel.text = hint and BAR.I18N(hint.messageKey, hint.messageData) or ""
end

local function readHint()
	local encoded = Spring.GetGameRulesParam(HINT_PARAM)
	hint = encoded and Json.decode(encoded) or nil
	show()
end

function widget:GameFrame(frame)
	if hint and hint.untilFrame and frame >= hint.untilFrame then
		hint = nil
		show()
	end
end

function widget:LanguageChanged()
	show()
end

function widget:Initialize()
	if not Spring.GetGameRulesParam("inMission") then
		widgetHandler:RemoveWidget(self)
		return
	end
	context = RmlUi.GetContext("shared")
	dataModel = context:OpenDataModel(MODEL_NAME, { text = "" }, self)
	document = context:LoadDocument("luaui/RmlWidgets/gui_mission_hint/gui_mission_hint.rml", self)
	document:Show()
	widgetHandler:RegisterGlobal("MissionHintChanged", readHint)
	readHint()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("MissionHintChanged")
	if document then
		document:Close()
		context:RemoveDataModel(MODEL_NAME)
	end
end
