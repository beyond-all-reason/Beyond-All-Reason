
function widget:GetInfo()
return {
	name    = "Unit Info",
	desc    = "Select a single unit and press CTRL + U. Or use a command: /unitinfo armcom.",
	author  = "Floris",
	date    = "August 2015",
	license = "Dental flush",
	layer   = -2,
	enabled = true,
}
end
local triggerKey = 117	-- 117 = U   (+ ctrl)

local show = false

local loadedFontSize = 32
local font = gl.LoadFont(LUAUI_DIRNAME.."Fonts/FreeSansBold.otf", loadedFontSize, 16,2)

local bgcorner = ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"
local closeButtonTex = ":n:"..LUAUI_DIRNAME.."Images/close.dds"

local bgMargin = 6

local closeButtonSize = 30
local screenHeight = 520-bgMargin-bgMargin
local screenWidth = 1050-bgMargin-bgMargin

local textareaMinLines = 10		-- wont scroll down more, will show at least this amount of lines 

local customScale = 1

local startLine = 1

local rot = 0
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

local sformat = string.format

local widgetScale = 1
local endPosX = 0.1
local vsx, vsy = Spring.GetViewGeometry()

local unitNames = {}
local fileContentLines = {}
local totalfileContentLines = 0

local spGetSelectedUnits		= Spring.GetSelectedUnits
local spGetSelectedUnitsCount	= Spring.GetSelectedUnitsCount
local spGetUnitDefID			= Spring.GetUnitDefID


function widget:ViewResize()
  vsx,vsy = Spring.GetViewGeometry()
  screenX = (vsx*0.5) - (screenWidth/2)
  screenY = (vsy*0.5) + (screenHeight/2)
  widgetScale = (0.75 + (vsx*vsy / 7500000)) * customScale
  if windowDlist then gl.DeleteList(windowDlist) end
  if show then
	windowDlist = gl.CreateList(DrawWindow)
  end
end

local myTeamID = Spring.GetMyTeamID()
local amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
local gameStarted = (Spring.GetGameFrame()>0)
function widget:GameStart()
    gameStarted = true
end

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


local versionOffsetX = 0
local versionOffsetY = 14
local versionFontSize = 16
local rot = 0

local function short(n,f)
	if (f == nil) then
		f = 0
	end
	if (n > 9999999) then
		return sformat("%."..f.."fm",n/1000000)
	elseif (n > 9999) then
		return sformat("%."..f.."fk",n/1000)
	else
		return sformat("%."..f.."f",n)
	end
end

local function CenterUnitDef(unitDefID, width, height)
  local ud = UnitDefs[unitDefID] 
  if (not ud) then
    return
  end
  if (not ud.dimensions) then
    ud.dimensions = Spring.GetUnitDefDimensions(unitDefID)
  end
  if (not ud.dimensions) then
    return
  end

  local d = ud.dimensions
  local xSize = (d.maxx - d.minx)
  local ySize = (d.maxy - d.miny)
  local zSize = (d.maxz - d.minz)

  local hSize -- maximum horizontal dimension
  if (xSize > zSize) then hSize = xSize else hSize = zSize end

  -- aspect ratios
  local mAspect = hSize / ySize
  local vAspect = width / height

  -- scale the unit to the box (maxspect)
  local scale
  if (mAspect > vAspect) then
    scale = (width / hSize)
  else
    scale = (height / ySize)
  end
  scale = scale * 0.8
  gl.Scale(scale, scale, scale)

  -- translate to the unit's midpoint
  local xMid = 0.5 * (d.maxx + d.minx)
  local yMid = 0.5 * (d.maxy + d.miny)
  local zMid = 0.5 * (d.maxz + d.minz)
  gl.Translate(-xMid, -yMid, -zMid)
end

function DrawUnit(x,y,width,height)
	
	-- background
	gl.Color(0.72,0.5,0.12,0.3)
	gl.Color(0.66,0.66,0.66,0.22)
	RectRound(x,y-height,x+width,y,6)
	
	if currentUnitDefID then
		gl.PushMatrix()
		gl.Translate(x+(width/2), y-(height/2), 0)
		gl.Rotate(26, 1, 0, 0)
		gl.Rotate(rot, 0, 1, 0)
		CenterUnitDef(currentUnitDefID, width*0.8, height*0.8)
		
		gl.UnitShape(currentUnitDefID, Spring.GetMyTeamID(), false, true ,true)
		
		gl.PopMatrix()
	end
end

function DrawUnitInfo(x,y,width)
	
	if currentUnitDefID then
		-- info
		local fontSize = 14
		local uDef = UnitDefs[currentUnitDefID]
		local margin = 13
		x = x + margin
		x2 = x + width - margin - margin
		y = y - margin
		local yOffset = fontSize
		local yOffsetGap = 11
		local value = 0
		
		font:Begin()
		font:SetTextColor(0.8,0.77,0.74,1)
		font:Print("Metal", x, y-yOffset, fontSize, "n")
		font:Print(uDef.metalCost, x2, y-yOffset, fontSize, "rn")
		yOffset = yOffset + fontSize
		font:Print("Energy", x, y-yOffset, fontSize, "n")
		font:Print(uDef.energyCost, x2, y-yOffset, fontSize, "rn")
		yOffset = yOffset + fontSize + yOffsetGap
		font:Print("Health", x, y-yOffset, fontSize, "n")
		font:Print(uDef.health, x2, y-yOffset, fontSize, "rn")
		yOffset = yOffset + fontSize + yOffsetGap
		if uDef.speed > 0 then
			value = ((uDef.speed < 100 and math.floor(uDef.speed) ~= uDef.speed) and short(uDef.speed,1) or short(uDef.speed,0))
			font:Print("Speed", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if uDef.energyUpkeep < 0 then
			value = ((0-uDef.energyUpkeep < 100 and math.floor(uDef.energyUpkeep) ~= uDef.energyUpkeep) and short(0-uDef.energyUpkeep,1) or short(0-uDef.energyUpkeep,0))
			font:Print("Energy +", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		elseif uDef.energyMake > 0 then
			value = ((uDef.energyMake < 100 and math.floor(uDef.energyMake) ~= uDef.energyMake) and short(uDef.energyMake,1) or short(uDef.energyMake,0))
			font:Print("Energy +", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if uDef.metalUpkeep < 0 then
			value = ((0-uDef.metalUpkeep < 100 and math.floor(uDef.metalUpkeep) ~= uDef.metalUpkeep) and short(0-uDef.metalUpkeep,1) or short(0-uDef.metalUpkeep,0))
			font:Print("Metal +", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		elseif uDef.metalMake > 0 then
			value = ((uDef.metalMake < 100 and math.floor(uDef.metalMake) ~= uDef.metalMake) and short(uDef.metalMake,1) or short(uDef.metalMake,0))
			font:Print("Metal +", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if uDef.buildSpeed > 0 then
			font:Print("BuildSpeed", x, y-yOffset, fontSize, "n")
			font:Print(uDef.buildSpeed, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if uDef.energyStorage > 0 or uDef.metalStorage > 0 then
			if uDef.energyStorage > 0 then
				font:Print("Energy store", x, y-yOffset, fontSize, "n")
				font:Print(uDef.energyStorage, x2, y-yOffset, fontSize, "rn")
				yOffset = yOffset + fontSize
			end
			if uDef.metalStorage > 0 then
				font:Print("Metal store", x, y-yOffset, fontSize, "n")
				font:Print(uDef.metalStorage, x2, y-yOffset, fontSize, "rn")
				yOffset = yOffset + fontSize
			end
			yOffset = yOffset + yOffsetGap
		end
		if uDef.autoHeal > 0 then
			value = ((uDef.autoHeal < 100 and math.floor(uDef.autoHeal) ~= uDef.autoHeal) and short(uDef.autoHeal,1) or short(uDef.autoHeal,0))
			font:Print("AutoHeal", x, y-yOffset, fontSize, "n")
			font:Print(value, x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if uDef.cloakCost > 0 then
			font:Print("Cloak cost", x, y-yOffset, fontSize, "n")
			font:Print(short(uDef.cloakCost,0), x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize
			if uDef.cloakCostMoving ~= uDef.cloakCost then
				font:Print("Cloak move", x, y-yOffset, fontSize, "n")
				font:Print(short(uDef.cloakCostMoving,0), x2, y-yOffset, fontSize, "rn")
				yOffset = yOffset + fontSize
			end
			yOffset = yOffset + yOffsetGap
		end
		if table.getn(uDef.buildOptions) > 0 then
			font:Print("Build options", x, y-yOffset, fontSize, "n")
			font:Print(table.getn(uDef.buildOptions), x2, y-yOffset, fontSize, "rn")
			yOffset = yOffset + fontSize + yOffsetGap
		end
		if table.getn(uDef.weapons) > 0 then
			local uWeps = uDef.weapons
			font:Print((#uWeps > 1 and "Weapons:" or "Weapon:"), x, y-yOffset, fontSize, "n")
			yOffset = yOffset + fontSize
			
			fontSize = 13
			for i = 1, #uWeps do
				local wDefID = uWeps[i].weaponDef
				font:Print("  "..WeaponDefs[wDefID].description, x, y-yOffset, fontSize, "n")
				yOffset = yOffset + fontSize
			end
		end
		
		font:End()
	end
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
	
	local fontColorTitle			= {1,1,1,1}
	local fontColorDate				= {0.66,0.88,0.66,1}
	local fontColorLine				= {0.8,0.77,0.74,1}
	local fontColorLineBullet		= {0.9,0.6,0.2,1}
	
	local textRightOffset = scrollbar and scrollbarMargin+scrollbarWidth+scrollbarWidth or 0
	local maxLines = math.floor((height-5)/fontSizeLine)
	
	-- textarea scrollbar
	if scrollbar then
		if (totalfileContentLines > maxLines or startLine > 1) then	-- only show scroll above X lines
			local scrollbarTop       = y-scrollbarOffsetTop-scrollbarMargin-(scrollbarWidth-scrollbarPosWidth)
			local scrollbarBottom    = y-scrollbarOffsetBottom-height+scrollbarMargin+(scrollbarWidth-scrollbarPosWidth)
			local scrollbarPosHeight = math.max(((height-scrollbarMargin-scrollbarMargin) / totalfileContentLines) * ((height-scrollbarMargin-scrollbarMargin) / 25), scrollbarPosMinHeight)
			local scrollbarPos       = scrollbarTop + (scrollbarBottom - scrollbarTop) * ((startLine-1) / totalfileContentLines)
			scrollbarPos             = scrollbarPos + ((startLine-1) / totalfileContentLines) * scrollbarPosHeight	-- correct position taking position bar height into account

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
	if fileContent then
		font:Begin()
		font:SetTextColor(fontColorLine)
		local lineKey = startLine
		local j = 1
		while j < maxLines do	-- maxlines is not exact, just a failsafe
			if (fontSizeTitle )*j > height then
				break;
			end
			if fileContentLines[lineKey] == nil then
				break;
			end
			
			local line = fileContentLines[lineKey]
			
			-- line
			line = "" .. line
			line, numLines = font:WrapText(line, (width)*(loadedFontSize/fontSizeLine))
			if (fontSizeTitle)*(j+numLines-1) > height then 
				break;
			end
			font:Print(line, x, y-(fontSizeTitle)*j, fontSizeLine, "n")
			j = j + (numLines - 1)

			j = j + 1
			lineKey = lineKey + 1
		end
		font:End()
	end
end

function widget:TextCommand(cmd)

	local unitname = cmd:match("^unitinfo (.+)$")
	if unitname and unitNames[unitname] then
		loadUnit(unitNames[unitname])
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
	-- side area
	gl.Color(0.33,0.33,0.33,0.2)
	RectRound(x,y-screenHeight,x+150,y,6)
	
	-- close button
    gl.Color(1,1,1,1)
	gl.Texture(closeButtonTex)
	gl.TexRect(screenX+screenWidth-closeButtonSize,screenY,screenX+screenWidth,screenY-closeButtonSize)
	gl.Texture(false)
	
	-- title
	local unitUd = UnitDefs[currentUnitDefID]
    local title = (unitUd['name'] or "")..(unitUd['humanName'] and "      "..unitUd['humanName'] or "")..(unitUd['humanName'] ~= unitUd['tooltip'] and "      "..unitUd['tooltip'] or "")
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
	DrawTextarea(x+170, y-10, screenWidth-170, screenHeight-22, 1)
	
	-- unit info
	DrawUnitInfo(x, y-150, 150)
end

local sec = 0
function widget:Update(dt)

	if not show then return end
	
	sec = sec + dt
	hoversize = math.sin(math.pi*(sec))
	rot = 30* math.sin(math.pi*(sec/2.5))
end


function widget:DrawScreen()
    if spIsGUIHidden() then return end
    if amNewbie and not gameStarted then return end
    
    if show or showOnceMore then
    
		-- draw the panel
		glPushMatrix()
			glTranslate(-(vsx * (widgetScale-1))/2, -(vsy * (widgetScale-1))/2, 0)
			glScale(widgetScale, widgetScale, 1)
			glCallList(windowDlist)
			DrawUnit(screenX, screenY, 150, 150)
		glPopMatrix()
		if (WG['guishader_api'] ~= nil) then
			local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
			local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
			WG['guishader_api'].InsertRect(rectX1, rectY2, rectX2, rectY1, 'unitinfo')
		end
		showOnceMore = false
		
    else
		if (WG['guishader_api'] ~= nil) then
			WG['guishader_api'].RemoveRect('unitinfo')
		end
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
			"\255\255\255\1Left mouse\255\255\255\255 on textarea to scroll down.\n"..
			"\255\255\255\1Right mouse\255\255\255\255 on textarea  to scroll up.\n\n"..
			"Add CTRL or SHIFT to scroll faster, or combine CTRL+SHIFT (+ALT).")
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if key == triggerKey and mods["ctrl"] then
		if spGetSelectedUnitsCount() >= 1 then
			local udefID = spGetUnitDefID(spGetSelectedUnits()[1])
			if currentUnitDefID == udefID then 
				show = not show 
			else
				loadUnit(udefID)
			end
		else
			show = false
		end
	end
end

function loadUnit(unitDefID)
	currentUnitDefID = unitDefID
	
	local unitUd = UnitDefs[unitDefID]
		
	fileContent = VFS.LoadFile("units/"..unitUd['name']..".lua")
	if fileContent then
		-- store file lines into array
		fileContentLines = lines(fileContent)
		
		local versionKey = 0
		for i, line in ipairs(fileContentLines) do
			totalfileContentLines = i
		end
		show = true
		if windowDlist then
			gl.DeleteList(windowDlist)
		end
		startLine = 1
		windowDlist = gl.CreateList(DrawWindow)
	else
		Spring.Echo("Unit info: couldn't load the unit file")
		--widgetHandler:RemoveWidget()
	end
end


function widget:MouseWheel(up, value)
	
	if show then	
		local addLines = value*-5 -- direction is retarded
		
		startLine = startLine + addLines
		if startLine < 1 then startLine = 1 end
		if startLine > totalfileContentLines - textareaMinLines then startLine = totalfileContentLines - textareaMinLines end
		
		if windowDlist then
			glDeleteList(windowDlist)
		end
		windowDlist = gl.CreateList(DrawWindow)
		return true
	else
		return false
	end
end

function widget:MousePress(x, y, button)
	if spIsGUIHidden() then return false end
    if amNewbie and not gameStarted then return end
    
    if show then 
		-- on window
		local rectX1 = ((screenX-bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY1 = ((screenY+bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		local rectX2 = ((screenX+screenWidth+bgMargin) * widgetScale) - ((vsx * (widgetScale-1))/2)
		local rectY2 = ((screenY-screenHeight-bgMargin) * widgetScale) - ((vsy * (widgetScale-1))/2)
		if IsOnRect(x, y, rectX1, rectY2, rectX2, rectY1) then
		
			-- on close button
			local brectX1 = rectX2 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			local brectY2 = rectY1 - (closeButtonSize+bgMargin+bgMargin * widgetScale)
			if IsOnRect(x, y, brectX1, brectY2, rectX2, rectY1) then
				showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
				show = not show
				return true
			end
			
			--[[ scroll text with mouse 2
			if button == 1 or button == 3 then
				if IsOnRect(x, y, rectX1+(160*widgetScale), rectY2, rectX2, rectY1) then
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
					if startLine > totalfileContentLines - textareaMinLines then startLine = totalfileContentLines - textareaMinLines end
					
					if windowDlist then
						glDeleteList(windowDlist)
					end
					windowDlist = gl.CreateList(DrawWindow)
					return true
				end
			end]]--
			
			if button == 1 or button == 3 then
				return true
			end
		elseif titleRect == nil or not IsOnRect(x, y, (titleRect[1] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[2] * widgetScale) - ((vsy * (widgetScale-1))/2), (titleRect[3] * widgetScale) - ((vsx * (widgetScale-1))/2), (titleRect[4] * widgetScale) - ((vsy * (widgetScale-1))/2)) then
			showOnceMore = true		-- show once more because the guishader lags behind, though this will not fully fix it
			show = not show
		end
    end
end

function lines(str)
  local t = {}
  local function helper(line) table.insert(t, line) return "" end
  helper((str:gsub("(.-)\r?\n", helper)))
  return t
end

function widget:Initialize()
	for udid, unitDef in pairs(UnitDefs) do
		unitNames[unitDef.name] = udid
	end
end

function widget:Shutdown()
    if buttonGL then
        glDeleteList(buttonGL)
        buttonGL = nil
    end
    if windowDlist then
        glDeleteList(windowDlist)
        windowDlist = nil
    end
end
