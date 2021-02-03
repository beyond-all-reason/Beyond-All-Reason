local scavengersAIEnabled = false
local teams = Spring.GetTeamList()
for i = 1,#teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 12) == 'ScavengersAI' then
		scavengersAIEnabled = true
		break
	end
end

if not scavengersAIEnabled and not (Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0) then
	return
end

function widget:GetInfo()
	return {
		name    = "Scavenger Info",
		desc    = "",
		author  = "Floris",
		date    = "Jan 2020",
		layer   = -99990,
		enabled = true,
	}
end

local texts = {
	title = 'Scavengers',
}

local show = true	-- gets disabled when it has been loaded before

local vsx,vsy = Spring.GetViewGeometry()
local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local textFile = VFS.LoadFile("gamedata/scavengers/infotext.txt")

local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.6)

local numGames = 0

local screenHeightOrg = 520
local screenWidthOrg = 1050
local screenHeight = screenHeightOrg
local screenWidth = screenWidthOrg

local textareaMinLines = 14		-- wont scroll down more, will show at least this amount of lines

local playSounds = true
local buttonclick = 'LuaUI/Sounds/buildbar_waypoint.wav'

local startLine = 1

local customScale = 1
local centerPosX = 0.5
local centerPosY = 0.5
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

local titleRect = {}
local textLines = {}
local totalTextLines = 0

local myTeamID = Spring.GetMyTeamID()

local showOnceMore = false		-- used because of GUI shader delay

local font, font2, loadedFontSize, chobbyInterface, titleRect, backgroundGuishader, textList, dlistcreated, bgpadding

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local elementCorner = Spring.FlowUI.elementCorner

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	widgetScale = ((vsx + vsy) / 2000) * 0.65 * customScale
	widgetScale = widgetScale * (1 - (0.11 * ((vsx / vsy) - 1.78)))        -- make smaller for ultrawide screens

	screenHeight = math.floor(screenHeightOrg * widgetScale)
	screenWidth = math.floor(screenWidthOrg * widgetScale)
	screenX = math.floor((vsx * centerPosX) - (screenWidth / 2))
	screenY = math.floor((vsy * centerPosY) + (screenHeight / 2))

	font, loadedFontSize = WG['fonts'].getFont()
	font2 = WG['fonts'].getFont(fontfile2)
	bgpadding = Spring.FlowUI.elementPadding
	elementCorner = Spring.FlowUI.elementCorner

	if textList then gl.DeleteList(textList) end
	textList = gl.CreateList(DrawWindow)
end


function DrawTextarea(x,y,width,height,scrollbar)
	local scrollbarOffsetTop 		= 0	-- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom 	= 0	-- note: wont add the offset to the top, only to bottom
	local scrollbarMargin    		= 10 * widgetScale
	local scrollbarWidth     		= 8 * widgetScale
	local scrollbarPosWidth  		= 4 * widgetScale
	local scrollbarPosMinHeight 	= 8 * widgetScale
	local scrollbarBackgroundColor	= {0,0,0,0.24}
	local scrollbarBarColor			= {1,1,1,0.08}

	local fontSizeTitle				= 18 * widgetScale
	local fontSizeLine				= 16 * widgetScale
	local lineSeparator				= 2 * widgetScale

	local fontColorTitle			= {1,1,1,1}
	local fontColorLine				= {0.8,0.77,0.74,1}

	local maxLines = math.floor((height-5)/fontSizeLine)

	-- textarea scrollbar
	if scrollbar then
		if (totalTextLines > maxLines or startLine > 1) then	-- only show scroll above X lines
			local scrollbarTop       = y-scrollbarOffsetTop-scrollbarMargin-(scrollbarWidth-scrollbarPosWidth)
			local scrollbarBottom    = y-scrollbarOffsetBottom-height+scrollbarMargin+(scrollbarWidth-scrollbarPosWidth)
			local scrollbarPosHeight = math.max(((height-scrollbarMargin-scrollbarMargin) / totalTextLines) * ((height-scrollbarMargin-scrollbarMargin) / 25), scrollbarPosMinHeight)
			if scrollbarPosHeight > scrollbarTop-scrollbarBottom then scrollbarPosHeight = scrollbarTop-scrollbarBottom end
			local scrollbarPos       = scrollbarTop + (scrollbarBottom - scrollbarTop) * ((startLine-1) / totalTextLines)
			scrollbarPos             = scrollbarPos + ((startLine-1) / totalTextLines) * scrollbarPosHeight	-- correct position taking position bar height into account

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
				x+width-scrollbarMargin-scrollbarWidth + (scrollbarWidth - scrollbarPosWidth),
				scrollbarPos,
				x+width-scrollbarMargin-(scrollbarWidth - scrollbarPosWidth),
				scrollbarPos - (scrollbarPosHeight),
				scrollbarPosWidth/2
			)
		end
	end

	-- draw textarea
	if textFile then
		font:Begin()
		local lineKey = startLine
		local j = 1
		while j < maxLines do	-- maxlines is not exact, just a failsafe
			if (lineSeparator+fontSizeTitle)*j > height then
				break;
			end
			if textLines[lineKey] == nil then
				break;
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
					break;
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
	UiElement(screenX, screenY - screenHeight, screenX + screenWidth, screenY, 0, 1, 1, 1, 1,1,1,1, ui_opacity + 0.2)

	-- title background
	local title = texts.title
	local titleFontSize = 18 * widgetScale
	titleRect = { screenX, screenY, math.floor(screenX + (font2:GetTextWidth(texts.title) * titleFontSize) + (titleFontSize*1.5)), math.floor(screenY + (titleFontSize*1.7)) }

	gl.Color(0, 0, 0, Spring.GetConfigFloat("ui_opacity", 0.6) + 0.2)
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], elementCorner, 1, 1, 0, 0)

	-- title
	font2:Begin()
	font2:SetTextColor(1, 1, 1, 1)
	font2:SetOutlineColor(0, 0, 0, 0.4)
	font2:Print(title, screenX + (titleFontSize * 0.75), screenY + (8*widgetScale), titleFontSize, "on")
	font2:End()

	-- textarea
	DrawTextarea(screenX+math.floor(28 * widgetScale), screenY-math.floor(14 * widgetScale), screenWidth-math.floor(28 * widgetScale), screenHeight-math.floor(28 * widgetScale), 1)
end


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
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
  if chobbyInterface then return end
  if spIsGUIHidden() then return end

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
	  if IsOnRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) or IsOnRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
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

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)

	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end

function widget:MouseWheel(up, value)

	if show then
		local addLines = value*-3 -- direction is retarded

		startLine = startLine + addLines
		if startLine > totalTextLines - textareaMinLines then startLine = totalTextLines - textareaMinLines end
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
  if spIsGUIHidden() then return end

	if show then
		-- on window
		if IsOnRect(x, y, screenX, screenY - screenHeight, screenX + screenWidth, screenY) then
			return true
		elseif titleRect == nil or not IsOnRect(x, y, titleRect[1], titleRect[2], titleRect[3], titleRect[4]) then
			if release then
				showOnceMore = show        -- show once more because the guishader lags behind, though this will not fully fix it
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
		--texts = WG['lang'].getText('scavengers')
	end
	if textFile then

		WG['scavengerinfo'] = {}
		WG['scavengerinfo'].toggle = function(state)
			if state ~= nil then
				show = state
			else
				show = not show
			end
		end
		WG['scavengerinfo'].isvisible = function()
			return show
		end

		-- somehow there are a few characters added at the start that we need to remove
		--textFile = string.sub(textFile, 4)

		-- store text into array
		textLines = lines(textFile)

		for i, line in ipairs(textLines) do
			totalTextLines = i
		end
		widget:ViewResize()
	else
		Spring.Echo("Text: couldn't load the text file")
		widgetHandler:RemoveWidget(self)
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
	return {numGames	= numGames}
end

function widget:SetConfigData(data)
	if data.numGames ~= nil then
		numGames = data.numGames + 1
	end
	if numGames > 1 then
		show = false
	end
end
