local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "AdvPlayersList Game Info",
		desc	= "Displays current gametime, fps and gamespeed",
		author	= "Floris",
		date	= "april 2017",
		license	= "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true,
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 0) == 1		-- much faster than drawing via DisplayLists only

local timeNotation = 24

local font

local widgetScale = 1
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	   = gl.PopMatrix
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0

local passedTime = 0
local usedTextWidth = 0
local textWidthClock = 0
local gameframe = Spring.GetGameFrame()

local vsx, vsy = Spring.GetViewGeometry()

local RectRound, UiElement, elementCorner


local function drawBackground()
	UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1, nil, nil, nil, nil, useRenderToTexture)
end

local function drawContent()
	local textsize = 11*widgetScale
	local textXPadding = 10*widgetScale

	local fps = Spring.GetFPS()
	local titleColor = '\255\200\200\200'
	local valueColor = '\255\245\245\245'
	local prevGameframe = gameframe
	gameframe = Spring.GetGameFrame()
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
	--local _,gamespeed,_ = Spring.GetGameSpeed()
	--gamespeed = string.format("%.2f", gamespeed)
	local gamespeed = string.format("%.2f", (gameframe-prevGameframe) / 30)
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
end

local function refreshUiDrawing()
	if WG['guishader'] then
		if guishaderList then
			guishaderList = glDeleteList(guishaderList)
		end
		guishaderList = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner, 1,0,0,1)
		end)
		WG['guishader'].InsertDlist(guishaderList, 'displayinfo', true)
	end

	if useRenderToTexture then
		if right-left >= 1 and top-bottom >= 1 then
			if not uiBgTex then
				uiBgTex = gl.CreateTexture(math.floor(right-left), math.floor(top-bottom), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
				gl.RenderToTexture(uiBgTex, function()
					gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
					gl.PushMatrix()
					gl.Translate(-1, -1, 0)
					gl.Scale(2 / (right-left), 2 / (top-bottom), 0)
					gl.Translate(-left, -bottom, 0)
					drawBackground()
					gl.PopMatrix()
				end)
			end
			if not uiTex then
				uiTex = gl.CreateTexture(math.floor(right-left), math.floor(top-bottom), {
					target = GL.TEXTURE_2D,
					format = GL.RGBA,
					fbo = true,
				})
			end
			gl.RenderToTexture(uiTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (right-left), 2 / (top-bottom), 0)
				gl.Translate(-left, -bottom, 0)
				drawContent()
				gl.PopMatrix()
			end)
		end
	else
		if drawlist[1] ~= nil then
			glDeleteList(drawlist[1])
		end
		drawlist[1] = glCreateList( function()
			drawBackground()
		end)
		if drawlist[2] ~= nil then
			glDeleteList(drawlist[2])
		end
		drawlist[2] = glCreateList( function()
			drawContent()
		end)
	end
end


local function updatePosition(force)
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
			widget:ViewResize()
		end
	end
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


function widget:Shutdown()
	if WG['guishader'] then
		WG['guishader'].RemoveDlist('displayinfo')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	if guishaderList then glDeleteList(guishaderList) end
	if uiTex then
		gl.DeleteTextureFBO(uiBgTex)
		uiBgTex = nil
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
	Spring.SendCommands("fps 1")
	Spring.SendCommands("clock 1")
	Spring.SendCommands("speed 1")
	WG['displayinfo'] = nil
end

function widget:Update(dt)
	updatePosition()
	passedTime = passedTime + dt
	if passedTime > 1 then
		updateDrawing = true
		passedTime = passedTime - 1
	end
end

function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(nil, 1.1 * (useRenderToTexture and 1.2 or 1), 0.35 * (useRenderToTexture and 1.2 or 1), 1.25)

	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	updateDrawing = true
	if uiTex then
		gl.DeleteTextureFBO(uiBgTex)
		uiBgTex = nil
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
end

function widget:DrawScreen()

	if updateDrawing then
		updateDrawing = false
		refreshUiDrawing()
	end

	if useRenderToTexture then
		if uiBgTex then
			-- background element
			gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
			gl.Texture(uiBgTex)
			gl.TexRect(left, bottom, right, top, false, true)
			gl.Texture(false)
		end
		if uiTex then
			-- content
			gl.Color(1,1,1,1)
			gl.Texture(uiTex)
			gl.TexRect(left, bottom, right, top, false, true)
			gl.Texture(false)
		end
	else
		if drawlist[1] then
			glPushMatrix()
			glCallList(drawlist[1])
			glCallList(drawlist[2])
			glPopMatrix()
		end
	end
end
