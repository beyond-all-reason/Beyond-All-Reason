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
		layer	= -4,
		enabled	= true,	--	loaded by default?
 	  handler = true, 
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume
-- This widget desperately needs to be reorganized


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
local advplayerlistPos = {}
local widgetHeight = 23
local top, left, bottom, right = 0,0,0,0

local shown = false
local mouseover = false
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
		
		glColor(0.45,0.45,0.45,1)
		glText(titleColor..'time  '..valueColor..time..titleColor..'      speed  '..valueColor..gamespeed..titleColor..'      fps  '..valueColor..fps, left+textXPadding, bottom+textYPadding, textsize, 'no')
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
		glColor(0, 0, 0, 0.66)
		RectRound(left, bottom, right, top, 5.5*widgetScale)
		
		local borderPadding = 2.75*widgetScale
		glColor(1,1,1,0.025)
		RectRound(left+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)
		
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
	Spring.SendCommands("fps 1")
	Spring.SendCommands("clock 1")
	Spring.SendCommands("speed 1")
	WG['displayinfo'] = nil
end

local passedTime = 0
function widget:Update(dt)
	passedTime = passedTime + dt
	if passedTime > 1 then
		updateValues()
		passedTime = passedTime - 1
	end
end


function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		
		if WG['music'] ~= nil then
			if widgetHandler.orderList["Music Player"] ~= nil and (widgetHandler.orderList["Music Player"] > 0) then
				advplayerlistPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
			end
		end
		
		left = advplayerlistPos[2]
		bottom = advplayerlistPos[1]
		right = advplayerlistPos[4]
		top = advplayerlistPos[1]+(widgetHeight*advplayerlistPos[5])
		widgetScale = advplayerlistPos[5]
		
		if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
			createList()
		end
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = newX, newY
end

function widget:DrawScreen()
	updatePosition()
	if drawlist[1] ~= nil then
		glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
		glPopMatrix()
	end
end
