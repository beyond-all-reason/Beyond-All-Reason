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
		name	= "AdvPlayersList info",
		desc	= "Displays current gametime, fps and gamespeed",
		author	= "Floris",
		date	= "april 2017",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true,	--	loaded by default?
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local fontfile = LUAUI_DIRNAME .. "fonts/" .. Spring.GetConfigString("ui_font", "FreeSansBold.otf")
local vsx,vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx*vsy / 5700000))
local fontfileSize = 25
local fontfileOutlineSize = 8.5
local fontfileOutlineStrength = 1.5
local font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local bgcorner				= ":n:LuaUI/Images/bgcorner.png"

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glColor        = gl.Color
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 23
local top, left, bottom, right = 0,0,0,0

local volume

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	updatePosition()
	WG['displayinfo'] = {}
	WG['displayinfo'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
	Spring.SendCommands("fps 0")
	Spring.SendCommands("clock 0")
	Spring.SendCommands("speed 0")
end


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

local function updateValues()
	
	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 7*widgetScale
		
	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		local _,gamespeed,_ = Spring.GetGameSpeed()
		gamespeed = string.format("%.2f", gamespeed)
		local fps = Spring.GetFPS()
		local titleColor = '\255\155\155\155'
		local valueColor = '\255\200\200\200'
		local gameframe = Spring.GetGameFrame()
		local minutes = math.floor((gameframe / 30 / 60))
		local seconds = math.floor((gameframe - ((minutes*60)*30)) / 30)
		if seconds == 0 then
			seconds = '00'
		elseif seconds < 10 then
			seconds = '0'..seconds
		end
		local time = minutes..':'..seconds

        font:Begin()
		font:Print(titleColor..'time  '..valueColor..time..titleColor..'      speed  '..valueColor..gamespeed..titleColor..'      fps  '..valueColor..fps, left+textXPadding, bottom+textYPadding, textsize, 'no')
        font:End()
    end)
end

local function createList()
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(left, bottom, right, top, 'displayinfo')
	end
	drawlist[1] = glCreateList( function()
		glColor(0, 0, 0, ui_opacity)
		RectRound(left, bottom, right, top, 5.5*widgetScale)
		
		local borderPadding = 3*widgetScale
		local borderPaddingRight = borderPadding
		if right >= vsx-0.2 then
			borderPaddingRight = 0
		end
		local borderPaddingLeft = borderPadding
		if left <= 0.2 then
			borderPaddingLeft = 0
		end
		glColor(1,1,1,ui_opacity*0.055)
		RectRound(left+borderPaddingLeft, bottom+borderPadding, right-borderPaddingRight, top-borderPadding, borderPadding*1.66)
		
	end)
	updateValues()
end


function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('displayinfo')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	gl.DeleteFont(font)
	Spring.SendCommands("fps 1")
	Spring.SendCommands("clock 1")
	Spring.SendCommands("speed 1")
	WG['displayinfo'] = nil
end

local guishaderEnabled = (WG['guishader_api'] ~= nil)

local passedTime = 0
local passedTime2 = 0
local uiOpacitySec = 0.5
function widget:Update(dt)

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
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
	if guishaderEnabled ~= (WG['guishader_api'] ~= nil) then
		guishaderEnabled = (WG['guishader_api'] ~= nil)
		createList()
	end
end


function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		
		if WG['music'] and WG['music'].GetPosition and WG['music'].GetPosition() then
            advplayerlistPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
        if widgetScale ~= advplayerlistPos[5] then
            local fontScale = widgetScale/2
            font = gl.LoadFont(fontfile, 52*fontScale, 17*fontScale, 1.5)
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

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
	local newFontfileScale = (0.5 + (vsx*vsy / 5700000))
	if (fontfileScale ~= newFontfileScale) then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize*fontfileScale, fontfileOutlineSize*fontfileScale, fontfileOutlineStrength)
	end
end

function widget:DrawScreen()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
		glPopMatrix()
	end
end
