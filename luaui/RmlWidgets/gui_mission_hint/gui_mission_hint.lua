local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Hint",
		desc = "The running mission's hint (ShowHint / HideHint), a box at the top center",
		author = "PtaQ",
		date = "2026-11-12",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Written by luarules/mission_api/actions/misc/hints.lua.
local HINT_PARAM = "missionHint"
local MODEL_NAME = "mission_hint"

local ui = {} -- context, document, dataModel
---@type table? the decoded entry on screen
local hint
---@type number? real seconds a timed hint has left
local secondsLeft

local function show()
	ui.dataModel.text = hint and BAR.I18N(hint.messageKey, hint.messageData) or ""
end

local function readHint()
	local encoded = Spring.GetGameRulesParam(HINT_PARAM)
	hint = encoded and Json.decode(encoded) or nil
	secondsLeft = hint and hint.seconds
	show()
end

-- Reading time is real time, and stands still while the game is paused.
function widget:Update(dt)
	local isPaused = select(3, Spring.GetGameSpeed())
	if not secondsLeft or isPaused then
		return
	end
	secondsLeft = secondsLeft - dt
	if secondsLeft <= 0 then
		hint, secondsLeft = nil, nil
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
	local context = RmlUi.GetContext("shared")
	if not context then
		return
	end
	ui.context = context
	ui.dataModel = context:OpenDataModel(MODEL_NAME, { text = "" }, self)
	ui.document = context:LoadDocument("luaui/RmlWidgets/gui_mission_hint/gui_mission_hint.rml", self)
	ui.document:Show()
	widgetHandler:RegisterGlobal("MissionHintChanged", readHint)
	readHint()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("MissionHintChanged")
	if ui.document then
		ui.document:Close()
		ui.context:RemoveDataModel(MODEL_NAME)
	end
end
