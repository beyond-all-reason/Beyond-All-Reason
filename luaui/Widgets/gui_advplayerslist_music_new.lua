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
local warHighLevel = 40000
local warMeterResetTime = 30 -- seconds
local interruptionMinimumTime = 20 -- seconds
local interruptionMaximumTime = 60 -- seconds

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
local boomboxTracks = {}
local boomboxCounter = 0

local menuTracks = {}
local loadingTracks = {}

local currentTrack
local peaceTracksPlayCounter, warhighTracksPlayCounter, warlowTracksPlayCounter, bossFightTracksPlayCounter, gameoverTracksPlayCounter, boomboxTracksPlayCounter
local fadeOutSkipTrack = false
local interruptionEnabled
local silenceTimerEnabled
local deviceLostSafetyCheck = 0
local interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
local gameFrame = 0
local serverFrame = 0
local bossHasSpawned = false

local function ReloadMusicPlaylists()
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
	local boomboxTracksNew			= VFS.DirList(musicDirNew..'/boombox', allowedExtensions)
	local bossFightTracksNew		= {}
	if Spring.Utilities.Gametype.IsRaptors() then
		table.append(bossFightTracksNew, VFS.DirList(musicDirNew..'/bossfight/raptors', allowedExtensions))
	elseif Spring.Utilities.Gametype.IsScavengers() then
		table.append(bossFightTracksNew, VFS.DirList(musicDirNew..'/bossfight/scavengers', allowedExtensions))
	else
		table.append(bossFightTracksNew, VFS.DirList(musicDirNew..'/bossfight/raptors', allowedExtensions))
		table.append(bossFightTracksNew, VFS.DirList(musicDirNew..'/bossfight/scavengers', allowedExtensions))
	end

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
	-----------------------------------SETTINGS---------------------------------------

	interruptionEnabled 			= Spring.GetConfigInt('UseSoundtrackInterruption', 1) == 1
	silenceTimerEnabled 			= Spring.GetConfigInt('UseSoundtrackSilenceTimer', 1) == 1
	local newSoundtrackEnabled 		= Spring.GetConfigInt('UseSoundtrackNew', 1) == 1
	local customSoundtrackEnabled	= Spring.GetConfigInt('UseSoundtrackCustom', 1) == 1

	if Spring.GetConfigInt('UseSoundtrackNew', 1) == 0 and Spring.GetConfigInt('UseSoundtrackOld', 0) == 1 then
		Spring.SetConfigInt('UseSoundtrackNew', 1)
		Spring.SetConfigInt('UseSoundtrackOld', 0)
	end
	-------------------------------CREATE PLAYLISTS-----------------------------------

	peaceTracks = {}
	warhighTracks = {}
	warlowTracks = {}
	gameoverTracks = {}
	bossFightTracks = {}
	menuTracks = {}
	loadingTracks = {}

	if newSoundtrackEnabled then
		table.append(peaceTracks, peaceTracksNew)
		table.append(warhighTracks, warhighTracksNew)
		table.append(warlowTracks, warlowTracksNew)
		table.append(gameoverTracks, gameoverTracksNew)
		table.append(bossFightTracks, bossFightTracksNew)
		table.append(menuTracks, menuTracksNew)
		table.append(loadingTracks, loadingTracksNew)
		table.append(boomboxTracks, boomboxTracksNew)
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

	if #boomboxTracks == 0 then
		boomboxTracks = bossFightTracks
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
	boomboxTracks 	= shuffleMusic(boomboxTracks)

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

	if #boomboxTracks > 1 then
		boomboxTracksPlayCounter = math.random(#boomboxTracks)
	else
		boomboxTracksPlayCounter = 1
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
local borderPaddingRight, borderPaddingLeft, font, draggingSlider, doCreateList, mouseover
local buttons = {}
local drawlist = {}
local advplayerlistPos = {}
local widgetScale = 1
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0
local borderPadding = bgpadding

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
	Spring.SetSoundStreamVolume(getMusicVolume() * math.max(math.min(fadeLevel, 100), 0) * 0.01)
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

local function createList()
	local trackname
	local padding = math.floor(2.75 * widgetScale) -- button background margin
	local padding2 = math.floor(2.5 * widgetScale) -- inner icon padding
	local volumeWidth = math.floor(50 * widgetScale)
	local heightoffset = -math.floor(0.9 * widgetScale)
	buttons['playpause'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}
	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding+heightoffset, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding+heightoffset}

	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding+heightoffset, buttons['next'][3]+((widgetHeight * widgetScale)), top-padding+heightoffset}
	--buttons['musicvolumeicon'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding+heightoffset, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (getVolumePos(maxMusicVolume/99))

	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding+heightoffset, buttons['musicvolume'][3]+((widgetHeight * widgetScale)), top-padding+heightoffset}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding+heightoffset, buttons['volumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (getVolumePos(volume/80))

	local textsize = 11 * widgetScale
	local textXPadding = 10 * widgetScale
	--local maxTextWidth = right-buttons['playpause'][3]-textXPadding-textXPadding
	local maxTextWidth = right-textXPadding-textXPadding

	if drawlist[1] ~= nil then
		for i=1, #drawlist do
			glDeleteList(drawlist[i])
		end
	end
	if WG['guishader'] then
		drawlist[5] = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner, 1,0,0,1)
		end)
		WG['guishader'].InsertDlist(drawlist[5], 'music', true)
	end
	drawlist[1] = glCreateList( function()
		UiElement(left, bottom, right, top, 1,0,0,1, 1,1,0,1)
		borderPadding = bgpadding
		borderPaddingRight = borderPadding
		if right >= vsx-0.2 then
			borderPaddingRight = 0
		end
		borderPaddingLeft = borderPadding
		if left <= 0.2 then
			borderPaddingLeft = 0
		end
	end)
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
		glColor(0.8,0.8,0.8,0.9)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		font:Begin()
		font:Print("\255\235\235\235"..trackname, buttons[button][3]+math.ceil(padding2*1.1), bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		font:End()
	end)
	drawlist[4] = glCreateList( function()

		local sliderWidth = math.floor((4.5 * widgetScale)+0.5)
		local lineHeight = math.floor((1.65 * widgetScale)+0.5)

		local button = 'musicvolumeicon'
		local sliderY = math.floor(buttons[button][2] + (buttons[button][4] - buttons[button][2])/2)
		glColor(0.8,0.8,0.8,0.9)
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
		createList()
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
		createList()
	end
	WG['music'].GetShowGui = function()
		return showGUI
	end
	WG['music'].SetShowGui = function(value)
		showGUI = value
	end
	WG['music'].getTracksConfig = function(value)
		local tracksConfig = {}
		for k,v in pairs(menuTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.menu'), processTrackname(v), v}
		end
		for k,v in pairs(loadingTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.loading'), processTrackname(v), v}
		end
		for k,v in pairs(peaceTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.peace'), processTrackname(v), v}
		end
		for k,v in pairs(warlowTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.warlow'), processTrackname(v), v}
		end
		for k,v in pairs(warhighTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.warhigh'), processTrackname(v), v}
		end
		for k,v in pairs(bossFightTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.bossfight'), processTrackname(v), v}
		end
		for k,v in pairs(gameoverTracks) do
			tracksConfig[#tracksConfig+1] = {Spring.I18N('ui.music.gameover'), processTrackname(v), v}
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
		createList()
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
	WG['music'] = nil
end

function widget:ViewResize(newX,newY)
	local prevVsx, prevVsy = vsx, vsy
	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont()

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	UiSlider = WG.FlowUI.Draw.Slider
	UiSliderKnob = WG.FlowUI.Draw.SliderKnob

	if prevVsx ~= vsx or prevVsy ~= vsy then
		createList()
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
			createList()
		end
		if draggingSlider == 'volume' then
			volume = math.ceil(getVolumeCoef(getSliderValue(draggingSlider, x)) * 80)
			Spring.SetConfigInt("snd_volmaster", volume)
			createList()
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
				createList()
			end
			button = 'volume'
			if math_isInRect(x, y, buttons[button][1] - sliderWidth, buttons[button][2], buttons[button][3] + sliderWidth, buttons[button][4]) then
				draggingSlider = button
				volume = math.ceil(getVolumeCoef(getSliderValue(button, x)) * 80)
				Spring.SetConfigInt("snd_volmaster", volume)
				createList()
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
				createList()
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

	if boomboxCounter > 0 and playedTime > 5 then
		boomboxCounter = 0
	end

	if currentTrackListString == "boombox" and playedTime > 60 then -- They didn't skip it, they don't hate it, we can play it in menu on next launch.
		Spring.SetConfigInt("boomboxcaptured", 1)
	end

	if not playingInit then
		playingInit = true
		if playedTime ~= prevPlayedTime then
			if not playing then
				playing = true
				createList()
			end
		else
			if playing then
				playing = false
				createList()
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
			doCreateList = true
		end
		if doCreateList then
			createList()
			doCreateList = nil
		end
	end
end

function widget:DrawScreen()
	if not showGUI then return end
	updatePosition()
	local mx, my, mlb = Spring.GetMouseState()
	mouseover = false
	if WG['topbar'] and WG['topbar'].showingQuit() then
		mouseover = false
	else
		if math_isInRect(mx, my, left, bottom, right, top) then
			local curVolume = Spring.GetConfigInt("snd_volmaster", 80)
			if volume ~= curVolume then
				volume = curVolume
				createList()
			end
			mouseover = true
		end
	end
	if drawlist[1] ~= nil then
		glPushMatrix()
		glCallList(drawlist[1])
		if not mouseover and not draggingSlider and playing and volume > 0 and playedTime < totalTime then
			glCallList(drawlist[3])
		else
			glCallList(drawlist[2])
			glCallList(drawlist[4])
		end
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
		glPopMatrix()
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
	boomboxCounter = boomboxCounter + 1
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

	if gameOver then
		currentTrackList = gameoverTracks
		currentTrackListString = "gameOver"
		playedGameOverTrack = true
	elseif bossHasSpawned then
		currentTrackList = bossFightTracks
		currentTrackListString = "bossFight"
	elseif boomboxCounter >= 4 and #boomboxTracks > 0 then
		currentTrackList = boomboxTracks
		currentTrackListString = "boombox"
	elseif warMeter >= warHighLevel then
		currentTrackList = warhighTracks
		currentTrackListString = "warHigh"
	elseif warMeter >= warLowLevel then
		currentTrackList = warlowTracks
		currentTrackListString = "warLow"
	else
		currentTrackList = peaceTracks
		currentTrackListString = "peace"
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
		if currentTrackListString == "gameOver" then
			currentTrack = currentTrackList[gameoverTracksPlayCounter]
		end
		if currentTrackListString == "boombox" then
			currentTrack = currentTrackList[boomboxTracksPlayCounter]
			if boomboxTracksPlayCounter < #boomboxTracks then
				boomboxTracksPlayCounter = boomboxTracksPlayCounter + 1
			else
				boomboxTracksPlayCounter = 1
			end
			boomboxCounter = 0
		end
	elseif #currentTrackList == 0 then
		return
	end

	if currentTrack then
		Spring.PlaySoundStream(currentTrack, 1)
		playing = true
		interruptionTime = math.random(interruptionMinimumTime, interruptionMaximumTime)
		if fadeDirection and currentTrackListString ~= "boombox" then
			setMusicVolume(fadeLevel)
		else
			setMusicVolume(100)
		end
	end

	createList()
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

		if warMeter > 0 then
			warMeter = math.floor(warMeter - (warMeter * 0.04))
			if warMeter > warHighLevel*3 then
				warMeter = warHighLevel*3
			end
			warMeterResetTimer = warMeterResetTimer + 1
			if warMeterResetTimer > warMeterResetTime then
				warMeter = 0
			end
		end

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

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)

end
