function widget:GetInfo()
	return {
		name    = "Game Info",
		desc    = "Displays information about game info.",
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
local seenGameInfo = {}
local hasAlwaysShowGameInfo = false
local hasUnseen = false
local allText = nil
local modOptionText = {}

local function checkModOptions()
	if not VFS.FileExists("modoptions.lua") then return end
	local modOptionsDefs = VFS.Include("modoptions.lua")
	if not modOptionsDefs then return end

	local currentModOptions = Spring.GetModOptions()

	local ignoredKeys = {
		["date_year"] = true,
		["date_month"] = true,
		["date_day"] = true,
		["date_hour"] = true,
		["dummyboolfeelfreetotouch"] = true,
		["tweakunits"] = true,
		["tweakdefs"] = true,
	}

	for _, option in ipairs(modOptionsDefs) do
		local key = option.key
		local val = currentModOptions[key]

		if key and val ~= nil and not ignoredKeys[key] then
			local def = option.def
			local changed = false
			local description = option.desc
			local name = option.name

			local valueName = nil

			if option.type == "bool" then
				local boolVal
				if type(val) == "string" then
					boolVal = (val == "1" or val == "true")
				elseif type(val) == "number" then
					boolVal = (val ~= 0)
				else
					boolVal = val
				end
				if boolVal ~= def then
					changed = true
					if boolVal then
						valueName = Spring.I18N("modoptions.enabled") or "Enabled"
					else
						valueName = Spring.I18N("modoptions.disabled") or "Disabled"
					end
				end
			elseif option.type == "number" then
				if tonumber(val) ~= tonumber(def) then
					changed = true
					valueName = val
				end
			elseif option.type == "list" then
				if val ~= def then
					changed = true
					if option.items then
						for _, item in ipairs(option.items) do
							if item.key == val then
								valueName = item.name
								if item.desc then
									description = item.desc
								end
								break
							end
						end
					end
				end
			elseif option.type == "string" then
				if val ~= def then
					changed = true
				end
			end

			if changed and name then
				local header = string.upper(name)
				local entry = header
				if valueName then
					entry = entry .. "\n-> " .. valueName
				end
				entry = entry .. "\n" .. (description or "")
				table.insert(modOptionText, entry)
			end
		end
	end
end

checkModOptions()

-- alwaysShow: when true, show this info every time the game runs
-- when false, only show it once and remember it's been seen
local function loadGameInfoText(infoType, alwaysShow)
	local infoText = Spring.I18N("gameinfo." .. infoType)
	if infoText then
		if alwaysShow then
			table.insert(textTable, 1, infoText)
			hasAlwaysShowGameInfo = true
		else
			if seenGameInfo[infoType] == nil then
				seenGameInfo[infoType] = false
			end

			table.insert(textTable, 1, infoText)

			if seenGameInfo[infoType] == false then
				hasUnseen = true
			end
		end
	else
		Spring.Echo("Game info not found: " .. infoType)
	end
end

local function initializeGameInfo()
	if scavengersAIEnabled then
		loadGameInfoText("scavengersMoveObjective", false)
	end
	-- add additional if statements to add info here. Multiple info entries work but it's best to only do one at a time.
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
	local title = Spring.I18N('ui.topbar.button.game')
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
				
				-- Mark all one-time game info as seen when the window is closed
				for infoType, seen in pairs(seenGameInfo) do
					if not seen then
						seenGameInfo[infoType] = true
					end
				end
				hasUnseen = false  -- All one-time game info have been seen now
			end
			return true
		end
	end
end

function widget:Initialize()
	textTable = {}
	hasAlwaysShowGameInfo = false
	hasUnseen = false

	initializeGameInfo()

	if #modOptionText > 0 then
		hasAlwaysShowGameInfo = true
		for i = #modOptionText, 1, -1 do
			table.insert(textTable, 1, modOptionText[i])
		end
	end

	allText = table.concat(textTable, "\n______________________________________________________________________________\n\n")

	show = hasAlwaysShowGameInfo or hasUnseen

	-- Always register the WG API so other widgets can add info dynamically
	WG['game_info'] = {}
	WG['game_info'].toggle = function(state)
		if state ~= nil then
			show = state
		else
			show = not show
		end

		if not show then
			local changed = false
			for infoType, seen in pairs(seenGameInfo) do
				if not seen then
					seenGameInfo[infoType] = true
					changed = true
				end
			end
			if changed then
				hasUnseen = false
			end
		end
	end
	WG['game_info'].isvisible = function()
		return show
	end

	WG['game_info'].hasGameInfo = function()
		return #textTable > 0
	end

	WG['game_info'].addInfo = function(infoType, alwaysShow)
		local infoText = Spring.I18N("gameinfo." .. infoType)
		if infoText then
			local shouldShow = false

			if alwaysShow then
				hasAlwaysShowGameInfo = true
				table.insert(textTable, 1, infoText)
				shouldShow = true
			else
				if seenGameInfo[infoType] == nil then
					seenGameInfo[infoType] = false
				end

				table.insert(textTable, 1, infoText)

				if seenGameInfo[infoType] == false then
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

			if WG['topbar'] and WG['topbar'].refreshButtons then
				WG['topbar'].refreshButtons()
			end

			return true
		else
			Spring.Echo("Game info not found: " .. infoType)
			return false
		end
	end

	if allText and allText ~= "" then
		textLines = string.lines(allText)
		totalTextLines = #textLines
		widget:ViewResize()
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
		for infoType, seen in pairs(seenGameInfo) do
			if not seen then
				seenGameInfo[infoType] = true
			end
		end
		hasUnseen = false
	end
	
	return {
		seenGameInfo = seenGameInfo
	}
end

function widget:SetConfigData(data)
	if data.seenGameInfo ~= nil then
		seenGameInfo = data.seenGameInfo
		
		hasUnseen = false
		for infoType, seen in pairs(seenGameInfo) do
			if seen == false then
				hasUnseen = true
				break
			end
		end
	end
	
	show = hasAlwaysShowGameInfo or hasUnseen
end

function widget:LanguageChanged()
	if textList then
		glDeleteList(textList)
		textList = nil
	end
	widget:Initialize()
end
