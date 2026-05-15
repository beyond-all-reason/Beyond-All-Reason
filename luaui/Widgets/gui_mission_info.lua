local _modOpts = Spring.GetModOptions()
local isScenario = _modOpts ~= nil and _modOpts.scenariooptions ~= nil

if not isScenario then
	return
end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name    = "Mission Info",
		desc    = "Shows the scenario mission briefing, objectives, and details.",
		author  = "Floirs",
		date    = "May 2026",
		license = "GNU GPL, v2 or later",
		layer   = -99990,
		enabled = true,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max

-- Localized Spring API for performance
local spGetViewGeometry = Spring.GetViewGeometry
local spGetGameSpeed   = Spring.GetGameSpeed

local vsx, vsy = spGetViewGeometry()

local show          = true   -- shown by default on first open
local showOnceMore  = false  -- used for guishader delay
local wePaused      = false  -- tracks if we issued the pause
local justClosedFromPress = false  -- prevents toggleWindow re-opening after mouseEvent close

local screenHeightOrg = 520
local screenWidthOrg  = 1050
local screenHeight = screenHeightOrg
local screenWidth  = screenWidthOrg
local startLine    = 1

local customScale  = 1
local centerPosX   = 0.5
local centerPosY   = 0.5
local screenX = (vsx * centerPosX) - (screenWidth / 2)
local screenY = (vsy * centerPosY) + (screenHeight / 2)

local math_isInRect = math.isInRect

local glCreateList = gl.CreateList
local glCallList   = gl.CallList
local glDeleteList = gl.DeleteList

local widgetScale = 1

local textLines      = {}
local totalTextLines = 0
local maxLines       = 20

local font, font2, loadedFontSize, titleRect, backgroundGuishader, textList, dlistcreated

local RectRound, UiElement, UiScroller, elementCorner

-- ─── Scenario data loading ───────────────────────────────────────────────────

local scenarioData = nil

local function getScenarioid()
	local raw = _modOpts.scenariooptions
	if not raw then return nil end
	local ok, decoded = pcall(string.base64Decode, raw)
	if not ok or not decoded then return nil end
	local ok2, opts = pcall(Json.decode, decoded)
	if not ok2 or type(opts) ~= 'table' then return nil end
	return opts.scenarioid
end

local function findScenarioData(targetid)
	if not targetid then return nil end
	local files = VFS.DirList("singleplayer/scenarios/", "*.lua")
	if not files then return nil end
	for _, fpath in ipairs(files) do
		if not string.find(fpath, "scenarioscripts") then
			local ok, data = pcall(VFS.Include, fpath)
			if ok and type(data) == 'table' and data.scenarioid == targetid then
				return data
			end
		end
	end
	return nil
end

local function buildTextLines(data)
	local lines = {}

	local function addTitle(s)
		lines[#lines + 1] = { kind = "title", text = s or "" }
	end

	local function addHeader(s)
		lines[#lines + 1] = { kind = "header", text = s or "" }
	end

	local function addLine(s)
		lines[#lines + 1] = { kind = "body", text = s or "" }
	end

	-- Scenario title as the main heading
	addTitle(data.title or Spring.I18N('ui.missioninfo.title'))
	addLine("")

	-- Difficulty
	if data.defaultdifficulty then
		local diffStr = Spring.I18N('ui.missioninfo.difficulty') .. ": " .. data.defaultdifficulty
		if data.difficulty then
			diffStr = diffStr .. "  (" .. data.difficulty .. "/10)"
		end
		addLine(diffStr)
	end

	addLine("")

	-- Objectives
	if data.victorycondition or data.losscondition then
		addHeader(Spring.I18N('ui.missioninfo.objectives'))
		addLine("")
		if data.victorycondition then
			addLine(Spring.I18N('ui.missioninfo.victory') .. ":  " .. data.victorycondition)
		end
		if data.losscondition then
			addLine(Spring.I18N('ui.missioninfo.defeat') .. ":  " .. data.losscondition)
		end
		addLine("")
	end

	-- Summary
	if data.summary and data.summary ~= "" then
		addHeader(Spring.I18N('ui.missioninfo.summary'))
		addLine("")
		for _, l in ipairs(string.lines(data.summary)) do
			addLine(l)
		end
		addLine("")
	end

	-- Briefing
	if data.briefing and data.briefing ~= "" then
		addHeader(Spring.I18N('ui.missioninfo.briefing'))
		addLine("")
		for _, l in ipairs(string.lines(data.briefing)) do
			addLine(l)
		end
	end

	return lines
end

-- ─── View resize / layout ────────────────────────────────────────────────────

function widget:ViewResize()
	vsx, vsy = spGetViewGeometry()
	widgetScale = ((vsx + vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx / vsy) - 1.78)))

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth  = mathFloor(screenWidthOrg  * widgetScale)
	screenX = mathFloor((vsx * centerPosX) - (screenWidth  / 2))
	screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)
	elementCorner = WG.FlowUI.elementCorner

	RectRound  = WG.FlowUI.Draw.RectRound
	UiElement  = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller

	if textList then gl.DeleteList(textList) end
	textList = gl.CreateList(DrawWindow)

	-- Layout changed: invalidate the guishader DList so it gets rebuilt next draw
	if backgroundGuishader ~= nil and WG['guishader'] then
		WG['guishader'].DeleteDlist('missiontext')
		backgroundGuishader = nil
	end
end

-- ─── Drawing ─────────────────────────────────────────────────────────────────

function DrawTextarea(x, y, width, height, scrollbar)
	local scrollbarOffsetTop    = 0
	local scrollbarOffsetBottom = 0
	local scrollbarMargin       = 10 * widgetScale
	local scrollbarWidth        = 8  * widgetScale
	local scrollbarPosWidth     = 4  * widgetScale

	local fontSizeTitle = 18 * widgetScale
	local fontSizeLine  = 16 * widgetScale
	local lineSeparator = 2  * widgetScale

	local fontColorTitle  = { 1,    1,    1,    1 }
	local fontColorHeader = { 0.9,  0.78, 0.45, 1 }
	local fontColorLine   = { 0.8,  0.77, 0.74, 1 }

	maxLines = mathFloor(height / (lineSeparator + fontSizeTitle))

	-- scrollbar
	if scrollbar then
		if totalTextLines > maxLines or startLine > 1 then
			local scrollbarTop    = y - scrollbarOffsetTop    - scrollbarMargin - (scrollbarWidth - scrollbarPosWidth)
			local scrollbarBottom = y - scrollbarOffsetBottom - height + scrollbarMargin + (scrollbarWidth - scrollbarPosWidth)

			UiScroller(
				mathFloor(x + width - scrollbarMargin - scrollbarWidth),
				mathFloor(scrollbarBottom - (scrollbarWidth - scrollbarPosWidth)),
				mathFloor(x + width - scrollbarMargin),
				mathFloor(scrollbarTop    + (scrollbarWidth - scrollbarPosWidth)),
				(#textLines) * (lineSeparator + fontSizeTitle),
				(startLine - 1) * (lineSeparator + fontSizeTitle)
			)
		end
	end

	-- text
	if #textLines > 0 then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines + 1 do
			if (lineSeparator + fontSizeTitle) * j > height then break end
			if textLines[lineKey] == nil then break end

			local entry = textLines[lineKey]
			local kind = entry.kind
			local text = entry.text

			if kind == "title" then
				font:SetTextColor(fontColorTitle)
				font:Print(text, x - (9 * widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeTitle, "n")
			elseif kind == "header" then
				font:SetTextColor(fontColorHeader)
				font:Print(text, x - (9 * widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeTitle, "n")
			else
				-- body: word-wrapped
				font:SetTextColor(fontColorLine)
				local wrappedText, numLines = font:WrapText(text, (width - (50 * widgetScale)) * (loadedFontSize / fontSizeLine))
				if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then break end
				font:Print(wrappedText, x, y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				j = j + (numLines - 1)
			end

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end

function DrawWindow()
	-- background panel
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1, 1, 1, 1, WG.FlowUI.clampedOpacity)

	-- title tab
	local title = Spring.I18N('ui.topbar.button.mission')
	local titleFontSize = 18 * widgetScale
	titleRect = {
		screenX,
		screenY,
		mathFloor(screenX + (font2:GetTextWidth(title) * titleFontSize) + (titleFontSize * 1.5)),
		mathFloor(screenY + (titleFontSize * 1.7)),
	}

	gl.Color(0, 0, 0, WG.FlowUI.clampedOpacity)
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	-- title text
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, screenX + (titleFontSize * 0.75), screenY + (8 * widgetScale), titleFontSize, "on")
	font2:End()

	-- content area
	DrawTextarea(
		screenX + mathFloor(28 * widgetScale),
		screenY - mathFloor(14 * widgetScale),
		screenWidth - mathFloor(28 * widgetScale),
		screenHeight - mathFloor(28 * widgetScale),
		1
	)
end

function widget:DrawScreen()
	if not textList then
		textList = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then
		gl.Texture(false)

		glCallList(textList)

		if WG['guishader'] and backgroundGuishader == nil then
			backgroundGuishader = glCreateList(function()
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
			end)
			dlistcreated = true
			WG['guishader'].InsertDlist(backgroundGuishader, 'missiontext')
		end
		showOnceMore = false

		local x, y = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY)
		or (titleRect and math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4])) then
			Spring.SetMouseCursor('cursornormal')
		end

	elseif dlistcreated and WG['guishader'] then
		WG['guishader'].DeleteDlist('missiontext')
		backgroundGuishader = nil
		dlistcreated = nil
	end
end

-- ─── Input ───────────────────────────────────────────────────────────────────

-- ─── Pause helpers ───────────────────────────────────────────────────────────

local function pauseGame()
	local _, _, isPaused = spGetGameSpeed()
	if not isPaused then
		Spring.SendCommands("pause 1")
		wePaused = true
	end
end

local function unpauseGame()
	if wePaused then
		wePaused = false
		Spring.SendCommands("pause 0")
	end
end

function widget:KeyPress(key)
	if key == 27 then  -- ESC
		show = false
	end
end

function widget:MouseWheel(up, value)
	if show then
		local addLines = value * -3
		startLine = startLine + addLines
		if startLine >= totalTextLines - maxLines then
			startLine = totalTextLines - maxLines + 1
		end
		if startLine < 1 then startLine = 1 end

		if textList then glDeleteList(textList) end
		textList = gl.CreateList(DrawWindow)
		return true
	end
	return false
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then return end
	if show then
		-- Inside main panel: consume the click
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			return true
		-- Inside title tab: consume the click
		elseif titleRect ~= nil and math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			return true
		else
			-- Outside: close on press but DON'T consume — lets top bar buttons receive the click
			if not release then
				showOnceMore = show
				show = false
				justClosedFromPress = true
				unpauseGame()
			end
		end
	end
end

-- ─── Lifecycle ───────────────────────────────────────────────────────────────

function widget:Initialize()
	local scenarioid = getScenarioid()
	scenarioData = findScenarioData(scenarioid)

	if scenarioData then
		textLines = buildTextLines(scenarioData)
	else
		-- Fallback: show what we can from the scenarioid alone
		textLines = {
			{ kind = "title", text = Spring.I18N('ui.missioninfo.title') },
			{ kind = "body",  text = "" },
			{ kind = "body",  text = "Mission ID: " .. (scenarioid or "unknown") },
			{ kind = "body",  text = "" },
			{ kind = "body",  text = "No additional briefing data found." },
		}
	end

	totalTextLines = #textLines

	WG['missioninfo'] = {}
	WG['missioninfo'].toggle = function(state)
		local wasVisible = show
		if state ~= nil then
			show = state
			justClosedFromPress = false  -- explicit state set clears the flag
		else
			show = not show
		end
		if show and not wasVisible then
			pauseGame()
		elseif not show and wasVisible then
			unpauseGame()
		end
		if show then
			if textList then glDeleteList(textList) end
			textList = gl.CreateList(DrawWindow)
		end
	end
	WG['missioninfo'].isvisible = function()
		-- Report true while justClosedFromPress so toggleWindow treats us as
		-- "was open" and doesn't immediately re-open after our mouseEvent close.
		return show or justClosedFromPress
	end

	widget:ViewResize()
end

function widget:GameStart()
	if show then
		pauseGame()
	end
end

function widget:Update()
	-- Clear the flag after all mouse events for this frame have been processed
	justClosedFromPress = false
end

function widget:Shutdown()
	if show then
		unpauseGame()
	end
	if textList then
		glDeleteList(textList)
		textList = nil
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('missiontext')
	end
	WG['missioninfo'] = nil
end

function widget:LanguageChanged()
	widget:ViewResize()
end
