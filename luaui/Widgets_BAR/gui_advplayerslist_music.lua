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
		name	= "AdvPlayersList Music Player",
		desc	= "Plays music and offers volume controls",
		author	= "Forboding Angel, Floris, Damgam",
		date	= "november 2016",
		license	= "GNU GPL, v2 or later",
		layer	= -4,
		enabled	= true	--	loaded by default?
	}
end

local pauseWhenPaused = false
local fadeInTime = 2
local fadeOutTime = 6.5

-- Unfucked volumes finally. Instead of setting the volume in Spring.PlaySoundStream. you need to call Spring.PlaySoundStream and then immediately call Spring.SetSoundStreamVolume
-- This widget desperately needs to be reorganized

local buttons = {}

local curTrack	= "no name"
local manualPlay = false	-- gets enabled when user loads a track

local musicDir = 'sounds/music/'
local peaceTracks = VFS.DirList(musicDir..'peace', '*.ogg')
local warTracks = VFS.DirList(musicDir..'war', '*.ogg')

local vsx, vsy = Spring.GetViewGeometry()
local borderPaddingRight, borderPaddingLeft, trackname, font, draggingSlider, prevStreamStartTime, force, doCreateList, chobbyInterface

local tracksConfig = {}
for i,v in pairs(peaceTracks) do
	if tracksConfig[v] == nil then
		tracksConfig[v] = {true, 'peace'}
	end
	if v[1] == false then
		peaceTracks[i] = nil
	end
end
for i,v in pairs(warTracks) do
	if tracksConfig[v] == nil then
		tracksConfig[v] = {true, 'war'}
	end
	if v[1] == false then
		warTracks[i] = nil
	end
end

local tracks = peaceTracks

local playedTracks = {}

local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local firstTime = false
local wasPaused = false
local gameOver = false
local playing = (Spring.GetConfigInt('music', 1) == 1)

local playedTime, totalTime = Spring.GetSoundStreamTime()
local targetTime = totalTime

if totalTime > 0 then
	firstTime = true
end

local playTex				= ":l:"..LUAUI_DIRNAME.."Images/music/play.png"
local pauseTex				= ":l:"..LUAUI_DIRNAME.."Images/music/pause.png"
local nextTex				= ":l:"..LUAUI_DIRNAME.."Images/music/next.png"
local musicTex				= ":l:"..LUAUI_DIRNAME.."Images/music/music.png"
local volumeTex				= ":l:"..LUAUI_DIRNAME.."Images/music/volume.png"

local widgetScale = 1
local glScale        = gl.Scale
local glRotate       = gl.Rotate
local glTranslate	 = gl.Translate
local glPushMatrix   = gl.PushMatrix
local glPopMatrix	 = gl.PopMatrix
local glColor        = gl.Color
local glRect         = gl.Rect
local glTexRect	     = gl.TexRect
local glTexture      = gl.Texture
local glCreateList   = gl.CreateList
local glDeleteList   = gl.DeleteList
local glCallList     = gl.CallList

local glBlending = gl.Blending
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA
local GL_ONE = GL.ONE

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element

local guishaderEnabled = (WG['guishader'] ~= nil)

local drawlist = {}
local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0
local borderPadding = 5

local shown = false
local mouseover = false

local dynamicMusic = Spring.GetConfigInt("bar_dynamicmusic", 1)
local interruptMusic = Spring.GetConfigInt("bar_interruptmusic", 1)
local warMeter = 0
local maxWarMeter = 1500


local fadeOut = false
local maxMusicVolume = Spring.GetConfigInt("snd_volmusic", 20)	-- user value, cause actual volume will change during fadein/outc
local volume = Spring.GetConfigInt("snd_volmaster", 100)

local fadeMult = 1
local uiOpacitySec = 0

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

function updateMusicVolume()	-- handles fadings
	playedTime, totalTime = Spring.GetSoundStreamTime()
	if playedTime < fadeInTime then
		fadeMult = playedTime / fadeInTime
	else
		fadeMult = (targetTime-playedTime) / fadeOutTime
	end
	if fadeMult > 1 then fadeMult = 1 end
	if fadeMult < 0 then fadeMult = 0 end
	Spring.SetConfigInt("snd_volmusic", (math.random()*0.1) + (maxMusicVolume * fadeMult))	-- added random value so its unique and forces engine to update (else it wont actually do)
end

function applyTracksConfig()
	local isPeace = (tracks == peaceTracks)
	peaceTracks = {}
	warTracks = {}
	for track, params in pairs(tracksConfig) do
		if params[1] then
			if params[2] == 'peace' then
				peaceTracks[#peaceTracks+1] = track
			else
				warTracks[#warTracks+1] = track
			end
		end
	end
	tracks = (isPeace and peaceTracks or warTracks)
end

function toggleTrack(track, value)
	local isPeace = (tracks == peaceTracks)
	local isPeaceTrack = tracksConfig[track][2] == 'peace'
	tracksConfig[track][1] = value
	if value then
		-- enable
		if isPeaceTrack then
			if not getKeyByValue(peaceTracks, track) then
				peaceTracks[#peaceTracks+1] = track
			end
		else
			if not getKeyByValue(warTracks, track) then
				warTracks[#warTracks+1] = track
			end
		end
	else
		-- disable
		if isPeaceTrack then
			peaceTracks[getKeyByValue(peaceTracks, track)] = nil
		else
			warTracks[getKeyByValue(warTracks, track)] = nil
		end
	end
	applyTracksConfig()
end


function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

function widget:Initialize()
	widget:ViewResize()
	updateMusicVolume()

	if #tracks == 0 then
		Spring.Echo("[Music Player] No music was found, Shutting Down")
		widgetHandler:RemoveWidget()
		return
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
	WG['music'].playTrack = function(track)
		PlayNewTrack(track)
	end
	WG['music'].GetMusicVolume = function()
		return maxMusicVolume
	end
	WG['music'].SetMusicVolume = function(value)
		maxMusicVolume = value
	end
	WG['music'].getTracksConfig = function(value)
		return tracksConfig
	end
	for track, params in pairs(tracksConfig) do
		-- get track
		WG['music']['getTrack'..track] = function()
			return params[1]
		end
		-- set track
		WG['music']['setTrack'..track] = function(value)
			toggleTrack(track, value)
		end
	end
end

local function createList()

	local padding = 2.75*widgetScale -- button background margin
	local padding2 = 2.5*widgetScale -- inner icon padding
	local volumeWidth = 50*widgetScale
	local heightoffset = -(0.9*widgetScale)
	buttons['playpause'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}

	buttons['next'] = {buttons['playpause'][3]+padding, bottom+padding+heightoffset, buttons['playpause'][3]+((widgetHeight*widgetScale)-padding), top-padding+heightoffset}

	buttons['musicvolumeicon'] = {buttons['next'][3]+padding+padding, bottom+padding+heightoffset, buttons['next'][3]+((widgetHeight*widgetScale)), top-padding+heightoffset}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding+heightoffset, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (maxMusicVolume/50)

	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding+heightoffset, buttons['musicvolume'][3]+((widgetHeight*widgetScale)), top-padding+heightoffset}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding+heightoffset, buttons['volumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (volume/200)

	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 7*widgetScale
	local maxTextWidth = right-buttons['next'][3]-textXPadding-textXPadding

	if drawlist[1] ~= nil then
		glDeleteList(drawlist[5])
		glDeleteList(drawlist[1])
		glDeleteList(drawlist[2])
		glDeleteList(drawlist[3])
		glDeleteList(drawlist[4])
	end
	if WG['guishader'] then
		drawlist[5] = glCreateList( function()
			RectRound(left, bottom, right, top, bgpadding*1.6, 1,0,0,1)
		end)
		WG['guishader'].InsertDlist(drawlist[5], 'music')
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
		glTexture(false)

	end)
	drawlist[3] = glCreateList( function()

		-- track name
		glColor(0.45,0.45,0.45,1)
		trackname = string.gsub(curTrack, ".ogg", "")
		trackname = string.gsub(trackname, musicDir.."peace/", "")
		trackname = string.gsub(trackname, musicDir.."war/", "")
		local text = ''
		for i=1, #trackname do
			local c = string.sub(trackname, i,i)
			local width = font:GetTextWidth(text..c)*textsize
			if width > maxTextWidth then
				break
			else
				text = text..c
			end
		end
		trackname = text
		font:Begin()
		font:Print('\255\235\235\235'..trackname, buttons['next'][3]+textXPadding, bottom+(0.3*widgetHeight*widgetScale), textsize, 'no')
		font:End()
	end)
	drawlist[4] = glCreateList( function()

		---glColor(0,0,0,0.5)
		--RectRound(left, bottom, right, top, 5.5*widgetScale)

		local sliderWidth = math.floor((4.5*widgetScale)+0.5)
		local sliderHeight = math.floor((4.5*widgetScale)+0.5)
		local lineHeight = math.floor((1.5*widgetScale)+0.5)

		local button = 'musicvolumeicon'
		local sliderY = buttons[button][2] + (buttons[button][4] - buttons[button][2])/2
		glColor(0.8,0.8,0.8,0.9)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'musicvolume'
		RectRound(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+lineHeight, (lineHeight/3)*widgetScale,2,2,2,2, {0.1,0.1,0.1,0.35}, {0.8,0.8,0.8,0.35})
		RectRound(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+(lineHeight*0.15), (lineHeight/3)*widgetScale,2,2,2,2, {1,1,1,0.17}, {1,1,1,0})
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/7)*widgetScale, 1,1,1,1, {0.6,0.6,0.6,1}, {0.9,0.9,0.9,1})


		button = 'volumeicon'
		glColor(0.8,0.8,0.8,0.9)
		glTexture(volumeTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'volume'
		RectRound(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+lineHeight, (lineHeight/3)*widgetScale,2,2,2,2, {0.1,0.1,0.1,0.35}, {0.8,0.8,0.8,0.35})
		RectRound(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+(lineHeight*0.15), (lineHeight/3)*widgetScale,2,2,2,2, {1,1,1,0.17}, {1,1,1,0})
		RectRound(buttons[button][5]-sliderWidth, sliderY-sliderHeight, buttons[button][5]+sliderWidth, sliderY+sliderHeight, (sliderWidth/7)*widgetScale, 1,1,1,1, {0.6,0.6,0.6,1}, {0.9,0.9,0.9,1})

	end)
	if WG['tooltip'] ~= nil and trackname then
		if trackname and trackname ~= '' then
			WG['tooltip'].AddTooltip('music', {left, bottom, right, top}, trackname, 0.8)
		else
			WG['tooltip'].RemoveTooltip('music')
		end
	end
end

function getSliderValue(button, x)
	local sliderWidth = buttons[button][3] - buttons[button][1]
	local value = (x - buttons[button][1]) / (sliderWidth)
	if value < 0 then value = 0 end
	if value > 1 then value = 1 end
	return value
end


function widget:MouseMove(x, y)
	if draggingSlider ~= nil then
		if draggingSlider == 'musicvolume' then
			maxMusicVolume = math.floor(getSliderValue(draggingSlider, x) * 50)
			Spring.SetConfigInt("snd_volmusic", math.floor(maxMusicVolume * fadeMult))
			createList()
		end
		if draggingSlider == 'volume' then
			volume = math.floor(getSliderValue(draggingSlider, x) * 200)
			Spring.SetConfigInt("snd_volmaster", volume)
			createList()
		end
	end
end

function widget:MousePress(x, y, button)
	return mouseEvent(x, y, button, false)
end

function widget:MouseRelease(x, y, button)
	return mouseEvent(x, y, button, true)
end

function mouseEvent(x, y, button, release)

	if Spring.IsGUIHidden() then return false end
	if button == 1 then
		if not release then
			local sliderWidth = (3.3*widgetScale) -- should be same as in createlist()
			local button = 'musicvolume'
			if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
				draggingSlider = button
				maxMusicVolume = math.floor(getSliderValue(button, x) * 50)
				Spring.SetConfigInt("snd_volmusic", math.floor(maxMusicVolume * fadeMult))
				createList()
			end
			button = 'volume'
			if isInBox(x, y, {buttons[button][1]-sliderWidth, buttons[button][2], buttons[button][3]+sliderWidth, buttons[button][4]}) then
				draggingSlider = button
				volume = math.floor(getSliderValue(button, x) * 200)
				Spring.SetConfigInt("snd_volmaster", volume)
				createList()
			end
		end
		if release and draggingSlider ~= nil then
			draggingSlider = nil
		end
		if button == 1 and not release and isInBox(x, y, {left, bottom, right, top}) then
			if buttons['playpause'] ~= nil and isInBox(x, y, {buttons['playpause'][1], buttons['playpause'][2], buttons['playpause'][3], buttons['playpause'][4]}) then
				playing = not playing
				Spring.SetConfigInt('music', (playing and 1 or 0))
				Spring.PauseSoundStream()
				createList()
				return true
			elseif buttons['next'] ~= nil and isInBox(x, y, {buttons['next'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
				PlayNewTrack()
				return true
			end
			return true
		end
	end

	if mouseover and isInBox(x, y, {left, bottom, right, top}) then
		return true
	end
end


function widget:Shutdown()
	shutdown = true
	Spring.SetConfigInt('music', (playing and 1 or 0))

	--Spring.StopSoundStream()	-- disable music outside of this widget, cause else it restarts on every luaui reload

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

function widget:UnitDamaged(_, _, _, damage)
	warMeter = warMeter + damage
	if warMeter > maxWarMeter then
		warMeter = maxWarMeter
	end
end


function getKeyByValue(t, id)
	for k, v in pairs(t) do
		if v == id then
			return k
		end
	end
	return false
end

function widget:GameFrame(n)
    if n%5 == 4 then
		updateMusicVolume()

		dynamicMusic = Spring.GetConfigInt("bar_dynamicmusic", 1)
		interruptMusic = Spring.GetConfigInt("bar_interruptmusic", 1)

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
			if not manualPlay then
				if interruptMusic == 1 and not fadeOut then
					if tracks == peaceTracks and warMeter >= 200 then
						fadeOut = true
						targetTime = playedTime + fadeOutTime
						if targetTime > totalTime then
							targetTime = totalTime
						end
					elseif (tracks == warTracks and warMeter <= 0) then
						fadeOut = true
						targetTime = playedTime + fadeOutTime
						if targetTime > totalTime then
							targetTime = totalTime
						end
					end
				end
			end
		end
   end
end


local averageSkipTime = 16
function PlayNewTrack(track)
	fadeOut = false
	if prevStreamStartTime then
		local timeDiff = os.clock()-prevStreamStartTime
		averageSkipTime = (timeDiff + (averageSkipTime*7)) / 8
		if averageSkipTime < 1 then
			Spring.Echo("[Music Player] detetected fast track skipping, sound device is probably not working properly")
			widgetHandler:RemoveWidget()
			return
		end
	end
	prevStreamStartTime = os.clock()

	Spring.StopSoundStream()

	if dynamicMusic == 0 then
		--Spring.Echo("Choosing a random track")
		local r = math.random(0,1)
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

	local newTrack
	if track then	-- user initiates manual play of a specific track
		manualPlay = true
		newTrack = track
		if not playing then
			playing = true
			Spring.SetConfigInt('music', (playing and 1 or 0))
		end
	else
		manualPlay = false
		-- make sure tracks dont get repeated until all of them played already
		local attempts = 0
		local maxAttempts = 1000
		if #tracks > 1 then
			local continue = false
			repeat
				newTrack = tracks[math.random(1, #tracks)]
				if not playedTracks[newTrack] then
					playedTracks[newTrack] = true
					continue = true
				end
				attempts = attempts + 1
				if attempts > maxAttempts then
					playedTracks = {}
					continue = true
				end
			until continue
		end
	end
	--Spring.Echo(#tracks, newTrack)
	curTrack = newTrack
	Spring.PlaySoundStream(newTrack)
    Spring.SetSoundStreamVolume(0)
	playedTime, totalTime = Spring.GetSoundStreamTime()
	if playedTime == 0 then playedTime = 0.001 end
	targetTime = totalTime
	if not playing then
		Spring.PauseSoundStream()
	end
	createList()
end

function widget:Update(dt)
	if playing then
		updateMusicVolume()
	end

	local mx, my, mlb = Spring.GetMouseState()
	if isInBox(mx, my, {left, bottom, right, top}) then
		mouseover = true
	end
	local curVolume = Spring.GetConfigInt("snd_volmaster", 100)
	if volume ~= curVolume then
		volume = curVolume
		doCreateList = true
	end
	uiOpacitySec = uiOpacitySec + dt
	if uiOpacitySec > 0.5 then
		uiOpacitySec = 0
		if ui_scale ~= Spring.GetConfigFloat("ui_scale",1) then
			ui_scale = Spring.GetConfigFloat("ui_scale",1)
			widget:ViewResize()
		end
		uiOpacitySec = 0
		if ui_opacity ~= Spring.GetConfigFloat("ui_opacity",0.66) or guishaderEnabled ~= (WG['guishader'] ~= nil)then
			ui_opacity = Spring.GetConfigFloat("ui_opacity",0.66)
			glossMult = 1 + (2-(ui_opacity*2))
			guishaderEnabled = (WG['guishader'] ~= nil)
			doCreateList = true
		end
	end
	if doCreateList then
		createList()
		doCreateList = nil
	end

	if gameOver then
		return
	end

	if not firstTime then
		PlayNewTrack()
		firstTime = true -- pop this cherry
	end

	if playedTime >= targetTime or playedTime == 0 then	-- both zero means track stopped in 8
		PlayNewTrack()
	end

	if pauseWhenPaused and Spring.GetGameSeconds() >= 0 then
    local _, _, paused = Spring.GetGameSpeed()
		if paused ~= wasPaused then
			Spring.PauseSoundStream()
			wasPaused = paused
		end
	end
end

function updatePosition(force)
	if WG['advplayerlist_api'] ~= nil then
		local prevPos = advplayerlistPos
		advplayerlistPos = WG['advplayerlist_api'].GetPosition()		-- returns {top,left,bottom,right,widgetScale}

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

	font = WG['fonts'].getFont()

	bgpadding = Spring.FlowUI.elementPadding

	if prevVsy ~= vsx or prevVsy ~= vsy then
		createList()
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreen()
	if chobbyInterface then return end
	updatePosition()
	local mx, my, mlb = Spring.GetMouseState()
	mouseover = false
	if WG['topbar'] and WG['topbar'].showingQuit() then
		mouseover = false
	else
		if isInBox(mx, my, {left, bottom, right, top}) then
			local curVolume = Spring.GetConfigInt("snd_volmaster", 100)
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
			glCallList(drawlist[2])
			if not mouseover and not draggingSlider or isInBox(mx, my, {buttons['playpause'][1], buttons['next'][2], buttons['next'][3], buttons['next'][4]}) then
				glCallList(drawlist[3])
			else
				glCallList(drawlist[4])
			end
			if mouseover then

			  -- display play progress
			  local progressPx = ((right-left)*(playedTime/totalTime))
			  if progressPx > 1 then
			    if progressPx < borderPadding*5 then
			    	progressPx = borderPadding*5
			    end
			    RectRound(left+borderPaddingLeft, bottom+borderPadding-(1.8*widgetScale), left-borderPaddingRight+progressPx , top-borderPadding, borderPadding*1.4, 2,2,2,2, {0.6,0.6,0.6,ui_opacity*0.14}, {1,1,1,ui_opacity*0.14})
			  end

			  local color = {1,1,1,0.18}
			  local colorHighlight = {1,1,1,0.3}
			  glBlending(GL_SRC_ALPHA, GL_ONE)
			  local button = 'playpause'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					RectRound(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4], borderPadding*0.6, 2,2,2,2, mlb and colorHighlight or color, mlb and colorHighlight or color)
				end
				button = 'next'
				if buttons[button] ~= nil and isInBox(mx, my, {buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4]}) then
					RectRound(buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4], borderPadding*0.6, 2,2,2,2, mlb and colorHighlight or color, mlb and colorHighlight or color)
				end
				glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)
			end
		glPopMatrix()
	end

	if mouseover then
		Spring.SetMouseCursor('cursornormal')
	end
end

function widget:GetConfigData(data)
  local savedTable = {}
  savedTable.curTrack = curTrack
  savedTable.maxMusicVolume = maxMusicVolume
  savedTable.tracksConfig = tracksConfig
  savedTable.playedTracks = playedTracks
  return savedTable
end

function widget:SetConfigData(data)
	if data.maxMusicVolume ~= nil then
		maxMusicVolume = data.maxMusicVolume
	end
	if data.tracksConfig ~= nil and type(data.tracksConfig) == 'table' then
		-- cleanup old removed tracks
		for track,params in pairs(data.tracksConfig) do
			if peaceTracks[getKeyByValue(peaceTracks, track)] or warTracks[getKeyByValue(warTracks, track)] then
				tracksConfig[track] = params
			end
		end
		applyTracksConfig()
	end
	if data.playedTracks ~= nil then
		playedTracks = data.playedTracks
	end
	if Spring.GetGameFrame() > 0 then
		if data.curTrack ~= nil then
			curTrack = data.curTrack
		end
		if data.warMeter ~= nil then
			warMeter = data.warMeter
		end
	else
		local i = Spring.GetConfigInt('musictrack', 1)
		if peaceTracks[i] then
			curTrack = peaceTracks[i]
		end
	end
end
