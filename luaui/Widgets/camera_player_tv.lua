local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Player-TV",
		desc = "Automatically tracks players camera, (shows player-switch countdown on top of the playerlist)",
		author = "Floris",
		date = "January 2018",
		license = "GNU GPL, v2 or later",
		layer = -2,
		enabled = true,
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 0) == 1		-- much faster than drawing via DisplayLists only

--[[ Commands
	/playerview #playerID		(playerID is optional)
	/playertv #playerID			(playerID is optional)
	/playercamera
]]--

local displayPlayername = true
local alwaysDisplayName = true
local playerChangeDelay = 40
local widgetHeight = 22


local fontfile2 = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")

local parentPos = {}
local drawlistsCountdown = {}
local drawlistsPlayername = {}
local fontSize = 12    -- countdown font
local top, left, bottom, right = 0, 0, 0, 0
local rejoining = false
local initGameframe = Spring.GetGameFrame()
local prevOrderID = 1

local currentTrackedPlayer
local playersTS = {}
local nextTrackingPlayerChange = os.clock() - 200

local tsOrderedPlayers = {}

local teamList = Spring.GetTeamList()
local isSpec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myTeamPlayerID = select(2, Spring.GetTeamInfo(myTeamID))
local vsx, vsy = Spring.GetViewGeometry()
local widgetScale = (0.7 + (vsx * vsy / 5000000))

local toggled = false
local toggled2 = not fullview
local drawlist = {}
local desiredLosmodeChanged = 0

local math_isInRect = math.isInRect

local playersList = Spring.GetPlayerList()
local spGetTeamColor = Spring.GetTeamColor
local spGetPlayerInfo = Spring.GetPlayerInfo

local aiTeams = {}
local teamColorKeys = {}
for i = 1, #teamList do
	local r, g, b, a = spGetTeamColor(teamList[i])
	teamColorKeys[teamList[i]] = r..'_'..g..'_'..b
	local _, _, _, isAiTeam = Spring.GetTeamInfo(teamList[i], false)
	if isAiTeam then
		aiTeams[teamList[i]] = true
	end
end

local font, font2, lockPlayerID, prevLockPlayerID, toggleButton, toggleButton2, toggleButton3, backgroundGuishader, showBackgroundGuishader, scheduledSpecFullView, desiredLosmode
local RectRound, elementCorner, bgpadding

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

local function tsOrderPlayers()
	tsOrderedPlayers = {}
	for _, playerID in ipairs(playersList) do
		if playersTS[playerID] then
			local _, _, spec, teamID = spGetPlayerInfo(playerID, false)
			if not spec then
				tsOrderedPlayers[#tsOrderedPlayers+1] = {playersTS[playerID], playerID}
			end
		end
	end
	local function compare(a,b)
		return a[1] > b[1]
	end
	table.sort(tsOrderedPlayers, compare)
end

local function GetSkill(playerID)
	local customtable = select(11, spGetPlayerInfo(playerID)) -- player custom table
	local tsMu = customtable.skill
	return tsMu and tonumber(tsMu:match("-?%d+%.?%d*")) or 0
end

local function SelectTrackingPlayer(playerID)
	local newTrackedPlayer
	local active = false
	local spec = false
	if playerID then
		_, active, spec = spGetPlayerInfo(playerID, false)
	end

	if playerID and (not spec) and active then
		newTrackedPlayer = playerID
	else
		local highestTs = 0
		for _, playerID in ipairs(playersList) do
			local _, active, spec = spGetPlayerInfo(playerID, false)
			if not spec and active then
				if playersTS[playerID] ~= nil and playersTS[playerID] > highestTs+math.random(-10,10) then
					highestTs = playersTS[playerID]
					newTrackedPlayer = playerID
				end
			end
		end
	end

	if newTrackedPlayer ~= nil and newTrackedPlayer ~= currentTrackedPlayer then
		currentTrackedPlayer = newTrackedPlayer

		if WG.lockcamera ~= nil and WG.lockcamera.SetPlayerID ~= nil then
			WG.lockcamera.SetPlayerID(currentTrackedPlayer)
		end
	end

end

local function createCountdownLists()
	for i = 1, #drawlistsCountdown do
		gl.DeleteList(drawlistsCountdown[i])
	end
	drawlistsCountdown = {}
	local i = 0
	local rightPadding = 10 * widgetScale
	while i < playerChangeDelay do
		drawlistsCountdown[i] = gl.CreateList(function()
			font:Begin()
			font:SetTextColor(0, 0, 0, 0.6)
			font:Print(i, right - rightPadding - (0.7 * widgetScale), bottom + (widgetHeight* 1.2 * widgetScale), fontSize * widgetScale, 'rn')
			font:Print(i, right - rightPadding + (0.7 * widgetScale), bottom + (widgetHeight* 1.2 * widgetScale), fontSize * widgetScale, 'rn')
			font:SetTextColor(0.88, 0.88, 0.88, 1)
			font:Print(i, right - rightPadding, bottom + (widgetHeight* 1.22 * widgetScale), fontSize * widgetScale, 'rn')
			font:End()
		end)
		i = i + 1
	end
end

local function refreshUiDrawing()
	for i = 1, #drawlist do
		gl.DeleteList(drawlist[i])
	end

	local buttonOpacity = useRenderToTexture and 0.87 or 0.66
	local mult = useRenderToTexture and 1.33 or 1

	drawlist = {}
	drawlist[1] = gl.CreateList(function()
		local fontSize = (widgetHeight * widgetScale) * 0.5

		local text, color1, color2
		font:Begin()

		-- Player TV Button
		if not toggled and not lockPlayerID then
			text = '\255\222\255\222   ' .. Spring.I18N('ui.playerTV.playerTV') .. '    '
			color1 = { 0, 0.8*mult, 0, buttonOpacity }
			color2 = { 0, 0.55*mult, 0, buttonOpacity }
		else
			text = '\255\255\222\222   ' .. (nextTrackingPlayerChange - os.clock() > -1 and Spring.I18N('ui.playerTV.cancelPlayerTV') or Spring.I18N('ui.playerTV.cancelCamera')) .. '    '
			color1 = { 0.88*mult, 0.1*mult, 0.1*mult, buttonOpacity }
			color2 = { 0.6*mult, 0.05*mult, 0.05*mult, buttonOpacity }
		end
		local textWidth = font:GetTextWidth(text) * fontSize
		if isSpec or lockPlayerID then
			toggleButton = { right - textWidth, bottom, right, top }
			RectRound(toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4], elementCorner, 1, 0, 1, 0, color1, color2)
			RectRound(toggleButton[1] + bgpadding, toggleButton[2], toggleButton[3], toggleButton[4] - bgpadding, elementCorner*0.66, 1, 0, 1, 0, { 0.3, 0.3, 0.3, 0.25*mult }, { 0.05, 0.05, 0.05, 0.25*mult })
			font:Print(text, toggleButton[3]-((toggleButton[3]-toggleButton[1])/2), toggleButton[2] + (7 * widgetScale), fontSize, 'oc')
		else
			toggleButton = { right, bottom, right, top }
		end

		-- Player Camera Button
		if isSpec and not toggled and not lockPlayerID and not aiTeams[myTeamID] then
			text = '\255\240\240\240   ' .. Spring.I18N('ui.playerTV.playerCamera') .. '   '
			color1 = { 0.6*mult, 0.6*mult, 0.6*mult, buttonOpacity }
			color2 = { 0.4*mult, 0.4*mult, 0.4*mult, buttonOpacity }
			textWidth = math.floor(font:GetTextWidth(text) * fontSize)
			toggleButton3 = { toggleButton[1] - textWidth-bgpadding, bottom, toggleButton[1]-bgpadding, top }
			RectRound(toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4], elementCorner, 1, 1, 0, toggleButton3[1] < left and 1 or 0, color1, color2)
			RectRound(toggleButton3[1] + bgpadding, toggleButton3[2], toggleButton3[3]-bgpadding, toggleButton3[4] - bgpadding, elementCorner*0.66, 1, 1, 0, toggleButton3[1] < left and 1 or 0, { 0.3, 0.3, 0.3, 0.25*mult }, { 0.05, 0.05, 0.05, 0.25*mult })
			font:Print(text, toggleButton3[3]-((toggleButton3[3]-toggleButton3[1])/2), toggleButton3[2] + (7 * widgetScale), fontSize, 'oc')
		else
			toggleButton3 = toggleButton
		end

		-- Player Viewpoint Button
		if not toggled2 then
			text = '\255\240\240\240   ' .. Spring.I18N('ui.playerTV.playerView') .. '   '
			color1 = { 0.6*mult, 0.6*mult, 0.6*mult, buttonOpacity }
			color2 = { 0.4*mult, 0.4*mult, 0.4*mult, buttonOpacity }
		else
			text = '\255\240\240\240   ' .. Spring.I18N('ui.playerTV.globalView') .. '   '
			color1 = { 0.88*mult, 0.1*mult, 0.1*mult, buttonOpacity }
			color2 = { 0.6*mult, 0.05*mult, 0.05*mult, buttonOpacity }
		end
		textWidth = math.floor(font:GetTextWidth(text) * fontSize)
		if toggled or lockPlayerID or aiTeams[myTeamID] then
			toggleButton2 = { toggleButton[1] - textWidth-bgpadding, bottom, toggleButton[1]-bgpadding, top }
		else
			toggleButton2 = { toggleButton3[1] - textWidth-bgpadding, bottom, toggleButton3[1]-bgpadding, top }
		end
		if isSpec then
			RectRound(toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4], elementCorner, 1, 1, 0, toggleButton2[1] < left and 1 or 0, color1, color2)
			RectRound(toggleButton2[1] + bgpadding, toggleButton2[2], toggleButton2[3]-bgpadding, toggleButton2[4] - bgpadding, elementCorner*0.66, 1, 1, 0, toggleButton2[1] < left and 1 or 0, { 0.3, 0.3, 0.3, 0.25*mult }, { 0.05, 0.05, 0.05, 0.25*mult })
			font:Print(text, toggleButton2[3]-((toggleButton2[3]-toggleButton2[1])/2), toggleButton2[2] + (7 * widgetScale), fontSize, 'oc')
		end
		font:End()
	end)
	drawlist[2] = gl.CreateList(function()
		-- Player TV Button highlight
		if toggled or lockPlayerID then
			gl.Color(1*mult, 0.2*mult, 0.2*mult, buttonOpacity)
		else
			gl.Color(0.2*mult, 1*mult, 0.2*mult, buttonOpacity)
		end
		RectRound(toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4], elementCorner, 1, 1, 1, 0)
		gl.Color(0, 0, 0, 0.14*mult)
		RectRound(toggleButton[1] + bgpadding, toggleButton[2], toggleButton[3], toggleButton[4] - bgpadding, elementCorner*0.66, 1, 1, 1, 0)

		local text = '\255\255\225\225   ' .. (nextTrackingPlayerChange - os.clock() > -1 and Spring.I18N('ui.playerTV.cancelPlayerTV') or Spring.I18N('ui.playerTV.cancelCamera')) .. '    '
		if not toggled and not lockPlayerID then
			text = '\255\225\255\225   ' .. Spring.I18N('ui.playerTV.playerTV') .. '    '
		end
		local fontSize = (widgetHeight * widgetScale) * 0.5
		local textWidth = math.floor(font:GetTextWidth(text) * fontSize)
		font:Begin()
		font:Print(text, toggleButton[3] - (textWidth / 2), toggleButton[2] + (0.32 * widgetHeight * widgetScale), fontSize, 'oc')
		font:End()
	end)
	drawlist[3] = gl.CreateList(function()
		-- Player Viewpoint Button highlight
		if toggled2 then
			gl.Color(0.85*mult, 0.2*mult, 0.2*mult, 0.4*mult)
		else
			gl.Color(0.85*mult, 0.85*mult, 0.85*mult, 0.4*mult)
		end
		RectRound(toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4], elementCorner, 1, 1, 0, toggleButton2[1] < left and 1 or 0)
		gl.Color(0, 0, 0, 0.14*mult)
		RectRound(toggleButton2[1] + bgpadding, toggleButton2[2], toggleButton2[3]-bgpadding, toggleButton2[4] - bgpadding, elementCorner*0.66, 1, 1, 0, toggleButton2[1] < left and 1 or 0)

		local text = '\255\255\255\244   ' .. Spring.I18N('ui.playerTV.globalView') .. '   '
		if not toggled2 then
			text = '\255\255\255\255   ' .. Spring.I18N('ui.playerTV.playerView') .. '   '
		end
		local fontSize = (widgetHeight * widgetScale) * 0.5
		local textWidth = math.floor(font:GetTextWidth(text) * fontSize)
		font:Begin()
		font:Print(text, toggleButton2[3] - (textWidth / 2), toggleButton2[2] + (0.32 * widgetHeight * widgetScale), fontSize, 'oc')
		font:End()
	end)
	if not toggled and not aiTeams[myTeamID] then
		drawlist[4] = gl.CreateList(function()
			-- Player Camera Button highlight
			if toggled2 then
				gl.Color(0.85*mult, 0.2*mult, 0.2*mult, 0.4*mult)
			else
				gl.Color(0.85*mult, 0.85*mult, 0.85*mult, 0.4*mult)
			end
			RectRound(toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4], elementCorner, 1, 1, 0, toggleButton3[1] < left and 1 or 0)
			gl.Color(0, 0, 0, 0.14*mult)
			RectRound(toggleButton3[1] + bgpadding, toggleButton3[2], toggleButton3[3]-bgpadding, toggleButton3[4] - bgpadding, elementCorner*0.66, 1, 1, 0, toggleButton3[1] < left and 1 or 0)

			local text = '\255\255\255\244   ' .. Spring.I18N('ui.playerTV.playerCamera') .. '   '
			local fontSize = (widgetHeight * widgetScale) * 0.5
			local textWidth = math.floor(font:GetTextWidth(text) * fontSize)
			font:Begin()
			font:Print(text, toggleButton3[3] - (textWidth / 2), toggleButton3[2] + (0.32 * widgetHeight * widgetScale), fontSize, 'oc')
			font:End()
		end)
	end

	if WG['guishader'] and (isSpec or lockPlayerID) then
		if backgroundGuishader then
			backgroundGuishader = gl.DeleteList(backgroundGuishader)
		end
		backgroundGuishader = gl.CreateList(function()
			if isSpec then
				RectRound(toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4], elementCorner, 1, 0, 0, 0)
				if toggleButton2 then
					RectRound(toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4], elementCorner, 1, 1, 0, toggleButton2[1] < left and 1 or 0)
				end
			end
			if not toggled and not lockPlayerID and not aiTeams[myTeamID] then
				RectRound(toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4], elementCorner, 1, 1, 0, toggleButton3[1] < left and 1 or 0)
			end
		end)
		WG['guishader'].InsertDlist(backgroundGuishader, 'playertv', true)
		showBackgroundGuishader = true
	end
end

local function updatePosition()
	local prevPos = parentPos
	if WG['displayinfo'] ~= nil then
		parentPos = WG['displayinfo'].GetPosition()        -- returns {top,left,bottom,right,widgetScale}
	elseif WG['unittotals'] ~= nil then
		parentPos = WG['unittotals'].GetPosition()        -- returns {top,left,bottom,right,widgetScale}
	elseif WG['music'] ~= nil then
		parentPos = WG['music'].GetPosition()        -- returns {top,left,bottom,right,widgetScale}
	elseif WG['advplayerlist_api'] ~= nil then
		parentPos = WG['advplayerlist_api'].GetPosition()        -- returns {top,left,bottom,right,widgetScale}
	else
		local scale = (vsy / 880) * (1 + (Spring.GetConfigFloat("ui_scale", 1) - 1) / 1.25)
		parentPos = {0,vsx-(220*scale),0,vsx,scale}
	end
	if parentPos[5] ~= nil then
		left = parentPos[2]
		bottom = parentPos[1]
		right = parentPos[4]
		top = parentPos[1] + math.floor(widgetHeight * parentPos[5])
		widgetScale = parentPos[5]
		if prevPos[1] == nil or prevPos[1] ~= parentPos[1] or prevPos[2] ~= parentPos[2] or prevPos[5] ~= parentPos[5] then
			widget:ViewResize()
		end
	end
end

function widget:GameStart()
	isSpec, fullview = Spring.GetSpectatingState()
	nextTrackingPlayerChange = os.clock()-0.3
	tsOrderPlayers()
	if isSpec and not rejoining and toggled then
		SelectTrackingPlayer()
	end
	if isSpec or lockPlayerID then
		updateDrawing = true
	end
end

function widget:PlayerChanged(playerID)
	myTeamID = Spring.GetMyTeamID()
	myTeamPlayerID = select(2, Spring.GetTeamInfo(myTeamID))
	isSpec, fullview = Spring.GetSpectatingState()
	tsOrderPlayers()
	local receateLists = false
	if not rejoining then
		if playerID ~= currentTrackedPlayer then
			SelectTrackingPlayer()
			receateLists = true
		end
	end
	local name = spGetPlayerInfo(playerID, false)
	if select(4, Spring.GetTeamInfo(myTeamID,false)) then	-- is AI?
		local _, _, _, aiName = Spring.GetAIInfo(myTeamID)
		local niceName = Spring.GetGameRulesParam('ainame_' .. myTeamID)
		name = niceName or aiName
	end
	if name and drawlistsPlayername[name] then
		drawlistsPlayername[name] = gl.DeleteList(drawlistsPlayername[name])
	end
	if receateLists then
		updateDrawing = true
	end
end


local function switchPlayerCam()
	nextTrackingPlayerChange = os.clock() + playerChangeDelay
	local tsOrderedPlayerCount = #tsOrderedPlayers
	local scope = 1 + math.floor(1 + tsOrderedPlayerCount / 1.33)
	if tsOrderedPlayerCount <= 2 then
		scope = 2
	elseif tsOrderedPlayerCount <= 6 then
		scope = 1 + math.floor(1 + tsOrderedPlayerCount / 1.15)
	elseif tsOrderedPlayerCount <= 10 then
		scope = 1 + math.floor(1 + tsOrderedPlayerCount / 1.22)
	end
	local orderID = math.random(1, scope)

	local r = math.random()
	orderID = 1 + math.floor((r * (r * r)) * scope)
	if orderID == prevOrderID then
		-- prevent same player POV again
		orderID = orderID - 1
		if orderID < 1 then
			orderID = 2
		end
	end
	prevOrderID = orderID
	if tsOrderedPlayers[orderID] then
		SelectTrackingPlayer(tsOrderedPlayers[orderID][2])
	end
end

local sec = 0.5
function widget:Update(dt)

	sec = sec + dt
	if sec > 1 then

		-- check if team colors have changed
		local detectedChanges = false
		for i = 1, #teamList do
			local r, g, b, a = spGetTeamColor(teamList[i])
			if teamColorKeys[teamList[i]] ~= r..'_'..g..'_'..b then
				teamColorKeys[teamList[i]] = r..'_'..g..'_'..b
				detectedChanges = true
			end
		end
		if detectedChanges then
			widget:ViewResize()
		end
	end

	if scheduledSpecFullView ~= nil then
		-- this is needed else the minimap/world doesnt update properly
		Spring.SendCommands("specfullview")
		scheduledSpecFullView = scheduledSpecFullView - 1
		if scheduledSpecFullView == 0 then
			scheduledSpecFullView = nil
		end
	end
	if desiredLosmodeChanged + 0.3 > os.clock() then
		if desiredLosmode ~= Spring.GetMapDrawMode() then
			-- this is needed else the minimap/world doesnt update properly
			Spring.SendCommands("togglelos")
		end
	end

	local prevRejoining = rejoining
	if WG['rejoin'] then
		rejoining = WG['rejoin'].showingRejoining()
	end
	if isSpec and toggled and Spring.GetGameFrame() % 30 == 5 then
		if rejoining and prevRejoining ~= rejoining then
			SelectTrackingPlayer()
		elseif rejoining and WG.lockcamera and WG.lockcamera.GetPlayerID() ~= nil then
			WG.lockcamera.SetPlayerID()
			nextTrackingPlayerChange = 0
		end

		if currentTrackedPlayer ~= nil and not rejoining then
			local _, active, spec = spGetPlayerInfo(currentTrackedPlayer, false)
			if not active or spec then
				SelectTrackingPlayer()
			end
		end
	end
	if not toggled2 and not fullview then
		toggled2 = true
		updateDrawing = true
	elseif toggled2 and fullview then
		toggled2 = false
		updateDrawing = true
	end

	updatePosition()

	local mx, my = Spring.GetMouseState()
	local prevButtonHovered = buttonHovered
	buttonHovered = nil
	if math_isInRect(mx, my, left, bottom, right, top) then
		if (isSpec or lockPlayerID) and toggleButton ~= nil and drawlist[2] and math_isInRect(mx, my, toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4]) then
			buttonHovered = 1
		end
		if isSpec and toggleButton2 ~= nil and drawlist[3] and math_isInRect(mx, my, toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4]) then
			buttonHovered = 2
		end
		if (isSpec and not lockPlayerID) and not toggled and toggleButton3 ~= nil and drawlist[4] and math_isInRect(mx, my, toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4]) then
			buttonHovered = 3
		end
	end
	if (buttonHovered and buttonHovered ~= prevButtonHovered) or (prevButtonHovered and prevButtonHovered ~= buttonHovered) then
		updateDrawing = true
	end

	if (isSpec or lockPlayerID) and not rejoining then
		if WG['tooltip'] and not toggled and not lockPlayerID then
			if buttonHovered and buttonHovered == 1 then
				Spring.SetMouseCursor('cursornormal')
				WG['tooltip'].ShowTooltip('playertv', Spring.I18N('ui.playerTV.tooltip'))
			end
			if buttonHovered and buttonHovered == 2 then
				Spring.SetMouseCursor('cursornormal')
				WG['tooltip'].ShowTooltip('playertv', Spring.I18N('ui.playerTV.playerViewTooltip'))
			end
			if buttonHovered and buttonHovered == 3 then
				Spring.SetMouseCursor('cursornormal')
				WG['tooltip'].ShowTooltip('playertv', Spring.I18N('ui.playerTV.playerCameraTooltip'))
			end
		end

		-- Player TV: switch player
		if toggled and os.clock() > nextTrackingPlayerChange and Spring.GetGameFrame() > initGameframe + 70 then
			switchPlayerCam()
		end
	end
end

local function drawContent()
	local gameFrame = Spring.GetGameFrame()
	if (rejoining or gameFrame == 0) and not lockPlayerID then
		if WG['guishader'] then
			WG['guishader'].RemoveDlist('playertv')
		end
	elseif backgroundGuishader and not showBackgroundGuishader then
		WG['guishader'].InsertDlist(backgroundGuishader, 'playertv', true)
		showBackgroundGuishader =  true
	end

	-- hover highlight
	if drawlist[1] then
		gl.PushMatrix()
		gl.CallList(drawlist[1])
		gl.PopMatrix()
		local mx, my, mb = Spring.GetMouseState()
		if (isSpec or lockPlayerID) and toggleButton ~= nil and drawlist[2] and math_isInRect(mx, my, toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4]) then
			gl.CallList(drawlist[2])
		end
		if isSpec and toggleButton2 ~= nil and drawlist[3] and math_isInRect(mx, my, toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4]) then
			gl.CallList(drawlist[3])
		end
		if (isSpec and not lockPlayerID) and not toggled and toggleButton3 ~= nil and drawlist[4] and math_isInRect(mx, my, toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4]) then
			gl.CallList(drawlist[4])
		end
	end

	if toggled and not rejoining then
		local countDown = math.floor(nextTrackingPlayerChange - os.clock())
		if drawlistsCountdown[countDown] ~= nil then
			gl.PushMatrix()
			gl.CallList(drawlistsCountdown[countDown])
			gl.PopMatrix()
		end
	end
	if displayPlayername then
		if WG['advplayerlist_api'] and WG.lockcamera then
			if not lockPlayerID or lockPlayerID ~= WG.lockcamera.GetPlayerID() and nextTrackingPlayerChange-os.clock() < 0 then
				--nextTrackingPlayerChange = os.clock() - 2
				lockPlayerID = WG.lockcamera.GetPlayerID()
				if not toggled and prevLockPlayerID ~= lockPlayerID then
					updateDrawing = true
					prevLockPlayerID = lockPlayerID
				end
			end
			if myTeamPlayerID and alwaysDisplayName and isSpec then
				if lockPlayerID then
					prevLockPlayerID = lockPlayerID
					lockPlayerID = WG.lockcamera.GetPlayerID()
				end
				local name, _, spec, teamID, _, _, _, _, _ = spGetPlayerInfo(myTeamPlayerID, false)
				if select(4, Spring.GetTeamInfo(myTeamID,false)) then	-- is AI?
					local _, _, _, aiName = Spring.GetAIInfo(myTeamID)
					local niceName = Spring.GetGameRulesParam('ainame_' .. myTeamID)
					name = niceName or aiName
					name = Spring.I18N('ui.playersList.aiName', { name = name })
				end
				if not name then name = '---' end
				-- create player name
				if not drawlistsPlayername[name] then
					drawlistsPlayername[name] = gl.CreateList(function()
						local r, g, b = 1, 1, 1
						if (not isSpec) and anonymousMode ~= "disabled" then
							r, g, b = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
						elseif not spec then
							r, g, b, _ = spGetTeamColor(myTeamID)
						end
						font2:Begin()
						font2:SetTextColor(r, g, b, 1)
						if (r + g * 1.2 + b * 0.4) < 0.65 then
							font2:SetOutlineColor(1, 1, 1, 1)
						else
							font2:SetOutlineColor(0, 0, 0, 1)
						end
						font2:Print(name, vsx * 0.985, vsy * 0.0215, 26 * widgetScale, "ron")
						font2:End()
					end)
				end
				-- draw player name
				if drawlistsPlayername[name] then
					gl.PushMatrix()
					gl.Translate(0, top, 0)
					gl.CallList(drawlistsPlayername[name])
					gl.PopMatrix()
				end
			end
		end
	end
end

function widget:DrawScreen()
	if updateDrawing then
		updateDrawing = false
		refreshUiDrawing()
		if useRenderToTexture then
			if right-left >= 1 and top-bottom >= 1 then
				uiTexTopExtra = math.floor(vsy*0.06)
				uiTexLeftExtra = math.floor(vsy*0.06)
				if not uiTex then
					uiTex = gl.CreateTexture(math.floor(right-left)+uiTexLeftExtra, math.floor(top-bottom)+uiTexTopExtra, {
						target = GL.TEXTURE_2D,
						format = GL.RGBA,
						fbo = true,
					})
				end
				gl.RenderToTexture(uiTex, function()
					gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
					gl.PushMatrix()
					gl.Translate(-1, -1, 0)
					gl.Scale(2 / ((right-left)+uiTexLeftExtra), 2 / ((top-bottom)+uiTexTopExtra), 0)
					gl.Translate(-left+uiTexLeftExtra, -bottom, 0)
					drawContent()
					gl.PopMatrix()
				end)
			end
		end
	end

	if useRenderToTexture then
		if uiTex then
			gl.Color(1,1,1,1)
			gl.Texture(uiTex)
			gl.TexRect(left-uiTexLeftExtra, bottom, right, top+uiTexTopExtra, false, true)
			gl.Texture(false)
		end
	else
		drawContent()
	end
end

local function togglePlayerTV(state)
	prevOrderID = nil
	currentTrackedPlayer = nil
	if (state~= nil and not state) or toggled or lockPlayerID then
		toggled = false
		toggled2 = false
		if WG.lockcamera then
			WG.lockcamera.SetPlayerID()
		end
		nextTrackingPlayerChange = 0
		lockPlayerID = nil
		prevLockPlayerID = nil
		updateDrawing = true
	elseif not rejoining then
		toggled = true
		toggled2 = true
		if WG.lockcamera and WG.lockcamera.SetLosMode then
			WG.lockcamera.SetLosMode('los')
		end
		switchPlayerCam()
		updateDrawing = true
	end
end

local function togglePlayerCamera()
	prevOrderID = nil
	currentTrackedPlayer = nil
	toggled2 = true
	if WG.lockcamera then
		WG.lockcamera.SetPlayerID(myTeamPlayerID)
	end
	prevLockPlayerID = nil
	lockPlayerID = nil
	updateDrawing = true
end

local function togglePlayerView(state)
	prevOrderID = nil
	currentTrackedPlayer = nil
	toggled2 = (state ~= nil and state or not toggled2)
	if not toggled2 then
		-- global viewpoint
		if not fullview then
			Spring.SendCommands("specfullview")
		end
		if Spring.GetMapDrawMode() == "los" then
			Spring.SendCommands("togglelos")
		end
	else
		-- player viewpoint
		if fullview then
			scheduledSpecFullView = 2 -- this is needed else the minimap/world doesnt update properly
			Spring.SendCommands("specfullview")
		end
		if Spring.GetMapDrawMode() ~= "los" then
			desiredLosmode = 'los'
			desiredLosmodeChanged = os.clock()
		end
	end
	updateDrawing = true
end

function widget:Initialize()
	widget:ViewResize()
	isSpec, fullview = Spring.GetSpectatingState()

	if isSpec and not fullview then
		toggled2 = true
	end
	if WG['advplayerlist_api'] == nil then
		widgetHandler:RemoveWidget()
		return
	end

	local humanPlayers = 0
	for _, playerID in ipairs(playersList) do
		local _, _, spec, team = spGetPlayerInfo(playerID, false)
		if not spec then
			playersTS[playerID] = GetSkill(playerID)
			if not select(3, Spring.GetTeamInfo(team, false)) and not select(4, Spring.GetTeamInfo(team, false)) then
				humanPlayers = humanPlayers + 1
			end
		end
	end
	if humanPlayers == 0 then
		widgetHandler:RemoveWidget()
		return
	end

	tsOrderPlayers()

	updatePosition()
	WG['playertv'] = {}
	WG['playertv'].GetPosition = function()
		return { top, left, bottom, right, widgetScale }
	end
	WG['playertv'].isActive = function()
		return (toggled and isSpec)
	end
	WG['playertv'].GetPlayerChangeDelay = function()
		return playerChangeDelay
	end
	WG['playertv'].SetPlayerChangeDelay = function(value)
		playerChangeDelay = value
		createCountdownLists()
	end
	WG['playertv'].GetAlwaysDisplayName = function()
		return alwaysDisplayName
	end
	WG['playertv'].SetAlwaysDisplayName = function(value)
		alwaysDisplayName = value
	end
end

function widget:MousePress(mx, my, mb)
	if isSpec or lockPlayerID then
		-- player tv
		if isSpec and toggleButton ~= nil and math_isInRect(mx, my, toggleButton[1], toggleButton[2], toggleButton[3], toggleButton[4]) then
			if mb == 1 then
				togglePlayerTV()
			end
			return true
		end
		-- player viewpoint
		if isSpec and toggleButton2 ~= nil and math_isInRect(mx, my, toggleButton2[1], toggleButton2[2], toggleButton2[3], toggleButton2[4]) then
			isSpec, fullview = Spring.GetSpectatingState()
			if mb == 1 then
				togglePlayerView()
			end
			return true
		end
		-- player camera
		if (isSpec or lockPlayerID) and toggleButton3 ~= nil and math_isInRect(mx, my, toggleButton3[1], toggleButton3[2], toggleButton3[3], toggleButton3[4]) then
			isSpec, fullview = Spring.GetSpectatingState()
			if mb == 1 then
				togglePlayerCamera()
			end
			return true
		end
	end
end

function widget:ViewResize()
	vsx, vsy = Spring.GetViewGeometry()

	bgpadding = WG.FlowUI.elementPadding
	elementCorner = WG.FlowUI.elementCorner
	RectRound = WG.FlowUI.Draw.RectRound

	font = WG['fonts'].getFont(nil, 1 * (useRenderToTexture and 1.2 or 1), 0.2 * (useRenderToTexture and 1.2 or 1), 1.3)
	font2 = WG['fonts'].getFont(fontfile2, 2 * (useRenderToTexture and 1.2 or 1), 0.2 * (useRenderToTexture and 1.2 or 1), 1.3)

	for i = 1, #drawlistsCountdown do
		gl.DeleteList(drawlistsCountdown[i])
	end
	for i, v in pairs(drawlistsPlayername) do
		gl.DeleteList(drawlistsPlayername[i])
	end
	drawlistsCountdown = {}
	drawlistsPlayername = {}
	if WG['guishader'] and backgroundGuishader then
		if backgroundGuishader then
			backgroundGuishader = gl.DeleteList(backgroundGuishader)
		end
		showBackgroundGuishader = nil
	end
	for i = 1, #drawlist do
		drawlist[i] = gl.DeleteList(drawlist[i])
	end

	if uiTex then
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end

	updateDrawing = true

	createCountdownLists()
end

function widget:TextCommand(command)
	if string.sub(command, 1, 10) == 'playerview' then
		local words = {}
		for w in command:gmatch("%S+") do
			words[#words+1] = w
		end
		if #words > 1 then
			local playerID = tonumber(words[#words])
			local teamID = select(4, spGetPlayerInfo(playerID))
			if teamID then
				Spring.SendCommands("specteam " .. teamID)
			end
		end
		togglePlayerView()
	end
	if string.sub(command, 1, 12) == 'playercamera' then
		togglePlayerCamera()
	end
	if string.sub(command, 1, 8) == 'playertv' then
		local words = {}
		for w in command:gmatch("%S+") do
			words[#words+1] = w
		end
		if #words > 1 then
			local playerID = tonumber(words[#words])
			local teamID = select(4, spGetPlayerInfo(playerID))
			if teamID and WG.lockcamera and WG.lockcamera.SetPlayerID then
				Spring.SendCommands("specteam " .. teamID)
				WG.lockcamera.SetPlayerID(playerID)
			else
				togglePlayerTV()
			end
		else
			togglePlayerTV()
		end
	end
end

function widget:Shutdown()
	for i = 1, #drawlistsCountdown do
		gl.DeleteList(drawlistsCountdown[i])
	end
	for i, v in pairs(drawlistsPlayername) do
		gl.DeleteList(drawlistsPlayername[i])
	end
	drawlistsCountdown = {}
	drawlistsPlayername = {}
	if WG['guishader'] then
		WG['guishader'].DeleteDlist('playertv')
	end
	for i = 1, #drawlist do
		gl.DeleteList(drawlist[i])
	end
	drawlist = {}
	if uiTex then
		gl.DeleteTextureFBO(uiTex)
		uiTex = nil
	end
	if toggled and WG.lockcamera then
		WG.lockcamera.SetPlayerID()
	end
end

function widget:GetConfigData(data)
	return {
		toggled = toggled,
		alwaysDisplayName = alwaysDisplayName,
		playerChangeDelay = playerChangeDelay
	}
end

function widget:SetConfigData(data)
	if Spring.GetGameFrame() > 0 and data.toggled ~= nil then
		toggled = data.toggled
	end
	if data.alwaysDisplayName ~= nil then
		alwaysDisplayName = data.alwaysDisplayName
	end
	if data.playerChangeDelay then
		playerChangeDelay = data.playerChangeDelay
	end
end

function widget:LanguageChanged()
	widget:ViewResize()
end
