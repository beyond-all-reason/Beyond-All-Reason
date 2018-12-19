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
		name	= "Music Player",
		desc	= "Plays music and offers volume controls",
		author	= "Forboding Angel, Floris, Damgam",
		date	= "november 2016",
		license	= "GNU GPL, v2 or later",
		layer	= -4,
		enabled	= true	--	loaded by default?
	}
end

local pauseWhenPaused = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume
-- This widget desperately needs to be reorganized

local buttons = {}

local previousTrack = ''
local curTrack	= "no name"

local peaceTracks = VFS.DirList('luaui/Widgets_BA/music/peace', '*.ogg')
local warTracks = VFS.DirList('luaui/Widgets_BA/music/war', '*.ogg')

local tracks = peaceTracks

local charactersInPath = 25

local ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)

local firstTime = false
local wasPaused = false
local firstFade = true
local gameOver = false
local playing = true

local vsx, vsy   = widgetHandler:GetViewSizes()

local playTex				= ":n:"..LUAUI_DIRNAME.."Images/music/play.png"
local pauseTex				= ":n:"..LUAUI_DIRNAME.."Images/music/pause.png"
local nextTex				= ":n:"..LUAUI_DIRNAME.."Images/music/next.png"
local musicTex				= ":n:"..LUAUI_DIRNAME.."Images/music/music.png"
local volumeTex				= ":n:"..LUAUI_DIRNAME.."Images/music/volume.png"
local buttonTex				= ":n:"..LUAUI_DIRNAME.."Images/button.dds"
local buttonHighlightTex				= ":n:"..LUAUI_DIRNAME.."Images/button-highlight.dds"
local bgcorner				= ":n:"..LUAUI_DIRNAME.."Images/bgcorner.png"

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

local dynamicMusic = Spring.GetConfigInt("ba_dynamicmusic", 1)
local interruptMusic = Spring.GetConfigInt("ba_interruptmusic", 1)
local warMeter = 0
local fadelvl = Spring.GetConfigInt("snd_volmusic", 20) * 0.01
local fadeOut = false

--Assume that if it isn't set, dynamic music is true
if dynamicMusic == nil then
	dynamicMusic = 1
end

--Assume that if it isn't set, interrupt music is true
if interruptMusic == nil then
	interruptMusic = 1
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	
	volume = Spring.GetConfigInt("snd_volmaster", 100)
	
	musicInitialValue = Spring.GetConfigInt("ba_musicInitialValue", 0)
	if musicInitialValue ~= 1 then
		Spring.SetConfigInt("snd_volmusic", 20)
		Spring.SetConfigInt("ba_musicInitialValue", 1)
	end
	
	music_volume = Spring.GetConfigInt("snd_volmusic", 20)
	
	if #tracks == 0 then 
		Spring.Echo("[Music Player] No music was found, Shutting Down")
		widgetHandler:RemoveWidget()
	end
	
	updatePosition()
	
	WG['music'] = {}
	WG['music'].GetPosition = function()
		if shutdown then
			return false
		end
		updatePosition(force)
		return {top,left,bottom,right,widgetScale}
	end
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

local function createList()
	
	local padding = 3*widgetScale -- button background margin
	local padding2 = 2.5*widgetScale -- inner icon padding
	local volumeWidth = 50*widgetScale
	
	buttons['playpause'] = {left+padding, bottom+padding, left+(widgetHeight*widgetScale)-padding, top-padding}
	
	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding}
	
	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding, buttons['next'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (music_volume/200)
	
	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding, buttons['musicvolume'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding, buttons['volumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (volume/200)
	
	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 7*widgetScale
	local maxTextWidth = right-buttons['next'][3]-textXPadding-textXPadding
		
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
		glDeleteList(drawlist[2])
		glDeleteList(drawlist[3])
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(left, bottom, right, top,'music')
	end
	drawlist[1] = glCreateList( function()
		glColor(0, 0, 0, ui_opacity)
		RectRound(left, bottom, right, top, 5.5*widgetScale)
		
		local borderPadding = 2.75*widgetScale
		glColor(1,1,1,ui_opacity*0.04)
		RectRound(left+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)
		
	end)
	drawlist[2] = glCreateList( function()
	
		local button = 'playpause'
		glColor(1,1,1,0.7)
		glTexture(buttonTex)
		glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
		glColor(1,1,1,0.4)
		if playing then
			glTexture(pauseTex)
		else
			glTexture(playTex)
		end
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'next'
		glColor(1,1,1,0.7)
		glTexture(buttonTex)
		glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
		glColor(1,1,1,0.4)
		glTexture(nextTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
	end)
	drawlist[3] = glCreateList( function()
		
		-- track name
		glColor(0.45,0.45,0.45,1)
		local trackname = string.gsub(curTrack, ".ogg", "")
		local text = ''
		for i=charactersInPath, #trackname do
	    local c = string.sub(trackname, i,i)
			local width = glGetTextWidth(text..c)*textsize
	    if width > maxTextWidth then
	    	break
	    else
	    	text = text..c
	    end
		end
		glText('\255\135\135\135'..text, buttons['next'][3]+textXPadding, bottom+textYPadding, textsize, 'no')
		
	end)
	drawlist[4] = glCreateList( function()
		
		---glColor(0,0,0,0.5)
		--RectRound(left, bottom, right, top, 5.5*widgetScale)

		local sliderWidth = 3.3*widgetScale
		local sliderHeight = 3.3*widgetScale
		local lineHeight = 0.8*widgetScale
		local lineOutlineSize = 0.85*widgetScale
		
		button = 'musicvolumeicon'
		local sliderY = buttons[button][2] + (buttons[button][4] - buttons[button][2])/2
		glColor(0.66,0.66,0.66,1)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'musicvolume'
		glColor(0,0,0,0.12)
		RectRound(buttons[button][1]-lineOutlineSize, sliderY-lineHeight-lineOutlineSize, buttons[button][3]+lineOutlineSize, sliderY+lineHeight+lineOutlineSize, (lineHeight/2.2)*widgetScale)
		glColor(0.45,0.45,0.45,1)
		RectRound(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight, (lineHeight/2.2)*widgetScale)
		glColor(0,0,0,0.12)
		RectRound(buttons[button][5]-sliderWidth-lineOutlineSize, sliderY-sliderHeight-lineOutlineSize, buttons[button][5]+sliderWidth+lineOutlineSize, sliderY+sliderHeight+lineOutlineSize, (sliderWidth/4)*widgetScale)
		glColor(0.66,0.66,0.66,1)
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/4)*widgetScale)


		button = 'volumeicon'
		glColor(0.66,0.66,0.66,1)
		glTexture(volumeTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		
		button = 'volume'
		glColor(0,0,0,0.12)
		RectRound(buttons[button][1]-lineOutlineSize, sliderY-lineHeight-lineOutlineSize, buttons[button][3]+lineOutlineSize, sliderY+lineHeight+lineOutlineSize, (lineHeight/2.2)*widgetScale)
		glColor(0.45,0.45,0.45,1)
		RectRound(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight, (lineHeight/2.2)*widgetScale)
		glColor(0,0,0,0.12)
		RectRound(buttons[button][5]-sliderWidth-lineOutlineSize, sliderY-sliderHeight-lineOutlineSize, buttons[button][5]+sliderWidth+lineOutlineSize, sliderY+sliderHeight+lineOutlineSize, (sliderWidth/4)*widgetScale)
		glColor(0.66,0.66,0.66,1)
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/4)*widgetScale)
		
	end)
end

function getSliderValue(draggingSlider, x)
	local sliderWidth = buttons[draggingSlider][3] - buttons[draggingSlider][1]
	local value = (x - buttons[draggingSlider][1]) / (sliderWidth)
	if value < 0 then value = 0 end
	if value > 1 then value = 1 end
	return value
end

function isInBox(mx, my, box)
  return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end


function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		if draggingSlider == 'musicvolume' then
			changeMusicVolume(getSliderValue('musicvolume', x) * 200)
		end
		if draggingSlider == 'volume' then
			changeVolume(getSliderValue('volume', x) * 200)
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function changeMusicVolume(value)
	music_volume = value
	Spring.SetConfigInt("snd_volmusic", music_volume)
  createList()
end

function changeVolume(value)
	volume = value
	Spring.SetConfigInt("snd_volmaster", volume)
  createList()
end

function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then return false end

	if not release then
		local sliderWidth = (3.3*widgetScale) -- should be same as in createlist()
		local button = 'musicvolume'
		if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
			draggingSlider = button
			changeMusicVolume(getSliderValue(button, x) * 200)
		end
		button = 'volume'
		if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
			draggingSlider = button
			changeVolume(getSliderValue(button, x) * 200)
		end
	end
	if release and draggingSlider ~= nil then
		draggingSlider = nil
	end
	if button == 1 and not release and isInBox(x, y, {left, bottom, right, top}) then
		if button == 1 and buttons['playpause'] ~= nil and isInBox(x, y, {buttons['playpause'][1], buttons['playpause'][2], buttons['playpause'][3], buttons['playpause'][4]}) then
			playing = not playing
			Spring.PauseSoundStream()
			createList()
			return true
		end
		if button == 1 and buttons['next'] ~= nil and isInBox(x, y, {buttons['next'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
			fadeOut = true
			PlayNewTrack()
			return true
		end
		return true
	end
	
end
function widget:IsAbove(mx, my)
	if isInBox(mx, my, {left, bottom, right, top}) then
  	local curVolume = Spring.GetConfigInt("snd_volmaster", 200)
  	if volume ~= curVolume then
  		volume = curVolume
  		createList()
  	end
		mouseover = true
	end
	return mouseover
end

function widget:GetTooltip(mx, my)
	if widget:IsAbove(mx,my) then
		return string.format("Music info and controls")
	end
end

function widget:Shutdown()
	shutdown = true
	Spring.StopSoundStream()
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('music')
	end
	
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	WG['music'] = nil
end

function widget:UnitDamaged(_, _, _, damage)
	warMeter = warMeter + damage
end

function widget:GameFrame(n)    
    if n%5 == 4 then
		--This is a little messy, but we need to be able to update these values on the fly so I see no better way
		music_volume = Spring.GetConfigInt("snd_volmusic", 20)
		
		dynamicMusic = Spring.GetConfigInt("ba_dynamicmusic", 1)
		interruptMusic = Spring.GetConfigInt("ba_interruptmusic", 1)
		
		--Assume that if it isn't set, dynamic music is true
		if dynamicMusic == nil then
			dynamicMusic = 1
		end

		--Assume that if it isn't set, interrupt music is true
		if interruptMusic == nil then
			interruptMusic = 1
		end
		
		if dynamicMusic == 1 then
			--Spring.Echo("[Music Player] Unit Death Count is currently: ".. warMeter)
			if warMeter <= 1 then
				warMeter = 0
			elseif warMeter >= 3000 then
				warMeter = warMeter - 500
			elseif warMeter >= 1000 then
				warMeter = warMeter - 100
			elseif warMeter >= 0 then
				warMeter = warMeter - 3
			end
			if interruptMusic == 1 then
				if tracks == peaceTracks and warMeter >= 200 then
					fadeOut = true
				elseif tracks == warTracks and warMeter <= 0 then
					fadeOut = true
				end
			end
		end
		
		--80's fadeout when a track is almost finished
		
		local playedTime, totalTime = Spring.GetSoundStreamTime()
		playedTime = math.floor(playedTime)
		totalTime = math.floor(totalTime)
			
		if totalTime ~= nil then
			--Spring.Echo("Total time is :" .. totalTime)
			if playedTime > totalTime - music_volume * 0.10 then
				--Spring.Echo("Fading out now!")
				fadeOut = true
			end
		end

		if fadeOut == true and fadelvl >= 0.01 then
			fadelvl = fadelvl - 0.02
			Spring.SetSoundStreamVolume(fadelvl)
		else
			fadeOut = false
		end
		if fadeOut == false and fadelvl <= 0.005 then
			fadelvl = music_volume * 0.01
			PlayNewTrack()
			--Spring.Echo("Playing a new song now")
		end
		
		if fadeIn == true and fadelvl <= music_volume and Spring.GetGameFrame() >= 1 then
			fadelvl = fadelvl + 0.02
			Spring.SetSoundStreamVolume(fadelvl)
		else
			fadeIn = false
		end
   end
end

function PlayNewTrack()
	Spring.StopSoundStream()
	fadelvl = 0
	fadeIn = true
	--Spring.Echo(dynamicMusic)
	
	if dynamicMusic == 0 then
		--Spring.Echo("Choosing a random track")
		r = math.random(0,1)
		if r == 0 then
			tracks = peaceTracks
		else
			tracks = warTracks
		end
	end
	
	if dynamicMusic == 1 then
		--Spring.Echo("Unit Death Count is (Gameframe): " .. warMeter)
		if warMeter <= 3 then
			tracks = peaceTracks
			--Spring.Echo("Current tracklist is : Peace Tracks")
		else
			tracks = warTracks
			--Spring.Echo("Current tracklist is : War Tracks")
		end
	end
	local newTrack = previousTrack
	repeat
		newTrack = tracks[math.random(1, #tracks)]
	until newTrack ~= previousTrack
	firstFade = false
	previousTrack = newTrack
	curTrack = newTrack
	local musicVolScaled = music_volume * 0.01	
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(musicVolScaled or 0.33)
	if playing == false then
		Spring.PauseSoundStream()
	end	
	createList()
end

local uiOpacitySec = 0
function widget:Update(dt)
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec>0.5 then
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
		end
		createList()
	end

	if gameOver then
		return
	end
	
	if (not firstTime) then
		PlayNewTrack()
		firstTime = true -- pop this cherry
	end
	
	local playedTime, totalTime = Spring.GetSoundStreamTime()
	playedTime = math.floor(playedTime)
	totalTime = math.floor(totalTime)
	
	if playedTime >= totalTime then	-- both zero means track stopped in 8
		PlayNewTrack()
	end
	
	if (pauseWhenPaused and Spring.GetGameSeconds()>=0) then
    local _, _, paused = Spring.GetGameSpeed()
		if (paused ~= wasPaused) then
			Spring.PauseSoundStream()
			wasPaused = paused
		end
	end
end

function updatePosition(force)
	if (WG['advplayerlist_api'] ~= nil) then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}
		
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
		  local mx, my, mlb = Spring.GetMouseState()
			if not mouseover and not draggingSlider or isInBox(mx, my, {buttons['playpause'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
				glCallList(drawlist[3])
			else
				glCallList(drawlist[4])
			end
			if mouseover then
			  local color = {1,1,1,0.25}
			  local colorHighlight = {1,1,1,0.33}
			  local button = 'playpause'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					if mlb then
						glColor(colorHighlight)
					else
						glColor(color)
					end
					glTexture(buttonHighlightTex)
					glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
				end
				button = 'next'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					if mlb then
						glColor(colorHighlight)
					else
						glColor(color)
					end
					glTexture(buttonHighlightTex)
					glTexRect(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4])
				end
			end
		glPopMatrix()
		mouseover = false
	end
end

function widget:GetConfigData(data)
	--local playedTime, totalTime = Spring.GetSoundStreamTime()
  local savedTable = {}
  --savedTable.curTrack	= curTrack
  --savedTable.playedTime = playedTime
  savedTable.playing = playing
  return savedTable
end

-- would be great if there is be a way to continue track where we left off after a /luaui reload
function widget:SetConfigData(data)
	if data.playing ~= nil then
		playing = data.playing
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------