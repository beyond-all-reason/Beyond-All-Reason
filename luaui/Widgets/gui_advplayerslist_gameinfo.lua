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

local timeNotation = 24

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font", "Poppins-Regular.otf")
local font, chobbyInterface, hovering

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local math_isInRect = math.isInRect

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

local passedTime = 0
local passedTime2 = 0
local usedTextWidth = 0
local textWidthClock = 0

local vsx, vsy = Spring.GetViewGeometry()

local RectRound, UiElement, elementCorner

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
		local text = titleColor..' x'..valueColor..gamespeed..titleColor..'     fps '..valueColor..fps
		font:Print(text, left+textXPadding+(textsize*(2.8+extraSpacing)), bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		local textWidth = font:GetTextWidth(text) * textsize
		if textWidth > usedTextWidth or textWidthClock+30 < os.clock() then
			usedTextWidth = textWidth
			textWidthClock = os.clock()
		end
		local clock = ''
		if timeNotation == 24 then
			clock = os.date("%H:%M")
		else
			clock = os.date("%I:%M %p")
		end
		font:Print(valueColor..clock, left+textXPadding+(textsize*(2.8+extraSpacing))+usedTextWidth+(textsize*1.3), bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')

		font:End()
    end)
end

local function createList()
	if drawlist[3] then
		drawlist[3] = glDeleteList(drawlist[3])
	end
	if WG['guishader'] then
		drawlist[3] = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner)
		end)
		WG['guishader'].InsertDlist(drawlist[3], 'displayinfo', true)
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
	local prevPos = advplayerlistPos
	if WG['unittotals'] ~= nil then
		advplayerlistPos = WG['unittotals'].GetPosition()
	elseif WG['music'] ~= nil then
		advplayerlistPos = WG['music'].GetPosition()
	elseif WG['advplayerlist_api'] then
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		advplayerlistPos = {0,vsx-(220*scale),0,vsx,scale}
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
		if math_isInRect(mx, my, left, bottom, right, top) then
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
