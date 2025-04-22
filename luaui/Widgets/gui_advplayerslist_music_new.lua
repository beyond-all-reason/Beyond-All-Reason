local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name	= "AdvPlayersList Music Player New",
		desc	= "Plays music and offers volume controls",
		author	= "Damgam",
		date	= "2021",
		license = "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true
	}
end

local useRenderToTexture = true --Spring.GetConfigFloat("ui_rendertotexture", 0) == 1		-- much faster than drawing via DisplayLists only
local useRenderToTextureBg = true

Spring.CreateDir("music/custom/loading")
Spring.CreateDir("music/custom/peace")
Spring.CreateDir("music/custom/warlow")
Spring.CreateDir("music/custom/warhigh")
Spring.CreateDir("music/custom/war")
Spring.CreateDir("music/custom/bossfight")
Spring.CreateDir("music/custom/gameover")
Spring.CreateDir("music/custom/menu")

----------------------------------------------------------------------
-- CONFIG
----------------------------------------------------------------------

local showGUI = true
local minSilenceTime = 30
local maxSilenceTime = 120
local warLowLevel = 1000
local warHighLevel = 32500
local warMeterResetTime = 40 -- seconds
local interruptionMinimumTime = 20 -- seconds
local interruptionMaximumTime = 60 -- seconds
local songsSinceEvent = 5 -- start with higher number so event track can be played first

----------------------------------------------------------------------
----------------------------------------------------------------------

local function applySpectatorThresholds()
	warLowLevel = warLowLevel*2
	warHighLevel = warHighLevel*2
	minSilenceTime = minSilenceTime*2
	maxSilenceTime = maxSilenceTime*2
	appliedSpectatorThresholds = true
	--Spring.Echo("[Music Player] Spectator mode enabled")
end

math.randomseed( os.clock() )

local peaceTracks = {}
local warhighTracks = {}
local warlowTracks = {}
local gameoverTracks = {}
local bossFightTracks = {}
local bossFightTracksAll = {}
local bonusTracks = {}

local eventPeaceTracks = {}
local eventWarLowTracks = {}
local eventWarHighTracks = {}

local menuTracks = {}
local loadingTracks = {}

local currentTrack
local peaceTracksPlayCounter, warhighTracksPlayCounter, warlowTracksPlayCounter, bossFightTracksPlayCounter, gameoverTracksPlayCounter, eventPeaceTracksPlayCounter, eventWarLowTracksPlayCounter, eventWarHighTracksPlayCounter
local fadeOutSkipTrack = false
local interruptionEnabled
local silenceTimerEnabled
local deviceLostSafetyCheck = 0
local interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
local gameFrame = 0
local serverFrame = 0
local bossHasSpawned = false

local function ReloadMusicPlaylists()
	-----------------------------------SETTINGS---------------------------------------

	interruptionEnabled 			= Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1
	silenceTimerEnabled 			= Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1
	local newSoundtrackEnabled 		= Spring.GetConfigInt('UseSoundtrackNew', 1) == 1
	local customSoundtrackEnabled	= Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1

	if Spring.GetConfigInt('UseSoundtrackNew', 1) == 0 and Spring.GetConfigInt('UseSoundtrackOld', 0) == 1 then
		Spring.SetConfigInt('UseSoundtrackNew', 1)
		Spring.SetConfigInt('UseSoundtrackOld', 0)
	end

	deviceLostSafetyCheck = 0
	---------------------------------COLLECT MUSIC------------------------------------

	local allowedExtensions = "{*.ogg,*.mp3}"
	-- New Soundtrack List
	local musicDirNew 			= 'music/original'
	local peaceTracksNew 			= VFS.DirList(musicDirNew..'/peace', allowedExtensions)
	local warhighTracksNew 			= VFS.DirList(musicDirNew..'/warhigh', allowedExtensions)
	local warlowTracksNew 			= VFS.DirList(musicDirNew..'/warlow', allowedExtensions)
	local gameoverTracksNew 		= VFS.DirList(musicDirNew..'/gameover', allowedExtensions)
	local menuTracksNew 			= VFS.DirList(musicDirNew..'/menu', allowedExtensions)
	local loadingTracksNew   		= VFS.DirList(musicDirNew..'/loading', allowedExtensions)
	local bossFightTracksNew		= {}
		  bonusTracks				= {}
	      scavTracks				= {}
		  raptorTracks				= {}

	-- Custom Soundtrack List
	local musicDirCustom 		= 'music/custom'
	local peaceTracksCustom 		= VFS.DirList(musicDirCustom..'/peace', allowedExtensions)
	local warhighTracksCustom 		= VFS.DirList(musicDirCustom..'/warhigh', allowedExtensions)
	local warlowTracksCustom 		= VFS.DirList(musicDirCustom..'/warlow', allowedExtensions)
	local warTracksCustom 			= VFS.DirList(musicDirCustom..'/war', allowedExtensions)
	local gameoverTracksCustom 		= VFS.DirList(musicDirCustom..'/gameover', allowedExtensions)
	local menuTracksCustom 			= VFS.DirList(musicDirCustom..'/menu', allowedExtensions)
	local loadingTracksCustom  		= VFS.DirList(musicDirCustom..'/loading', allowedExtensions)
	local bossFightTracksCustom 	= VFS.DirList(musicDirCustom..'/bossfight', allowedExtensions)

	-- Events
	eventPeaceTracks = {}
	eventWarLowTracks = {}
	eventWarHighTracks = {}

	peaceTracks = {}
	warhighTracks = {}
	warlowTracks = {}
	gameoverTracks = {}
	bossFightTracks = {}
	menuTracks = {}
	loadingTracks = {}

	if newSoundtrackEnabled then

		-- Raptors --------------------------------------------------------------------------------------------------------------------
		if Spring.Utilities.Gametype.IsRaptors() then
			table.append(eventPeaceTracks, VFS.DirList(musicDirNew..'/events/raptors/peace', allowedExtensions))
			table.append(eventWarLowTracks, VFS.DirList(musicDirNew..'/events/raptors/warlow', allowedExtensions))
			table.append(eventWarHighTracks, VFS.DirList(musicDirNew..'/events/raptors/warhigh', allowedExtensions))
			table.append(bossFightTracks, VFS.DirList(musicDirNew..'/events/raptors/bossfight', allowedExtensions))
		end
		table.append(raptorTracks, VFS.DirList(musicDirNew..'/events/raptors/loading', allowedExtensions))
		table.append(raptorTracks, VFS.DirList(musicDirNew..'/events/raptors/peace', allowedExtensions))
		table.append(raptorTracks, VFS.DirList(musicDirNew..'/events/raptors/warlow', allowedExtensions))
		table.append(raptorTracks, VFS.DirList(musicDirNew..'/events/raptors/warhigh', allowedExtensions))
		table.append(raptorTracks, VFS.DirList(musicDirNew..'/events/raptors/bossfight', allowedExtensions))

		-- Scavengers --------------------------------------------------------------------------------------------------------------------
		if Spring.Utilities.Gametype.IsScavengers() then
			table.append(eventPeaceTracks, VFS.DirList(musicDirNew..'/events/scavengers/peace', allowedExtensions))
			table.append(eventWarLowTracks, VFS.DirList(musicDirNew..'/events/scavengers/warlow', allowedExtensions))
			table.append(eventWarHighTracks, VFS.DirList(musicDirNew..'/events/scavengers/warhigh', allowedExtensions))
			table.append(bossFightTracks, VFS.DirList(musicDirNew..'/events/scavengers/bossfight', allowedExtensions))
		end
		table.append(scavTracks, VFS.DirList(musicDirNew..'/events/scavengers/loading', allowedExtensions))
		table.append(scavTracks, VFS.DirList(musicDirNew..'/events/scavengers/peace', allowedExtensions))
		table.append(scavTracks, VFS.DirList(musicDirNew..'/events/scavengers/warlow', allowedExtensions))
		table.append(scavTracks, VFS.DirList(musicDirNew..'/events/scavengers/warhigh', allowedExtensions))
		table.append(scavTracks, VFS.DirList(musicDirNew..'/events/scavengers/bossfight', allowedExtensions))

		-- April Fools --------------------------------------------------------------------------------------------------------------------
		if ((tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7) and Spring.GetConfigInt('UseSoundtrackAprilFools', 1) == 1) then
			table.append(eventPeaceTracks, VFS.DirList(musicDirNew..'/events/aprilfools/peace', allowedExtensions))
			table.append(eventWarLowTracks, VFS.DirList(musicDirNew..'/events/aprilfools/war', allowedExtensions))
			table.append(eventWarHighTracks, VFS.DirList(musicDirNew..'/events/aprilfools/war', allowedExtensions))
			table.append(eventWarLowTracks, VFS.DirList(musicDirNew..'/events/aprilfools/warlow', allowedExtensions))
			table.append(eventWarHighTracks, VFS.DirList(musicDirNew..'/events/aprilfools/warhigh', allowedExtensions))
		elseif (not ((tonumber(os.date("%m")) == 4 and tonumber(os.date("%d")) <= 7)) and Spring.GetConfigInt('UseSoundtrackAprilFoolsPostEvent', 0) == 1) then
			table.append(peaceTracksNew, VFS.DirList(musicDirNew..'/events/aprilfools/peace', allowedExtensions))
			table.append(warlowTracksNew, VFS.DirList(musicDirNew..'/events/aprilfools/war', allowedExtensions))
			table.append(warhighTracksNew, VFS.DirList(musicDirNew..'/events/aprilfools/war', allowedExtensions))
			table.append(warlowTracksNew, VFS.DirList(musicDirNew..'/events/aprilfools/warlow', allowedExtensions))
			table.append(warhighTracksNew, VFS.DirList(musicDirNew..'/events/aprilfools/warhigh', allowedExtensions))
		end
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/menu', allowedExtensions))
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/loading', allowedExtensions))
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/peace', allowedExtensions))
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/war', allowedExtensions))
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/warlow', allowedExtensions))
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/aprilfools/warhigh', allowedExtensions))

		-- Christmas ----------------------------------------------------------------------------------------------------------------------
		table.append(bonusTracks, VFS.DirList(musicDirNew..'/events/xmas/menu', allowedExtensions))
	end

	-------------------------------CREATE PLAYLISTS-----------------------------------

	if newSoundtrackEnabled then
		table.append(peaceTracks, peaceTracksNew)
		table.append(warhighTracks, warhighTracksNew)
		table.append(warlowTracks, warlowTracksNew)
		table.append(gameoverTracks, gameoverTracksNew)
		table.append(bossFightTracks, bossFightTracksNew)
		table.append(menuTracks, menuTracksNew)
		table.append(loadingTracks, loadingTracksNew)
	end

	if customSoundtrackEnabled then
		table.append(peaceTracks, peaceTracksCustom)
		table.append(warhighTracks, warhighTracksCustom)
		table.append(warlowTracks, warlowTracksCustom)
		table.append(warhighTracks, warTracksCustom)
		table.append(warlowTracks, warTracksCustom)
		table.append(gameoverTracks, gameoverTracksCustom)
		table.append(bossFightTracks, bossFightTracksCustom)
		table.append(menuTracks, menuTracksCustom)
		table.append(loadingTracks, loadingTracksCustom)
	end

	if #bossFightTracks == 0 then
		bossFightTracks = warhighTracks
	end

	if #loadingTracks == 0 then
		loadingTracks = warhighTracks
	end

	if #gameoverTracks == 0 then
		gameoverTracks = peaceTracks
	end

	if #menuTracks == 0 then
		menuTracks = peaceTracks
	end

	----------------------------------SHUFFLE--------------------------------------

	local function shuffleMusic(playlist)
		local originalPlaylist = {}
		table.append(originalPlaylist, playlist)
		local shuffledPlaylist = {}
		if #originalPlaylist > 0 then
			repeat
				local r = math.random(#originalPlaylist)
				table.insert(shuffledPlaylist, originalPlaylist[r])
				table.remove(originalPlaylist, r)
			until(#originalPlaylist == 0)
		else
			shuffledPlaylist = originalPlaylist
		end
		return shuffledPlaylist
	end

	peaceTracks 	= shuffleMusic(peaceTracks)
	warhighTracks 	= shuffleMusic(warhighTracks)
	warlowTracks 	= shuffleMusic(warlowTracks)
	gameoverTracks 	= shuffleMusic(gameoverTracks)
	bossFightTracks = shuffleMusic(bossFightTracks)
	eventPeaceTracks = shuffleMusic(eventPeaceTracks)
	eventWarLowTracks = shuffleMusic(eventWarLowTracks)
	eventWarHighTracks = shuffleMusic(eventWarHighTracks)
	bonusTracks = shuffleMusic(bonusTracks)

	-- Spring.Echo("----- MUSIC PLAYER PLAYLIST -----")
	-- Spring.Echo("----- peaceTracks -----")
	-- for i = 1,#peaceTracks do
	-- 	Spring.Echo(peaceTracks[i])
	-- end
	-- Spring.Echo("----- warlowTracks -----")
	-- for i = 1,#warlowTracks do
	-- 	Spring.Echo(warlowTracks[i])
	-- end
	-- Spring.Echo("----- warhighTracks -----")
	-- for i = 1,#warhighTracks do
	-- 	Spring.Echo(warhighTracks[i])
	-- end
	-- Spring.Echo("----- gameoverTracks -----")
	-- for i = 1,#gameoverTracks do
	-- 	Spring.Echo(gameoverTracks[i])
	-- end
	-- Spring.Echo("----- bossFightTracks -----")
	-- for i = 1,#bossFightTracks do
	-- 	Spring.Echo(bossFightTracks[i])
	-- end

	if #peaceTracks > 1 then
		peaceTracksPlayCounter = math.random(#peaceTracks)
	else
		peaceTracksPlayCounter = 1
	end

	if #warhighTracks > 1 then
		warhighTracksPlayCounter = math.random(#warhighTracks)
	else
		warhighTracksPlayCounter = 1
	end

	if #warlowTracks > 1 then
		warlowTracksPlayCounter = math.random(#warlowTracks)
	else
		warlowTracksPlayCounter = 1
	end

	if #bossFightTracks > 1 then
		bossFightTracksPlayCounter = math.random(#bossFightTracks)
	else
		bossFightTracksPlayCounter = 1
	end

	if #gameoverTracks > 1 then
		gameoverTracksPlayCounter = math.random(#gameoverTracks)
	else
		gameoverTracksPlayCounter = 1
	end

	if #eventPeaceTracks > 1 then
		eventPeaceTracksPlayCounter = math.random(#eventPeaceTracks)
	else
		eventPeaceTracksPlayCounter = 1
	end

	if #eventWarLowTracks > 1 then
		eventWarLowTracksPlayCounter = math.random(#eventWarLowTracks)
	else
		eventWarLowTracksPlayCounter = 1
	end

	if #eventWarHighTracks > 1 then
		eventWarHighTracksPlayCounter = math.random(#eventWarHighTracks)
	else
		eventWarHighTracksPlayCounter = 1
	end
end

local currentTrackList = peaceTracks
local currentTrackListString = "intro"

local defaultMusicVolume = 50
local warMeter = 0
local warMeterResetTimer = 0
local gameOver = false
local playedGameOverTrack = false
local fadeLevel = 100
local faderMin = 45 -- range in dB for volume faders, from -faderMin to 0dB

local playedTime, totalTime = Spring.GetSoundStreamTime()
local prevPlayedTime = playedTime

local silenceTimer = math.random(minSilenceTime, maxSilenceTime)

local maxMusicVolume = Spring.GetConfigInt("snd_volmusic", 50)	-- user value, cause actual volume will change during fadein/outc
if maxMusicVolume > 99 then
	Spring.SetConfigInt("snd_volmusic", 99)
	maxMusicVolume = 99
end
local volume = Spring.GetConfigInt("snd_volmaster", 80)
if volume > 80 then
	Spring.SetConfigInt("snd_volmaster", 80)
	volume = 80
end

local RectRound, UiElement, UiButton, UiSlider, UiSliderKnob, bgpadding, elementCorner
local borderPaddingRight, borderPaddingLeft, font, draggingSlider, mouseover
local buttons = {}
local drawlist = {}
local advplayerlistPos = {}
local widgetScale = 1
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0
local borderPadding = bgpadding
local updateDrawing = false

local vsx, vsy = Spring.GetViewGeometry()
local ui_opacity = Spring.GetConfigFloat("ui_opacity", 0.7)

local playing = (Spring.GetConfigInt('music', 1) == 1)
local shutdown

local playTex	= ":l:"..LUAUI_DIRNAME.."Images/music/play.png"
local pauseTex	= ":l:"..LUAUI_DIRNAME.."Images/music/pause.png"
local nextTex	= ":l:"..LUAUI_DIRNAME.."Images/music/next.png"
local musicTex	= ":l:"..LUAUI_DIRNAME.."Images/music/music.png"
local volumeTex	= ":l:"..LUAUI_DIRNAME.."Images/music/volume.png"

local glPushMatrix   = gl.PushMatrix
local glPopMatrix	 = gl.PopMatrix
local glColor        = gl.Color
local glTexRect	     = gl.TexRect
local glTexture      = gl.Texture
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local math_isInRect = math.isInRect

local function getVolumeCoef(fader)
	if fader <= 0 then
		return 0
	elseif fader >= 1 then
		return 1
	end
	local db = faderMin * (fader - 1) -- interpolate between -faderMin and 0
	return 10 ^ (db * 0.05) -- ranges between 0.005 and 1.0 in log scale
end

local faderMinDelta = getVolumeCoef(0.01) -- volume setting only allows discrete values in 0.02 steps
local function getVolumePos(coef)
	if coef < faderMinDelta then
		return 0
	elseif coef >= 1 then
		return 1
	end
	local db = math.log10(coef) * 20
	return (db/faderMin) + 1
end

local fadeDirection

local function getFastFadeSpeed()
	return 1.5 * 0.33
end
local function getSlowFadeSpeed()
	return math.max(Spring.GetGameSpeed(), 0.01)
end
local getFadeSpeed = getSlowFadeSpeed

local function fadeChange()
	return (0.33 / getFadeSpeed()) * fadeDirection
end

local function getMusicVolume()
	return Spring.GetConfigInt("snd_volmusic", defaultMusicVolume) * 0.01
end

local function setMusicVolume(fadeLevel)
	Spring.SetSoundStreamVolume(getMusicVolume() * math.clamp(fadeLevel, 0, 100) * 0.01)
end

local function updateFade()
	if fadeDirection then
		if Spring.GetConfigInt("UseSoundtrackFades", 1) == 1 then
			fadeLevel = fadeLevel + fadeChange()
		else
			if fadeDirection < 0 then
				fadeLevel = 0
			elseif fadeDirection > 0 then
				fadeLevel = 100
			end
		end
		setMusicVolume(fadeLevel)
		if fadeDirection < 0 and fadeLevel <= 0 then
			fadeDirection = nil
			if fadeOutSkipTrack then
				PlayNewTrack()
			else
				Spring.StopSoundStream()
			end
		elseif fadeDirection > 0 and fadeLevel >= 100 then
			fadeDirection = nil
		end
	end
end

local function getSliderWidth()
	return math.floor((4.5 * widgetScale)+0.5)
end

local function capitalize(text)
	local str = ''
	local upperNext = true
	local char = ''
	for i=1, string.len(text) do
		char = string.sub(text, i,i)
		if upperNext then
			str = str..string.upper(char)
			upperNext = false
		else
			str = str..char
		end
		if char == ' ' then
			upperNext = true
		end
	end
	return str
end

local function processTrackname(trackname)
	trackname = string.gsub(trackname, ".%w+$", "")
	trackname = trackname:match("[^/|\\]*$")
	return capitalize(trackname)
end

local function drawBackground()
	UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1, nil, nil, nil, nil, useRenderToTextureBg)
	borderPadding = bgpadding
	borderPaddingRight = borderPadding
	if right >= vsx-0.2 then
		borderPaddingRight = 0
	end
	borderPaddingLeft = borderPadding
	if left <= 0.2 then
		borderPaddingLeft = 0
	end
end

local function drawContent()
	local trackname
	local padding2 = math.floor(2.5 * widgetScale) -- inner icon padding
	local textsize = 11 * widgetScale * math.clamp(1+((1-(vsy/1200))*0.4), 1, 1.15)
	local textXPadding = 10 * widgetScale
	--local maxTextWidth = right-buttons['playpause'][3]-textXPadding-textXPadding
	local maxTextWidth = right-textXPadding-textXPadding

	local button = 'playpause'

	if not mouseover and not draggingSlider and playing and volume > 0 and playedTime < totalTime then
		-- track name
		trackname = currentTrack or ''
		glColor(0.45,0.45,0.45,1)

		trackname = processTrackname(trackname)

		local text = ''
		for i = 1, #trackname do
			local c = string.sub(trackname, i,i)
			local width = font:GetTextWidth(text..c) * textsize
			if width > maxTextWidth then
				break
			else
				text = text..c
			end
		end
		trackname = text

		glColor(0.8,0.8,0.8,useRenderToTexture and 1 or 0.9)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		font:Begin()
		font:SetOutlineColor(0.15,0.15,0.15,useRenderToTexture and 1 or 0.8)
		font:Print("\255\235\235\235"..trackname, buttons[button][3]+math.ceil(padding2*1.1), bottom+(0.48*widgetHeight*widgetScale)-(textsize*0.35), textsize, 'no')
		font:End()
	else
		glColor(0.88,0.88,0.88,0.9)
		if playing then
			glTexture(pauseTex)
		else
			glTexture(playTex)
		end
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)

		button = 'next'
		glColor(0.88,0.88,0.88,0.9)
		glTexture(nextTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)

		local sliderWidth = math.floor((4.5 * widgetScale)+0.5)
		local lineHeight = math.floor((1.65 * widgetScale)+0.5)

		local button = 'musicvolumeicon'
		local sliderY = math.floor(buttons[button][2] + (buttons[button][4] - buttons[button][2])/2)
		glColor(0.8,0.8,0.8,useRenderToTexture and 1 or 0.9)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'musicvolume'
		UiSlider(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight)
		UiSliderKnob(buttons[button][5]-(sliderWidth/2), sliderY, sliderWidth)

		button = 'volumeicon'
		glColor(0.8,0.8,0.8,0.9)
		glTexture(volumeTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'volume'
		UiSlider(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight)
		UiSliderKnob(buttons[button][5]-(sliderWidth/2), sliderY, sliderWidth)
	end
end

local function refreshUiDrawing()
	if WG['guishader'] then
		if guishaderList then
			guishaderList = glDeleteList(guishaderList)
		end
		guishaderList = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner, 1,0,0,1)
		end)
		WG['guishader'].InsertDlist(guishaderList, 'music', true)
	end

	local trackname
	local padding = math.floor(2.75 * widgetScale) -- button background margin
	local padding2 = math.floor(2.5 * widgetScale) -- inner icon padding
	local volumeWidth = math.floor(50 * widgetScale)
	local heightoffset = -math.floor(0.9 * widgetScale)
	local textsize = 11 * widgetScale
	local textXPadding = 10 * widgetScale
	--local maxTextWidth = right-buttons['playpause'][3]-textXPadding-textXPadding
	local maxTextWidth = right-textXPadding-textXPadding

	buttons['playpause'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}
	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding+heightoffset, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding+heightoffset}

	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding+heightoffset, buttons['next'][3]+((widgetHeight * widgetScale)), top-padding+heightoffset}
	--buttons['musicvolumeicon'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding+heightoffset, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (getVolumePos(maxMusicVolume/99))

	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding+heightoffset, buttons['musicvolume'][3]+((widgetHeight * widgetScale)), top-padding+heightoffset}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding+heightoffset, buttons['volumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (getVolumePos(volume/80))

	if drawlist[1] ~= nil then
		for i=1, #drawlist do
			glDeleteList(drawlist[i])
		end
	end
	if right-left >= 1 and top-bottom >= 1 then
		if useRenderToTextureBg then
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
		else
			drawlist[1] = glCreateList( function()
				drawBackground()
			end)
		end
		if useRenderToTexture then
			if not uiTex then
				uiTex = gl.CreateTexture(math.floor(right-left), math.floor(top-bottom), {	--*(vsy<1400 and 2 or 1)
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
		else
			drawlist[2] = glCreateList( function()
				local button = 'playpause'
				glColor(0.88,0.88,0.88,0.9)
				if playing then
					glTexture(pauseTex)
				else
					glTexture(playTex)
				end
				glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)

				button = 'next'
				glColor(0.88,0.88,0.88,0.9)
				glTexture(nextTex)
				glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
			end)
			drawlist[3] = glCreateList( function()
				-- track name
				trackname = currentTrack or ''
				glColor(0.45,0.45,0.45,1)

				trackname = processTrackname(trackname)

				local text = ''
				for i = 1, #trackname do
					local c = string.sub(trackname, i,i)
					local width = font:GetTextWidth(text..c) * textsize
					if width > maxTextWidth then
						break
					else
						text = text..c
					end
				end
				trackname = text

				local button = 'playpause'
				glColor(0.8,0.8,0.8,useRenderToTexture and 1 or 0.9)
				glTexture(musicTex)
				glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
				glTexture(false)

				font:Begin()
				font:SetOutlineColor(0.15,0.15,0.15,useRenderToTexture and 1 or 0.8)
				font:Print("\255\235\235\235"..trackname, buttons[button][3]+math.ceil(padding2*1.1), bottom+(0.48*widgetHeight*widgetScale)-(textsize*0.35), textsize, 'no')
				font:End()
			end)
			drawlist[4] = glCreateList( function()

				local sliderWidth = math.floor((4.5 * widgetScale)+0.5)
				local lineHeight = math.floor((1.65 * widgetScale)+0.5)

				local button = 'musicvolumeicon'
				local sliderY = math.floor(buttons[button][2] + (buttons[button][4] - buttons[button][2])/2)
				glColor(0.8,0.8,0.8,useRenderToTexture and 1 or 0.9)
				glTexture(musicTex)
				glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
				glTexture(false)

				button = 'musicvolume'
				UiSlider(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight)
				UiSliderKnob(buttons[button][5]-(sliderWidth/2), sliderY, sliderWidth)

				button = 'volumeicon'
				glColor(0.8,0.8,0.8,0.9)
				glTexture(volumeTex)
				glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
				glTexture(false)

				button = 'volume'
				UiSlider(buttons[button][1], sliderY-lineHeight, buttons[button][3], sliderY+lineHeight)
				UiSliderKnob(buttons[button][5]-(sliderWidth/2), sliderY, sliderWidth)
			end)
		end
	end
	if WG['tooltip'] ~= nil and trackname then
		if trackname and trackname ~= '' then
			WG['tooltip'].AddTooltip('music', {left, bottom, right, top}, trackname, 0.8)
		else
			WG['tooltip'].RemoveTooltip('music')
		end
	end
end

local function updatePosition(force)
	local prevPos = advplayerlistPos
	if WG['advplayerlist_api'] ~= nil then
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		advplayerlistPos = {0,vsx-(220*scale),0,vsx,scale}
	end
	left = advplayerlistPos[2]
	bottom = advplayerlistPos[1]
	right = advplayerlistPos[4]
	top = math.ceil(advplayerlistPos[1]+(widgetHeight * advplayerlistPos[5]))
	widgetScale = advplayerlistPos[5]
	if (prevPos[1] == nil or prevPos[1] ~= advplayerlistPos[1] or prevPos[2] ~= advplayerlistPos[2] or prevPos[5] ~= advplayerlistPos[5]) or force then
		widget:ViewResize()
	end
end

function widget:Initialize()
	if Spring.GetGameFrame() == 0 and Spring.GetConfigInt('music_loadscreen', 1) == 1 then
		currentTrack = Spring.GetConfigString('music_loadscreen_track', '')
	end
	ReloadMusicPlaylists()
	silenceTimer = math.random(minSilenceTime,maxSilenceTime)
	widget:ViewResize()
	--Spring.StopSoundStream() -- only for testing purposes

	WG['music'] = {}
	WG['music'].GetPosition = function()
		if shutdown then
			return false
		end
		updatePosition()
		return {showGUI and top or bottom,left,bottom,right,widgetScale}
	end
	WG['music'].GetMusicVolume = function()
		return maxMusicVolume
	end
	WG['music'].SetMusicVolume = function(value)
		maxMusicVolume = value
		Spring.SetConfigInt("snd_volmusic", math.min(99,math.ceil(maxMusicVolume))) -- It took us 2 and half year to realize that the engine is not saving value of a 100 because it's engine default, which is why we're maxing it at 99
		if fadeDirection then
			setMusicVolume(fadeLevel)
		end
		updateDrawing = true
	end
	WG['music'].GetShowGui = function()
		return showGUI
	end
	WG['music'].SetShowGui = function(value)
		showGUI = value
	end
	WG['music'].getTracksConfig = function(value)
		local tracksConfig = {}

		local function sortPlaylist(playlist)
			table.sort(playlist, function(a, b)
				local nameA = processTrackname(a) or ""
				local nameB = processTrackname(b) or ""
				return string.lower(nameA) < string.lower(nameB)
			end)
		end

		local menuTracksSorted = table.copy(menuTracks)
		sortPlaylist(menuTracksSorted)
		for k,v in pairs(menuTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.menu'), processTrackname(v), v}
		end

		local loadingTracksSorted = table.copy(loadingTracks)
		sortPlaylist(loadingTracksSorted)
		for k,v in pairs(loadingTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.loading'), processTrackname(v), v}
		end

		local peaceTracksSorted = table.copy(peaceTracks)
		sortPlaylist(peaceTracksSorted)
		for k,v in pairs(peaceTracksSorted) do
			if peaceTracks[k] and not string.find(peaceTracks[k], "/events/") then
				tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.peace'), processTrackname(v), v}
			end
		end

		local warlowTracksSorted = table.copy(warlowTracks)
		sortPlaylist(warlowTracksSorted)
		for k,v in pairs(warlowTracksSorted) do
			if warlowTracks[k] and not string.find(warlowTracks[k], "/events/") then
				tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.warlow'), processTrackname(v), v}
			end
		end

		local warhighTracksSorted = table.copy(warhighTracks)
		sortPlaylist(warhighTracksSorted)
		for k,v in pairs(warhighTracksSorted) do
			if warhighTracks[k] and not string.find(warhighTracks[k], "/events/") then
				tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.warhigh'), processTrackname(v), v}
			end
		end

		local raptorTracksSorted = table.copy(raptorTracks)
		sortPlaylist(raptorTracksSorted)
		for k,v in pairs(raptorTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.raptors'), processTrackname(v), v}
		end

		local scavTracksSorted = table.copy(scavTracks)
		sortPlaylist(scavTracksSorted)
		for k,v in pairs(scavTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.scavengers'), processTrackname(v), v}
		end

		local gameoverTracksSorted = table.copy(gameoverTracks)
		sortPlaylist(gameoverTracksSorted)
		for k,v in pairs(gameoverTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.gameover'), processTrackname(v), v}
		end

		local bonusTracksSorted = table.copy(bonusTracks)
		sortPlaylist(bonusTracksSorted)
		for k,v in pairs(bonusTracksSorted) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.bonus'), processTrackname(v), v}
		end
		return tracksConfig
	end
	WG['music'].playTrack = function(track)
		currentTrack = track
		Spring.StopSoundStream()
		Spring.PlaySoundStream(currentTrack, 1)
		playing = true
		Spring.SetConfigInt('music', (playing and 1 or 0))
		local playedTime, totalTime = Spring.GetSoundStreamTime()
		interruptionTime = totalTime + 2
		if fadeDirection then
			setMusicVolume(fadeLevel)
		else
			setMusicVolume(100)
		end
		updateDrawing = true
	end
	WG['music'].RefreshSettings = function()
		interruptionEnabled 			= Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1
		silenceTimerEnabled 			= Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1
	end
	WG['music'].RefreshTrackList = function()
		Spring.StopSoundStream()
		ReloadMusicPlaylists()
		PlayNewTrack()
	end
end

function widget:Shutdown()
	shutdown = true
	Spring.SetConfigInt('music', (playing and 1 or 0))

	if WG['guishader'] then
		WG['guishader'].RemoveDlist('music')
	end
	if WG['tooltip'] ~= nil then
		WG['tooltip'].RemoveTooltip('music')
	end
	for i=1,#drawlist do
		glDeleteList(drawlist[i])
	end
	if guishaderList then glDeleteList(guishaderList) end
	if uiBgTex then
		gl.DeleteTextureFBO(uiBgTex)
		uiBgTex = nil
	end
	if uiTex then
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
	WG['music'] = nil
end



function widget:ViewResize(newX,newY)
	vsx, vsy = Spring.GetViewGeometry()

	local outlineMult = math.clamp(1/(vsy/1400), 1, 2)
	font = WG['fonts'].getFont(nil, 0.95, 0.37 * (useRenderToTexture and outlineMult or 1), useRenderToTexture and 1.2+(outlineMult*0.2) or 1.15)

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob
	UiSlider = function(px, py, sx, sy)
		local cs = (sy-py)*0.25
		local edgeWidth = math.max(1, math.floor((sy-py) * 0.1))
		if useRenderToTexture then
			-- faint dark outline edge
			RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.33 })
			-- bottom
			RectRound(px, py, sx, sy, cs, 1,1,1,1, { 1, 1, 1, 0.22 }, { 1, 1, 1, 0 })
			-- top
			RectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.4, 0.4, 0.4, 0.6 }, { 0.9,0.9,0.9, 0.6 })
		else
			-- faint dark outline edge
			RectRound(px-edgeWidth, py-edgeWidth, sx+edgeWidth, sy+edgeWidth, cs*1.5, 1,1,1,1, { 0,0,0,0.05 })
			-- bottom
			RectRound(px, py, sx, sy, cs, 1,1,1,1, { 1, 1, 1, 0.1 }, { 1, 1, 1, 0 })
			-- top
			RectRound(px, py, sx, sy, cs, 1,1,1,1, { 0.1, 0.1, 0.1, 0.22 }, { 0.9,0.9,0.9, 0.22 })
		end
	end

	updateDrawing = true
	if uiTex then
		gl.DeleteTextureFBO(uiBgTex)
		uiBgTex = nil
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
end

local function getSliderValue(button, x)
	local sliderWidth = buttons[button][3] - buttons[button][1]
	local value = (x - buttons[button][1]) / (sliderWidth)
	if value < 0 then value = 0 end
	if value > 1 then value = 1 end
	return value
end

function widget:MouseMove(x, y)
	if showGUI and draggingSlider ~= nil then
		if draggingSlider == 'musicvolume' then
			maxMusicVolume = math.ceil(getVolumeCoef(getSliderValue(draggingSlider, x)) * 99)
			Spring.SetConfigInt("snd_volmusic", math.min(99,maxMusicVolume))  -- It took us 2 and half year to realize that the engine is not saving value of a 100 because it's engine default, which is why we're maxing it at 99
			if fadeDirection then
				setMusicVolume(fadeLevel)
			end
			updateDrawing = true
		end
		if draggingSlider == 'volume' then
			volume = math.ceil(getVolumeCoef(getSliderValue(draggingSlider, x)) * 80)
			Spring.SetConfigInt("snd_volmaster", volume)
			updateDrawing = true
		end
	end
end

local function mouseEvent(x, y, button, release)
	if Spring.IsGUIHidden() then return false end
	if not showGUI then return end
	if button == 1 then
		if not release then
			local sliderWidth = (3.3 * widgetScale) -- should be same as in createlist()
			local button = 'musicvolume'
			if math_isInRect(x, y, buttons[button][1] - sliderWidth, buttons[button][2], buttons[button][3] + sliderWidth, buttons[button][4]) then
				draggingSlider = button
				maxMusicVolume = math.ceil(getVolumeCoef(getSliderValue(button, x)) * 99)
				Spring.SetConfigInt("snd_volmusic", math.min(99, maxMusicVolume))   -- It took us 2 and half year to realize that the engine is not saving value of a 100 because it's engine default, which is why we're maxing it at 99
				updateDrawing = true
			end
			button = 'volume'
			if math_isInRect(x, y, buttons[button][1] - sliderWidth, buttons[button][2], buttons[button][3] + sliderWidth, buttons[button][4]) then
				draggingSlider = button
				volume = math.ceil(getVolumeCoef(getSliderValue(button, x)) * 80)
				Spring.SetConfigInt("snd_volmaster", volume)
				updateDrawing = true
			end
		end
		if release and draggingSlider ~= nil then
			draggingSlider = nil
		end
		if button == 1 and not release and math_isInRect(x, y, left, bottom, right, top) then
			if buttons['playpause'] ~= nil and math_isInRect(x, y, buttons['playpause'][1], buttons['playpause'][2], buttons['playpause'][3], buttons['playpause'][4]) then
				playing = not playing
				Spring.SetConfigInt('music', (playing and 1 or 0))
				Spring.PauseSoundStream()
				updateDrawing = true
			elseif buttons['next'] ~= nil and math_isInRect(x, y, buttons['next'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]) then
				playing = true
				Spring.SetConfigInt('music', (playing and 1 or 0))
				PlayNewTrack()
			end
			return true
		end
	end

	if mouseover and math_isInRect(x, y, left, bottom, right, top) then
		return true
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

local playingInit = false
function widget:Update(dt)
	local frame = Spring.GetGameFrame()
	local _,_,paused = Spring.GetGameSpeed()

	playedTime, totalTime = Spring.GetSoundStreamTime()

	if not playingInit then
		playingInit = true
		if playedTime ~= prevPlayedTime then
			if not playing then
				playing = true
				updateDrawing = true
			end
		else
			if playing then
				playing = false
				updateDrawing = true
			end
		end
	end
	prevPlayedTime = playedTime

	if playing and (paused or frame < 1) then
		if totalTime == 0 then
			PlayNewTrack(true)
		end
	end
	if paused then
		updateFade()
	end

	if showGUI then
		local mx, my, mlb = Spring.GetMouseState()
		if math_isInRect(mx, my, left, bottom, right, top) then
			mouseover = true
		end
		local curVolume = Spring.GetConfigInt("snd_volmaster", 80)
		if volume ~= curVolume then
			volume = curVolume
			updateDrawing = true
		end
	end
end

local prevShowTrackname = false
function widget:DrawScreen()
	if not showGUI then return end
	updatePosition()

	local mx, my, mlb = Spring.GetMouseState()
	prevMouseover = mouseover
	mouseover = false
	if WG['topbar'] and WG['topbar'].showingQuit() then
		mouseover = false
	else
		if math_isInRect(mx, my, left, bottom, right, top) then
			local curVolume = Spring.GetConfigInt("snd_volmaster", 80)
			if volume ~= curVolume then
				volume = curVolume
				updateDrawing = true
			end
			mouseover = true
		end
	end

	showTrackname = not (not mouseover and not draggingSlider and playing and volume > 0 and playedTime < totalTime)
	if updateDrawing or (useRenderToTexture and mouseover ~= prevMouseover) or showTrackname ~= prevShowTrackname then
		updateDrawing = false
		refreshUiDrawing()
	end
	prevShowTrackname = showTrackname

	if useRenderToTextureBg then
		if uiBgTex then
			-- background element
			gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
			gl.Texture(uiBgTex)
			gl.TexRect(left, bottom, right, top, false, true)
			gl.Texture(false)
		end
	else
		glCallList(drawlist[1])
	end
	if useRenderToTexture then
		if uiTex then
			-- content
			gl.Color(1,1,1,1)
			gl.Texture(uiTex)
			gl.TexRect(left, bottom, right, top, false, true)
			gl.Texture(false)
		end
	else
		if not mouseover and not draggingSlider and playing and volume > 0 and playedTime < totalTime then
			if drawlist[3] then
				glCallList(drawlist[3])
			end
		else
			if drawlist[2] then
				glCallList(drawlist[2])
			end
			if drawlist[4] then
				glCallList(drawlist[4])
			end
		end
	end
	if drawlist[2] ~= nil or uiTex then
		if mouseover then
			-- display play progress
			local progressPx = math.floor((right - left) * (playedTime / totalTime))
			if progressPx > 1 and playedTime / totalTime < 1 then
				if progressPx < borderPadding * 5 then
					progressPx = borderPadding * 5
				end
				RectRound(left + borderPaddingLeft, bottom + borderPadding - (1.8 * widgetScale), left - borderPaddingRight + progressPx, top - borderPadding, borderPadding, 2, 2, 2, 2, { 0.6, 0.6, 0.6, ui_opacity * 0.15 }, { 1, 1, 1, ui_opacity * 0.15 })
			end

			local color = { 1, 1, 1, 0.1 }
			local colorHighlight = { 1, 1, 1, 0.3 }
			glBlending(GL_SRC_ALPHA, GL_ONE)
			local button = 'playpause'
			if buttons[button] ~= nil and math_isInRect(mx, my, buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]) then
				UiButton(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4], 1, 1, 1, 1, 1, 1, 1, 1, 1, mlb and colorHighlight or color)
			end
			local button = 'next'
			if buttons[button] ~= nil and math_isInRect(mx, my, buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]) then
				UiButton(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4], 1, 1, 1, 1, 1, 1, 1, 1, 1, mlb and colorHighlight or color)
			end
			glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
		end
	end

	if mouseover then
		Spring.SetMouseCursor('cursornormal')
	end
end

function PlayNewTrack(paused)
	if Spring.GetConfigInt('music', 1) ~= 1 then
		return
	end
	if (not paused) and Spring.GetGameFrame() > 1 then
		deviceLostSafetyCheck = deviceLostSafetyCheck + 1
	end
	Spring.StopSoundStream()
	fadeOutSkipTrack = false
	silenceTimer = math.random(minSilenceTime,maxSilenceTime)

	if (not gameOver) and Spring.GetGameFrame() > 1 then
		fadeLevel = 0
		fadeDirection = 1
	else
		-- Fade in only when game is in progress
		fadeDirection = nil
	end
	currentTrack = nil
	currentTrackList = nil
	currentTrackIsEventMusic = nil

	if gameOver then
		currentTrackList = gameoverTracks
		currentTrackListString = "gameOver"
		playedGameOverTrack = true
	elseif bossHasSpawned then
		currentTrackList = bossFightTracks
		currentTrackListString = "bossFight"
	elseif warMeter >= warHighLevel then
		if #eventWarHighTracks > 0 and songsSinceEvent > math.random(1,4) then
			currentTrackList = eventWarHighTracks
			currentTrackListString = "eventWarHigh"
			songsSinceEvent = 0
		else
			currentTrackList = warhighTracks
			currentTrackListString = "warHigh"
		end
	elseif warMeter >= warLowLevel then
		if #eventWarLowTracks > 0 and songsSinceEvent > math.random(1,4) then
			currentTrackList = eventWarLowTracks
			currentTrackListString = "eventWarLow"
			songsSinceEvent = 0
		else
			currentTrackList = warlowTracks
			currentTrackListString = "warLow"
		end
	else
		if #eventPeaceTracks > 0 and songsSinceEvent > math.random(1,4) then
			currentTrackList = eventPeaceTracks
			currentTrackListString = "eventPeace"
			songsSinceEvent = 0
		else
			currentTrackList = peaceTracks
			currentTrackListString = "peace"
		end
	end

	if not currentTrackList then
		return
	end

	if #currentTrackList > 0 then
		if currentTrackListString == "peace" then
			currentTrack = currentTrackList[peaceTracksPlayCounter]
			if peaceTracksPlayCounter < #peaceTracks then
				peaceTracksPlayCounter = peaceTracksPlayCounter + 1
			else
				peaceTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "warHigh" then
			currentTrack = currentTrackList[warhighTracksPlayCounter]
			if warhighTracksPlayCounter < #warhighTracks then
				warhighTracksPlayCounter = warhighTracksPlayCounter + 1
			else
				warhighTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "warLow" then
			currentTrack = currentTrackList[warlowTracksPlayCounter]
			if warlowTracksPlayCounter < #warlowTracks then
				warlowTracksPlayCounter = warlowTracksPlayCounter + 1
			else
				warlowTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "bossFight" then
			currentTrack = currentTrackList[bossFightTracksPlayCounter]
			if bossFightTracksPlayCounter < #bossFightTracks then
				bossFightTracksPlayCounter = bossFightTracksPlayCounter + 1
			else
				bossFightTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "eventPeace" then
			currentTrack = currentTrackList[eventPeaceTracksPlayCounter]
			if eventPeaceTracksPlayCounter < #eventPeaceTracks then
				eventPeaceTracksPlayCounter = eventPeaceTracksPlayCounter + 1
			else
				eventPeaceTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "eventWarLow" then
			currentTrack = currentTrackList[eventWarLowTracksPlayCounter]
			if eventWarLowTracksPlayCounter < #eventWarLowTracks then
				eventWarLowTracksPlayCounter = eventWarLowTracksPlayCounter + 1
			else
				eventWarLowTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "eventWarHigh" then
			currentTrack = currentTrackList[eventWarHighTracksPlayCounter]
			if eventWarHighTracksPlayCounter < #eventWarHighTracks then
				eventWarHighTracksPlayCounter = eventWarHighTracksPlayCounter + 1
			else
				eventWarHighTracksPlayCounter = 1
			end
		end
		if currentTrackListString == "gameOver" then
			currentTrack = currentTrackList[gameoverTracksPlayCounter]
		end
	elseif #currentTrackList == 0 then
		return
	end

	if currentTrack then
		Spring.PlaySoundStream(currentTrack, 1)
		playing = true

		if string.find(currentTrackListString, "event") then
			interruptionTime = 999999
		else
			interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
			songsSinceEvent = songsSinceEvent + 1
		end

		if fadeDirection then
			setMusicVolume(fadeLevel)
		else
			setMusicVolume(100)
		end
	end

	updateDrawing = true
end

function widget:UnitDamaged(unitID, unitDefID, _, damage)
	if damage > 1 then
		warMeterResetTimer = 0
		local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
		if damage > maxHealth then
			warMeter = math.ceil(warMeter + maxHealth)
		else
			warMeter = math.ceil(warMeter + damage)
		end
		if totalTime == 0 and silenceTimer >= 0 and damage and damage > 0 then
			silenceTimer = silenceTimer - damage*0.001
			--Spring.Echo("silenceTimer: ", silenceTimer)
		end
	end
end

function widget:GameProgress(n)
	-- happens every 150 frames
	serverFrame = n
end

function widget:GameFrame(n)
	gameFrame = n
	if n%1800 == 0 then
		deviceLostSafetyCheck = 0
	end

	updateFade()

	if gameOver and not playedGameOverTrack then
		getFadeSpeed = getFastFadeSpeed
		fadeOutSkipTrack = true
		fadeDirection = -5
	end

	if Spring.Utilities.Gametype.IsRaptors() then
		if (Spring.GetGameRulesParam("raptorQueenAnger", 0)) > 50 then
			warMeter = warHighLevel+1
		elseif (Spring.GetGameRulesParam("raptorQueenAnger", 0)) > 10 then
			warMeter = warLowLevel+1
		else
			warMeter = 0
		end
	elseif Spring.Utilities.Gametype.IsScavengers() then
		if (Spring.GetGameRulesParam("scavBossAnger", 0)) > 50 then
			warMeter = warHighLevel+1
		elseif (Spring.GetGameRulesParam("scavBossAnger", 0)) > 10 then
			warMeter = warLowLevel+1
		else
			warMeter = 0
		end
	elseif warMeter > 0 then
		warMeter = math.floor(warMeter - (warMeter * 0.04))
		if warMeter > warHighLevel*3 then
			warMeter = warHighLevel*3
		end
		warMeterResetTimer = warMeterResetTimer + 1
		if warMeterResetTimer > warMeterResetTime then
			warMeter = 0
		end
	end

	if n%30 == 15 then
		if Spring.GetGameRulesParam("BossFightStarted") and Spring.GetGameRulesParam("BossFightStarted") == 1 then
			bossHasSpawned = true
		else
			bossHasSpawned = false
		end
		if deviceLostSafetyCheck >= 3 then
			return
		end

		if not appliedSpectatorThresholds and Spring.GetSpectatingState() == true then
			applySpectatorThresholds()
		end

		local musicVolume = getMusicVolume()
		--if musicVolume > 0 then
		--	playing = true
		--else
		--	playing = false
		--	silenceTimer = math.random(minSilenceTime,maxSilenceTime)
		--	--Spring.PauseSoundStream()
		--	Spring.StopSoundStream()
		--	return
		--end

		if not gameOver then
			if playedTime > 0 and totalTime > 0 then -- music is playing
				if not fadeDirection then
					Spring.SetSoundStreamVolume(musicVolume)
					if (bossHasSpawned and currentTrackListString ~= "bossFight") or ((not bossHasSpawned) and currentTrackListString == "bossFight") then
						fadeDirection = -2
						fadeOutSkipTrack = true
					elseif (interruptionEnabled and (playedTime >= interruptionTime) and gameFrame >= serverFrame-300)
					  and ((currentTrackListString == "intro" and n > 90)
						or (currentTrackListString == "peace" and warMeter > warHighLevel * 0.5 ) -- Peace in battle times, let's play some WarLow music at half of WarHigh threshold
						or (currentTrackListString == "warLow" and warMeter > warHighLevel * 2 ) -- WarLow music is playing but battle intensity is very high, Let's switch to WarHigh at double of WarHigh threshold
						or (currentTrackListString == "warHigh" and warMeter <= warLowLevel * 0.5 ) -- WarHigh music is playing, but it has been quite peaceful recently. Let's switch to peace music at 50% of WarLow threshold
						or (currentTrackListString == "warLow" and warMeter <= warLowLevel * 0.25 )) then -- WarLow music is playing, but it has been quite peaceful recently. Let's switch to peace music at 25% of WarLow threshold
							fadeDirection = -2
							fadeOutSkipTrack = true
					elseif (playedTime >= totalTime - 12 and Spring.GetConfigInt("UseSoundtrackFades", 1) == 1) then
						fadeDirection = -1
					end
				end
			elseif totalTime == 0 then -- there's no music
				if silenceTimerEnabled and not bossHasSpawned then
					--Spring.Echo("silenceTimer: ", silenceTimer)
					if silenceTimer > 0 then
						silenceTimer = silenceTimer - 1
					elseif silenceTimer <= 0 then
						PlayNewTrack()
					end
				else
					PlayNewTrack()
				end
			end
		end
	end
end

function widget:GameOver(winningAllyTeams)
	gameOver = true
end

function widget:GetConfigData(data)
	return {
		curTrack = currentTrack,
		showGUI = showGUI
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.curTrack ~= nil then
			currentTrack = data.curTrack
		end
	end
	if data.showGUI ~= nil then
		showGUI = data.showGUI
	end
end

function widget:UnitCreated(_, _, _, builderID)
	if builderID and warMeter < warLowLevel and silenceTimer > 0 and totalTime == 0 then
		--Spring.Echo("silenceTimer: ", silenceTimer)
		silenceTimer = silenceTimer - 2
	end
end

function widget:UnitFinished()
	if warMeter < warLowLevel and silenceTimer > 0 and totalTime == 0 then
		--Spring.Echo("silenceTimer: ", silenceTimer)
		silenceTimer = silenceTimer - 5
	end
end

--function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
--
--end
