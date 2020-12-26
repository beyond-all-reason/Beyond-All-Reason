--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file: gui_musicPlayer.lua
--	brief:	yay music
--	author:	cake
--
--	Copyright (C) 2007.
--	Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name	= "AdvPlayersList Unit Totals",
		desc	= "Displays number of units",
		author	= "Floris",
		date	= "december 2019",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= false,	--	loaded by default?
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local backgroundTexture = "LuaUI/Images/stripes.png"
local bgtexOpacity = 0.016
local bgtexScale = 6	-- lower = smaller tiles
local bgtexSize

local vsx, vsy = Spring.GetViewGeometry()

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix    = gl.PopMatrix
local glColor        = gl.Color
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local font, bgpadding, chobbyInterface, hovering

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0
local gameMaxUnits = 2000
if Spring.GetModOptions() and Spring.GetModOptions().maxunits then
	gameMaxUnits = tonumber(Spring.GetModOptions().maxunits)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:Initialize()
	widget:ViewResize()
	updatePosition()
	WG['unittotals'] = {}
	WG['unittotals'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
end


local function DrawRectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
	local csyMult = 1 / ((sy-py)/cs)

	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	gl.Vertex(px+cs, py, 0)
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	gl.Vertex(sx-cs, sy, 0)
	gl.Vertex(px+cs, sy, 0)

	-- left side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px, py+cs, 0)
	gl.Vertex(px+cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)

	-- right side
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx, py+cs, 0)
	gl.Vertex(sx-cs, py+cs, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)

	local offset = 0.15		-- texture offset, because else gaps could show

	-- bottom left
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or px <= 0)  or (bl ~= nil and bl == 0)) and bl ~= 2   then
		gl.Vertex(px, py, 0)
	else
		gl.Vertex(px+cs, py, 0)
	end
	gl.Vertex(px+cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(px+cs, py+cs, 0)
	gl.Vertex(px, py+cs, 0)
	-- bottom right
	if c2 then
		gl.Color(c1[1],c1[2],c1[3],c1[4])
	end
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		gl.Vertex(sx, py, 0)
	else
		gl.Vertex(sx-cs, py, 0)
	end
	gl.Vertex(sx-cs, py, 0)
	if c2 then
		gl.Color(c1[1]*(1-csyMult)+(c2[1]*csyMult),c1[2]*(1-csyMult)+(c2[2]*csyMult),c1[3]*(1-csyMult)+(c2[3]*csyMult),c1[4]*(1-csyMult)+(c2[4]*csyMult))
	end
	gl.Vertex(sx-cs, py+cs, 0)
	gl.Vertex(sx, py+cs, 0)
	-- top left
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		gl.Vertex(px, sy, 0)
	else
		gl.Vertex(px+cs, sy, 0)
	end
	gl.Vertex(px+cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(px+cs, sy-cs, 0)
	gl.Vertex(px, sy-cs, 0)
	-- top right
	if c2 then
		gl.Color(c2[1],c2[2],c2[3],c2[4])
	end
	if ((sy >= vsy or sx >= vsx)  or (tr ~= nil and tr == 0)) and tr ~= 2 then
		gl.Vertex(sx, sy, 0)
	else
		gl.Vertex(sx-cs, sy, 0)
	end
	gl.Vertex(sx-cs, sy, 0)
	if c2 then
		gl.Color(c2[1]*(1-csyMult)+(c1[1]*csyMult),c2[2]*(1-csyMult)+(c1[2]*csyMult),c2[3]*(1-csyMult)+(c1[3]*csyMult),c2[4]*(1-csyMult)+(c1[4]*csyMult))
	end
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.Vertex(sx, sy-cs, 0)
end
function RectRound(px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)		-- (coordinates work differently than the RectRound func in other widgets)
	gl.Texture(false)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs, tl,tr,br,bl, c1,c2)
end

local function DrawTexturedRectRound(px, py, sx, sy, cs, tl, tr, br, bl, offset, size)
	local scale = size and (size / (sx-px)) or 1
	local offset = offset or 0
	local csyMult = 1 / ((sy - py) / cs)
	local ycMult = (sy-py) / (sx-px)

	local function drawTexCoordVertex(x, y)
		local yc = 1 - ((y - py) / (sy - py))
		local xc = ((x - px) / (sx - px))
		yc = 1 - ((y - py) / (sy - py))
		gl.TexCoord((xc/scale)+offset, ((yc*ycMult)/scale)+offset)
		gl.Vertex(x, y, 0)
	end

	-- mid section
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(px + cs, sy)

	-- left side
	drawTexCoordVertex(px, py + cs)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)

	-- right side
	drawTexCoordVertex(sx, py + cs)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)

	-- bottom left
	if ((py <= 0 or px <= 0) or (bl ~= nil and bl == 0)) and bl ~= 2 then
		drawTexCoordVertex(px, py)
	else
		drawTexCoordVertex(px + cs, py)
	end
	drawTexCoordVertex(px + cs, py)
	drawTexCoordVertex(px + cs, py + cs)
	drawTexCoordVertex(px, py + cs)
	-- bottom right
	if ((py <= 0 or sx >= vsx) or (br ~= nil and br == 0)) and br ~= 2 then
		drawTexCoordVertex(sx, py)
	else
		drawTexCoordVertex(sx - cs, py)
	end
	drawTexCoordVertex(sx - cs, py)
	drawTexCoordVertex(sx - cs, py + cs)
	drawTexCoordVertex(sx, py + cs)
	-- top left
	if ((sy >= vsy or px <= 0) or (tl ~= nil and tl == 0)) and tl ~= 2 then
		drawTexCoordVertex(px, sy)
	else
		drawTexCoordVertex(px + cs, sy)
	end
	drawTexCoordVertex(px + cs, sy)
	drawTexCoordVertex(px + cs, sy - cs)
	drawTexCoordVertex(px, sy - cs)
	-- top right
	if ((sy >= vsy or sx >= vsx) or (tr ~= nil and tr == 0)) and tr ~= 2 then
		drawTexCoordVertex(sx, sy)
	else
		drawTexCoordVertex(sx - cs, sy)
	end
	drawTexCoordVertex(sx - cs, sy)
	drawTexCoordVertex(sx - cs, sy - cs)
	drawTexCoordVertex(sx, sy - cs)
end
function TexturedRectRound(px, py, sx, sy, cs, tl, tr, br, bl, offset, size)
	gl.BeginEnd(GL.QUADS, DrawTexturedRectRound, px, py, sx, sy, cs, tl, tr, br, bl, offset, size)
end

local function updateValues()

	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 10*widgetScale

	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		local titleColor = '\255\210\210\210'
		local valueColor = '\255\255\255\255'
		local myTotalUnits = Spring.GetTeamUnitCount(Spring.GetMyTeamID())
        font:Begin()
		font:Print(titleColor..'# units  '..valueColor..myTotalUnits..titleColor..' / '..valueColor..gameMaxUnits, left+textXPadding, bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
        font:End()
    end)
end

local function createList()
	if drawlist[3] ~= nil then
		glDeleteList(drawlist[3])
	end
	if WG['guishader'] then
		drawlist[3] = glCreateList( function()
			RectRound(left, bottom, right, top, bgpadding*1.6)
		end)
		WG['guishader'].InsertDlist(drawlist[3], 'unittotals')
	end
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		--glColor(0, 0, 0, ui_opacity)
		RectRound(left, bottom, right, top, bgpadding*1.6, 1,1,1,1, {0.1,0.1,0.1,ui_opacity}, {0,0,0,ui_opacity})

		local borderPadding = bgpadding
		local borderPaddingRight = borderPadding
		if right >= vsx-0.2 then
			borderPaddingRight = 0
		end
		local borderPaddingLeft = borderPadding
		if left <= 0.2 then
			borderPaddingLeft = 0
		end
		--glColor(1,1,1,ui_opacity*0.055)
		RectRound(left+borderPaddingLeft, bottom, right-borderPaddingRight, top-borderPadding, bgpadding, 1,1,1,1, {0.3,0.3,0.3,ui_opacity*0.1}, {1,1,1,ui_opacity*0.1})

		gl.Texture(backgroundTexture)
		gl.Color(1,1,1, bgtexOpacity)
		TexturedRectRound(left+borderPaddingLeft, bottom, right-borderPaddingRight, top-borderPadding, bgpadding, 1,1,1,1, 0, bgtexSize)
		gl.Texture(false)

		-- gloss
		glBlending(GL_SRC_ALPHA, GL_ONE)
		RectRound(left+borderPaddingLeft, top-borderPadding-((top-bottom)*0.35), right-borderPaddingRight, top-borderPadding, bgpadding, 1,1,0,0, {1,1,1,0.006*glossMult}, {1,1,1,0.055*glossMult})
		RectRound(left+borderPaddingLeft, bottom, right-borderPaddingRight, bottom+((top-bottom)*0.35), bgpadding, 0,0,1,1, {1,1,1,0.025*glossMult},{1,1,1,0})
		glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
	end)
	updateValues()
end


function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('unittotals')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	WG['unittotals'] = nil
end

local guishaderEnabled = (WG['guishader'])

local passedTime = 0
local passedTime2 = 0
local uiOpacitySec = 0.5
function widget:Update(dt)

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize()
		end
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) or guishaderEnabled ~= (WG['guishader']) then
			guishaderEnabled = (WG['guishader'])
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			glossMult = 1 + (2-(ui_opacity*2))
			createList()
		end
	end
	passedTime = passedTime + dt
	passedTime2 = passedTime2 + dt
	if passedTime > 0.1 then
		passedTime = passedTime - 0.1
		updatePosition()
	end
	if passedTime2 > 1 then
		updateValues()
		passedTime2 = passedTime2 - 1
	end
end


function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		if WG['music'] and WG['music'].GetPosition and WG['music'].GetPosition() then
            advplayerlistPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
		left = advplayerlistPos[2]
		bottom = advplayerlistPos[1]
		right = advplayerlistPos[4]
		top = math.ceil(advplayerlistPos[1]+(widgetHeight*advplayerlistPos[5]))
		widgetScale = advplayerlistPos[5]
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList()
		end
	end
end

function widget:ViewResize()
	local prevVsx, prevVsy = vsx, vsy
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()

	local widgetSpaceMargin = math.floor(0.0045 * vsy * ui_scale) / vsy
	bgpadding = math.ceil(widgetSpaceMargin * 0.66 * vsy)
	bgtexSize = bgpadding * bgtexScale
	if prevVsy ~= vsx or prevVsy ~= vsy then
		createList()
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end

	hovering = false
	if drawlist[1] ~= nil then
		local mx, my, mb = Spring.GetMouseState()
		if isInBox(mx, my, {left, bottom, right, top}) then
			Spring.SetMouseCursor('cursornormal')
			hovering = true
		end
		glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
		glPopMatrix()
	end
end

function widget:MousePress(mx, my, mb)
	if hovering then
		return true
	end
end
