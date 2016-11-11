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
		layer	= -3,
		enabled	= true	--	loaded by default?
	}
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

--Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume

WG.music_volume = Spring.GetConfigInt("snd_volmusic") * 0.01

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

local firstTime = false
local wasPaused = false
local firstFade = true
local initSeed = 0
local seedInitialized = false
local gameOver = false

local myTeam = Spring.GetMyTeamID()
local isSpec = Spring.GetSpectatingState() or Spring.IsReplay()
local defeat = false

options_path = 'Settings/Interface/Pause Screen'

options = {
	pausemusic = {name='Pause Music', type='bool', value=false},
}


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


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:Initialize()
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
end


function widget:Shutdown()
	Spring.StopSoundStream()
	
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].RemoveRect('music')
	end

	for i=1,#windows do
		(windows[i]):Dispose()
	end
end

local function PlayNewTrack()
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
	
	Spring.PlaySoundStream(newTrack)
	Spring.SetSoundStreamVolume(WG.music_volume or 0.33)
	Spring.Echo([[[Music Player] Music Volume is set to: ]] .. WG.music_volume .. [[
 
[Music Player] Press Shift and the +/- keys to adjust the music volume]])
	playing = true

	WG.music_start_volume = WG.music_volume
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
	Spring.SetSoundStreamVolume(WG.music_volume or 0.33)
	WG.music_start_volume = WG.music_volume
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
	if drawlist[1] ~= nil then
		glDeleteList(drawlist[1])
	end
	if (WG['guishader_api'] ~= nil) then
		WG['guishader_api'].InsertRect(left, bottom, right, top,'music')
	end
	drawlist[1] = glCreateList( function()
		glColor(0, 0, 0, 0.6)
		RectRound(left, bottom, right, top, 5.5*widgetScale)
		
		local borderPadding = 2.75*widgetScale
		--glColor(1,1,1,0.022)
		--RectRound(left+borderPadding, bottom+borderPadding, right-borderPadding, top-borderPadding, 4.4*widgetScale)
		
		-- track name
		local textsize = 11*widgetScale
		local maxTextWidth = 180*widgetScale
		local textPadding = 3.3*widgetScale
		glColor(0.3,0.3,0.3,1)
		local text = ''
		for i=1, #curTrack do
	    local c = string.sub(curTrack, i,i)
			local width = glGetTextWidth(text..c)*textsize
	    if width > maxTextWidth then
	    	break
	    else
	    	text = text..c
	    end
		end
		glText(text, left + (textPadding*widgetScale), bottom + (textPadding*widgetScale), textsize)
		
		-- next button
		
		-- pause button
		
		-- volume slider
		
	end)
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
  return savedTable
end

-- would be great if there is be a way to continue track where we left off after a /luaui reload
function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.curTrack ~= nil then
		curTrack = data.curTrack
		if data.playing then
			
		end
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------