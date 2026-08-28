local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Objectives",
		desc = "Shows the mission's live objective list.",
		author = "Mission API",
		date = "August 2026",
		license = "GNU GPL, v2 or later",
		layer = -99989,
		enabled = true,
	}
end

local spGetGameRulesParam = Spring.GetGameRulesParam
local spGetViewGeometry = Spring.GetViewGeometry

local OBJECTIVES_PARAM = "missionObjectives"
local VERSION_PARAM = "missionObjectivesVersion"

local objectives = {}
local knownVersion = -1
local vsx, vsy = spGetViewGeometry()

local font

---The resolver. STUB: an i18n lookup that falls back to the key itself, so authored
---prose and translation keys both render and the mission-i18n question stays open.
---@param textKey string?
local function resolveText(textKey)
	if not textKey or textKey == "" then
		return ""
	end
	local translated = BAR.I18N(textKey)
	if translated and translated ~= "" then
		return translated
	end
	return textKey
end

---Rules params, not messages: a late joiner, a `/luaui reload`, a spectator and a replay
---all have to render the list, and only state that persists can do that. The version
---counter is what makes polling cheap.
local function readObjectives()
	local version = spGetGameRulesParam(VERSION_PARAM)
	if not version or version == knownVersion then
		return false
	end

	knownVersion = version

	local encoded = spGetGameRulesParam(OBJECTIVES_PARAM)
	if type(encoded) ~= "string" or encoded == "" then
		objectives = {}
		return true
	end

	local ok, decoded = pcall(Json.decode, encoded)
	objectives = (ok and type(decoded) == "table") and decoded or {}
	return true
end

---Nothing here filters: synced already dropped what the player should not see, because a
---widget can be replaced and cannot be trusted with it.
local function objectiveLine(objective)
	local text = resolveText(objective.textKey)

	if objective.amount and objective.amount > 0 and not objective.completed then
		text = text .. "  " .. tostring(objective.progress or 0) .. "/" .. tostring(objective.amount)
	end

	if objective.completed then
		local outcome = objective.failed and BAR.I18N("ui.mission.failed") or BAR.I18N("ui.mission.completed")
		text = text .. "  (" .. tostring(outcome) .. ")"
	end

	return text
end

function widget:Initialize()
	if not WG.FlowUI then
		widgetHandler:RemoveWidget()
		return
	end
	font = WG.fonts and WG.fonts.getFont and WG.fonts.getFont() or gl.LoadFont("FreeSansBold.otf", 16, 2, 2)
	widgetHandler:RegisterGlobal("MissionMessage", MissionMessage)
	readObjectives()
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal("MissionMessage")
end

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
end

function widget:GameFrame(frameNumber)
	-- Slow poll: the version counter only moves when synced republishes.
	if frameNumber % 15 == 0 then
		readObjectives()
	end
end

function widget:DrawScreen()
	if #objectives == 0 then
		return
	end

	local lineHeight = 18
	local padding = 10
	local width = 320
	local height = padding * 2 + lineHeight * (#objectives + 1)
	local x = vsx - width - 20
	local y = vsy - 140

	WG.FlowUI.Draw.Element(x, y - height, x + width, y, 1, 1, 1, 1)

	font:Begin()
	font:SetTextColor(1, 1, 1, 1)
	font:Print(BAR.I18N("ui.mission.objectives"), x + padding, y - padding - lineHeight, 16, "o")

	for i = 1, #objectives do
		local objective = objectives[i]
		if objective.completed then
			font:SetTextColor(0.6, 0.6, 0.6, 1)
		else
			font:SetTextColor(1, 1, 1, 1)
		end
		font:Print(objectiveLine(objective), x + padding, y - padding - lineHeight * (i + 1), 14, "o")
	end
	font:End()
end

---A moment, relayed by the gadget's unsynced half through `Script.LuaUI.MissionMessage`.
---Reached by a registered global, not a callin. STUB: echoed to the console until there
---is somewhere better to put transient mission text.
function MissionMessage(message)
	Spring.Echo(resolveText(message))
end
