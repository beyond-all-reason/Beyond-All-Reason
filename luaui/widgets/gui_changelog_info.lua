
function widget:GetInfo()
return {
	name    = "Changelog Info",
	desc    = "Leftmouse: scroll down,  Rightmouse: scroll up,  ctrl/shift/alt combi: speedup)",
	author  = "Floris (original: keybind info by Bluestone)",
	date    = "August 2015",
	license = "Dental flush",
	layer   = 0,
	enabled = true,
}
end

local startLine = 1

local hoverColor = {1,1,1,0.2}
local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local closeButtonTex = ":n:"..LUAUI_DIRNAME.."Images/close.dds"

local changelogFile = io.open(LUAUI_DIRNAME.."changelog.txt", "r")

local bgMargin = 10
local closeButtonSize = 30
local screenHeight = 486
local screenWidth = (350*3)-8

local customScale = 1

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

local bgColorMultiplier = 1

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
local endPosX = 0.05
local vsx, vsy = Spring.GetViewGeometry()

local versions = {}
local changelogFileLines = {}
local totalChangelogLines = 0

function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.75 + (vsx*vsy / 7500000)) * customScale
  if changelogList then gl.DeleteList(changelogList) end
  changelogList = gl.CreateList(ChangelogScreen)
  --endPosX = 0.07
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)
function widget:GameStart()
    gameStarted = true
end

-- button
local textSize = 0.75
local textMargin = 0.25
local lineWidth = 0.0625

local posX = 0.35
local posY = 0
local showOnceMore = false
local buttonGL
local startPosX = posX

local function DrawL()
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
end

function RectRound(px,py,sx,sy,cs)
	
	--local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.floor(sx),math.floor(sy),math.floor(cs)
	
	gl.Rect(px+cs, py, sx-cs, sy)
	gl.Rect(sx-cs, py+cs, sx, sy-cs)
	gl.Rect(px+cs, py+cs, px, sy-cs)
	
	gl.Texture(bgcorner)
	--if py <= 0 or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, py+cs, px+cs, py)		-- top left
	
	--if py <= 0 or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, py+cs, sx-cs, py)		-- top right
	
	--if sy >= vsy or px <= 0 then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(px, sy-cs, px+cs, sy)		-- bottom left
	
	--if sy >= vsy or sx >= vsx then gl.Texture(false) else gl.Texture(bgcorner) end
	gl.TexRect(sx, sy-cs, sx-cs, sy)		-- bottom right
	
	gl.Texture(false)
end

function DrawButton()
    glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	RectRound(0,0,4.5,1,0.25)
    DrawL()
    glText("Changelog", textMargin, textMargin, textSize, "no")
end


local versionColor		= "\255\255\210\070"
local titleColor		= "\255\254\254\254"
local descriptionColor	= "\255\192\190\180"

function ChangelogScreen()
    local vsx,vsy = Spring.GetViewGeometry()
    local x = screenX --rightwards
    local y = screenY --upwards
    
    gl.Color(0,0,0,0.8)
	RectRound(x-20-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+24+bgMargin,8)
	--glRect(x-20-bgMargin,y+24+bgMargin,x+screenWidth+bgMargin,y-screenHeight-bgMargin)
	
    gl.Color(1,1,1,1)
	gl.Texture(closeButtonTex)
	gl.TexRect(screenX+screenWidth-closeButtonSize,screenY+24,screenX+screenWidth,screenY+24-closeButtonSize)
	gl.Texture(false)
	
	local xOffset = 0
	local yOffset = 20
	local fontSize = 15
	if changelogFile then
		local lineKey = 1
		local j = 0
		while j < 25 do	
			if (fontSize+yOffset)*j > (screenHeight) then
				break;
			end
			if versions[lineKey] == nil then
				break;
			end
			
			-- version button title
			local line = " " .. versionColor .. versions[lineKey]['line']
			gl.Text(line, x-10+xOffset, y-((fontSize+yOffset)*j)+5, fontSize)
			
			j = j + 1
			lineKey = lineKey + 1
		end
	end
	
	local xOffset = 75
	local fontSizeLine = 13
	local fontSizeTitle = 15
	if changelogFile then
		local lineKey = startLine
		local j = 0
		local height = 0
		local width = 0
		while j < 40 do	
			if (fontSizeTitle)*j > (screenHeight-16) then
				break;
			end
			if changelogFileLines[lineKey] == nil then
				break;
			end
			
			local line = changelogFileLines[lineKey]
			
			if string.find(line, '^([0-9][.][0-9][0-9])') then
				-- version title
				local versionStrip = string.match(line, '( [0-9][.][0-9][0-9])')
				if versionStrip ~= nil then
					line = " " .. titleColor .. versionStrip
 				else
					line = " " .. titleColor .. line
				end
				gl.Text(line, x-16+xOffset, y-((fontSizeTitle)*j)+5, fontSizeTitle)
				
			else
				-- line
				local line = "  " .. descriptionColor .. line
				gl.Text(line, x-7+xOffset, y-(fontSizeTitle)*j, fontSizeLine)
				width = math.max(glGetTextWidth(line)*fontSizeLine,width)
				height = height + fontSizeTitle
			end

			j = j + 1
			lineKey = lineKey + 1
		end
	end
end


function widget:GameFrame(n)
	
	if n>endPosX and posX > endPosX then
		posX = posX - 0.005
		if posX < 0 then posX = 0 end
		
		bgColorMultiplier = posX / startPosX
	end
end

function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if amNewbie and not gameStarted then return end
    
    -- draw the button
    if not buttonGL then
        buttonGL = gl.CreateList(DrawButton)
    end
    
    glLineWidth(lineWidth)

    glPushMatrix()
        glTranslate(posX*vsx, posY*vsy, 0)
        glScale(17*widgetScale, 17*widgetScale, 1)
		glColor(0, 0, 0, (0.3*bgColorMultiplier))
        glCallList(buttonGL)
    glPopMatrix()

    glColor(1, 1, 1, 1)
    glLineWidth(1)
    
    -- draw the help
    if not changelogList then
        changelogList = gl.CreateList(ChangelogScreen)
    end
    
    if show or showOnceMore then
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(changelogList)
		glPopMatrix()
		if (WG['guishader_api'] ~= nil) then
			local rectX1 = ((screenX-20-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+24+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'changelog')
		end
		showOnceMore = false
	
		
		-- verion button hover	
		local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
		local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)
			
		local xOffset = 0
		local yOffset = 20
		local fontSize = 15
		
		local x,y = Spring.GetMouseState()
		if changelogFile then
			local lineKey = 1
			local j = 0
			while j < 25 do	
				if (fontSize+yOffset)*j > (screenHeight) then
					break;
				end
				if versions[lineKey] == nil then
					break;
				end
				
				-- version title
				local textX = usedScreenX-((10+xOffset)*widgetScale)
				local textY = usedScreenY-((((fontSize+yOffset)*j)-5)*widgetScale)
				--gl.Text(" " .. versionColor .. versions[lineKey]['line'], textX, textY, (fontSize*widgetScale))
				
				if IsOnRect(x, y, textX-fontSize, textY-fontSize, textX+(fontSize*4.7), textY+(fontSize*1.8)) then
					gl.Color(hoverColor)
					RectRound(
						textX-fontSize,
						textY-fontSize,
						textX+(fontSize*4.7),
						textY+(fontSize*1.8), 
						5*widgetScale
					)
					break;
				end
				j = j + 1
				lineKey = lineKey + 1
			end
		end
		
    else
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('changelog')
		end
	end
end

function IsOnRect(x, y, BLcornerX, BLcornerY,TRcornerX,TRcornerY)
	
	-- check if the mouse is in a rectangle
	return x >= BLcornerX and x <= TRcornerX
	                      and y >= BLcornerY
	                      and y <= TRcornerY
end


function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    if amNewbie and not gameStarted then return end
    
    if show then 
		-- on window
		local rectX1 = ((screenX-20-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+24+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
		
			-- on close button
			rectX1 = rectX2 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			rectY2 = rectY1 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = not show
			end
			
			-- scroll text with mouse 2
			if button == 1 or button == 3 then
				if IsOnRect(x, y, rectX1+(90*widgetScale), rectY2, rectX2, rectY1) then
					local alt, ctrl, meta, shift = Spring.GetModKeyState()
					local addLines = 4
					
					if ctrl or shift then 
						addLines = 8
					end
					if ctrl and shift then 
						addLines = 25
					end
					if ctrl and shift and alt then 
						addLines = 50
					end
					if button == 3 then 
						addLines = -addLines
					end
					startLine = startLine + addLines
					if startLine < 1 then startLine = 1 end
					if startLine > totalChangelogLines - 11 then startLine = totalChangelogLines - 11 end
					
					if changelogList then
						glDeleteList(changelogList)
					end
					changelogList = gl.CreateList(ChangelogScreen)
					return true
				end
			end
				
			-- version buttons
			if button == 1 then
				local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
				local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)
					
				local xOffset = 0
				local yOffset = 20
				local fontSize = 15
				
				local x,y = Spring.GetMouseState()
				if changelogFile then
					local lineKey = 1
					local j = 0
					while j < 25 do	
						if (fontSize+yOffset)*j > (screenHeight) then
							break;
						end
						if versions[lineKey] == nil then
							break;
						end
						
						-- version title
						local textX = usedScreenX-((10+xOffset)*widgetScale)
						local textY = usedScreenY-((((fontSize+yOffset)*j)-5)*widgetScale)
						--gl.Text(" " .. versionColor .. versions[lineKey]['line'], textX, textY, (fontSize*widgetScale))
						
						if IsOnRect(x, y, textX-fontSize, textY-fontSize, textX+(fontSize*4.7), textY+(fontSize*1.8)) then
							startLine = versions[lineKey]['changelogLine']
							if changelogList then
								glDeleteList(changelogList)
							end
							changelogList = gl.CreateList(ChangelogScreen)
							break;
						end
						
						j = j + 1
						lineKey = lineKey + 1
					end
				end
			end
			
			if button == 1 or button == 3 then
				return true
			end
		else
			showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
    else
		tx = (x - posX*vsx)/(17*widgetScale)
		ty = (y - posY*vsy)/(17*widgetScale)
		if tx < 0 or tx > 4.5 or ty < 0 or ty > 1 then return false end
		
		showOnceMore = show		-- show once more because the guishader lags behind, though this will not fully fix it
		show = not show
    end
end


function widget:Initialize()
  
	if changelogFile then
		-- store changelog into array
		changelogFileLines = {}
		for line in changelogFile:lines() do
			table.insert (changelogFileLines, line);
		end
		
		local versionKey = 0
		for i, line in ipairs(changelogFileLines) do
		
			if string.find(line, '^([0-9][.][0-9][0-9])') then
				versionKey = versionKey + 1
				versions[versionKey] = {}
				versions[versionKey]['line'] = string.match(line, '( [0-9][.][0-9][0-9])')  -- strip the first version number, which is the old version
				versions[versionKey]['changelogLine'] = i
			end
			totalChangelogLines = i
		end
		io.close(changelogFile)
	else
		Spring.Echo("Changelog: couldn't load the changelog file")
		widgetHandler:RemoveWidget()
	end
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if changelogList then
        glDeleteList(changelogList)
        changelogList = nil
    end
end
