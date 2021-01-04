
function widget:GetInfo()
return {
	name    = "Changelog Info",
	desc    = "",
	author  = "Floris",
	date    = "August 2015",
	layer   = -99990,
	enabled = true,
}
end

--local show = true

local texts = {        -- fallback (if you want to change this, also update: language/en.lua, or it will be overwritten)
	title = 'Changelog',
}

local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx,vsy = Spring.GetViewGeometry()

local changelogFile = VFS.LoadFile("changelog.txt")

local bgMargin = 6

local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local startLine = 1

local customScale = 1
local centerPosX = 0.5	-- note: dont go too far from 0.5
local centerPosY = 0.49		-- note: dont go too far from 0.5
local screenX = (vsx*centerPosX) - (screenWidth/2)
local screenY = (vsy*centerPosY) + (screenHeight/2)

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

local font, loadedFontSize, font2, changelogList, titleRect, chobbyInterface, backgroundGuishader, changelogList, dlistcreated, show

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	screenX = (vsx*centerPosX) - (screenWidth/2)
	screenY = (vsy*centerPosY) + (screenHeight/2)
    widgetScale = ((vsx+vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx/vsy) - 1.78)))		-- make smaller for ultrawide screens

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)

	if changelogList then gl.DeleteList(changelogList) end
	changelogList = gl.CreateList(DrawWindow)
end

local myTeamID = Spring.GetMyTeamID()

local showOnceMore = false		-- used because of GUI shader delay

local RectRound = Spring.FlowUI.Draw.RectRound
local TexturedRectRound = Spring.FlowUI.Draw.TexturedRectRound

local versionOffsetX = 28
local versionOffsetY = 14
local versionFontSize = 16

local versionQuickLinks = {}


function DrawSidebar(x,y,width,height)
	local fontSize		= versionFontSize
	local fontOffsetY	= versionOffsetY
	local fontOffsetX	= versionOffsetX

	-- background
	gl.Color(0.7,0.5,0.15,0.14)
	RectRound(x,y-height,x+width,y,5.5, 1,0,0,1, {0.55,0.4,0.12,0.14}, {0.8,0.57,0.18,0.14})

	-- version links
	versionQuickLinks = {}
	if changelogFile then
		font:Begin()
		font:SetOutlineColor(0.2,0.17,0,0.33)
		font:SetTextColor(0.8,0.65,0.15,1)
		local lineKey = 1
		local yOffset = 24
		local j = 0
		while j < 22 do
			if ((fontSize+fontOffsetY)*j)+4 > height-yOffset then
				break;
			end
			if versions[lineKey] == nil then
				break;
			end
			local line = changelogLines[versions[lineKey]]

			-- version button title
			line = " " .. string.match(line, '( %d*%d.?%d+)')
			local textY = y-((fontSize+fontOffsetY)*j)-20
			font:Print(line, x+fontOffsetX, textY, fontSize, "ocn")

			versionQuickLinks[j] = {
				x,
				textY-(versionFontSize*0.66),
				x+70,
				textY+(versionFontSize*1.21)
			}

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end


function DrawTextarea(x,y,width,height,scrollbar)
	local scrollbarOffsetTop 		= 0	-- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom 	= 0	-- note: wont add the offset to the top, only to bottom
	local scrollbarMargin    		= 10
	local scrollbarWidth     		= 8
	local scrollbarPosWidth  		= 4
	local scrollbarPosMinHeight 	= 8
	local scrollbarBackgroundColor	= {0,0,0,0.24}
	local scrollbarBarColor			= {1,1,1,0.15}

	local fontSizeTitle				= 18		-- is version number
	local fontSizeDate				= 14
	local fontSizeLine				= 16
	local lineSeparator				= 2

	local fontColorTitle			= {1,1,1,1}
	local fontColorDate				= {0.66,0.88,0.66,1}
	local fontColorLine				= {0.8,0.77,0.74,1}
	local fontColorLineBullet		= {0.9,0.6,0.2,1}

	local textRightOffset = scrollbar and scrollbarMargin+scrollbarWidth+scrollbarWidth or 0
	local maxLines = math.floor((height-5)/fontSizeLine)

	-- textarea scrollbar
	if scrollbar then
		if (totalChangelogLines > maxLines or startLine > 1) then	-- only show scroll above X lines
			local scrollbarTop       = y-scrollbarOffsetTop-scrollbarMargin-(scrollbarWidth-scrollbarPosWidth)
			local scrollbarBottom    = y-scrollbarOffsetBottom-height+scrollbarMargin+(scrollbarWidth-scrollbarPosWidth)
			local scrollbarPosHeight = math.max(((height-scrollbarMargin-scrollbarMargin) / totalChangelogLines) * ((height-scrollbarMargin-scrollbarMargin) / 25), scrollbarPosMinHeight)
			if scrollbarPosHeight > scrollbarTop-scrollbarBottom then scrollbarPosHeight = scrollbarTop-scrollbarBottom end
			local scrollbarPos       = scrollbarTop + (scrollbarBottom - scrollbarTop) * ((startLine-1) / totalChangelogLines)
			scrollbarPos             = scrollbarPos + ((startLine-1) / totalChangelogLines) * scrollbarPosHeight	-- correct position taking position bar height into account

			-- background
			gl.Color(scrollbarBackgroundColor)
			RectRound(
				x+width-scrollbarMargin-scrollbarWidth,
				scrollbarBottom-(scrollbarWidth-scrollbarPosWidth),
				x+width-scrollbarMargin,
				scrollbarTop+(scrollbarWidth-scrollbarPosWidth),
				scrollbarWidth/2
			)
			-- bar
			gl.Color(scrollbarBarColor)
			RectRound(
				x+width-scrollbarMargin-(scrollbarWidth*0.75),
				scrollbarPos - (scrollbarPosHeight),
				x+width-scrollbarMargin-(scrollbarWidth*0.25),
				scrollbarPos,
				scrollbarPosWidth/2.5
			)
		end
	end

	-- draw textarea
	if changelogFile then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines do	-- maxlines is not exact, just a failsafe
			if (lineSeparator+fontSizeTitle)*j > height then
				break;
			end
			if changelogLines[lineKey] == nil then
				break;
			end

			local line = changelogLines[lineKey]
			if string.find(line, '^([0-9][0-9][/][0-9][0-9][/][0-9][0-9])') or string.find(line, '^([0-9][/][0-9][0-9][/][0-9][0-9])') then
				-- date line
				line = "  " .. line
				font:SetTextColor(fontColorDate)
				font:Print(line, x, y-(lineSeparator+fontSizeTitle)*j, fontSizeDate, "n")
			elseif string.find(line, '^(%d*%d.?%d+)') then
				-- version line
				local versionStrip = string.match(line, '( %d*%d.?%d+)')
				if versionStrip ~= nil then
					line = " " .. versionStrip
 				else
					line = " " .. line
				end
				font:SetTextColor(fontColorTitle)
				font:Print(line, x-9, y-(lineSeparator+fontSizeTitle)*j, fontSizeTitle, "n")

			else
				font:SetTextColor(fontColorLine)
				local numLines
				if string.find(line, '^(-)') then
					-- bulletpointed line
					local firstLetterPos = 2
					if string.find(line, '^(- )') then
						firstLetterPos = 3
					end
					line = string.upper(string.sub(line, firstLetterPos, firstLetterPos))..string.sub(line, firstLetterPos+1)
					line, numLines = font:WrapText(line, (width - 90 - textRightOffset)*(loadedFontSize/fontSizeLine))
					if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
						break;
					end
					font:Print("   - ", x, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
					font:Print(line, x+26, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
				else
					-- line
					line = "  " .. line
					line, numLines = font:WrapText(line, (width-50)*(loadedFontSize/fontSizeLine))
					if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
						break;
					end
					font:Print(line, x, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
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
    local vsx,vsy = Spring.GetViewGeometry()
    local x = screenX --rightwards
    local y = screenY --upwards

	-- background
	if WG['guishader'] then
		gl.Color(0,0,0,0.8)
	else
		gl.Color(0,0,0,0.85)
	end
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1, {0.05,0.05,0.05,WG['guishader'] and 0.8 or 0.88}, {0,0,0,WG['guishader'] and 0.8 or 0.88})
	-- content area
	gl.Color(0.33,0.33,0.33,0.15)
	RectRound(x,y-screenHeight,x+screenWidth,y,5.5, 1,1,1,1, {0.25,0.25,0.25,0.2}, {0.5,0.5,0.5,0.2})

	-- title
    local title = texts.title
	local titleFontSize = 18
	if WG['guishader'] then
		gl.Color(0,0,0,0.8)
	else
		gl.Color(0,0,0,0.85)
	end
    titleRect = {x-bgMargin, y+bgMargin, x+(font2:GetTextWidth(title)*titleFontSize)+27-bgMargin, y+37}
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)
	font2:Begin()
	font2:SetTextColor(1,1,1,1)
	font2:SetOutlineColor(0,0,0,0.4)
	font2:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font2:End()

	-- version links
	DrawSidebar(x, y, 70, screenHeight)

	-- textarea
	DrawTextarea(x+90, y-10, screenWidth-90, screenHeight-24, 1)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
  if chobbyInterface then return end
  if spIsGUIHidden() then return end

  -- draw the help
  if not changelogList then
      changelogList = gl.CreateList(DrawWindow)
  end

  if show or showOnceMore then
	  gl.Texture(false)	-- some other widget left it on

		-- draw the changelog panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(changelogList)
		glPopMatrix()
		if WG['guishader'] then
			local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			if backgroundGuishader ~= nil then
				glDeleteList(backgroundGuishader)
			end
			backgroundGuishader = glCreateList( function()
				-- background
				RectRound(rectX1, rectY2, rectX2, rectY1, 9*widgetScale, 0,1,1,1)
				-- title
				rectX1 = (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2)
				rectY1 = (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2)
				rectX2 = (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2)
				rectY2 = (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)
				RectRound(rectX1, rectY1, rectX2, rectY2, 9*widgetScale, 1,1,0,0)
			end)
			dlistcreated = true
			WG['guishader'].InsertDlist(backgroundGuishader, 'changelog')
		end
		showOnceMore = false

		-- draw button hover
		local usedScreenX = (vsx*centerPosX) - ((screenWidth/2)*widgetScale)
		local usedScreenY = (vsy*centerPosY) + ((screenHeight/2)*widgetScale)

		local x,y,pressed = Spring.GetMouseState()
		if changelogFile then
			local lineKey = 1
			local j = 0
			local yOffset = 24
			local yOffsetUp = (((versionFontSize*0.66)+yOffset)*widgetScale)
			local yOffsetDown = (((versionFontSize*1.21)-yOffset)*widgetScale)
			while j < 22 do
				if ((versionFontSize+versionOffsetY)*j)+4 > (screenHeight-yOffset) then
					break;
				end
				if versions[lineKey] == nil then
					break;
				end
				if versionQuickLinks[j] == nil then
					break;
				end

				--local cc = (versionQuickLinks[j][1]/vsx) * vsx/widgetScale
				--Spring.Echo(usedScreenX..'  '..versionQuickLinks[j][1]..'  '..cc)

				-- version title
				local textX = usedScreenX-((10+versionOffsetX)*widgetScale)
				local textY = usedScreenY-((((versionFontSize+versionOffsetY)*j)-5)*widgetScale)
				local x1 = usedScreenX
				local y1 = textY-yOffsetUp
				local x2 = usedScreenX+(70*widgetScale)
				local y2 = textY+yOffsetDown
				if IsOnRect(x, y, x1, y1, x2, y2) then
					if pressed then
						gl.Color(1,0.93,0.75,0.23)
					else
						gl.Color(1,0.93,0.75,0.15)
					end
					RectRound(x1, y1, x2, y2, 3*widgetScale)
					break;
				end
				j = j + 1
				lineKey = lineKey + 1
			end
		end
  elseif dlistcreated and WG['guishader'] then
	WG['guishader'].DeleteDlist('changelog')
	dlistcreated = nil
  end
end

function widget:KeyPress(key)
	if key == 27 then	-- ESC
		show = false
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)

	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

--function widget:IsAbove(x, y)
--	-- on window
--	if show then
--		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
--		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
--		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
--		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
--		return IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1)
--	else
--		return false
--	end
--end
--
--function widget:GetTooltip(mx, my)
--	if show and widget:IsAbove(mx,my) then
--		return string.format(
--			"\255\255\255\1Left mouse\255\255\255\255 on textarea to scroll down.\n"..
--			"\255\255\255\1Right mouse\255\255\255\255 on textarea  to scroll up.\n\n"..
--			"Add CTRL or SHIFT to scroll faster, or combine CTRL+SHIFT (+ALT).")
--	end
--end

function widget:MouseWheel(up, value)

	if show then
		local addLines = value*-3 -- direction is retarded

		startLine = startLine + addLines
		if startLine > totalChangelogLines - textareaMinLines then startLine = totalChangelogLines - textareaMinLines end
		if startLine < 1 then startLine = 1 end

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
  if spIsGUIHidden() then return end

  if show then
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then

			--[[ scroll text with mouse 2
			if button == 1 or button == 3 then
				if IsOnRect(x, y, rectX1+(90*widgetScale), rectY2, rectX2, rectY1) then
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
				local usedScreenX = (vsx*centerPosX) - ((screenWidth/2)*widgetScale)
				local usedScreenY = (vsy*centerPosY) + ((screenHeight/2)*widgetScale)

				local x,y = Spring.GetMouseState()
				if changelogFile then
					local lineKey = 1
					local j = 0
					while j < 25 do
						if (versionFontSize+versionOffsetY)*j > (screenHeight-yOffset) then
							break;
						end
						if versions[lineKey] == nil then
							break;
						end

						-- version title
						local textX = usedScreenX-((10+versionOffsetX)*widgetScale)
						local textY = usedScreenY-((((versionFontSize+versionOffsetY)*j)-5)*widgetScale)

						local x1 = usedScreenX
						local y1 = textY-(((versionFontSize*0.66)+yOffset)*widgetScale)
						local x2 = usedScreenX+((70*widgetScale))
						local y2 = textY+(((versionFontSize*1.21)-yOffset)*widgetScale)
						if IsOnRect(x, y, x1, y1, x2, y2) then
							startLine = versions[lineKey]
							if changelogList then
								glDeleteList(changelogList)
							end
							changelogList = gl.CreateList(DrawWindow)
							if playSounds then
								Spring.PlaySoundFile(buttonclick, 0.6, 'ui')
							end
							break;
						end

						j = j + 1
						lineKey = lineKey + 1
					end
				end
				return true
			end

			if button == 1 or button == 3 then
				return true
			end
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
			if release then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = false
			end
			return true
		end
	end
end

function lines(str)
  local t = {}
  local function helper(line) t[#t+1] = line return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function widget:Initialize()
	if WG['lang'] then
		texts = WG['lang'].getText('changelog')
	end
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

			if insertedLatest == false or string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9]0)$') or  string.find(line, '^(%d*%d.?%d+ [/-]> %d*%d.[0-9])$') then
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
		widgetHandler:RemoveWidget(self)
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
