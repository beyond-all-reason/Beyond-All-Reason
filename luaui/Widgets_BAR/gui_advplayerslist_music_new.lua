



local defaultMusicVolume = 50

local warMeter = 0

local musicDir = 'sounds/musicnew/'
local introTracks = VFS.DirList(musicDir..'intro', '*.ogg')
local peaceTracks = VFS.DirList(musicDir..'peace', '*.ogg')
local warhighTracks = VFS.DirList(musicDir..'warhigh', '*.ogg')
local warlowTracks = VFS.DirList(musicDir..'warlow', '*.ogg')
local victoryTracks = VFS.DirList(musicDir..'victory', '*.ogg')
local defeatTracks = VFS.DirList(musicDir..'defeat', '*.ogg')
if #victoryTracks == 0 then victoryTracks = introTracks end
if #defeatTracks == 0 then defeatTracks = introTracks end
local myAllyTeam = Spring.GetMyAllyTeamID()

local currentTrackList = introTracks

local gameOver = false
local playedGameOverTrack = false
local endfadelevel = 999
local silenceTimer = 0

local playedTime, totalTime = Spring.GetSoundStreamTime()

local curTrackName	= "no name"
local prevTrackName = "no name"
local appliedSilence = true
local minSilenceTime = 10
local maxSilenceTime = 60


--- config
local enableSilenceGaps = true
local musicVolume = Spring.GetConfigInt("snd_volmusic", defaultMusicVolume)*0.01
---


local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local UiButton = Spring.FlowUI.Draw.Button
local UiSlider = Spring.FlowUI.Draw.Slider
local UiSliderKnob = Spring.FlowUI.Draw.SliderKnob
local bgpadding = Spring.FlowUI.elementPadding

local elementCorner = Spring.FlowUI.elementCorner

local maxMusicVolume = Spring.GetConfigInt("snd_volmusic", 20)	-- user value, cause actual volume will change during fadein/outc
local volume = Spring.GetConfigInt("snd_volmaster", 100)

local buttons = {}
local drawlist = {}

local advplayerlistPos = {}
local widgetHeight = 22
local top, left, bottom, right = 0,0,0,0
local borderPadding = bgpadding

local uiOpacitySec = 0

local vsx, vsy = Spring.GetViewGeometry()
local ui_opacity = tonumber(Spring.GetConfigFloat("ui_opacity",0.66) or 0.66)
local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale",1) or 1)
local glossMult = 1 + (2-(ui_opacity*2))	-- increase gloss/highlight so when ui is transparant, you can still make out its boundaries and make it less flat

local firstTime = false
local playing = (Spring.GetConfigInt('music', 1) == 1)

local borderPaddingRight, borderPaddingLeft, trackname, font, draggingSlider, prevStreamStartTime, force, doCreateList, chobbyInterface

local playedTime, totalTime = Spring.GetSoundStreamTime()
local targetTime = totalTime

if totalTime > 0 then
	firstTime = true
end

local playTex				= ":l:"..LUAUI_DIRNAME.."Images/music/play.png"
local pauseTex				= ":l:"..LUAUI_DIRNAME.."Images/music/pause.png"
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


function widget:GetInfo()
	return {
		name	= "AdvPlayersList Music Player (orchestral)",
		desc	= "Plays music and offers volume controls",
		author	= "Damgam",
		date	= "2021",
		license	= "i don't care",
		layer	= -4,
		enabled	= false	--	loaded by default?
	}
end

function widget:Initialize()
	widget:ViewResize()
	--Spring.StopSoundStream() -- only for testing purposes

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

function isInBox(mx, my, box)
	return mx > box[1] and my > box[2] and mx < box[3] and my < box[4]
end

local function createList()
	local padding = math.floor(2.75*widgetScale) -- button background margin
	local padding2 = math.floor(2.5*widgetScale) -- inner icon padding
	local volumeWidth = math.floor(50*widgetScale)
	local heightoffset = -math.floor(0.9*widgetScale)
	buttons['playpause'] = {left+padding+padding, bottom+padding+heightoffset, left+(widgetHeight*widgetScale), top-padding+heightoffset}

	buttons['musicvolumeicon'] = {buttons['playpause'][3]+padding+padding, bottom+padding+heightoffset, buttons['playpause'][3]+((widgetHeight*widgetScale)), top-padding+heightoffset}
	buttons['musicvolume'] = {buttons['musicvolumeicon'][3]+padding, bottom+padding+heightoffset, buttons['musicvolumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['musicvolume'][5] = buttons['musicvolume'][1] + (buttons['musicvolume'][3] - buttons['musicvolume'][1]) * (maxMusicVolume/100)

	buttons['volumeicon'] = {buttons['musicvolume'][3]+padding+padding+padding, bottom+padding+heightoffset, buttons['musicvolume'][3]+((widgetHeight*widgetScale)), top-padding+heightoffset}
	buttons['volume'] = {buttons['volumeicon'][3]+padding, bottom+padding+heightoffset, buttons['volumeicon'][3]+padding+volumeWidth, top-padding+heightoffset}
	buttons['volume'][5] = buttons['volume'][1] + (buttons['volume'][3] - buttons['volume'][1]) * (volume/200)

	local textsize = 11*widgetScale
	local textYPadding = 8*widgetScale
	local textXPadding = 7*widgetScale
	local maxTextWidth = right-buttons['playpause'][3]-textXPadding-textXPadding

	if drawlist[1] ~= nil then
		glDeleteList(drawlist[5])
		glDeleteList(drawlist[1])
		glDeleteList(drawlist[2])
		glDeleteList(drawlist[3])
		glDeleteList(drawlist[4])
	end
	if WG['guishader'] then
		drawlist[5] = glCreateList( function()
			RectRound(left, bottom, right, top, elementCorner, 1,0,0,1)
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
	end)
	drawlist[3] = glCreateList( function()

		-- track name
		trackname = curTrack or ''
		glColor(0.45,0.45,0.45,1)
		trackname = string.gsub(trackname, ".ogg", "")
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
	end)
	drawlist[4] = glCreateList( function()

		local sliderWidth = math.floor((4.5*widgetScale)+0.5)
		local sliderHeight = math.floor((4.5*widgetScale)+0.5)
		local lineHeight = math.floor((1.5*widgetScale)+0.5)

		local button = 'musicvolumeicon'
		local sliderY = math.floor(buttons[button][2] + (buttons[button][4] - buttons[button][2])/2)
		glColor(0.8,0.8,0.8,0.9)
		glTexture(musicTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'musicvolume'
		UiSlider(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+lineHeight)
		UiSliderKnob(buttons[button][5]-(sliderWidth/2), sliderY, sliderWidth)

		button = 'volumeicon'
		glColor(0.8,0.8,0.8,0.9)
		glTexture(volumeTex)
		glTexRect(buttons[button][1]+padding2, buttons[button][2]+padding2, buttons[button][3]-padding2, buttons[button][4]-padding2)
		glTexture(false)

		button = 'volume'
		UiSlider(buttons[button][1], sliderY-math.ceil(lineHeight*1.15), buttons[button][3], sliderY+lineHeight)
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
	elementCorner = Spring.FlowUI.elementCorner

	if prevVsy ~= vsx or prevVsy ~= vsy then
		createList()
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
			maxMusicVolume = math.floor(getSliderValue(draggingSlider, x) * 100)
			Spring.SetConfigInt("snd_volmusic", math.floor(maxMusicVolume))
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
				maxMusicVolume = math.floor(getSliderValue(button, x) * 100)
				Spring.SetConfigInt("snd_volmusic", math.floor(maxMusicVolume))
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
			end
			return true
		end
	end

	if mouseover and isInBox(x, y, {left, bottom, right, top}) then
		return true
	end
end

function widget:Update(dt)
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
		glCallList(drawlist[4])
		if mouseover then

			-- display play progress
			local progressPx = math.floor((right - left) * (playedTime / totalTime))
			if progressPx > 1 then
				if progressPx < borderPadding * 5 then
					progressPx = borderPadding * 5
				end
				RectRound(left + borderPaddingLeft, bottom + borderPadding - (1.8 * widgetScale), left - borderPaddingRight + progressPx, top - borderPadding, borderPadding * 1.4, 2, 2, 2, 2, { 0.6, 0.6, 0.6, ui_opacity * 0.14 }, { 1, 1, 1, ui_opacity * 0.14 })
			end

			local color = { 1, 1, 1, 0.1 }
			local colorHighlight = { 1, 1, 1, 0.3 }
			glBlending(GL_SRC_ALPHA, GL_ONE)
			local button = 'playpause'
			if buttons[button] ~= nil and isInBox(mx, my, { buttons[button][1], buttons[button][2], buttons[button][3], buttons[button][4] }) then
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

function PlayNewTrack()
	Spring.StopSoundStream()
	appliedSilence = false
	prevTrack = curTrack
	curTrack = nil
	--Spring.Echo("[NewMusicPlayer] Warmeter: "..warMeter)

	currentTrackList = nil
	if gameOver == true then
		if VictoryMusic == true then
			currentTrackList = victoryTracks
			playedGameOverTrack = true
		else
			currentTrackList = defeatTracks
			playedGameOverTrack = true
		end
	elseif warMeter >= 20000 then
		currentTrackList = warhighTracks
		--Spring.Echo("[NewMusicPlayer] Playing warhigh track")
	elseif warMeter >= 1000 then
		currentTrackList = warlowTracks
		--Spring.Echo("[NewMusicPlayer] Playing warlow track")
	else
		currentTrackList = peaceTracks
		--Spring.Echo("[NewMusicPlayer] Playing peace track")
	end

	if not currentTrackList  then
		--Spring.Echo("[NewMusicPlayer] there is some issue with getting track list")
		return
	end

	if #currentTrackList > 1 then
		repeat
			curTrack = currentTrackList[math.random(1,#currentTrackList)]
		until(curTrack ~= prevTrack)
	elseif #currentTrackList == 1 then
		curTrack = currentTrackList[1]
	elseif #currentTrackList == 0 then
		--Spring.Echo("[NewMusicPlayer] empty track list")
		return
	end

	if curTrack then
		local musicVolume = (Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))*0.01
		Spring.PlaySoundStream(curTrack, 1)
		Spring.SetSoundStreamVolume(musicVolume)
	end
	warMeter = 0
end


function widget:UnitDamaged(unitID,unitDefID,_,damage)
	if damage > 1 then
		local curHealth, maxHealth = Spring.GetUnitHealth(unitID)
		if damage > maxHealth then
			local damage = maxHealth
			warMeter = math.ceil(warMeter + damage)
		else
			warMeter = math.ceil(warMeter + damage)
		end
	end
end

function widget:GameFrame(n)
	if not playing then return end

	--if n == 1 then
		--Spring.StopSoundStream()
	--end
	if gameOver == true and playedGameOverTrack == false and endfadelevel ~= 999 then
		endfadelevel = endfadelevel - ((Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))/45)
		local musicVolume = endfadelevel*0.01
		Spring.SetSoundStreamVolume(musicVolume)
	end
	if n%30 == 15 or gameOver == true then
		playedTime, totalTime = Spring.GetSoundStreamTime()
		if gameOver == false then
			if playedTime > 0 and totalTime > 0 then -- music is playing
				local musicVolume = (Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))*0.01
				Spring.SetSoundStreamVolume(musicVolume)
				if warMeter > 0 then
					warMeter = math.floor(warMeter - (warMeter*0.02))
					--Spring.Echo("[NewMusicPlayer] Warmeter: ".. warMeter)
				end
			elseif totalTime == 0 then -- there's no music
				if appliedSilence == true and silenceTimer <= 0 then
					PlayNewTrack()
				elseif appliedSilence == false and silenceTimer <= 0 then
					if enableSilenceGaps == true then
						silenceTimer = math.random(minSilenceTime,maxSilenceTime)
						--Spring.Echo("[NewMusicPlayer] Silence Time: ".. silenceTimer)
					else
						silenceTimer = 1
					end
					appliedSilence = true
				elseif appliedSilence == true and silenceTimer > 0 then
					silenceTimer = silenceTimer - 1
					--Spring.Echo("[NewMusicPlayer] Silence Time Left: ".. silenceTimer)
					if warMeter > 0 then
						warMeter = math.floor(warMeter - (warMeter*0.02))
						--Spring.Echo("[NewMusicPlayer] Warmeter: ".. warMeter)
					end
				end
			end
		end
		if gameOver == true and playedGameOverTrack == false then
			if totalTime > 0 then
				if endfadelevel == 999 then
					endfadelevel = (Spring.GetConfigInt("snd_volmusic", defaultMusicVolume))
				elseif endfadelevel <= 0 then
					silenceTimer = 0
					PlayNewTrack()
				end
			else
				PlayNewTrack()
			end
		end
	end
end

function widget:GameOver(winningAllyTeams)
	gameOver = true
	
	--local myTeamID = Spring.GetMyTeamID()
	--local myTeamUnits = Spring.GetTeamUnits(myTeamID)

	VictoryMusic = false
	
	for i = 1,#winningAllyTeams do
		
		local winningAllyTeam = winningAllyTeams[i]
		if winningAllyTeam == myAllyTeam then
			VictoryMusic = true
			break
		end
		
		--if #myTeamUnits > 0  then
		--	VictoryMusic = true
		--elseif #myTeamUnits == 0 then
		--	VictoryMusic = false
		--end

	end
end

function widget:GetConfigData(data)
	return {curTrack = curTrack}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 then
		if data.curTrack ~= nil then
			curTrack = data.curTrack
		end
	end
end

