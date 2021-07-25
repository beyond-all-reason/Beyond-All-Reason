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
		name	= "AdvPlayersList Game Info",
		desc	= "Displays current gametime, fps and gamespeed",
		author	= "Floris",
		date	= "april 2017",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true,	--	loaded by default?
	}
end

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local font, chobbyInterface, hovering

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glColor        = gl.Color
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

local guishaderEnabled = (WG['guishader'] ~= nil)

local passedTime = 0
local passedTime2 = 0
local uiOpacitySec = 0.5

local vsx, vsy = Spring.GetViewGeometry()

local RectRound, UiElement, elementCorner

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:Initialize()
	widget:ViewResize()
	updatePosition()
	WG['displayinfo'] = {}
	WG['displayinfo'].GetPosition = function()
		return {top,left,bottom,right,widgetScale}
	end
	Spring.SendCommands("fps 0")
	Spring.SendCommands("clock 0")
	Spring.SendCommands("speed 0")
end

local function updateValues()

	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 10*widgetScale

	if drawlist[2] ~= nil then
		glDeleteList(drawlist[2])
	end
	drawlist[2] = glCreateList( function()
		local _,gamespeed,_ = Spring.GetGameSpeed()
		gamespeed = string.format("%.2f", gamespeed)
		local fps = Spring.GetFPS()
		local titleColor = '\255\200\200\200'
		local valueColor = '\255\245\245\245'
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
		font:Print(valueColor..time, left+textXPadding, bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		local extraSpacing = 0
		if minutes > 99 then
			extraSpacing = 1.34
		elseif minutes > 9 then
			extraSpacing = 0.7
		end

		font:Print(titleColor..' x'..valueColor..gamespeed..titleColor..'      fps '..valueColor..fps, left+textXPadding+(textsize*(3.2+extraSpacing)), bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		font:End()
    end)
end

local function createList()
	if drawlist[3] ~= nil then
		glDeleteList(drawlist[3])
	end
	if WG['guishader'] then
		drawlist[3] = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner)
		end)
		WG['guishader'].InsertDlist(drawlist[3], 'displayinfo')
	end
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	drawlist[1] = glCreateList( function()
		UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1)
	end)
	updateValues()
end


function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('displayinfo')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	Spring.SendCommands("fps 1")
	Spring.SendCommands("clock 1")
	Spring.SendCommands("speed 1")
	WG['displayinfo'] = nil
end

function widget:Update(dt)

	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize()
		end
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) or guishaderEnabled ~= (WG['guishader'] ~= nil) then
			guishaderEnabled = (WG['guishader'] ~= nil)
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
end


function updatePosition(force)
	if WG['advplayerlist_api'] ~= nil then
		local prevPos = advplayerlistPos
		if WG['unittotals'] ~= nil then
			advplayerlistPos = WG['unittotals'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		elseif WG['music'] ~= nil then
			advplayerlistPos = WG['music'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		else
			advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		end
		if advplayerlistPos[5] ~= nil then
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
end

function widget:ViewResize(newX,newY)
	local prevVsx, prevVsy = vsx, vsy
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(fontfile)

	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	if prevVsy ~= vsx or prevVsy ~= vsy then
		updateValues()
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
