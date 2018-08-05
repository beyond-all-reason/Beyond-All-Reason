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
		name	= "AdvPlayersList lockcamera",
		desc	= "Displays current tracked player",
		author	= "Floris",
		date	= "july 2017",
		license	= "GNU GPL, v2 or later",
		layer	= -2,
		enabled	= true,	--	loaded by default?
		handler = true,
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local vsx, vsy   = widgetHandler:GetViewSizes()

local bgcorner				= ":n:LuaUI/Images/bgcorner.png"

local widgetScale = 1
local glText         = gl.Text
local glGetTextWidth = gl.GetTextWidth
local glBlending     = gl.Blending
local glScale        = gl.Scale
local glRotate       = gl.Rotate
local glTranslate	   = gl.Translate
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glColor        = gl.Color
local glRect         = gl.Rect
local glTexRect	     = gl.TexRect
local glTexture      = gl.Texture
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local drawlist = {}
local parentPos = {}
local widgetHeight = 23
local top, left, bottom, right = 0,0,0,0

local shown = false
local mouseover = false
local volume

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	updatePosition()
	WG['lockcamerainfo'] = {}
	WG['lockcamerainfo'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
	Spring.SendCommands("fps 0")
	Spring.SendCommands("clock 0")
	Spring.SendCommands("speed 0")
end


local function DrawRectRound(px,py,sx,sy,cs)
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
	local o = offset

	-- top left
	if py <= 0 or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, py+cs, 0)
	-- top right
	if py <= 0 or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, py, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, py, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, py+cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, py+cs, 0)
	-- bottom left
	if sy >= vsy or px <= 0 then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(px, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(px+cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(px+cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(px, sy-cs, 0)
	-- bottom right
	if sy >= vsy or sx >= vsx then o = 0.5 else o = offset end
	gl.TexCoord(o,o)
	gl.Vertex(sx, sy, 0)
	gl.TexCoord(o,1-o)
	gl.Vertex(sx-cs, sy, 0)
	gl.TexCoord(1-o,1-o)
	gl.Vertex(sx-cs, sy-cs, 0)
	gl.TexCoord(1-o,o)
	gl.Vertex(sx, sy-cs, 0)
end

function RectRound(px,py,sx,sy,cs)
	local px,py,sx,sy,cs = math.floor(px),math.floor(py),math.ceil(sx),math.ceil(sy),math.floor(cs)

	gl.Texture(bgcorner)
	gl.BeginEnd(GL.QUADS, DrawRectRound, px,py,sx,sy,cs)
	gl.Texture(false)
end

function colourNames(teamID)
	nameColourR,nameColourG,nameColourB,nameColourA = Spring.GetTeamColor(teamID)
	R255 = math.floor(nameColourR*255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
	G255 = math.floor(nameColourG*255)
	B255 = math.floor(nameColourB*255)
	if ( R255%10 == 0) then
		R255 = R255+1
	end
	if( G255%10 == 0) then
		G255 = G255+1
	end
	if ( B255%10 == 0) then
		B255 = B255+1
	end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end

local function createList()
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	if (WG['guishader_api'] ~= nil) then
		--WG['guishader_api'].InsertRect(left, bottom, right, top, 'lockcamerainfo')
	end
	drawlist[1] = glCreateList( function()
		--glColor(0, 0, 0, 0.66)
		--RectRound(left, bottom, right, top, 5.5*widgetScale)
		--
		--local borderPadding = 2.75*widgetScale
		--glColor(1,1,1,0.025)
		--RectRound(left+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)
		local text = '   cancel   '
		local fontSize = (widgetHeight*widgetScale) * 0.5
		local textWidth = gl.GetTextWidth(text) * fontSize
		glColor(0.66, 0, 0, 0.66)
		RectRound(right-textWidth, bottom, right, top, 5.5*widgetScale)
		cancelButton = {right-textWidth, bottom, right, top }

		local borderPadding = 2.75*widgetScale
		glColor(0,0,0,0.18)
		RectRound(right-textWidth+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)

		glText('\255\255\222\222'..text, right-(textWidth/2), bottom+(8*widgetScale), fontSize, 'oc')

		if lockPlayerID ~= nil then
			local name,_,_,teamID,_,_,_,_,_ = Spring.GetPlayerInfo(lockPlayerID)
			name = name..'  '
			local fontSize = (widgetHeight*widgetScale) * 0.66
			local nameWidth = gl.GetTextWidth(name) * fontSize
			local nameColourR,nameColourG,nameColourB,_ = Spring.GetTeamColor(teamID)
			--glText('\255\222\222\222viewing   ', right-textWidth-nameWidth, bottom+(7.5*widgetScale), fontSize*0.7, 'or')
			if (nameColourR + nameColourG*1.2 + nameColourB*0.4) < 0.8 then
				glText(colourNames(teamID)..name, right-textWidth, bottom+(8*widgetScale), fontSize, 'or')
			else
				glColor(0,0,0,0.6)
				glText(name, right-textWidth-(0.7*widgetScale), bottom+(7*widgetScale), fontSize, 'rn')
				glText(name, right-textWidth+(0.7*widgetScale), bottom+(7*widgetScale), fontSize, 'rn')
				glColor(nameColourR,nameColourG,nameColourB,1)
				glText(name, right-textWidth, bottom+(8*widgetScale), fontSize, 'rn')
			end
		end
	end)
	drawlist[2] = glCreateList( function()
		glColor(1, 0.2, 0.2, 0.4)
		RectRound(cancelButton[1], cancelButton[2], cancelButton[3], cancelButton[4], 5.5*widgetScale)

		local borderPadding = 2.75*widgetScale
		glColor(0,0,0,0.14)
		RectRound(cancelButton[1]+borderPadding, cancelButton[2]+borderPadding, cancelButton[3]-borderPadding, cancelButton[4]-borderPadding, 4.4*widgetScale)

		local text = '   cancel   '
		local fontSize = (widgetHeight*widgetScale) * 0.5
		local textWidth = gl.GetTextWidth(text) * fontSize
		glText('\255\255\222\222'..text, cancelButton[3]-(textWidth/2), cancelButton[2]+(8*widgetScale), fontSize, 'oc')
	end)
end


function widget:Shutdown()
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('lockcamerainfo')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
end

local passedTime = 0
function widget:Update(dt)
	passedTime = passedTime + dt
	if passedTime > 0.1 then
		passedTime = passedTime - 0.1
		updatePosition()
		if WG['advplayerlist_api'] and WG['advplayerlist_api'].GetLockPlayerID ~= nil then
			lockPlayerID = WG['advplayerlist_api'].GetLockPlayerID()
			if lockPlayerID ~= prevLockPlayerID then
				createList()
			end
			prevLockPlayerID = lockPlayerID
		end
	end
end


function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = parentPos
		if WG['displayinfo'] ~= nil then
			if widgetHandler.orderList["AdvPlayersList info"] ~= nil and (widgetHandler.orderList["AdvPlayersList info"] > 0) then
				parentPos = WG['displayinfo'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
			end
		elseif WG['music'] ~= nil then
			if widgetHandler.orderList["Music Player"] ~= nil and (widgetHandler.orderList["Music Player"] > 0) then
				parentPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
			end
		else
			parentPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end

		parentPos = WG['displayinfo'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}

		left = parentPos[2]
		bottom = parentPos[1]
		right = parentPos[4]
		top = parentPos[1]+(widgetHeight*parentPos[5])
		widgetScale = parentPos[5]

		if (prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5]) or force then
			createList()
		end
	end
end

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:MousePress(mx, my, mb)
	if mb == 1 and cancelButton ~= nil and lockPlayerID ~= nil and isInBox(mx, my, cancelButton) then
		lockPlayerID = WG['advplayerlist_api'].SetLockPlayerID()
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
end


function widget:DrawScreen()
	if lockPlayerID ~= nil and drawlist[1] ~= nil then
		glPushMatrix()
		glCallList(drawlist[1])
		glPopMatrix()
		mx,my,mb = Spring.GetMouseState()
		if cancelButton ~= nil and lockPlayerID ~= nil and isInBox(mx, my, cancelButton) then
			glCallList(drawlist[2])
		end
	end
end
