
function widget:GetInfo()
	return {
		name    = "Game info",
		desc    = "",
		author  = "Floris",
		date    = "May 2017",
		license = "",
		layer   = 2,
		enabled = true,
	}
end

local loadedFontSize = 32
local font = gl.LoadFont("LuaUI/Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = "LuaUI/Images/bgcorner.png"


local titlecolor = "\255\255\205\100"
local keycolor = ""
local valuecolor = "\255\255\255\255"
local valuegreycolor = "\255\180\180\180"
local vcolor = valuegreycolor
local separator = "::"

local teams = Spring.GetTeamList()
for i =1, #teams do
	local luaAI = Spring.GetTeamLuaAI(teams[i])
	if luaAI and luaAI ~= "" and string.sub(luaAI, 1, 9) == 'Chicken: ' then
		chickensEnabled = true
	end
end

local content = ""
content = content .. titlecolor..Game.gameName..valuegreycolor.." ("..Game.gameMutator..") "..titlecolor..Game.gameVersion.."\n"
content = content .. keycolor.."Engine"..separator..valuegreycolor..((Game and Game.version) or (Engine and Engine.version) or "Engine version error").."\n"
content = content .. "\n"

-- map info
content = content .. titlecolor..Game.mapName.."\n"
content = content .. valuegreycolor..Game.mapDescription.."\n"
content = content .. keycolor.."Size"..separator..valuegreycolor..Game.mapX..valuegreycolor.." x "..valuegreycolor..Game.mapY.."\n"
content = content .. keycolor.."Gravity"..separator..valuegreycolor..Game.gravity.."\n"
content = content .. keycolor.."Hardness"..separator..valuegreycolor..Game.mapHardness.. keycolor.."\n"
tidal = Game.tidal
if Spring.GetModOptions() and Spring.GetModOptions().map_tidal then
	map_tidal = Spring.GetModOptions().map_tidal
	if map_tidal == "unchanged" then
	elseif map_tidal == "low" then
		tidal = 13
	elseif map_tidal == "medium" then
		tidal = 18
	elseif map_tidal == "high" then
		tidal = 23
	end
end
if Spring.GetTidal then
	tidal = Spring.GetTidal()
end
content = content .. keycolor.."Tidal speed"..separator..valuegreycolor..tidal.. keycolor.."\n"


if Game.windMin == Game.windMax then
	content = content .. keycolor.."Wind speed"..separator..valuegreycolor..Game.windMin..valuegreycolor.."\n"
else
	content = content .. keycolor.."Wind speed"..separator..valuegreycolor..Game.windMin..valuegreycolor.."  -  "..valuegreycolor..Game.windMax.."\n"
end
if Game.waterDamage == 0 then
	vcolor = valuegreycolor
else
	vcolor = valuecolor
end
content = content .. keycolor.."Water damage"..separator..vcolor..Game.waterDamage .. keycolor.."\n"
content = content .. "\n"

-- modoptions
local defaultModoptions = VFS.Include("modoptions.lua")
local modoptionsDefault = {}

for key, value in pairs(defaultModoptions) do
	local v = value.def
	if value.def == false then
		v = 0
	elseif value.def == true then
		v = 1
	end
	modoptionsDefault[tostring(value.key)] = tostring(v)
end
-- modoptions.lua doesnt contain engine modoptions: maxunits, pathfinder, startmetal, startenergy, disablemapdamage, fixedallies
modoptionsDefault['maxspeed'] = '3'
modoptionsDefault['minspeed'] = '0.3'
modoptionsDefault['pathfinder'] = 'normal'
modoptionsDefault['startmetal'] = '1000'
modoptionsDefault['startenergy'] = '1000'
modoptionsDefault['fixedallies'] = '1'
modoptionsDefault['maxunits'] = '2000'
modoptionsDefault['disablemapdamage'] = '0'

local modoptions = Spring.GetModOptions()
local vcolor = valuegreycolor
local changedModoptions = {}
local unchangedModoptions = {}
local changedChickenModoptions = {}
local unchangedChickenModoptions = {}

for key, value in pairs(modoptions) do
	if string.sub(key, 1, 8) == 'chicken_' then
		if chickensEnabled then
			if value == modoptionsDefault[key]  then
				unchangedChickenModoptions[key] = value
			else
				changedChickenModoptions[key] = value
			end
		end
		modoptions[key] = nil	-- filter chicken modoptions
	end
end

for key, value in pairs(modoptions) do
	if value == modoptionsDefault[key]  then
		unchangedModoptions[key] = value
	else
		changedModoptions[key] = value
	end
end
if chickensEnabled then	-- filter chicken modoptions
	content = content .. titlecolor.."Chicken options\n"
	for key, value in pairs(changedChickenModoptions) do
		content = content .. keycolor..string.sub(key, 9)..separator..valuecolor..value.."\n"
	end
	for key, value in pairs(unchangedChickenModoptions) do
		content = content .. keycolor..string.sub(key, 9)..separator..valuegreycolor..value.."\n"
	end
	content = content .. "\n"
end
content = content .. titlecolor.."Mod options\n"
for key, value in pairs(changedModoptions) do
	content = content .. keycolor..key..separator..valuecolor..value.."\n"
end
for key, value in pairs(unchangedModoptions) do
	content = content .. keycolor..key..separator..valuegreycolor..value.."\n"
end


local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 400-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines 

local customScale = 1

local startLine = 1

local vsx,vsy = Spring.GetViewGeometry()
local screenX = (vsx*0.5) - (screenWidth/2)
local screenY = (vsy*0.5) + (screenHeight/2)

local spIsGUIHidden = Spring.IsGUIHidden
local showHelp = false

local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glPolygonMode = gl.PolygonMode
local glRect = gl.Rect
local glText = gl.Text
local glShape = gl.Shape
local glGetTextWidth = gl.GetTextWidth
local glGetTextHeight = gl.GetTextHeight

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

local changelogLines = {}
local totalChangelogLines = 0

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
	screenX = (vsx*0.5) - (screenWidth/2)
	screenY = (vsy*0.5) + (screenHeight/2)
	widgetScale = (0.5 + (vsx*vsy / 5700000)) * customScale
	if changelogList then gl.DeleteList(changelogList) end
	changelogList = gl.CreateList(DrawWindow)
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)

local showOnceMore = false		-- used because of GUI shader delay

local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl)
	gl.TexCoord(0.8,0.8)
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	local offset = 0.05		-- texture offset, because else gaps could show

	-- bottom left
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-offset)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-offset,1-offset)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-offset,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
	gl.Texture(false)
end

function DrawTextarea(x,y,width,height,scrollbar)
	local scrollbarOffsetTop 		= 18	-- note: wont add the offset to the bottom, only to top
	local scrollbarOffsetBottom 	= 12	-- note: wont add the offset to the top, only to bottom
	local scrollbarMargin    		= 10
	local scrollbarWidth     		= 8
	local scrollbarPosWidth  		= 4
	local scrollbarPosMinHeight 	= 8
	local scrollbarBackgroundColor	= {0,0,0,0.24	}
	local scrollbarBarColor			= {1,1,1,0.08}

	local fontSizeTitle				= 17		-- is version number
	local fontSizeDate				= 13
	local fontSizeLine				= 15
	local lineSeparator				= 2

	local fontColorTitle			= {1,1,1,1}
	local fontColorDate				= {0.66,0.88,0.66,1}
	local fontColorLine				= {0.8,0.77,0.74,1}
	local fontColorCommand			= {0.9,0.6,0.2,1}

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
				x+width-scrollbarMargin-scrollbarWidth + (scrollbarWidth - scrollbarPosWidth),
				scrollbarPos,
				x+width-scrollbarMargin-(scrollbarWidth - scrollbarPosWidth),
				scrollbarPos - (scrollbarPosHeight),
				scrollbarPosWidth/2
			)
		end
	end

	-- draw textarea
	if content then
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
			if string.find(line, '::') then
				local cmd = string.match(line, '^[ \+a-zA-Z0-9_-]*')		-- escaping the escape: \\ doesnt work in lua !#$@&*()&5$#
				local descr = string.sub(line, string.len(string.match(line, '^[ \+a-zA-Z0-9_-]*::'))+1)
				descr, numLines = font:WrapText(descr, (width-scrollbarMargin-scrollbarWidth - 250 - textRightOffset)*(loadedFontSize/fontSizeLine))
				if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
					break;
				end

				font:SetTextColor(fontColorCommand)
				font:Print(cmd, x+20, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")

				font:SetTextColor(fontColorLine)
				font:Print(descr, x+250, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
				j = j + (numLines - 1)
			else
				-- line
				font:SetTextColor(fontColorLine)
				line = "" .. line
				line, numLines = font:WrapText(line, (width-scrollbarMargin-scrollbarWidth)*(loadedFontSize/fontSizeLine))
				if (lineSeparator+fontSizeTitle)*(j+numLines-1) > height then
					break;
				end
				font:Print(line, x+10, y-(lineSeparator+fontSizeTitle)*j, fontSizeLine, "n")
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
	gl.Color(0,0,0,0.8)
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1)
	-- content area
	gl.Color(0.33,0.33,0.33,0.15)
	RectRound(x,y-screenHeight,x+screenWidth,y,6)

	-- close button
	local size = closeButtonSize*0.7
	local width = size*0.055
	gl.Color(1,1,1,1)
	gl.PushMatrix()
	gl.Translate(screenX+screenWidth-(closeButtonSize/2),screenY-(closeButtonSize/2),0)
	gl.Rotate(-45,0,0,1)
	gl.Rect(-width,size/2,width,-size/2)
	gl.Rotate(90,0,0,1)
	gl.Rect(-width,size/2,width,-size/2)
	gl.PopMatrix()

	-- title
	local title = "Game info"
	local titleFontSize = 18
	gl.Color(0,0,0,0.8)
	titleRect = {x-bgMargin, y+bgMargin, x+(glGetTextWidth(title)*titleFontSize)+27-bgMargin, y+37}
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)
	font:Begin()
	font:SetTextColor(1,1,1,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font:End()

	-- textarea
	DrawTextarea(x, y-10, screenWidth, screenHeight-24, 1)
end


function widget:DrawScreen()
	if spIsGUIHidden() then return end
	if amNewbie then return end

	-- draw the help
	if not changelogList then
		changelogList = gl.CreateList(DrawWindow)
	end

	if show or showOnceMore then

		-- draw the changelog panel
		glPushMatrix()
		glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
		glScale(widgetScale, widgetScale, 1)
		glCallList(changelogList)
		glPopMatrix()
		if (WG['guishader_api'] ~= nil) then
			local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'gameinfo')
			--WG['guishader_api'].setBlurIntensity(0.0017)
			--WG['guishader_api'].setScreenBlur(true)
		end
		showOnceMore = false

	else
		if (WG['guishader_api'] ~= nil) then
			local removed = WG['guishader_api'].RemoveRect('gameinfo')
			if removed then
				--WG['guishader_api'].setBlurIntensity()
				WG['guishader_api'].setScreenBlur(false)
			end
		end
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
		if startLine < 1 then startLine = 1 end
		if startLine > totalChangelogLines - textareaMinLines then startLine = totalChangelogLines - textareaMinLines end

		if changelogList then
			glDeleteList(changelogList)
		end

		changelogList = gl.CreateList(DrawWindow)
		return true
	else
		return false
	end
end

function widget:MouseMove(x, y)
	if show then
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if not IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then

		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)
	if spIsGUIHidden() then return false end

	if show then
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then

			-- on close button
			local brectX1 = rectX2 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			local brectY2 = rectY1 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			if IsOnRect(x, y, brectX1, brectY2, rectX2, rectY1) then
				if release then
					showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
					show = not show
				end
				return true
			end

			if button == 1 or button == 3 then
				if button == 3 and release then
					show = not show
				end
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


local function hideWindows()
	if (WG['options'] ~= nil) then
		WG['options'].toggle(false)
	end
	if (WG['changelog'] ~= nil) then
		WG['changelog'].toggle(false)
	end
	if (WG['keybinds'] ~= nil) then
		WG['keybinds'].toggle(false)
	end
	if (WG['commands'] ~= nil) then
		WG['commands'].toggle(false)
	end
	if (WG['teamstats'] ~= nil) then
		WG['teamstats'].toggle(false)
	end
end

function toggle()
	show = not show
	if show then
		hideWindows()
	end
end

function widget:Initialize()
	if content then

		widgetHandler:AddAction("customgameinfo", toggle)
		Spring.SendCommands("unbind any+i gameinfo")
		Spring.SendCommands("unbind i gameinfo")
		Spring.SendCommands("bind i customgameinfo")

		WG['gameinfo'] = {}
		WG['gameinfo'].toggle = function(state)
			if state ~= nil then
				show = state
			else
				show = not show
			end
			if show then
				hideWindows()
			end
		end

		-- somehow there are a few characters added at the start that we need to remove
		--content = string.sub(content, 4)

		-- store changelog into array
		changelogLines = lines(content)

		for i, line in ipairs(changelogLines) do
			totalChangelogLines = i
		end

	else
		--Spring.Echo("Commands info: couldn't load the commandslist file")
		widgetHandler:RemoveWidget(self)
	end
end

function widget:Shutdown()
	Spring.SendCommands("unbind i customgameinfo")
	Spring.SendCommands("bind any+i gameinfo")
	Spring.SendCommands("bind i gameinfo")
	widgetHandler:RemoveAction("customgameinfo", toggle)

	if buttonGL then
		glDeleteList(buttonGL)
		buttonGL = nil
	end
	if changelogList then
		glDeleteList(changelogList)
		changelogList = nil
	end
end
