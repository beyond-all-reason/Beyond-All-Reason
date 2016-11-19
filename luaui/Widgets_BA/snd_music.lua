--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--	file:		gui_music.lua
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
		desc	= "Plays music based on situation",
		author	= "cake, trepan, Smoth, Licho, xponen, Forboding Angel, Floris",
		date	= "Mar 01, 2008, Aug 20 2009, Nov 23 2011",
		license	= "GNU GPL, v2 or later",
		layer	= -4,
		enabled	= true	--	loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume
music_volume = Spring.GetConfigInt("snd_volmusic") * 0.01
music_start_volume = music_volume

local unitExceptions = include("Configs/snd_music_exception.lua")

local windows = {}

local WAR_THRESHOLD = 5000000000000000
local PEACE_THRESHOLD = 1000000000000000

local musicType = 'peace'
local dethklok = {} -- keeps track of the number of doods killed in each time frame
local timeframetimer = 0
local previousTrack = ''
local previousTrackType = ''
local newTrackWait = 1000
local numVisibleEnemy = 0
local fadeVol
local curTrack	= "no name"
local songText	= "no name"

local warTracks		=	VFS.DirList('luaui/Widgets_BA/music/war/', '*.ogg')
local peaceTracks	=	VFS.DirList('luaui/Widgets_BA/music/peace/', '*.ogg')
local victoryTracks	=	VFS.DirList('luaui/Widgets_BA/music/victory/', '*.ogg')
local defeatTracks	=	VFS.DirList('luaui/Widgets_BA/music/defeat/', '*.ogg')

local charactersInPath = 30

local firstTime = false
local wasPaused = false
local firstFade = true
local initSeed = 0
local seedInitialized = false
local gameOver = false
local playing = true

local myTeam = Spring.GetMyTeamID()
local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()
local defeat = false

options_path = 'Settings/Interface/Pause Screen'

options = {
	pausemusic = {name='Pause Music', type='bool', value=false},
}

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

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
	
  volume = Spring.GetConfigInt("snd_volmaster", 100)
  
	-- Spring.Echo(math.random(), math.random())
	-- Spring.Echo(os.clock())

	-- for TrackName,TrackDef in pairs(peaceTracks) do
		-- Spring.Echo("Track: " .. TrackDef)
	-- end
	--math.randomseed(os.clock()* 101.01)--lurker wants you to burn in hell rgn
	-- for i=1,20 do Spring.Echo(math.random()) end

	if #peaceTracks == 0 and #warTracks == 0 and #victoryTracks == 0 and #defeatTracks == 0 then 
		Spring.Echo("[Music Player] No music was found, Shutting Down")
		widgetHandler:RemoveWidget()
	end
	
	for i = 1, 30, 1 do
		dethklok[i]=0
	end
	updatePosition()
	
	WG['music'] = {}
	WG['music'].GetPosition = function()
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

local buttons = {}
local function createList()
	
	local padding = 3*widgetScale -- button background margin
	local padding2 = 2.5*widgetScale -- inner icon padding
	local volumeWidth = 50*widgetScale
	
	buttons['playpause'] = {left+padding, bottom+padding, left+(widgetHeight*widgetScale)-padding, top-padding}
	
	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding}
	
	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding, buttons['next'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (music_volume/100)
	
	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding, buttons['musicvolume'][3]+((widgetHeight*widgetScale)), top-padding}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding, buttons['volumeicon'][3]+padding+volumeWidth, top-padding}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (volume/100)
	
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
		glColor(0, 0, 0, 0.6)
		RectRound(left, bottom, right, top, 5.5*widgetScale)
		
		local borderPadding = 2.75*widgetScale
		glColor(1,1,1,0.022)
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
			changeMusicVolume(getSliderValue('musicvolume', x) * 100)
			Spring.SetConfigInt("snd_volmusic", music_volume)
		end
		if draggingSlider == 'volume' then
			changeVolume(getSliderValue('volume', x) * 100)
			Spring.SetConfigInt("snd_volmaster", volume)
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
			changeMusicVolume(getSliderValue(button, x) * 100)
		end
		button = 'volume'
		if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
			draggingSlider = button
			changeVolume(getSliderValue(button, x) * 100)
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
			PlayNewTrack()
			return true
		end
		return true
	end
	
end
function widget:IsAbove(mx, my)
	if isInBox(mx, my, {left, bottom, right, top}) then
  	local curVolume = Spring.GetConfigInt("snd_volmaster", 100)
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
	Spring.StopSoundStream()
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('music')
	end

	for i=1,#windows do
		(windows[i]):Dispose()
	end
	
	glDeleteList(drawlist[1])
	glDeleteList(drawlist[2])
	glDeleteList(drawlist[3])
	glDeleteList(drawlist[4])
end

function PlayNewTrack()
	Spring.StopSoundStream()
	local newTrack = previousTrack
	repeat
		if musicType == 'peace' then
			newTrack = peaceTracks[math.random(1, #peaceTracks)]
		elseif musicType == 'war' then
			newTrack = warTracks[math.random(1, #warTracks)]
		end
	until newTrack ~= previousTrack
	-- for key, val in pairs(oggInfo) do
		-- Spring.Echo(key, val)
	-- end
	firstFade = false
	previousTrack = newTrack

	-- if (oggInfo.comments.TITLE and oggInfo.comments.TITLE) then
		-- Spring.Echo("Song changed to: " .. oggInfo.comments.TITLE .. " By: " .. oggInfo.comments.ARTIST)
	-- else
		-- Spring.Echo("Song changed but unable to get the artist and title info")
	-- end
	curTrack = newTrack
	music_volume = Spring.GetConfigInt("snd_volmusic") * 0.01
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(music_volume or 0.33)
	Spring.Echo([[[Music Player] Music Volume is set to: ]] .. music_volume .. [[
 
[Music Player] Press Shift and the +/- keys to adjust the music volume]])
	if playing == false then
		Spring.PauseSoundStream()
	end

	music_start_volume = music_volume
	
	createList()
end

function widget:Update(dt)
	if gameOver then
		return
	end
	if (Spring.GetGameSeconds()>=0) then
		if not seedInitialized then
			math.randomseed(os.clock()* 100)
			seedInitialized=true
		end
		timeframetimer = timeframetimer + dt
		if (timeframetimer > 1) then	-- every second
			timeframetimer = 0
			newTrackWait = newTrackWait + 1
			local PlayerTeam = Spring.GetMyTeamID()
			numVisibleEnemy = 0
			local doods = Spring.GetVisibleUnits()
			for _, u in ipairs(doods) do
				if (Spring.IsUnitAllied(u) ~= true) then
					numVisibleEnemy = numVisibleEnemy + 1
				end
			end

			totalKilled = 0
			for i = 1, 10, 1 do --calculate the first half of the table (1-15)
				totalKilled = totalKilled + (dethklok[i] * 2)
			end

			for i = 11, 20, 1 do -- calculate the second half of the table (16-45)
				totalKilled = totalKilled + dethklok[i]
			end

			for i = 20, 1, -1 do -- shift value(s) to the end of table
				dethklok[i+1] = dethklok[i]
			end
			dethklok[1] = 0 -- empty the first row

			--Spring.Echo (totalKilled)

			if (totalKilled > WAR_THRESHOLD) then
				musicType = 'war'
			end

			if (totalKilled <= PEACE_THRESHOLD) then
				musicType = 'peace'
			end

			if (not firstTime) then
				PlayNewTrack()
				firstTime = true -- pop this cherry
			end

			local playedTime, totalTime = Spring.GetSoundStreamTime()
			playedTime = math.floor(playedTime)
			totalTime = math.floor(totalTime)
			--Spring.Echo(playedTime, totalTime)

			--Spring.Echo(playedTime, totalTime, newTrackWait)

			--if((totalTime - playedTime) <= 6 and (totalTime >= 1) ) then
				--Spring.Echo("time left:", (totalTime - playedTime))
				--Spring.Echo("volume:", (totalTime - playedTime)/6)
				--if ((totalTime - playedTime)/6 >= 0) then
				--	Spring.SetSoundStreamVolume((totalTime - playedTime)/6)
				--else
				--	Spring.SetSoundStreamVolume(0.1)
				--end
			--elseif(playedTime <= 5 )then--and not firstFade
				--Spring.Echo("time playing:", playedTime)
				--Spring.Echo("volume:", playedTime/5)
				--Spring.SetSoundStreamVolume( playedTime/5)
			--end

			if ( (musicType ~= previousTrackType and musicType == 'war') or (playedTime >= totalTime)) then	-- both zero means track stopped in 8
				previousTrackType = musicType
				PlayNewTrack()

				--Spring.Echo("Track: " .. newTrack)
				newTrackWait = 0
			end
		end
    local _, _, paused = Spring.GetGameSpeed()
		if (paused ~= wasPaused) and options.pausemusic.value then
			Spring.PauseSoundStream()
			wasPaused = paused
		end
	end
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitExceptions[unitDefID] then
		return
	end

	if (damage < 1.5) then return end
	local PlayerTeam = Spring.GetMyTeamID()

	if (UnitDefs[unitDefID] == nil) then return end

	if paralyzer then
		return
	else
		if (teamID == PlayerTeam) then
			damage = damage * 1.5
		end
		local multifactor = 1
		if (numVisibleEnemy > 3) then
			multifactor = math.log(numVisibleEnemy)
		end
		dethklok[1] = dethklok[1] + (damage * multifactor);
	end
end

function widget:UnitDestroyed(unitID, unitDefID, teamID)
	if unitExceptions[unitDefID] then
		return
	end
	local unitWorth = 50
	if (UnitDefs[unitDefID].metalCost > 500) then
		unitWorth = 200
	end
	if (UnitDefs[unitDefID].metalCost > 1000) then
		unitWorth = 300
	end
	if (UnitDefs[unitDefID].metalCost > 3000) then
		unitWorth = 500
	end
	if (UnitDefs[unitDefID].metalCost > 8000) then
		unitWorth = 700
	end
	if (teamID == PlayerTeam) then
		unitWorth = unitWorth * 1.5
	end
	local multifactor = 1
	if (numVisibleEnemy > 3) then
		multifactor = math.log(numVisibleEnemy)
	end
	dethklok[1] = dethklok[1] + (unitWorth*multifactor);
end

function widget:TeamDied(team)
	if team == myTeam and not isSpec then
		defeat = true
	end
end

function widget:GameOver()
	--gameOver = true
	local track
	-- FIXME: get a better way to detect who won
	if not defeat then
		if #victoryTracks <= 0 then return end
		track = victoryTracks[math.random(1, #victoryTracks)]
	else
		if #defeatTracks <= 0 then return end
		track = defeatTracks[math.random(1, #defeatTracks)]
	end
	Spring.StopSoundStream()
	Spring.PlaySoundStream(track)
	Spring.SetSoundStreamVolume(music_volume or 0.33)
	music_start_volume = music_volume
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
	local playedTime, totalTime = Spring.GetSoundStreamTime()
  local savedTable = {}
  savedTable.curTrack	= curTrack
  savedTable.playedTime = playedTime
  savedTable.playing = playing
  savedTable.music_volume = music_volume
  return savedTable
end

-- would be great if there is be a way to continue track where we left off after a /luaui reload
function widget:SetConfigData(data)
	if data.playing ~= nil then
		playing = data.playing
		music_volume = data.music_volume
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------