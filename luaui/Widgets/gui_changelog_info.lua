function widget:GetInfo()
	return {
		name = "Changelog Info",
		desc = "",
		author = "Floris",
		date = "August 2015",
		layer = -99990,
		enabled = true,
	}
end

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx, vsy = Spring.GetViewGeometry()

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)

local changelogFile = VFS.LoadFile("changelog.txt")

local screenHeightOrg = 520
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local textareaMinLines = 20        -- wont scroll down more, will show at least this amount of lines

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local startLine = 1

local customScale = 1
local centerPosX = 0.5
local centerPosY = 0.5
local screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
local screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape

local bgColorMultiplier = 0

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTranslate = gl.Translate
local glScale = gl.Scale

local GL_FILL = GL.FILL
local GL_FRONT_AND_BACK = GL.FRONT_AND_BACK
local GL_LINE_STRIP = GL.LINE_STRIP

local widgetScale = 1
local vsx, vsy = Spring.GetViewGeometry()

local versions = {}
local changelogLines = {}
local totalChangelogLines = 0

local myTeamID = Spring.GetMyTeamID()

local showOnceMore = false        -- used because of GUI shader delay

local RectRound, UiElement, UiScroller, elementCorner

local versionOffsetX = 28
local versionOffsetY = 14
local versionFontSize = 16

local versionQuickLinks = {}
local maxLines = 20

local math_isInRect = math.isInRect

local font, loadedFontSize, font2, changelogList, titleRect, chobbyInterface, backgroundGuishader, changelogList, dlistcreated, show, bgpadding

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()
	widgetScale = ((vsx + vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx / vsy) - 1.78)))        -- make smaller for ultrawide screens

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)
	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiScroller = WG.FlowUI.Draw.Scroller

	if changelogList then
		gl.DeleteList(changelogList)
	end
	changelogList = gl.CreateList(DrawWindow)
end

function DrawSidebar(x, y, width, height)
	local fontSize = versionFontSize * widgetScale
	local fontOffsetY = versionOffsetY * widgetScale
	local fontOffsetX = versionOffsetX * widgetScale

	-- background
	gl.Color(0.7, 0.5, 0.15, 0.14)
	RectRound(x, y - height, x + width, y, bgpadding, 0, 0, 0, 1, { 0.55, 0.4, 0.12, 0.14 }, { 0.8, 0.57, 0.18, 0.14 })

	-- version links
	versionQuickLinks = {}
	if changelogFile then
		font:Begin()
		font:SetOutlineColor(0.2, 0.17, 0, 0.33)
		font:SetTextColor(0.8, 0.65, 0.15, 1)
		local lineKey = 1
		local yOffset = 24*widgetScale
		local j = 0
		while j < 22 do
			if ((fontSize + fontOffsetY) * j) + 4 > height - yOffset then
				break ;
			end
			if versions[lineKey] == nil then
				break ;
			end
			local line = changelogLines[versions[lineKey]]

			-- version button title
			line = " " .. string.match(line, '( %d*%d.?%d+)')
			local textY = y - ((fontSize + fontOffsetY) * j) - (20*widgetScale)
			font:Print(line, x + fontOffsetX, textY, fontSize, "ocn")

			versionQuickLinks[j] = {
				math.floor(x),
				math.floor(textY - (versionFontSize * widgetScale * 0.66)),
				math.floor(x + (70*widgetScale)),
				math.ceil(textY + (versionFontSize * widgetScale * 1.21))
			}

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end

function DrawTextarea(x, y, width, height, scrollbar)
	local scrollbarOffsetTop = 0    -- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom = 0    -- note: wont add the offset to the top, only to bottom
	local scrollbarMargin = 10 * widgetScale
	local scrollbarWidth = 8 * widgetScale
	local scrollbarPosWidth = 4 * widgetScale
	local scrollbarPosMinHeight = 8 * widgetScale
	local scrollbarBackgroundColor = { 0, 0, 0, 0.24 }
	local scrollbarBarColor = { 1, 1, 1, 0.15 }

	local fontSizeTitle = 18 * widgetScale
	local fontSizeDate = 14 * widgetScale
	local fontSizeLine = 16 * widgetScale
	local lineSeparator = 2 * widgetScale

	local fontColorTitle = { 1, 1, 1, 1 }
	local fontColorDate = { 0.66, 0.88, 0.66, 1 }
	local fontColorLine = { 0.8, 0.77, 0.74, 1 }
	local fontColorLineBullet = { 0.9, 0.6, 0.2, 1 }

	local textRightOffset = scrollbar and scrollbarMargin + scrollbarWidth + scrollbarWidth or 0
	maxLines = math.floor(height / (lineSeparator + fontSizeTitle))

	-- textarea scrollbar
	if scrollbar then
		if totalChangelogLines > maxLines or startLine > 1 then
			-- only show scroll above X lines
			local scrollbarTop = y - scrollbarOffsetTop - scrollbarMargin - (scrollbarWidth - scrollbarPosWidth)
			local scrollbarBottom = y - scrollbarOffsetBottom - height + scrollbarMargin + (scrollbarWidth - scrollbarPosWidth)

			UiScroller(
				math.floor(x + width - scrollbarMargin - scrollbarWidth),
				math.floor(scrollbarBottom - (scrollbarWidth - scrollbarPosWidth)),
				math.floor(x + width - scrollbarMargin),
				math.floor(scrollbarTop + (scrollbarWidth - scrollbarPosWidth)),
				(#changelogLines) * (lineSeparator + fontSizeTitle),
				(startLine-1) * (lineSeparator + fontSizeTitle)
			)
		end
	end

	-- draw textarea
	if changelogFile then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines+1 do
			-- maxlines is not exact, just a failsafe
			if (lineSeparator + fontSizeTitle) * j > height then
				break
			end
			if changelogLines[lineKey] == nil then
				break
			end

			local line = changelogLines[lineKey]
			if string.find(line, '^([0-9][0-9][/][0-9][0-9][/][0-9][0-9])') or string.find(line, '^([0-9][/][0-9][0-9][/][0-9][0-9])') then
				-- date line
				line = "  " .. line
				font:SetTextColor(fontColorDate)
				font:Print(line, x, y - (lineSeparator + fontSizeTitle) * j, fontSizeDate, "n")
			elseif string.find(line, '^(%d*%d.?%d+)') then
				-- version line
				local versionStrip = string.match(line, '( %d*%d.?%d+)')
				if versionStrip ~= nil then
					line = " " .. versionStrip
				else
					line = " " .. line
				end
				font:SetTextColor(fontColorTitle)
				font:Print(line, x - (9*widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeTitle, "n")

			else
				font:SetTextColor(fontColorLine)
				local numLines
				if string.find(line, '^(-)') then
					-- bulletpointed line
					local firstLetterPos = 2
					if string.find(line, '^(- )') then
						firstLetterPos = 3
					end
					line = string.upper(string.sub(line, firstLetterPos, firstLetterPos)) .. string.sub(line, firstLetterPos + 1)
					line, numLines = font:WrapText(line, (width - (90*widgetScale) - textRightOffset) * (loadedFontSize / fontSizeLine))
					if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
						break
					end
					font:Print("   - ", x, y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
					font:Print(line, x + (26*widgetScale), y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				else
					-- line
					line = "  " .. line
					line, numLines = font:WrapText(line, (width - (50*widgetScale)) * (loadedFontSize / fontSizeLine))
					if (lineSeparator + fontSizeTitle) * (j + numLines - 1) > height then
						break
					end
					font:Print(line, x, y - (lineSeparator + fontSizeTitle) * j, fontSizeLine, "n")
				end
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
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, ui_opacity + 0.2)

	-- title background
	local title = Spring.I18N('ui.changelog.title')
	local titleFontSize = 18 * widgetScale
	titleRect = { screenX, screenY, math.floor(screenX + (font2:GetTextWidth(title) * titleFontSize) + (titleFontSize*1.5)), math.floor(screenY + (titleFontSize*1.7)) }

	gl.Color(0, 0, 0, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, screenX + (titleFontSize * 0.75), screenY + (8*widgetScale), titleFontSize, "on")
	font2:End()

	-- version links
	DrawSidebar(screenX+bgpadding, screenY-bgpadding, 70*widgetScale, screenHeight-bgpadding-bgpadding)

	-- textarea
	DrawTextarea(screenX + (90*widgetScale), screenY - (10*widgetScale), screenWidth - (90*widgetScale), screenHeight - (24*widgetScale), 1)
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity", 0.6) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)
			widget:ViewResize()
		end
	end
end

function widget:DrawScreen()
	if chobbyInterface then
		return
	end
	if spIsGUIHidden() then
		return
	end

	-- draw the help
	if not changelogList then
		changelogList = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then
		gl.Texture(false)    -- some other widget left it on

		-- draw the changelog panel
		glCallList(changelogList)
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
			WG['guishader'].InsertDlist(backgroundGuishader, 'changelog')
			dlistcreated = true
		end
		showOnceMore = false

		-- draw button hover
		local usedScreenX = math.floor((vsx * centerPosX) - ((screenWidth / 2) * widgetScale))
		local usedScreenY = math.floor((vsy * centerPosY) + ((screenHeight / 2) * widgetScale))

		local x, y, pressed = Spring.GetMouseState()
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) or math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			Spring.SetMouseCursor('cursornormal')
		end
		if changelogFile then
			local lineKey = 1
			local j = 0
			local yOffset = 24 * widgetScale
			local yOffsetUp = ((versionFontSize * 0.66) + yOffset) * widgetScale
			local yOffsetDown = ((versionFontSize * 1.21) - yOffset) * widgetScale
			for k,v in pairs(versionQuickLinks) do
				if math_isInRect(x, y, v[1], v[2], v[3], v[4]) then
					if pressed then
						gl.Color(1, 0.93, 0.75, 0.23)
					else
						gl.Color(1, 0.93, 0.75, 0.15)
					end
					RectRound(v[1], v[2], v[3], v[4], bgpadding, 0,0,0,0)
					break;
				end
			end
		end
	elseif dlistcreated and WG['guishader'] then
		WG['guishader'].DeleteDlist('changelog')
		dlistcreated = nil
	end
end

function widget:KeyPress(key)
	if key == 27 then
		-- ESC
		show = false
	end
end

function widget:MouseWheel(up, value)

	if show then
		local addLines = value * -3 -- direction is retarded

		startLine = startLine + addLines
		if startLine >= totalChangelogLines - maxLines then
			startLine = totalChangelogLines - maxLines+1
		end
		if startLine < 1 then
			startLine = 1
		end

		if changelogList then
			glDeleteList(changelogList)
		end

		changelogList = gl.CreateList(DrawWindow)
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
	if spIsGUIHidden() then
		return
	end

	if show then
		-- on window
		if math_isInRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then

			--[[ scroll text with mouse 2
			if button == 1 or button == 3 then
				if math_isInRect(x, y, rectX1+(90*widgetScale), rectY2, rectX2, rectY1) then
					if release then
						local alt, ctrl, meta, shift = Spring.GetModKeyState()
						local addLines = 3

						if ctrl or shift then
							addLines = 8
						end
						if ctrl and shift then
							addLines = 22
						end
						if ctrl and shift and alt then
							addLines = 66
						end
						if button == 3 then
							addLines = -addLines
						end
						startLine = startLine + addLines
						if startLine < 1 then startLine = 1 end
						if startLine > totalChangelogLines - textareaMinLines then startLine = totalChangelogLines - textareaMinLines end

						if changelogList then
							glDeleteList(changelogList)
						end
						changelogList = gl.CreateList(DrawWindow)
					end
					return true
				end
			end]]--

			-- version buttons
			if button == 1 and release then
				local yOffset = 24
				local usedScreenX = math.floor((vsx * centerPosX) - ((screenWidth / 2) * widgetScale))
				local usedScreenY = math.floor((vsy * centerPosY) + ((screenHeight / 2) * widgetScale))

				local x, y = Spring.GetMouseState()
				if changelogFile then
					for k,v in pairs(versionQuickLinks) do
						if math_isInRect(x, y, v[1], v[2], v[3], v[4]) then
							startLine = versions[k+1]
							if changelogList then
								glDeleteList(changelogList)
							end
							changelogList = gl.CreateList(DrawWindow)
							if playSounds then
								Spring.PlaySoundFile(buttonclick, 0.6, 'ui')
							end
							break;
						end
					end
				end
				return true
			end

			if button == 1 or button == 3 then
				return true
			end

		elseif titleRect == nil or not math_isInRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			if release then
				showOnceMore = true        -- show once more because the guishader lags behind, though this will not fully fix it
				show = false
			end
			return true
		end
	end
end

function lines(str)
	local t = {}
	local function helper(line)
		t[#t + 1] = line
		return ""
	end
	helper((str:gsub("(.-)\r?\n", helper)))
	return t
end

function widget:Initialize()
	widget:ViewResize()
	if changelogFile then

		WG['changelog'] = {}
		WG['changelog'].toggle = function(state)
			if state ~= nil then
				show = state
			else
				show = not show
			end
		end
		WG['changelog'].isvisible = function()
			return show
		end

		-- somehow there are a few characters added at the start that we need to remove
		changelogFile = string.sub(changelogFile, 4)

		-- store changelog into array
		changelogLines = lines(changelogFile)

		local versionKey = 0
		local insertedLatest = false
		for i, line in ipairs(changelogLines) do

			if insertedLatest == false or string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9]0)$') or string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9])$') then
				--if string.find(line, '^(%d*%d.?%d+ [/-]> )') then
				versionKey = versionKey + 1
				versions[versionKey] = i
				insertedLatest = true
			end
			totalChangelogLines = i
		end
		widget:ViewResize()
	else
		Spring.Echo("Changelog: couldn't load the changelog file")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
	if changelogList then
		glDeleteList(changelogList)
		changelogList = nil
	end
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('changelog')
	end
end
