local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Mission Objectives",
		desc    = "Displays the current mission stage and objectives.",
		author  = "",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

----------------------------------------------------------------
--- State
----------------------------------------------------------------

local stageTitle
local objectives     = {}  -- objectiveID -> { text, kind, progress, amount }
local objectiveOrder = {}  -- ordered list of objectiveIDs for stable display

local function contains(list, item)
	for _, v in ipairs(list) do
		if v == item then return true end
	end
	return false
end

----------------------------------------------------------------
--- Layout
----------------------------------------------------------------

local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = vsy / 1080

local panelW    = math.floor(300 * widgetScale)
local padX      = math.floor(12  * widgetScale)
local padY      = math.floor(10  * widgetScale)
local titleH    = math.floor(28  * widgetScale)
local lineH     = math.floor(20  * widgetScale)

local panelX, panelY  -- top-left of panel

local function updateLayout()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = vsy / 1080
	panelW  = math.floor(300 * widgetScale)
	padX    = math.floor(12  * widgetScale)
	padY    = math.floor(10  * widgetScale)
	titleH  = math.floor(28  * widgetScale)
	lineH   = math.floor(20  * widgetScale)
	panelX  = vsx - panelW - math.floor(10 * widgetScale)
	panelY  = math.floor(80 * widgetScale) + (vsy * 2 / 3)
end

updateLayout()

----------------------------------------------------------------
--- Fonts / FlowUI
----------------------------------------------------------------

local font, font2, loadedFontSize
local RectRound, UiElement, elementCorner

local function loadFontsAndUI()
	font, loadedFontSize = WG['fonts'].getFont()
	font2                = WG['fonts'].getFont(2)
	elementCorner        = WG.FlowUI.elementCorner
	RectRound            = WG.FlowUI.Draw.RectRound
	UiElement            = WG.FlowUI.Draw.Element
end

----------------------------------------------------------------
--- Draw list
----------------------------------------------------------------

local mainDList
local dirty = true

local function panelHeight()
	return titleH + padY + #objectiveOrder * lineH + padY
end

local function drawPanel()
	if not stageTitle then return end

	local scale = vsy / 1080
	local x = panelX
	local y = panelY
	local w = panelW
	local h = panelHeight()

	local opacity = math.max(0.75, Spring.GetConfigFloat("ui_opacity", 0.7))

	-- Background
	UiElement(x, y - h, x + w, y, 0, 1, 1, 1, 1, 1, 1, 1, opacity)

	-- Title bar (at the top)
	gl.Color(0, 0, 0, opacity)
	RectRound(x, y - titleH, x + w, y, elementCorner, 1, 1, 0, 0)

	local titleFontSize = math.floor(14 * scale)
	local bodyFontSize  = math.floor(13 * scale)

	-- Title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.5)
	font2:Print(stageTitle, x + padX, y - math.floor(titleH * 0.5) - math.floor(titleFontSize * 0.5), titleFontSize, "on")
	font2:End()

	-- Objectives
	font:Begin()
	for i, id in ipairs(objectiveOrder) do
		local obj = objectives[id]
		if not obj then break end

		local oy = y - titleH - padY - (i - 0.5) * lineH
		local kind = obj.kind

		if kind == 'done' then
			font:SetTextColor(0.5, 0.9, 0.5, 1)
		else
			font:SetTextColor(0.9, 0.85, 0.75, 1)
		end

		local marker = kind == 'done' and "[X] " or "[ ] "

		local suffix = ''
		if kind == 'progress' then
			suffix = ' (' .. tostring(obj.progress) .. '/' .. tostring(obj.amount) .. ')'
		elseif kind == 'remaining' then
			suffix = ' (' .. tostring(obj.progress) .. ' remaining)'
		end

		font:Print(marker .. obj.text .. suffix, x + padX, oy, bodyFontSize, "n")
	end
	font:End()
end

local function rebuildDList()
	if mainDList then gl.DeleteList(mainDList) end
	mainDList = gl.CreateList(drawPanel)
	dirty = false
end

----------------------------------------------------------------
--- Message parsing
----------------------------------------------------------------

function widget:RecvLuaMsg(msg, _)
	-- Stage: "missionStage|<title>|<objID1>|<objID2>|..."
	if msg:find("^missionStage|") then
		local parts = {}
		for part in (msg .. '|'):gmatch('([^|]*)|') do
			parts[#parts + 1] = part
		end
		stageTitle = parts[2]
		-- Clear current objectives
		objectives = {}
		objectiveOrder = {}
		-- Add objective IDs for this stage
		for i = 3, #parts do
			if parts[i] ~= '' then
				objectiveOrder[#objectiveOrder + 1] = parts[i]
			end
		end
		dirty = true
		return
	end

	-- Objective: "missionObjective|<kind>|<id>|<text>[|<progress>[|<amount>]]"
	if msg:find("^missionObjective|") then
		local parts = {}
		for part in (msg .. '|'):gmatch('([^|]*)|') do
			parts[#parts + 1] = part
		end
		-- parts: [1]=missionObjective [2]=kind [3]=id [4]=text [5]=progress [6]=amount
		local kind     = parts[2]
		local id       = parts[3]
		local text     = parts[4]
		local progress = tonumber(parts[5])
		local amount   = tonumber(parts[6])

		-- Only update if this objective is in the current stage
		if contains(objectiveOrder, id) then
			objectives[id] = { kind = kind, text = text, progress = progress, amount = amount }
			dirty = true
		end
	end
end

----------------------------------------------------------------
--- Widget call-ins
----------------------------------------------------------------

function widget:ViewResize()
	updateLayout()
	loadFontsAndUI()
	dirty = true
end

function widget:DrawScreen()
	if not stageTitle then return end
	if dirty then rebuildDList() end
	if mainDList then gl.CallList(mainDList) end
end

function widget:Initialize()
	if not WG['fonts'] or not WG.FlowUI then
		Spring.Echo("[Mission Objectives] Required APIs (fonts, FlowUI) not available.")
		widgetHandler:RemoveWidget()
		return
	end
	loadFontsAndUI()
end

function widget:Shutdown()
	if mainDList then
		gl.DeleteList(mainDList)
		mainDList = nil
	end
end
