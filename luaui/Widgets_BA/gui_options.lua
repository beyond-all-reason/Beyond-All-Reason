
function widget:GetInfo()
return {
	name    = "Options",
	desc    = "",
	author  = "Floris",
	date    = "September 2016",
	layer   = -2000,
	enabled = true,
  handler = true, 
}
end

--local show = true

local loadedFontSize = 32
local font = gl.LoadFont(LUAUI_DIRNAME.."Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local bgcorner1 = ":n:"..LUAUI_DIRNAME.."Images/bgcorner1.png" -- only used to draw dropdown arrow

local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

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
local glTexRect = gl.TexRect
local glRotate = gl.Rotate
local glTexture = gl.Texture
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

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)

local options = {}
local optionButtons = {}
local optionHover = {}
local optionSelect = {}
local fullWidgetsList = {}
local addedWidgetOptions = false
local showPresetButtons = true

local luaShaders = tonumber(Spring.GetConfigInt("ForceShaders",1) or 0)


function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.75 + (vsx*vsy / 7500000)) * customScale
  if windowList then gl.DeleteList(windowList) end
  windowList = gl.CreateList(DrawWindow)
  if presetsList then gl.DeleteList(presetsList) end
  presetsList = gl.CreateList(DrawPresets)
end

function widget:GameStart()
	gameStarted = true
end

-- button
local textSize		= 0.75
local textMargin	= 0.25
local lineWidth		= 0.0625

local posX = 0.15
local posY = 0
local showOnceMore = false		-- used because of GUI shader delay
local buttonGL
local startPosX = posX

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
	
	local offset = 0.07		-- texture offset, because else gaps could show
	
	-- bottom left
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2   then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl)
	gl.Texture(false)
end

function DrawButton()
  glPolygonMode(GL_FRONT_AND_BACK, GL_FILL)
	RectRound(0,0,4.5,1.05,0.25, 2,2,0,0)
	local vertices = {
		{v = {0, 1, 0}},
		{v = {0, 0, 0}},
		{v = {1, 0, 0}},
	}
	glShape(GL_LINE_STRIP, vertices)
  glText("Options", textMargin, textMargin, textSize, "no")
end
	
function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

local presets = {
	low = {
		label   = '\255\195\155\110Set quality for:\n   \255\255\255\255GPU   \255\150\120\090CPU',
		order   = 1,
		toggler = 'GPU'
	},
	medium = {
		label   = 'Low',
		order   = 2
	},
	high = {
		label   = 'Medium',
		order   = 3
	},
	ultra = {
		label   = 'High',
		order   = 4
	}
}
function DrawPresets()
	local margin = 7
	local padding = 3.5
	local totalWidth = screenWidth * 0.6666 - margin
	for preset, pp in pairs(presets) do
		gl.Color(0.1,0.05,0.016,0.75)
		local x = screenX + margin
		presets[preset].pos = {
			x + ((totalWidth/4)*(pp.order-1)),
			screenY-screenHeight+margin,
			x + ((totalWidth/4)*(pp.order))-margin,
			screenY-screenHeight+90-margin,
			padding
		}
		RectRound(
			presets[preset].pos[1],
			presets[preset].pos[2],
			presets[preset].pos[3],
			presets[preset].pos[4],
			6
		)
		gl.Color(1,0.8,0.2,0.15)
		RectRound(
			presets[preset].pos[1]+padding,
			presets[preset].pos[2]+padding,
			presets[preset].pos[3]-padding,
			presets[preset].pos[4]-padding,
			4
		)
		local fontSize = 18
		local textWidth = glGetTextWidth(presets[preset].label)*fontSize
		local labellines = #lines(presets[preset].label)
  	glText(
  		'\255\230\230\230'..presets[preset].label, 
  		presets[preset].pos[3]-((presets[preset].pos[3]-presets[preset].pos[1])/2)-(textWidth/2), 
  		presets[preset].pos[2]+23+((fontSize*labellines)/2), 
  		fontSize, 
  		"no"
  	)
	end
end

function getOptionByID(id)
	for i, option in pairs(options) do
		if option.id == id then
			return i
		end
	end
	return false
end

function checkWidgets()

	-- bloom
	local bloomValue = 0
	if widgetHandler.orderList["Bloom Shader"] ~= nil and widgetHandler.orderList["Bloom Shader"] > 0 then
		bloomValue = 1
		if WG['bloom'] ~= nil and WG['bloom'].getAdvBloom() then
			bloomValue = 2
		end
	end
	options[getOptionByID('bloom')].value = bloomValue
	
	-- cursors
	local cursorsets = {}
	local cursor = 1
	local cursoroption
	if (WG['cursors'] ~= nil) then
		cursorsets = WG['cursors'].getcursorsets()
		local cursorname = WG['cursors'].getcursor()
		for i,c in pairs(cursorsets) do
			if c == cursorname then
				cursor = i
				break
			end
		end
		table.insert(options, {id="cursor", name="Cursor", type="select", options=cursorsets, value=cursor})
	end
	-- Darken map
	if (WG['darkenmap'] ~= nil) then
		table.insert(options, {id="darkenmap", name="Darken map", min=0, max=0.55, type="slider", value=WG['darkenmap'].getMapDarkness(), description='Darkens the whole map (not the units)\n\nRemembers setting per map\nUse /resetmapdarkness if you want to reset all stored map settings'})
		table.insert(options, {id="darkenmap_darkenfeatures", name="Darken features with map", type="bool", value=WG['darkenmap'].getDarkenFeatures(), description='Darkens features (trees, wrecks, ect..) along with darken map slider above\n\nNOTE: This setting is CPU intensive because it cycles through all visible features \nand renders then another time.'})
	end
	-- EnemySpotter
	if (WG['enemyspotter'] ~= nil) then
		table.insert(options, {id="enemyspotter_opacity", name="Enemyspotter opacity", min=0.15, max=0.4, type="slider", value=WG['enemyspotter'].getOpacity(), description='Set the opacity of the enemy-spotter rings'})
		table.insert(options, {id="enemyspotter_highlight", name="Enemyspotter unit highlight", type="bool", value=WG['enemyspotter'].getHighlight(), description='Colorize/highlight enemy units'})
	end
	-- Smart Select
	if (WG['smartselect'] ~= nil) then
		table.insert(options, {id="smartselect_includebuildings", name="Include buildings in area-selection", type="bool", value=WG['smartselect'].getIncludeBuildings(), description='When rectangle-drag-selecting an area, include building units too?\nIf disabled: non-mobile units will not be selected\n(nanos always will be selected)'})
	end
	-- redui buildmenu
	if WG['red_buildmenu'] ~= nil then
  	table.insert(options, {id="buildmenushortcuts", name="Buildmenu shortcuts", type="bool", value=WG['red_buildmenu'].getConfigShortcutsInfo(), description='Enables and shows shortcut keys in the buildmenu\n(reselect something to see the change applied)'})
	end
end


function DrawWindow()

	-- add widget options
	if not addedWidgetOptions then
		addedWidgetOptions = true
		checkWidgets()
	end
	
  local vsx,vsy = Spring.GetViewGeometry()
  local x = screenX --rightwards
  local y = screenY --upwards
	
	-- background
  gl.Color(0,0,0,0.8)
	RectRound(x-bgMargin,y-screenHeight-bgMargin,x+screenWidth+bgMargin,y+bgMargin,8, 0,1,1,1)
	-- content area
	gl.Color(0.33,0.33,0.33,0.15)
	RectRound(x,y-screenHeight,x+screenWidth,y,6)
	
	--[[ close button
	local size = closeButtonSize*0.7
	local width = size*0.055
  gl.Color(1,1,1,1)
	gl.PushMatrix()
		gl.Translate(screenX+screenWidth-(closeButtonSize/2),screenY-(closeButtonSize/2),0)
  	gl.Rotate(-45,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
  	gl.Rotate(90,0,0,1)
  	gl.Rect(-width,size/2,width,-size/2)
	gl.PopMatrix()]]--
	
	-- title
  local title = "Options"
	local titleFontSize = 18
  gl.Color(0,0,0,0.8)
  titleRect = {x-bgMargin, y+bgMargin, x+(glGetTextWidth(title)*titleFontSize)+27-bgMargin, y+37}
	RectRound(titleRect[1], titleRect[2], titleRect[3], titleRect[4], 8, 1,1,0,0)
	
	font:Begin()
	font:SetTextColor(1,1,1,1)
	font:SetOutlineColor(0,0,0,0.4)
	font:Print(title, x-bgMargin+(titleFontSize*0.75), y+bgMargin+8, titleFontSize, "on")
	font:End()
	
	local width = screenWidth/3
	--gl.Color(0.66,0.66,0.66,0.08)
	--RectRound(x+width+width+6,y-screenHeight,x+width+width+width,y,6)
	
	-- description background
	gl.Color(0.72,0.5,0.12,0.14)
	RectRound(x,y-screenHeight,x+width+width,y-screenHeight+90,6)
  
	-- draw options
	local oHeight = 15
	local oPadding = 6
	y = y - oPadding - 11
	local oWidth = (screenWidth/3)-oPadding-oPadding
	local yHeight = screenHeight-102-oPadding
	local xPos = x + oPadding + 5
	local xPosMax = xPos + oWidth - oPadding - oPadding
	local yPosMax = y-yHeight
	local boolPadding = 3.5
	local boolWidth = 40
	local sliderWidth = 110
	local selectWidth = 140
	local i = 0
	optionButtons = {}
	optionHover = {}
	local row = 1 
	for oid,option in pairs(options) do
		yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
		if yPos-oHeight < yPosMax then
		  row = row + 1
			i = 0
			xPos = x + (( (screenWidth/3))*(row-1))
			xPosMax = xPos + oWidth
			yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
			gl.Color(0,0,0,0.25)
			RectRound(xPos-oPadding-2.5,y-screenHeight+118,xPos-oPadding+2.5,y,2)
		end
		
		--option name
  	glText('\255\230\230\230'..option.name, xPos+(oPadding/2), yPos-(oHeight/3)-oPadding, oHeight, "no")
  	
  	-- define hover area
		optionHover[oid] = {xPos, yPos-oHeight-oPadding, xPosMax, yPos+oPadding}
			
  	-- option controller
  	local rightPadding = 4
  	if option.type == 'bool' then
			optionButtons[oid] = {}
			optionButtons[oid] = {xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
			glColor(1,1,1,0.11)
			RectRound(xPosMax-boolWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 3)
			if option.value == true then
				glColor(0.66,0.92,0.66,1)
				RectRound(xPosMax-oHeight+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolPadding-rightPadding, yPos-boolPadding, 2.5)
			else
				glColor(0.92,0.66,0.66,1)
				RectRound(xPosMax-boolWidth+boolPadding-rightPadding, yPos-oHeight+boolPadding, xPosMax-boolWidth+oHeight-boolPadding-rightPadding, yPos-boolPadding, 2.5)
			end
		
		elseif option.type == 'slider' then
			local sliderSize = oHeight*0.75
			local sliderPos = (option.value-option.min) / (option.max-option.min)
			glColor(1,1,1,0.11)
			RectRound(xPosMax-(sliderSize/2)-sliderWidth-rightPadding, yPos-((oHeight/7)*4.2), xPosMax-(sliderSize/2)-rightPadding, yPos-((oHeight/7)*2.8), 1)
			glColor(0.8,0.8,0.8,1)
			RectRound(xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2), 3)
			optionButtons[oid] = {xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)-(sliderSize/2)-rightPadding, yPos-oHeight+((oHeight-sliderSize)/2), xPosMax-(sliderSize/2)-sliderWidth+(sliderWidth*sliderPos)+(sliderSize/2)-rightPadding, yPos-((oHeight-sliderSize)/2)}
			optionButtons[oid].sliderXpos = {xPosMax-(sliderSize/2)-sliderWidth-rightPadding, xPosMax-(sliderSize/2)-rightPadding}
			
		elseif option.type == 'select' then
			optionButtons[oid] = {xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos}
			glColor(1,1,1,0.11)
			RectRound(xPosMax-selectWidth-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 3)
  		glText(option.options[tonumber(option.value)], xPosMax-selectWidth+5-rightPadding, yPos-(oHeight/3)-oPadding, oHeight*0.85, "no")
			glColor(1,1,1,0.11)
			RectRound(xPosMax-oHeight-rightPadding, yPos-oHeight, xPosMax-rightPadding, yPos, 2.5)
			glColor(1,1,1,0.16)
			glTexture(bgcorner1)
 			glPushMatrix()
   			glTranslate(xPosMax-(oHeight*0.5)-rightPadding, yPos-(oHeight*0.33), 0)
				glRotate(-45,0,0,1)
				glTexRect(-(oHeight*0.25),-(oHeight*0.25),(oHeight*0.25),(oHeight*0.25))
 	 		glPopMatrix()
		end
		i = i + 1
	end
end


function correctMouseForScaling(x,y)
	local interfaceScreenCenterPosX = (screenX+(screenWidth/2))/vsx
	local interfaceScreenCenterPosY = (screenY-(screenHeight/2))/vsy
	x = x - (((x/vsx)-interfaceScreenCenterPosX) * vsx)*((widgetScale-1)/widgetScale)
	y = y - (((y/vsy)-interfaceScreenCenterPosY) * vsy)*((widgetScale-1)/widgetScale)
	return x,y
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
  
  	
  -- draw the window
  if not windowList then
    windowList = gl.CreateList(DrawWindow)
  end
  if not presetsList then
    presetsList = gl.CreateList(DrawPresets)
  end
  
  -- update new slider value
	if sliderValueChanged then
		gl.DeleteList(windowList)
		windowList = gl.CreateList(DrawWindow)
		sliderValueChanged = nil
  end
  
  if show or showOnceMore then
  	
		-- draw the options panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(windowList)
			if (WG['guishader_api'] ~= nil) then
				local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
				local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
				WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'options')
				--WG['guishader_api'].setBlurIntensity(0.0017)
				--WG['guishader_api'].setScreenBlur(true)
			end
			showOnceMore = false
			
			-- draw button hover
			local usedScreenX = (vsx*0.5) - ((screenWidth/2)*widgetScale)
			local usedScreenY = (vsy*0.5) + ((screenHeight/2)*widgetScale)
			
			-- mouseover (highlight and tooltip)
		  local description = ''
			local x,y = Spring.GetMouseState()
			local cx, cy = correctMouseForScaling(x,y)
		  showPresetButtons = true
			if not showSelectOptions then
				for i, o in pairs(optionHover) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						glColor(1,1,1,0.05)
						RectRound(o[1]-4, o[2], o[3]+4, o[4], 4)
						showPresetButtons = false
						if options[i].description ~= nil then
							description = options[i].description
							glText('\255\255\210\120'..options[i].description, screenX+15, screenY-screenHeight+64.5, 16, "no")
						end
					end
				end
			end
			for i, o in pairs(optionButtons) do
				if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
					glColor(1,1,1,0.08)
					RectRound(o[1], o[2], o[3], o[4], 2.5)
				end
			end
			
			-- draw select options
			if showSelectOptions ~= nil then
				showPresetButtons = false
				local oHeight = optionButtons[showSelectOptions][4] - optionButtons[showSelectOptions][2]
				local oPadding = 4
				y = optionButtons[showSelectOptions][4] -oPadding
				local yPos = y
				--Spring.Echo(oHeight)
				optionSelect = {}
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
				end
				glColor(0.22,0.22,0.22,0.85)
				RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				glColor(1,1,1,0.07)
				RectRound(optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4], 4)
				for i, option in pairs(options[showSelectOptions].options) do
					yPos = y-(((oHeight+oPadding+oPadding)*i)-oPadding)
					if IsOnRect(cx, cy, optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding) then
						glColor(1,1,1,0.1)
						RectRound(optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, 4)
					end
					table.insert(optionSelect, {optionButtons[showSelectOptions][1], yPos-oHeight-oPadding, optionButtons[showSelectOptions][3], yPos+oPadding, i})
					glText('\255\255\255\255'..option, optionButtons[showSelectOptions][1]+7, yPos-(oHeight/2.25)-oPadding, oHeight*0.85, "no")
				end
			end
			
			-- draw preset quality buttons
			showPresetButtons = false
			if showPresetButtons == true then
				--glCallList(presetsList)
				
				for preset, pp in pairs(presets) do
					if IsOnRect(cx, cy, pp.pos[1], pp.pos[2], pp.pos[3], pp.pos[4]) then
						glColor(0.7,1,0.3,0.2)
						local padding = pp.pos[5]
						RectRound(pp.pos[1]+padding, pp.pos[2]+padding, pp.pos[3]-padding, pp.pos[4]-padding, 6)
					end
				end
			end
		glPopMatrix()
	else
		if (WG['guishader_api'] ~= nil) then
			local removed = WG['guishader_api'].RemoveRect('options')
			if removed then
				--WG['guishader_api'].setBlurIntensity()
			  WG['guishader_api'].setScreenBlur(false)
			end
		end
	end
end


function applyOptionValue(i)
	local id = options[i].id
	if options[i].type == 'bool' then
		options[i].value = not options[i].value
		local value = 0
		if options[i].value then
			value = 1
		end
		if id == 'advmapshading' then
			Spring.SendCommands("AdvMapShading "..value)
			Spring.SetConfigInt("AdvMapShading",value)
		elseif id == 'advmodelshading' then
			Spring.SendCommands("AdvModelShading "..value)
			Spring.SetConfigInt("AdvModelShading",value)
		elseif id == 'advsky' then
			Spring.SetConfigInt("AdvSky",value)
		elseif id == 'shadows' then
			Spring.SendCommands("Shadows "..value)
		elseif id == 'fullscreen' then
			Spring.SendCommands("Fullscreen "..value)
			Spring.SetConfigInt("Fullscreen",value)
		elseif id == 'borderless' then
			Spring.SendCommands("WindowBorderless "..value)
			Spring.SetConfigInt("WindowBorderless",value)
		elseif id == 'screenedgemove' then
			Spring.SetConfigInt("FullscreenEdgeMove",value)
			Spring.SetConfigInt("WindowedEdgeMove",value)
		elseif id == 'hwcursor' then
			Spring.SendCommands("HardwareCursor "..value)
			Spring.SetConfigInt("HardwareCursor",value)
		elseif id == 'fpstimespeed' then
			Spring.SendCommands("fps "..value)
			Spring.SendCommands("clock "..value)
			Spring.SendCommands("speed "..value)
		elseif id == 'buildmenushortcuts' then
			WG['red_buildmenu'].setConfigShortcutsInfo(options[i].value)
		elseif id == 'darkenmap_darkenfeatures' then
			WG['darkenmap'].setDarkenFeatures(options[i].value)
		elseif id == 'enemyspotter_highlight' then
			WG['enemyspotter'].setHighlight(options[i].value)
		elseif id == 'smartselect_includebuildings' then
			WG['smartselect'].setIncludeBuildings(options[i].value)
		end
		
		if options[i].widget ~= nil then
			if value ~= 0 then
				if id == 'bloom' or id == 'guishader' or id == 'xrayshader' or id == 'snow' or id == 'mapedgeextension' then
					if luaShaders ~= 1 and not enabledLuaShaders then
						Spring.SetConfigInt("ForceShaders", 1)
						enabledLuaShaders = true
					end
				end
				widgetHandler:EnableWidget(options[i].widget)
			else
				widgetHandler:DisableWidget(options[i].widget)
			end
			if id == "teamcolors" then
      	Spring.SendCommands("luarules reloadluaui")	-- cause several widgets are still using old colors
			end
		end
	
	elseif options[i].type == 'slider' then
		local value =  options[i].value
		if id == 'fsaa' then
			Spring.SetConfigInt("FSAALevel",value)
		elseif id == 'shadowslider' then
			local enabled = 1
			if value == options.min then 
				enabled = 0
			end
			Spring.SendCommands("shadows "..enabled.." "..value)
			Spring.SetConfigInt("shadows", value)
		elseif id == 'decals' then
			Spring.SetConfigInt("GroundDecals", value)
			Spring.SendCommands("GroundDecals "..value)
		elseif id == 'scrollspeed' then
			Spring.SetConfigInt("ScrollWheelSpeed",value)
		elseif id == 'disticon' then
			--Spring.SetConfigInt("UnitIconDist "..value)
			Spring.SendCommands("disticon "..value)
		elseif id == 'treeradius' then
			Spring.SetConfigInt("TreeRadius",value)
		elseif id == 'particles' then
			Spring.SetConfigInt("MaxParticles",value)
		elseif id == 'nanoparticles' then
			Spring.SetConfigInt("MaxNanoParticles",value)
		elseif id == 'grassdetail' then
			Spring.SetConfigInt("GrassDetail",value)
		elseif id == 'grounddetail' then
			Spring.SetConfigInt("GroundDetail", value)
			Spring.SendCommands("grounddetail "..value)
		elseif id == 'sndvolmaster' then
			Spring.SetConfigInt("snd_volmaster", value)
		elseif id == 'crossalpha' then
			Spring.SendCommands("cross "..tonumber(Spring.GetConfigInt("CrossSize",1) or 10).." "..value)
			Spring.SetConfigInt("CrossAlpha", value)
		elseif id == 'darkenmap' then
			WG['darkenmap'].setMapDarkness(value)
		elseif id == 'enemyspotter_opacity' then
			WG['enemyspotter'].setOpacity(value)
		elseif id == 'bloom' then
			if value > 0 then
				widgetHandler:EnableWidget(options[i].widget)
				if luaShaders ~= 1 and not enabledLuaShaders then
					Spring.SetConfigInt("ForceShaders", 1)
					enabledLuaShaders = true
				end
			end
			if value == 1 then
				WG['bloom'].setAdvBloom(false)
			elseif value == 2 then
				WG['bloom'].setAdvBloom(true)
			else
				widgetHandler:DisableWidget(options[i].widget)
			end
		end
		
	elseif options[i].type == 'select' then
		local value =  options[i].value
		if id == 'water' then
			Spring.SendCommands("water "..(value-1))
		elseif id == 'camera' then
			Spring.SetConfigInt("CamMode",(value-1))
			if value == 1 then 
				Spring.SendCommands('viewfps')
			elseif value == 2 then 
				Spring.SendCommands('viewta')
			elseif value == 3 then 
				Spring.SendCommands('viewspring')
			elseif value == 4 then 
				Spring.SendCommands('viewrot')
			elseif value == 5 then 
				Spring.SendCommands('viewfree')
			end
		elseif id == 'cursor' then
			WG['cursors'].setcursor(options[i].options[value])
		end
	end
	
	if windowList then gl.DeleteList(windowList) end
	windowList = gl.CreateList(DrawWindow)
end


function loadPreset(preset)
	Spring.Echo('loading options preset: '..presets[preset].label)
	
	
	gl.DeleteList(windowList)
	windowList = gl.CreateList(DrawWindow)
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

function widget:IsAbove(x, y)
	-- on window
	if show then
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		return IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1)
	else
		return false
	end
end

function widget:GetTooltip(mx, my)
	if show and widget:IsAbove(mx,my) then
		return string.format(
			"")
	end
end

function getSliderValue(draggingSlider, cx)
	local sliderWidth = optionButtons[draggingSlider].sliderXpos[2] - optionButtons[draggingSlider].sliderXpos[1]
	local value = (cx - optionButtons[draggingSlider].sliderXpos[1]) / sliderWidth
	value = options[draggingSlider].min + ((options[draggingSlider].max - options[draggingSlider].min) * value)
	if value < options[draggingSlider].min then value = options[draggingSlider].min end
	if value > options[draggingSlider].max then value = options[draggingSlider].max end
	if options[draggingSlider].step ~= nil then
		value = math.floor((value / options[draggingSlider].step)+0.5) * options[draggingSlider].step
	end
	return value
end

function widget:MouseWheel(up, value)
	local x,y = Spring.GetMouseState()
	local cx, cy = correctMouseForScaling(x,y)
	if show then	
		return true
	end
end

function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		local cx, cy = correctMouseForScaling(x,y)
		options[draggingSlider].value = getSliderValue(draggingSlider,cx)
		sliderValueChanged = true
		applyOptionValue(draggingSlider)
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
		local cx, cy = correctMouseForScaling(x,y)
  
		if release then
		 	-- apply new slider value
			if draggingSlider ~= nil then
				options[draggingSlider].value = getSliderValue(draggingSlider,cx)
				applyOptionValue(draggingSlider)
				draggingSlider = nil
				return
			end
			
			-- select option
			if showSelectOptions ~= nil then
				for i, o in pairs(optionSelect) do
					if IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						options[showSelectOptions].value = o[5]
						applyOptionValue(showSelectOptions)
					end
				end
				if selectClickAllowHide ~= nil or not IsOnRect(cx, cy, optionButtons[showSelectOptions][1], optionButtons[showSelectOptions][2], optionButtons[showSelectOptions][3], optionButtons[showSelectOptions][4]) then
					showSelectOptions = nil
					selectClickAllowHide = nil
				else
					selectClickAllowHide = true
				end
				return
			end
		end
		
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
			
			
			if release then
			
				-- select option
				if showSelectOptions == nil then
					if showPresetButtons then
						for preset, pp in pairs(presets) do
							if IsOnRect(cx, cy, pp.pos[1], pp.pos[2], pp.pos[3], pp.pos[4]) then
								if pp.toggler ~= nil then
									if presets[preset].toggler == 'GPU' then
										presets[preset].toggler = 'CPU'
										presets[preset].label = '\255\195\155\110Set quality for:\n   \255\150\120\090GPU   \255\255\255\255CPU'
									else
										presets[preset].toggler = 'GPU'
										presets[preset].label = '\255\195\155\110Set quality for:\n   \255\255\255\255GPU   \255\150\120\090CPU'
									end
								  if presetsList then gl.DeleteList(presetsList) end
								  presetsList = gl.CreateList(DrawPresets)
								else
									loadPreset(preset)
								end
							end
						end
					end
						
					for i, o in pairs(optionButtons) do
						if options[i].type == 'bool' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							applyOptionValue(i)
						elseif options[i].type == 'slider' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
						
						elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							
						end
					end
				end
			else -- mousepress
				if not showSelectOptions then
					for i, o in pairs(optionButtons) do
						if options[i].type == 'slider' and (IsOnRect(cx, cy, o.sliderXpos[1], o[2], o.sliderXpos[2], o[4]) or IsOnRect(cx, cy, o[1], o[2], o[3], o[4])) then
							draggingSlider = i
							options[draggingSlider].value = getSliderValue(draggingSlider,cx)
							applyOptionValue(draggingSlider)
						elseif options[i].type == 'select' and IsOnRect(cx, cy, o[1], o[2], o[3], o[4]) then
							if showSelectOptions == nil then
								showSelectOptions = i
							elseif showSelectOptions == i then
								--showSelectOptions = nil
							end
						end
					end
				end
			end
			--[[ on close button
			local brectX1 = rectX2 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			local brectY2 = rectY1 - ((closeButtonSize+bgMargin+bgMargin) * widgetScale)
			if IsOnRect(x, y, brectX1, brectY2, rectX2, rectY1) then
				if release then
					showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
					show = not show
				end
				return true
			end]]--
			
			if button == 1 or button == 3 then
				return true
			end
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
			if release and draggingSlider == nil then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = not show
			end
		end
		
		if show then
			if windowList then gl.DeleteList(windowList) end
			windowList = gl.CreateList(DrawWindow)
		end
		
		return true
  else
		tx = (x - posX*vsx)/(17*widgetScale)
		ty = (y - posY*vsy)/(17*widgetScale)
		if tx < 0 or tx > 4.5 or ty < 0 or ty > 1.05 then return false end
		if release then
			showOnceMore = show		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
		if show then
			if windowList then gl.DeleteList(windowList) end
			windowList = gl.CreateList(DrawWindow)
		end
		return true
  end
end


function widget:Initialize()

	-- get widget list
  for name,data in pairs(widgetHandler.knownWidgets) do
		fullWidgetsList[name] = data
  end
	  
		local bloomValue = 0
		
	options = {
		{id="fullscreen", name="Fullscreen", type="bool", value=tonumber(Spring.GetConfigInt("Fullscreen",1) or 1) == 1},
		{id="borderless", name="Borderless", type="bool", value=tonumber(Spring.GetConfigInt("WindowBorderless",1) or 1) == 1},
		{id="screenedgemove", name="Screen edge moves camera", type="bool", value=tonumber(Spring.GetConfigInt("FullscreenEdgeMove",1) or 1) == 1, description="If mouse is close to screen edge this will move camera\n\nChanges will be applied next game"},
		{id="hwcursor", name="Hardware cursor", type="bool", value=tonumber(Spring.GetConfigInt("hardwareCursor",1) or 1) == 1, description="When disabled: the mouse cursor refresh rate will be the same as your ingame fps"},
		{id="fsaa", name="Anti Aliasing", type="slider", min=0, max=16, step=1, value=tonumber(Spring.GetConfigInt("FSAALevel",1) or 2), description='Changes will be applied next game'},
		{id="advmapshading", name="Advanced map shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvMapShading",1) or 1) == 1, description='When disabled: map shadows aren\'t rendered as well'},
		{id="advmodelshading", name="Advanced model shading", type="bool", value=tonumber(Spring.GetConfigInt("AdvModelShading",1) or 1) == 1},
		
		-- only one of these shadow options are shown, depending if "Shadow Quality Manager" widget is active
		{id="shadows", name="Shadows", type="bool", value=tonumber(Spring.GetConfigInt("Shadows",1) or 1) == 1, description='Shadow detail is currently controlled by "Shadow Quality Manager" widget\n...this widget will auto reduce detail when fps gets low.\n\nShadows requires "Advanced map shading" option to be enabled'},
		{id="shadowslider", name="Shadows", type="slider", min=1500, max=6000, value=tonumber(Spring.GetConfigInt("ShadowMapSize",1) or 2000), description='Set shadow detail\nSlider positioned the very left means shadows will be disabled\n\nShadows requires "Advanced map shading" option to be enabled'},
		
		--{id="bloom", widget="Bloom Shader", name="Bloom shader", type="bool", value=widgetHandler.orderList["Bloom Shader"] ~= nil and (widgetHandler.orderList["Bloom Shader"] > 0), description='Bloom will make the map and units glow'},
		{id="bloom", widget="Bloom Shader", name="Bloom shader", type="slider", min=0, max=2, step=1, value=0, description='Bloom will make the map and units glow\n\nSetting the slider all the way will stress your GPU more'},
		{id="decals", name="Ground decals", type="slider", min=0, max=5, step=1, value=tonumber(Spring.GetConfigInt("GroundDecals",1) or 1), description='Set how long map decals will stay.\n\nDecals are ground scars, footsteps/tracks and shading under buildings'},
		{id="guishader", widget="GUI-Shader", name="GUI blur shader", type="bool", value=widgetHandler.orderList["GUI-Shader"] ~= nil and (widgetHandler.orderList["GUI-Shader"] > 0), description='Blurs the world under every user interface element\n\nIntel Graphics have trouble with this'},
		{id="mapedgeextension", widget="Map Edge Extension", name="Map edge extension", type="bool", value=widgetHandler.orderList["Map Edge Extension"] ~= nil and (widgetHandler.orderList["Map Edge Extension"] > 0), description='Mirrors the map at screen edges and darkens and decolorizes them\n\nEnabled shaders for best result'},
		{id="water", name="Water type", type="select", options={'basic','reflective','dynamic','reflective&refractive','bump-mapped'}, value=(tonumber(Spring.GetConfigInt("Water",1) or 1)+1)},
		{id="projectilelights", widget="Projectile lights", name="Projectile lights", type="bool", value=widgetHandler.orderList["Projectile lights"] ~= nil and (widgetHandler.orderList["Projectile lights"] > 0), description='Projectiles are plasmaballs, it will light up the map below them'},
		{id="lups", widget="LupsManager", name="Lups particle effects", type="bool", value=widgetHandler.orderList["LupsManager"] ~= nil and (widgetHandler.orderList["LupsManager"] > 0), description='Toggle unit particle effects: jet beams, ground flashes, fusion energy balls'},
		{id="xrayshader", widget="XrayShader", name="Unit xray shader", type="bool", value=widgetHandler.orderList["XrayShader"] ~= nil and (widgetHandler.orderList["XrayShader"] > 0), description='Highlights all units, highlight effect dissolves on close camera range.\n\nFades out and disables at low fps\nWorks less on dark teamcolors'},
		{id="outline", widget="Outline", name="Unit Outline (tiny)", type="bool", value=widgetHandler.orderList["Outline"] ~= nil and (widgetHandler.orderList["Outline"] > 0), description='Adds a small outline to units that make them more crisp and stand out'},
		{id="disticon", name="Unit icon distance", type="slider", min=0, max=800, value=tonumber(Spring.GetConfigInt("UnitIconDist",1) or 800)},
		{id="treeradius", name="Tree render distance", type="slider", min=0, max=2000, value=tonumber(Spring.GetConfigInt("TreeRadius",1) or 1000), description='Applies to SpringRTS engine default trees\n\nChanges will be applied next game'},
		{id="particles", name="Max particles", type="slider", min=2500, max=25000, value=tonumber(Spring.GetConfigInt("MaxParticles",1) or 1000), description='Particles used for explosions, smoke, fire and missiletrails\n\nSetting a low value will mean that various effects wont show properly'},
		{id="nanoparticles", name="Max nano particles", type="slider", min=500, max=5000, value=tonumber(Spring.GetConfigInt("MaxNanoParticles",1) or 500), description='NOTE: Nano particles are more expensive regarding the CPU'},
		{id="grounddetail", name="Ground mesh detail", type="slider", min=50, max=200, value=tonumber(Spring.GetConfigInt("GroundDetail",1) or 60), description='Ground geometry mesh detail'},
		{id="grassdetail", name="Grass", type="slider", min=0, max=10, step=1, value=tonumber(Spring.GetConfigInt("GrassDetail",1) or 5), description='Amount of grass rendered\n\nChanges will be applied next game'},
		{id="advsky", name="Advanced sky", type="bool", value=tonumber(Spring.GetConfigInt("AdvSky",1) or 1) == 1, description='Enables high resolution clouds\n\nChanges will be applied next game'},
		
		{id="crossalpha", name="Mouse cross alpha", type="slider", min=0, max=1, value=tonumber(Spring.GetConfigInt("CrossAlpha",1) or 1), description='Opacity of mouse icon in center of screen when you are in camera pan mode\n\n(The\'icon\' has a dot in center with 4 arrows pointing in all directions)'},
		{id="commandsfx", widget="Commands FX", name="Unit command FX", type="bool", value=widgetHandler.orderList["Commands FX"] ~= nil and (widgetHandler.orderList["Commands FX"] > 0), description='Shows unit target lines when you give orders\n\nThe commands from your teammates are shown as well'},
		
		{id="scrollspeed", name="Zoom direction/speed", type="slider", min=-45, max=45, step=1, value=tonumber(Spring.GetConfigInt("ScrollWheelSpeed",1) or 25), description='Leftside of the slider means inversed scrolling direction!\nNOTE: Having the slider centered means no mousewheel zooming at all!\n\nChanges will be applied next game'},
		{id="sndvolmaster", name="Sound volume", type="slider", min=0, max=200, value=tonumber(Spring.GetConfigInt("snd_volmaster",1) or 100)},
		{id="fpstimespeed", name="Display FPS, GameTime and Speed", type="bool", value=tonumber(Spring.GetConfigInt("ShowFPS",1) or 1) == 1, description='Located at the top right of the screen\n\nIndividually toggle them with /fps /clock /speed'},
		
		{id="snow", widget="Snow", name="Snow", type="bool", value=widgetHandler.orderList["Snow"] ~= nil and (widgetHandler.orderList["Snow"] > 0), description='Snows at winter maps, auto reduces amount when fps gets lower and unitcount higher\n\nUse /snow to toggle snow for current map (it remembers)'},
		{id="teamcolors", widget="Common Team Colors", name="Team colors based on a palette", type="bool", value=widgetHandler.orderList["Common Team Colors"] ~= nil and (widgetHandler.orderList["Common Team Colors"] > 0), description='Replaces lobby team colors for a color palette based one\n\nNOTE: reloads all widgets because these need to update their teamcolors'},
		
		{id="camera", name="Camera", type="select", options={'fps','overhead','spring','rot overhead','free'}, value=(tonumber(Spring.GetConfigInt("CamMode",1) or 2))},
	}
	
	local processedOptions = {}
	local insert = true
	for oid,option in pairs(options) do
		insert = true
		if option.type == 'slider' then
			if option.value < option.min then option.value = option.min end
			if option.value > option.max then option.value = option.max end
		end
		if option.id == "shadows" and (fullWidgetsList["Shadow Quality Manager"] == nil or (widgetHandler.orderList["Shadow Quality Manager"] == 0)) then
			insert = false
		end
		if option.id == "shadowslider" and fullWidgetsList["Shadow Quality Manager"] ~= nil and (widgetHandler.orderList["Shadow Quality Manager"] > 0) then
			insert = false
		end
		if option.widget ~= nil and fullWidgetsList[option.widget] == nil then
			insert = false
		end
		if luaShaders ~= 1 then
			if option.id == "advmapshading" or option.id == "advmodelshading" or option.id == "bloom" or option.id == "guishader" or option.id == "xrayshader" or option.id == "mapedgeextension" or option.id == "snow" then
				option.description = 'You dont have shaders enabled, we will enable it for you but...\n\nChanges will be applied next game'
			end
		end
		if insert then
			table.insert(processedOptions, option)
		end
	end
	options = processedOptions
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
    end
    if windowList then
        glDeleteList(windowList)
        glDeleteList(presetsList)
    end
end
