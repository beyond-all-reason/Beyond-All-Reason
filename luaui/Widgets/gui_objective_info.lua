function widget:GetInfo()
	return {
		name    = "Objective Info",
		desc    = "Displays information about game objectives.",
		author  = "Floris, SethDGamre",
		date    = "Jan 2020",
		license = "GNU GPL, v2 or later",
		layer   = -99990,
		enabled = true,
	}
end

local mathFloor = math.floor
local mathMax = math.max
local spGetViewGeometry = Spring.GetViewGeometry

local modOptions = Spring.GetModOptions()
local scavengersAIEnabled = Spring.Utilities.Gametype.IsScavengers()

local textTable = {}
local seenObjectives = {}
local hasAlwaysShowObjectives = false
local hasUnseen = false
local allText = nil

-- alwaysShow: when true, show this objective every time the game runs
-- when false, only show it once and remember it's been seen
local function loadObjectivesText(objectiveType, alwaysShow)
	local objectiveText = Spring.I18N("objectives." .. objectiveType)
	if objectiveText then
		if alwaysShow then
			table.insert(textTable, objectiveText)
			hasAlwaysShowObjectives = true
		else
			if seenObjectives[objectiveType] == nil then
				seenObjectives[objectiveType] = false
			end

			table.insert(textTable, 1, objectiveText)

			if seenObjectives[objectiveType] == false then
				hasUnseen = true
			end
		end
	else
		Spring.Echo("Objective not found: " .. objectiveType)
	end
end

local function initializeObjectives()
	if scavengersAIEnabled then
		loadObjectivesText("scavengers", false)
	end
	-- add additional if statements to add objectives here. Multiple objective entries work but it's best to only do one at a time.
end

local show = false

local vsx,vsy = spGetViewGeometry()

local screenHeightOrg = 520
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg
local startLine = 1

local customScale = 1
local centerPosX = 0.5
local centerPosY = 0.5
local screenX = (vsx*centerPosX) - (screenWidth/2)
local screenY = (vsy*centerPosY) + (screenHeight/2)

local math_isInRect = math.isInRect

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local widgetScale = 1

local textLines = {}
local totalTextLines = 0

local maxLines = 20

local showOnceMore = false		-- used because of GUI shader delay

local font, font2, loadedFontSize, titleRect, backgroundGuishader, textList, dlistcreated

local RectRound, UiElement, UiScroller, elementCorner

function widget:ViewResize()
	vsx,vsy = spGetViewGeometry()
	widgetScale = ((vsx + vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx / vsy) - 1.78)))        -- make smaller for ultrawide screens

	screenHeight = mathFloor(screenHeightOrg * widgetScale)
	screenWidth = mathFloor(screenWidthOrg * widgetScale)
	screenX = mathFloor((vsx * centerPosX) - (screenWidth / 2))
	screenY = mathFloor((vsy * centerPosY) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(2)
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller

	if textList then gl.DeleteList(textList) end
	textList = gl.CreateList(DrawWindow)
end


function DrawTextarea(x,y,width,height,scrollbar)
	local scrollbarOffsetTop 		= 0	-- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom 	= 0	-- note: wont add the offset to the top, only to bottom
	local scrollbarMargin    		= 10 * widgetScale
	local scrollbarWidth     		= 8 * widgetScale
	local scrollbarPosWidth  		= 4 * widgetScale

	local fontSizeTitle				= 18 * widgetScale
	local fontSizeLine				= 16 * widgetScale
	local lineSeparator				= 2 * widgetScale

	local fontColorTitle			= {1,1,1,1}
	local fontColorLine				= {0.8,0.77,0.74,1}

	maxLines = mathFloor(height / (lineSeparator + fontSizeTitle))

	-- textarea scrollbar
	if scrollbar then
		if (totalTextLines > maxLines or startLine > 1) then	-- only show scroll above X lines
			local scrollbarTop       = y-scrollbarOffsetTop-scrollbarMargin-(scrollbarWidth-scrollbarPosWidth)
			local scrollbarBottom    = y-scrollbarOffsetBottom-height+scrollbarMargin+(scrollbarWidth-scrollbarPosWidth)

			UiScroller(
				mathFloor(x + width - scrollbarMargin - scrollbarWidth),
				mathFloor(scrollbarBottom - (scrollbarWidth - scrollbarPosWidth)),
				mathFloor(x + width - scrollbarMargin),
				mathFloor(scrollbarTop + (scrollbarWidth - scrollbarPosWidth)),
				(#textLines) * (lineSeparator + fontSizeTitle),
				(startLine-1) * (lineSeparator + fontSizeTitle)
			)
		end
	end

	-- draw textarea
	if allText then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines+1 do
			-- maxlines is not exact, just a failsafe
			if (lineSeparator + fontSizeTitle) * j > height then
				break
			end
			if textLines[lineKey] == nil then
				break
			end

			local line = textLines[lineKey]
			local numLines
			if string.find(line, '^[A-Z][A-Z]') then
				font:SetTextColor(fontColorTitle)
				font:Print(line, x-(9 * widgetScale), y-(lineSeparator+fontSizeTitle)*j, fontSizeTitle, "n")

			else
				font:SetTextColor(fontColorLine)
				-- line
				line, numLines = font:WrapText(line, (width-(50 * widgetScale))*(loadedFontSize/fontSizeLine))
				if (lineSeparator+fontSizeTitle) * (j+numLines-1) > height then
					break
				end
				font:Print(line, x, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
				j = j + (numLines - 1)
			end

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end


function DrawWindow()
	-- background
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, mathMax(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))

	-- title background
	local title = Spring.I18N('ui.topbar.button.objectives')
	local titleFontSize = 18 * widgetScale
	titleRect = { screenX, screenY, mathFloor(screenX + (font2:GetTextWidth(title) * titleFontSize) + (titleFontSize*1.5)), mathFloor(screenY + (titleFontSize*1.7)) }

	gl.Color(0, 0, 0, mathMax(0.75, Spring.GetConfigFloat("ui_opacity", 0.7)))
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, screenX + (titleFontSize * 0.75), screenY + (8*widgetScale), titleFontSize, "on")
	font2:End()

	-- textarea
	DrawTextarea(screenX+mathFloor(28 * widgetScale), screenY-mathFloor(14 * widgetScale), screenWidth-mathFloor(28 * widgetScale), screenHeight-mathFloor(28 * widgetScale), 1)
end


function widget:DrawScreen()

  -- draw the help
  if not textList then
      textList = gl.CreateList(DrawWindow)
  end

  if show or showOnceMore then
	  gl.Texture(false)	-- some other widget left it on

		-- draw the text panel
	  glCallList(textList)

		if WG['guishader'] then
			if backgroundGuishader ~= nil then
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList(function()
				-- background
				RectRound(screenX, screenY - screenHeight, screenX + screenWidth, screenY, elementCorner, 0, 1, 1, 1)
				-- title
				RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)
			end)
			dlistcreated = true
			WG['guishader'].InsertDlist(backgroundGuishader, 'text')
		end
		showOnceMore = false

	  local x, y, pressed = Spring.GetMouseState()
	  if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
		  Spring.SetMouseCursor('cursornormal')
	  end

  elseif dlistcreated and WG['guishader'] then
	WG['guishader'].DeleteDlist('text')
	dlistcreated = nil
  end
end

function widget:KeyPress(key)
	if key == 27 then	-- ESC
		show = false
	end
end

function widget:MouseWheel(up, value)

	if show then
		local addLines = value*-3 -- direction is retarded

		startLine = startLine + addLines
		if startLine >= totalTextLines - maxLines then
			startLine = totalTextLines - maxLines+1
		end
		if startLine < 1 then startLine = 1 end

		if textList then
			glDeleteList(textList)
		end

		textList = gl.CreateList(DrawWindow)
		return true
	else
		return false
	end
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
		-- on window
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			return true
		elseif titleRect == nil or not math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			if release then
				showOnceMore = show        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
				
				-- Mark all one-time objectives as seen when the window is closed
				for objectiveType, seen in pairs(seenObjectives) do
					if not seen then
						seenObjectives[objectiveType] = true
					end
				end
				hasUnseen = false  -- All one-time objectives have been seen now
			end
			return true
		end
	end
end

function widget:Initialize()
	textTable = {}
	hasAlwaysShowObjectives = false
	hasUnseen = false
	
	initializeObjectives()

	if not next(textTable) then
		widgetHandler:RemoveWidget()
		return false
	end
	
	
	allText = table.concat(textTable, "\n______________________________________________________________________________\n\n")
	
	show = hasAlwaysShowObjectives or hasUnseen

	if allText then
		WG['objectives_info'] = {}
		WG['objectives_info'].toggle = function(state)
			if state ~= nil then
				show = state
			else
				show = not show
			end
			
			if not show then
				local objectivesChanged = false
				for objectiveType, seen in pairs(seenObjectives) do
					if not seen then
						seenObjectives[objectiveType] = true
						objectivesChanged = true
					end
				end
				if objectivesChanged then
					hasUnseen = false
				end
			end
		end
		WG['objectives_info'].isvisible = function()
			return show
		end
		
		WG['objectives_info'].addObjective = function(objectiveType, alwaysShow)
			local objectiveText = Spring.I18N("objectives." .. objectiveType)
			if objectiveText then
				local shouldShow = false
				
				if alwaysShow then
					hasAlwaysShowObjectives = true
					table.insert(textTable, objectiveText)
					shouldShow = true
				else
					if seenObjectives[objectiveType] == nil then
						seenObjectives[objectiveType] = false
					end
					
					table.insert(textTable, 1, objectiveText)
					
					if seenObjectives[objectiveType] == false then
						hasUnseen = true
						shouldShow = true
					end
				end
				
				allText = table.concat(textTable, "\n______________________________________________________________________________\n\n")
				
				textLines = string.lines(allText)
				totalTextLines = #textLines
				
				if textList then
					glDeleteList(textList)
				end
				textList = gl.CreateList(DrawWindow)
				
				if shouldShow then
					show = true
				end
				
				return true
			else
				Spring.Echo("Objective not found: " .. objectiveType)
				return false
			end
		end

		textLines = string.lines(allText)
		totalTextLines = #textLines
		
		widget:ViewResize()
	else
		Spring.Echo("Text: couldn't load the text file")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
    if textList then
        glDeleteList(textList)
        textList = nil
    end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('text')
	end
end

function widget:GetConfigData(data)
	if show then
		for objectiveType, seen in pairs(seenObjectives) do
			if not seen then
				seenObjectives[objectiveType] = true
			end
		end
		hasUnseen = false
	end
	
	return {
		seenObjectives = seenObjectives
	}
end

function widget:SetConfigData(data)
	if data.seenObjectives ~= nil then
		seenObjectives = data.seenObjectives
		
		hasUnseen = false
		for objectiveType, seen in pairs(seenObjectives) do
			if seen == false then
				hasUnseen = true
				break
			end
		end
	end
	
	show = hasAlwaysShowObjectives or hasUnseen
end

function widget:LanguageChanged()
	if textList then
		glDeleteList(textList)
		textList = nil
	end
	widget:Initialize()
end
