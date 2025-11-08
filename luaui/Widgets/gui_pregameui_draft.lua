local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Pregame UI - Draft Spawn Order",
		desc = "",
		author = "Floris, Tom Fyuri",
		date = "2024",
		license = "GNU GPL, v2 or later",
		layer = -999999,
		enabled = true
	}
end


-- Localized functions for performance
local mathFloor = math.floor
local mathMax = math.max
local mathRandom = math.random
local tableInsert = table.insert

-- Localized Spring API for performance
local spGetGroundHeight = Spring.GetGroundHeight
local spEcho = Spring.Echo
local spGetViewGeometry = Spring.GetViewGeometry

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx, vsy = spGetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 6200000))
local fontfileSize = 50
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local uiScale = (0.7 + (vsx * vsy / 6500000))
local myPlayerID = Spring.GetMyPlayerID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local _, _, mySpec, myTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local isFFA = Spring.Utilities.Gametype.IsFFA()
local isReplay = Spring.IsReplay()

local readyButtonColor = {0.05, 0.28, 0}
local unreadyButtonColor = {0.28, 0.05, 0}
local subButtonColor = {0.08, 0.22, 0}
local unsubButtonColor = {0.22, 0.08, 0}
local waitButtonColor = {0.01, 0.01, 0.01}

local readied = false	-- send readystate (in widget:GameSetup)
local pressedReady	-- pressed button
local startPointChosen = false

local NETMSG_STARTPLAYING = 4 -- see BaseNetProtocol.h, packetID sent during the 3.2.1 countdown
local SYSTEM_ID = -1 -- see LuaUnsyncedRead::GetPlayerTraffic, playerID to get hosts traffic from
local gameStarting = false
local timer = 0
local timer2 = 0
local auto_ready_timer = 120
local auto_ready = not Spring.Utilities.Gametype.IsSinglePlayer()

local buttonPosX = 0.8
local buttonPosY = 0.76
local buttonX = mathFloor(vsx * buttonPosX)
local buttonY = mathFloor(vsy * buttonPosY)

local orgbuttonH = 40
local orgbuttonW = 115

local buttonW = mathFloor(orgbuttonW * uiScale / 2) * 2
local buttonH = mathFloor(orgbuttonH * uiScale / 2) * 2

local buttonList, buttonHoverList
local buttonText = ''
local lockText = ''
local locked = false
local showLockButton = true
local buttonDrawn = false
local isReadyBlocked = false
local readyBlockedConditions = {}
local cachedTooltipText = ""

local function hasActiveConditions()
	for k, v in pairs(readyBlockedConditions) do
		return true
	end
	return false
end

local function updateTooltip()
	isReadyBlocked = hasActiveConditions()
	if isReadyBlocked then
		cachedTooltipText = ""
		for conditionKey, description in pairs(readyBlockedConditions) do
			if description ~= nil then
				if cachedTooltipText ~= "" then
					cachedTooltipText = cachedTooltipText .. "\n"
				end
				cachedTooltipText = cachedTooltipText .. Spring.I18N(description)
			end
		end
	else
		cachedTooltipText = ""
	end
end

local RectRound, UiElement, UiButton, elementPadding, uiPadding

local enableSubbing = false
local eligibleAsSub = false
local offeredAsSub = false
--local allowUnready = false	-- not enabled cause unreadying doesnt work, have to do workaroud

local numPlayers = Spring.Utilities.GetPlayerCount()

local shapeOpacity = 0.6
local unitshapes = {}
local teamStartPositions = {}
local teamList = Spring.GetTeamList()

local uiElementRect = {0,0,0,0}
local uiLockRect = {0,0,0,0}
local buttonRect = {0,0,0,0}
local lockRect = {0,0,0,0}
local blinkButton = false

-- DraftOrder mod start
local draftMode = Spring.GetModOptions().draft_mode
local turnTimeOut = 8 -- This controls timeout for random/skill mode placement turns, default: 8s
local turnTimeOutBigTeam = 5 -- When allyTeam has 9 or more players on it: 5s
local bigTeamAmountOfPlayers = 8 -- How many players for it to be considered big team?
local connectionTimeOut = 45 -- How many seconds to wait for allies before placing them at the tail end of the queue in random/skill draft
local VoteSkipTurnDelay = 3
local draftModeLoaded = false
local DMDefaultColorString = '\255\200\200\200'
local DMWarnColor = '\255\255\255\255'
local myTurn = false
local myAllyTeamJoined = false
local ihavejoined_fair = false
local currentTurnTimeout = nil
local voteSkipTurnTimeout = nil
local voteConTimeout = nil
local connectionTimeoutHappened = false
local fairTimeout = nil
local current_playerID = -1
local next_playerID = -1
local auto_ready_disable = false
local myTeamPlayersOrder = nil
local currentPlayerIndex = 0
local hasStartbox = false
local moreThanOneAlly = true
local TeamPlacementUI = nil
local TeamPlacementUIshown = false
local devUItestMode = false -- flip to true to test UI with fake players
-- a lot of code copied and slightly modified from advplayerlist...
local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}
local imgDir = LUAUI_DIRNAME .. "Images/advplayerslist/"
local imageDirectory = ":lc:" .. imgDir
local pics = {
    readyTexture = imageDirectory .. "indicator.dds",
    rank0 = imageDirectory .. "ranks/1.png",
    rank1 = imageDirectory .. "ranks/2.png",
    rank2 = imageDirectory .. "ranks/3.png",
    rank3 = imageDirectory .. "ranks/4.png",
    rank4 = imageDirectory .. "ranks/5.png",
    rank5 = imageDirectory .. "ranks/6.png",
    rank6 = imageDirectory .. "ranks/7.png",
    rank7 = imageDirectory .. "ranks/8.png",
	hourglass = imageDirectory .. "hourglass.png"
}
local playerReadyState = {}
local playerScale = 1.5
local gl_Texture = gl.Texture
local gl_Color = gl.Color

local glCreateList = gl.CreateList
local glCallList = gl.CallList
local glDeleteList = gl.DeleteList

local function RectQuad(px, py, sx, sy)
    local o = 0.008        -- texture offset, because else grey line might show at the edges
    gl.TexCoord(o, 1 - o)
    gl.Vertex(px, py, 0)
    gl.TexCoord(1 - o, 1 - o)
    gl.Vertex(sx, py, 0)
    gl.TexCoord(1 - o, o)
    gl.Vertex(sx, sy, 0)
    gl.TexCoord(o, o)
    gl.Vertex(px, sy, 0)
end

local function DrawRect(px, py, sx, sy)
    gl.BeginEnd(GL.QUADS, RectQuad, px, py, sx, sy)
end

local function DrawState(playerID, posX, posY)
	-- note that adv pl list uses a phantom pID for absent players, so this will always show unready for players not ingame
	local ready = (playerReadyState[playerID] == 1) or (playerReadyState[playerID] == 2) or (playerReadyState[playerID] == -1)
	local hasStartPoint = (playerReadyState[playerID] == 4)
	if ai then
		gl_Color(0.1, 0.1, 0.97, 1)
	else
		if ready then
			gl_Color(0.1, 0.95, 0.2, 1) -- green
		else
			if hasStartPoint then
				gl_Color(1, 0.65, 0.1, 1) -- yellow
			else
				gl_Color(0.8, 0.1, 0.1, 1) -- red
			end
		end
	end
	gl_Texture(pics["readyTexture"])
	DrawRect(posX, posY - (1*playerScale), posX + (16*playerScale), posY + (16*playerScale))
	gl_Color(1, 1, 1, 1)
end

local function DrawHourglass(posX, posY)
	gl_Texture(pics["hourglass"])
	DrawRect(posX, posY - (1*playerScale), posX + (16*playerScale), posY + (16*playerScale))
	gl_Color(1, 1, 1, 1)
end

local function SetSidePics()
    local playerList = Spring.GetPlayerList()
    for _, playerID in pairs(playerList) do
        playerReadyState[playerID] = Spring.GetGameRulesParam("player_" .. tostring(playerID) .. "_readyState")
    end
end

local function DrawRankImage(rankImage, posX, posY)
    gl_Color(1, 1, 1, 1)
    gl_Texture(rankImage)
    DrawRect(posX + (3*playerScale), posY + (8*playerScale) - (7.5*playerScale), posX + (17*playerScale), posY + (8*playerScale) + (7.5*playerScale))
end

local function DrawRank(rank, posX, posY)
    if rank == 0 then
        DrawRankImage(pics["rank0"],  posX, posY)
    elseif rank == 1 then
        DrawRankImage(pics["rank1"],  posX, posY)
    elseif rank == 2 then
        DrawRankImage(pics["rank2"],  posX, posY)
    elseif rank == 3 then
        DrawRankImage(pics["rank3"],  posX, posY)
    elseif rank == 4 then
        DrawRankImage(pics["rank4"],  posX, posY)
    elseif rank == 5 then
        DrawRankImage(pics["rank5"],  posX, posY)
    elseif rank == 6 then
        DrawRankImage(pics["rank6"],  posX, posY)
    elseif rank == 7 then
        DrawRankImage(pics["rank7"],  posX, posY)
    else

    end
end

local function DrawSkill(skill, uncertainty, posX, posY)
    local fontsize = 14 * (playerScale + ((1-playerScale)*0.25))
    font:Begin()
	if uncertainty > 6.65 then
		font:Print("??", posX + (4.5*playerScale), posY + (5.3*playerScale), fontsize, "o")
	else
		font:Print(skill, posX + (4.5*playerScale), posY + (5.3*playerScale), fontsize, "o")
	end

    font:End()
end

local function round(num, idp)
    local mult = 10 ^ (idp or 0)
    return mathFloor(num * mult + 0.5) / mult
end

-- advplayerlist end
local function colourNames(teamID, blink)
	local mult = 1
	local nameColourR, nameColourG, nameColourB = 0.9, 0.9, 0.9
	if teamID ~= nil then
		if blink then mult = 0.66 end
		nameColourR, nameColourG, nameColourB = Spring.GetTeamColor(teamID)
	end
	if anonymousMode ~= "disabled" and teamID ~= myTeamID then
		nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
	return Spring.Utilities.Color.ToString(nameColourR * mult, nameColourG * mult, nameColourB * mult)
end

local function canPlayerPlaceNow(playerID)
	if draftMode == nil or draftMode == "disabled" then return true end
	if draftMode == "fair" or not myAllyTeamJoined then
		return myAllyTeamJoined
	else -- skill/random
		if currentPlayerIndex == nil or currentPlayerIndex <= 0 or myTeamPlayersOrder == nil then
			return false
		end
		 -- returns true if playerID is found before array hits index (currentPlayerIndex)
		for i = 1, #myTeamPlayersOrder do
			if (i > currentPlayerIndex) then
				return false
			end
			if myTeamPlayersOrder[i].id == playerID then
				return true
			end
		end
	end
    return false
end

local function findPlayerName(playerID)
	local tname = nil
	if myTeamPlayersOrder then
		for _, player in ipairs(myTeamPlayersOrder) do
			if player.id == playerID then
				if player.name ~= nil then
					return player.name
				else -- try to cache missing player name
					tname = select(1, Spring.GetPlayerInfo(playerID, false))
					tname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or tname
					if tname ~= nil then
						player.name = tname
						return player.name
					end
				end
			end
		end
	end
	tname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerID)) or Spring.GetPlayerInfo(playerID, false)
	if not tname then
		tname = "unconnected" 	-- show "unconnected" instead of nil if we don't know the name
	end
	return tname
end

local function draftModeInited() -- We want to ensure the player's UI is loaded and seen by the player before proceeding
	if draftModeLoaded then return end

	local mode = draftMode:gsub("^%l", string.upper) -- Random/Captain/Skill/Fair
	spEcho(Spring.I18N('ui.draftOrderMod.mode' .. mode)..".")
	draftModeLoaded = true
	if mode == "Fair" then
		fairTimeout = os.clock() + 2
	else
		fairTimeout = os.clock() + 1 -- 1 second delay so that the last to load but first to place will hear the voice "Choose your starting location"
	end
end

local function checkStartPointChosen()
	if not mySpec and not startPointChosen then
		local x, y, z = Spring.GetTeamStartPosition(myTeamID)
		if x ~= nil and x > 0 and z ~= nil and z > 0 then
			startPointChosen = true
		end
	end
end

local function buttonTextRefresh()
	if mySpec then
		if eligibleAsSub then
			showLockButton = true
			if not offeredAsSub then
				buttonText = Spring.I18N('ui.substitutePlayers.offer')
			else
				buttonText = Spring.I18N('ui.substitutePlayers.withdraw')
			end
		else
			showLockButton = false
		end
	else
		if (draftMode == nil or draftMode == "disabled") then -- regular
			showLockButton = true
			if readied then
				if locked then
					buttonText = Spring.I18N('ui.initialSpawn.unlock')
				else
					buttonText = Spring.I18N('ui.initialSpawn.lock')
				end
			else
				buttonText = Spring.I18N('ui.initialSpawn.ready')
			end
		else -- modded
			checkStartPointChosen()
			if not myAllyTeamJoined then -- all draftModes
				showLockButton = true
				local text = Spring.I18N('ui.draftOrderMod.waitingForPlayers')
				if (voteConTimeout) then
					vcttimer = mathFloor(voteConTimeout-os.clock())+1
					if (vcttimer > 0) then
						text = text .. " " .. vcttimer .. "s"
					end
				end
				buttonText = text
			elseif canPlayerPlaceNow(myPlayerID) then -- "fair" mode will always this block
				if startPointChosen then
					showLockButton = true
					if locked then
						buttonText = Spring.I18N('ui.initialSpawn.unlock')
					else
						buttonText = Spring.I18N('ui.initialSpawn.lock')
					end
				else
					showLockButton = false
					buttonText = ""
				end
			elseif myAllyTeamJoined then -- allyTeamJoined and draftMode is random/skill
				showLockButton = true
				buttonText = Spring.I18N('ui.draftOrderMod.waitingForTurn')
			else showLockButton = false end -- how did we get here?
		end
	end
end

local function PlayChooseStartLocSound()
	if not mySpec and not startPointChosen and WG['notifications'] then
		WG['notifications'].addEvent('ChooseStartLoc', true)
	end
end

local function getHumanCountWithinAllyTeam(allyTeamID)
	local myTeamList = Spring.GetTeamList(allyTeamID)
	local count = 0
	for _, teamID in ipairs(myTeamList) do
		local _, _, _, isAiTeam = Spring.GetTeamInfo(teamID, false)
		if not isAiTeam then
			count = count + 1
		end
	end
	return count
end

-- we will draw this basically:	   (y)
-- 			  4s				-- 0.256
-- 	 Place your Commander		-- 0.23
--     Next is "Player2"		-- 0.205
-- 	"Pick a startpos within"    -- I'm not going to touch that just yet (map_startbox.lua) (~0.18)

-- UI design by Scopa, implemented by Tom Fyuri
local function DrawTeamPlacement()
	SetSidePics()
	TeamPlacementUI = glCreateList(function()

	-- Center Screen Stuff
	local tmsg = ""
	if currentTurnTimeout then
		tmsg = mathFloor(currentTurnTimeout-os.clock())+1
		if (tmsg <= 0) then tmsg = " ?" else -- this implies that player has "connection problems" in which we will force skip that player's turn in a few seconds anyway
			tmsg = tmsg .. "s"
		end
	elseif (current_playerID > -1 and next_playerID > -1) then
		tmsg = ""
	else
		tmsg = ""
	end
	local amIunlocked = canPlayerPlaceNow(myPlayerID)
	if not startPointChosen and next_playerID > -1 and ((amIunlocked and current_playerID == myPlayerID) or (not amIunlocked and current_playerID ~= myPlayerID)) then
		font:Print(DMWarnColor .. tmsg, vsx * 0.5, vsy * 0.256, 22.0 * uiScale, "co")
	end
	if not amIunlocked and (current_playerID ~= myPlayerID) then
		-- added because you can't place until your turn has come up or passed
		if (current_playerID > -1) then
			local tname = findPlayerName(current_playerID)
			local tTeamID = select(4, Spring.GetPlayerInfo(current_playerID, false))
			local text = colourNames(tTeamID, false)..tname
			font:Print(DMDefaultColorString .. Spring.I18N('ui.draftOrderMod.waitingFor', { name = text}), vsx * 0.5, vsy * 0.23, 22.0 * uiScale, "co")
		end
	elseif not startPointChosen then
		font:Print(DMWarnColor .. Spring.I18N('ui.draftOrderMod.placeYourCom'), vsx * 0.5, vsy * 0.23, 22.0 * uiScale, "co")
	end
	if (current_playerID > -1 and next_playerID > -1) then
		local tname = findPlayerName(next_playerID)
		local tTeamID = select(4, Spring.GetPlayerInfo(next_playerID, false))
		local text = colourNames(tTeamID, false)..tname
		font:Print(DMDefaultColorString .. Spring.I18N('ui.draftOrderMod.nextIsPlayer', { name = text}), vsx * 0.5, vsy * 0.205, 15.0 * uiScale, "co")
	end

	-- Team Placement UI
	local x = vsx * 0.78
	local y = vsy * 0.83
	-- ^ this is top right corner, we align everything to it

	local max_height = (#(myTeamPlayersOrder) * 26 * uiScale) + 64
	local max_width = 0
	for i, data in ipairs(myTeamPlayersOrder) do
		local text = findPlayerName(data.id) or ""
		local w = font:GetTextWidth(text)
		if max_width < w then
			max_width = w
		end
	end
	local button_width = uiElementRect[3]-uiElementRect[1]

	local rank_column_offset = 24
	local skill_column_offset = 58
	local player_column_offset = rank_column_offset + skill_column_offset + 24
	local padding_left = 12
	local player_name_font_size = 16

	max_width = mathMax((max_width * player_name_font_size * uiScale) + padding_left + player_column_offset + padding_left, button_width)

	-- we can modify "lock position" button pos here
	buttonPosX = 0.78
	buttonPosY = 0.83
	buttonX = mathFloor(vsx * buttonPosX) + max_width/2
	buttonY = mathFloor(vsy * buttonPosY) - max_height - 4 - buttonH
	--

	font:SetOutlineColor(0, 0, 0, 0.5)
	UiElement(x, y - max_height, x + max_width, y, 1, 1, 1, 1, 1, 1, 1, 1, nil)
	gl_Color(1, 1, 1, 1)
	font:Print(DMWarnColor .. Spring.I18N('ui.draftOrderMod.teamPlacement'), x + max_width/2, y - 32, player_name_font_size * uiScale, "co")
	local y_shift
	for i, data in ipairs(myTeamPlayersOrder) do
		y_shift = y - (i * 26 * uiScale) - 40
		local playerID = data.id
		-- Draw black background with black bottom border for current player's turn -- added by Scopa
		if current_playerID == playerID then
			gl.Color(0, 0, 0, 0.8) -- 80% opaque black
			local highlightTop = y_shift + 26 * uiScale - 7
			local highlightBottom = y_shift - 7
			gl.Rect(x, highlightTop, x + max_width, highlightBottom)
			gl.Color(1, 1, 1, 1)
		end
		--
		local playerName = findPlayerName(playerID)
		local _, active, _, playerTeamID, _, ping, _, _, rank, _, customtable = Spring.GetPlayerInfo(playerID, true)
		local playerRank, playerSkill, playerSigma = 0, 0, 8.33
		if type(customtable) == 'table' then
			local tsMu = customtable.skill
			local tsSigma = customtable.skilluncertainty
			local ts = tsMu and tonumber(tsMu:match("%d+%.?%d*"))
			if (ts ~= nil) then playerSkill = round(ts, 0) end
			if (rank ~= nil) then playerRank = rank end
			if tsSigma then playerSigma = tonumber(tsSigma) end
		end
		-- | indicator/timer/hourglass | rankicon | skill/zero | [playercolor] playername |
		local x_offset = padding_left
		if (current_playerID == playerID) then
			font:Print(DMDefaultColorString .. tmsg, x + x_offset - 1, y_shift + 3, 15 * uiScale, "lo")
		elseif (canPlayerPlaceNow(playerID)) then
			x_offset = padding_left - 5
			DrawState(playerID, x + x_offset, y_shift - 3)
		else
			x_offset = padding_left - 4
			DrawHourglass(x + x_offset + 1, y_shift - 1)
		end
		local colorMod = colourNames(playerTeamID)
		if (not active) then
			if os.clock() % 0.75 <= 0.375 then
				colorMod = colourNames(playerTeamID, true)
			end
		else
			x_offset = padding_left + rank_column_offset
			DrawRank(playerRank, x + x_offset, y_shift - 3)
			x_offset = padding_left + skill_column_offset
			DrawSkill(playerSkill, playerSigma, x + x_offset, y_shift - 4)
		end
		x_offset = padding_left + player_column_offset
		font:Print(colorMod .. playerName, x + x_offset, y_shift + 3, player_name_font_size * uiScale, "lo")
	end

	end)
	TeamPlacementUIshown = true
end
-- DraftOrder mod end

local function drawButton()
	buttonTextRefresh()
	local cantPlaceNow = not canPlayerPlaceNow(myPlayerID)
	if draftMode ~= nil and draftMode ~= "disabled" and buttonText == "" and not mySpec and showLockButton then
		showLockButton = false
	end
	local color = { 0.15, 0.15, 0.15 }
	if not mySpec then
		if cantPlaceNow then
			color = waitButtonColor
		elseif not locked then
			if isReadyBlocked then
				color = { 0.3, 0.3, 0.3 }
			else
				color = readyButtonColor
			end
		else
			color = unreadyButtonColor
		end
	elseif eligibleAsSub then
		color = offeredAsSub and unsubButtonColor or subButtonColor
	end

	-- because text can change now
	orgbuttonW = font:GetTextWidth('       '..buttonText) * 24
	buttonW = mathFloor(orgbuttonW * uiScale / 2) * 2
	buttonH = mathFloor(orgbuttonH * uiScale / 2) * 2

	uiElementRect = { buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding }
	buttonRect = { buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2) }

	if (not showLockButton and buttonDrawn) then
		if buttonList then
			glDeleteList(buttonList)
		end
		if buttonHoverList then
			glDeleteList(buttonHoverList)
		end
		buttonList = nil
		buttonHoverList = nil
		buttonDrawn = false
	end

	if showLockButton then
		if buttonList then
			glDeleteList(buttonList)
		end
		buttonList = gl.CreateList(function()
			UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
			UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.55, color[2]*0.55, color[3]*0.55, 1 }, { color[1], color[2], color[3], 1 })
		end)
		if buttonHoverList then
			glDeleteList(buttonHoverList)
		end
		buttonHoverList = gl.CreateList(function()
			UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
			UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.85, color[2]*0.85, color[3]*0.85, 1 }, { color[1]*1.5, color[2]*1.5, color[3]*1.5, 1 })
		end)

		local playerList = Spring.GetPlayerList()
		local numPlayers = #playerList
		local numPlayersReady = 0
		if numPlayers > 3 and not cantPlaceNow then
			for _, playerID in pairs(playerList) do
				local readystate = Spring.GetGameRulesParam("player_" .. tostring(playerID) .. "_readyState")
				if readystate == -1 or readystate == 1 or readystate == 2 then
					numPlayersReady = numPlayersReady + 1
				end
			end
			blinkButton = (numPlayers / numPlayersReady > 0.75)
		end
		-- in draftmode just blink the button if you didnt lock
		if (draftMode ~= nil and draftMode ~= "disabled") and not cantPlaceNow and not locked then
			blinkButton = true
		end

		if WG['guishader'] then
			WG['guishader'].InsertRect(
				uiElementRect[1],
				uiElementRect[2],
				uiElementRect[3],
				uiElementRect[4],
				'pregameui_draft'
			)
		end

		-- draw ready button and text
		local x, y = Spring.GetMouseState()
		local colorString
		if x > buttonRect[1] and x < buttonRect[3] and y > buttonRect[2] and y < buttonRect[4] and not cantPlaceNow then
			glCallList(buttonHoverList)
			colorString = "\255\210\210\210"

			if isReadyBlocked and WG['tooltip'] then
				WG['tooltip'].ShowTooltip('pregameui', cachedTooltipText)
			end
		else
			glCallList(buttonList)
			timer2 = timer2 + Spring.GetLastUpdateSeconds()
			if mySpec then
				colorString = offeredAsSub and "\255\255\255\225" or "\255\222\222\222"
			else
				if isReadyBlocked then
					colorString = "\255\150\150\150"
				else
					colorString = os.clock() % 0.75 <= 0.375 and "\255\255\255\255" or "\255\222\222\222"
				end
			end
			if readied or cantPlaceNow then
				colorString = "\255\222\222\222"
			end
			if blinkButton and not readied and not isReadyBlocked and os.clock() % 0.75 <= 0.375 then
				local mult = 1.33
				UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { readyButtonColor[1]*0.55*mult, readyButtonColor[2]*0.55*mult, readyButtonColor[3]*0.55*mult, 1 }, { readyButtonColor[1]*mult, readyButtonColor[2]*mult, readyButtonColor[3]*mult, 1 })
			end
		end
		font:Begin()
		font:Print(colorString .. buttonText, buttonRect[1]+((buttonRect[3]-buttonRect[1])/2), (buttonRect[2]+((buttonRect[4]-buttonRect[2])/2)) - (buttonH * 0.16), 24 * uiScale, "co")
		font:End()
		gl.Color(1, 1, 1, 1)
		buttonDrawn = true
	end
end

local function progressQueueLocally(shift) -- only for dev UI testing of DOM
	currentPlayerIndex = currentPlayerIndex + shift
	if myTeamPlayersOrder ~= nil then
		if myTeamPlayersOrder[currentPlayerIndex] and myTeamPlayersOrder[currentPlayerIndex].id ~= nil then
			current_playerID = myTeamPlayersOrder[currentPlayerIndex].id
		else
			current_playerID = -1
		end
		if myTeamPlayersOrder[currentPlayerIndex+1] and myTeamPlayersOrder[currentPlayerIndex+1].id ~= nil then
			next_playerID = myTeamPlayersOrder[currentPlayerIndex+1].id
		else
			next_playerID = -1
		end
		if current_playerID > -1 then
			currentTurnTimeout = os.clock() + turnTimeOut
		end
		if current_playerID > -1 and next_playerID > -1 then
			voteSkipTurnTimeout = os.clock() + turnTimeOut + VoteSkipTurnDelay
		end
		if current_playerID == myPlayerID then
			myTurn = true
			PlayChooseStartLocSound()
		elseif next_playerID == myPlayerID then
			Spring.PlaySoundFile("beep6", 1, 'ui')
		elseif myTurn then
			myTurn = false
		end
	end
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = spGetViewGeometry()
	uiScale = (0.75 + (vsx * vsy / 6000000))
	buttonX = mathFloor(vsx * buttonPosX)
	buttonY = mathFloor(vsy * buttonPosY)
	orgbuttonW = font:GetTextWidth('       '..buttonText) * 24
	buttonW = mathFloor(orgbuttonW * uiScale / 2) * 2
	buttonH = mathFloor(orgbuttonH * uiScale / 2) * 2

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end

	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	RectRound = WG.FlowUI.Draw.RectRound
	elementPadding = WG.FlowUI.elementPadding
	uiPadding = mathFloor(elementPadding * 4.5)
end

local ihavejoined = false
function widget:GameSetup(state, ready, playerStates)
	local spec, fullview = Spring.GetSpectatingState()
	-- sends a "I arrived" message
	-- NOTE: Spring.GetGameRulesParam("player_" .. Spring.GetMyPlayerID() .. "_joined") seems to be always nil!
	if not spec and not ihavejoined and Spring.GetGameRulesParam("player_" .. Spring.GetMyPlayerID() .. "_joined") == nil then
		Spring.SendLuaRulesMsg("joined_game")
		ihavejoined = true
	end

	-- check when the 3.2.1 countdown starts
	if not gameStarting and ((Spring.GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0) > 0) then
		gameStarting = true		-- ugly but effective (can also detect by parsing state string)
	end

	-- if we can't choose startpositions, no need for ready button etc
	if Game.startPosType ~= 2 then
		-- additionally automatically set readyState to true if this is a FFA game
		if isFFA and (not readied or not ready) then
			readied = true
		end
		return true, true
	end

	if not auto_ready_disable then
		-- starts game after a specified amount of time after all players have joined
		if Spring.GetGameRulesParam("all_players_joined") == 1 and not gameStarting and auto_ready then
			auto_ready_timer = auto_ready_timer - Spring.GetLastUpdateSeconds()
		end
		if auto_ready_timer <=0 and auto_ready == true then
			return true, true
		end
	end

	-- only return true, true once ALL players are ready
	ready = true
	local playerList = Spring.GetPlayerList()
	for _, playerID in pairs(playerList) do
		local _, _, spectator_flag = Spring.GetPlayerInfo(playerID, false)
		if spectator_flag == false then
			local is_player_ready = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")
			--spEcho(#playerList, playerID, is_player_ready)
			if is_player_ready == 0 or is_player_ready == 4 then
				ready = false
			end
		end
	end

	return true, ready

end

function widget:MousePress(sx, sy)
	if showLockButton then

		-- pressing button element
		if sx > uiElementRect[1] and sx < uiElementRect[3] and sy > uiElementRect[2] and sy < uiElementRect[4] then
			-- pressing actual button
			if sx > buttonRect[1] and sx < buttonRect[3] and sy > buttonRect[2] and sy < buttonRect[4] then

				local cantPlaceNow = not canPlayerPlaceNow(myPlayerID)
				if cantPlaceNow then
					if not startPointChosen then
						return false -- can't place - can't click ready/lock
					end
				end

				-- if not pressed on ready
				if not readied then
					if not mySpec then
						if not readied then
							if isReadyBlocked then
								return true
							elseif startPointChosen then
								pressedReady = true
								readied = true
								Spring.SendLuaRulesMsg("ready_to_start_game")
								-- also default lock player in place
								locked = true
								Spring.SendLuaRulesMsg("locking_in_place")
							else
								spEcho(Spring.I18N('ui.initialSpawn.choosePoint'))
							end

						end

					-- substitute
					elseif eligibleAsSub then
						offeredAsSub = not offeredAsSub
						if offeredAsSub then
							spEcho(Spring.I18N('ui.substitutePlayers.substitutionMessage'))
						else
							spEcho(Spring.I18N('ui.substitutePlayers.offerWithdrawn'))
						end
						Spring.SendLuaRulesMsg(offeredAsSub and '\144' or '\145')
					end
				-- lock position text showing
				else
					if locked then
						locked = false
						Spring.SendLuaRulesMsg("unlocking_in_place")
					else
						locked = true
						Spring.SendLuaRulesMsg("locking_in_place")
					end
				end

				widget:ViewResize(vsx, vsy)
			end
			return true
		end

	end
end

function widget:MouseRelease(sx, sy)
	return false
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:GameFrame(gf)
	widgetHandler:RemoveWidget()
end

function widget:Initialize()
	if (Game.startPosType ~= 2) or draftMode == nil or draftMode == "disabled" then
		widgetHandler:RemoveWidget()
		return
	end

	if Spring.GetGameFrame() > 0 or isReplay then
		widgetHandler:RemoveWidget()
		return
	end

	if mySpec and enableSubbing then
		if numPlayers <= 4 or isReplay or isFFA then
			eligibleAsSub = false
		else
			eligibleAsSub = true
			-- TODO: ...check if you're eligible at all for any of the players
			--local customtable = select(11, Spring.GetPlayerInfo(myPlayerID))
			--if type(customtable) == 'table' then
			--	local tsMu = customtable.skill
			--	local tsSigma = customtable.skilluncertainty
			--end
		end
	else
	-- 	widgetHandler:RemoveWidget() -- not removing cause we still need widget:GameSetup to return true else there is player list readystate drawn on the left side of the screen
	-- 	return
	end

	local myAllyCount = getHumanCountWithinAllyTeam(myAllyTeamID)
	moreThanOneAlly = (myAllyCount > 1)

	if (Game.startPosType == 2) and (draftMode ~= nil or draftMode ~= "disabled") then
		local biggestNumberOfPlayers = 1
		local allyTeams = Spring.GetAllyTeamList()
		for i = 1, #allyTeams do
			local allyCount = getHumanCountWithinAllyTeam(allyTeams[i])
			if (allyCount > biggestNumberOfPlayers) then
				biggestNumberOfPlayers = allyCount
			end
		end
		if biggestNumberOfPlayers > bigTeamAmountOfPlayers then -- big team, not regular game
			local min_auto_ready_timer = 5 + (biggestNumberOfPlayers * (turnTimeOutBigTeam + VoteSkipTurnDelay + 1)) -- 20vs20 = 185s (5 + 180)
			if (auto_ready_timer < min_auto_ready_timer) then
				auto_ready_timer = min_auto_ready_timer
			end
		end
	end

	local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(myAllyTeamID)
	if xn and (xn ~= 0 or zn ~= 0 or xp ~= msx or zp ~= msz) then
		hasStartbox = true
	end

	widget:ViewResize(vsx, vsy)
	checkStartPointChosen()

	if (draftMode ~= nil and draftMode ~= "disabled") then
		reloadedDraftMode = os.clock()+2 -- in case you luaui reload
	end

	WG['pregameui_draft'] = {}
	WG['pregameui_draft'].addReadyCondition = function(conditionKey, description)
		if conditionKey and description then
			readyBlockedConditions[conditionKey] = description
			updateTooltip()
		end
	end
	WG['pregameui_draft'].removeReadyCondition = function(conditionKey)
		if conditionKey and readyBlockedConditions[conditionKey] then
			readyBlockedConditions[conditionKey] = nil
			updateTooltip()
		end
	end
	WG['pregameui_draft'].clearAllReadyConditions = function()
		readyBlockedConditions = {}
		updateTooltip()
	end
end

function widget:DrawScreen()
	if mySpec and not eligibleAsSub then
		return
	end
	if not startPointChosen then
		checkStartPointChosen()
	end

	-- display autoready timer
	if Spring.GetGameRulesParam("all_players_joined") == 1 and not gameStarting and auto_ready and not auto_ready_disable then
		local colorString = auto_ready_timer % 0.75 <= 0.375 and "\255\233\233\233" or "\255\255\255\255"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = mathMax(1, mathFloor(auto_ready_timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()
	end

	-- DraftOrder mod start
	local showingTeamplacementUI = false
	if draftModeLoaded then
		-- "Victory" condition was at y: 0.155 (now at 0.68) -- gui_game_type_info.lua
		-- "Pick a startspot within..." is probably at ~0.08 -- I have no idea how map_startbox.lua decids where to draw it, so if this mod is enabled, that widget won't draw it, instead we do it here
		if not mySpec then
			if draftMode ~= "fair" and myTeamPlayersOrder and (moreThanOneAlly or devUItestMode) then
				if (TeamPlacementUIshown) then
					glCallList(TeamPlacementUI)
					showingTeamplacementUI = true
				end
			end
			if draftMode == "fair" or myAllyTeamJoined then
				if hasStartbox then
					local infotext = Spring.I18N('ui.startSpot.anywhere')
					local infotextBoxes = Spring.I18N('ui.startSpot.startbox')
					font:Begin()
					font:Print(DMDefaultColorString .. infotextBoxes or infotext, vsx * 0.5, vsy * 0.18, 15.0 * uiScale, "co")
					font:End()
				end -- and if the player doens't have green box? not tell them anything?
			end
			-- non-UI part
			if draftMode ~= "fair" then
				if myTurn and currentTurnTimeout and os.clock() >= currentTurnTimeout and not startPointChosen then
					Spring.SendLuaRulesMsg("skip_my_turn")
					myTurn = false
				end

				if voteSkipTurnTimeout and os.clock() >= voteSkipTurnTimeout then
					Spring.SendLuaRulesMsg("vote_skip_turn")
					voteSkipTurnTimeout = nil
				end

				if (devUItestMode) and currentTurnTimeout then -- dev UI testing mode
					if (os.clock() >= currentTurnTimeout) or (myTurn and startPointChosen) then
						progressQueueLocally(1)
					end
				end
			end
		end
	end
	if not showingTeamplacementUI then
		if WG['guishader'] then
			WG['guishader'].RemoveRect('pregameui_draft')
		end
	end

	if not mySpec and draftMode ~= "disabled" then
		if not myAllyTeamJoined then
			local text = DMWarnColor .. Spring.I18N('ui.draftOrderMod.waitingForTeamToLoad')
			if (voteConTimeout) then
				vcttimer = mathFloor(voteConTimeout-os.clock())+1
				if (vcttimer > 0) then
					text = text .. " " .. vcttimer .. "s"
				end
			end
			font:Begin()
			font:Print(DMDefaultColorString .. text, vsx * 0.5, vsy * 0.23, 22.0 * uiScale, "co")
			font:End()
		end
		if fairTimeout and os.clock() >= fairTimeout and not ihavejoined_fair then
			Spring.SendLuaRulesMsg("i_have_joined_fair")
			ihavejoined_fair = true
		end
		if voteConTimeout and os.clock() >= voteConTimeout and ihavejoined_fair then
			-- TODO do we draw UI or spEcho that Player X have voted to forcestart draft (skip waiting for unconnected allies)?
			if not myAllyTeamJoined then
				Spring.SendLuaRulesMsg("vote_wait_too_long")
			end
			voteConTimeout = nil
		end
		if (reloadedDraftMode and os.clock() >= reloadedDraftMode) then
			reloadedDraftMode = nil
			Spring.SendLuaRulesMsg("send_me_the_info_again")
			draftModeInited()
		end
	end
	-- DOM end

	if gameStarting then
		timer = timer + Spring.GetLastUpdateSeconds()
		local colorString = timer % 0.75 <= 0.375 and "\255\233\233\233" or "\255\255\255\255"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = mathMax(1, 3 - mathFloor(timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()
	end

	drawButton()
end

local function removeUnitShape(id)
	if unitshapes[id] then
		WG.StopDrawUnitShapeGL4(unitshapes[id])
		unitshapes[id] = nil
	end
end

local function addUnitShape(id, unitDefID, px, py, pz, rotationY, teamID, opacity)
	opacity = opacity or shapeOpacity
	if unitshapes[id] then
		removeUnitShape(id)
	end
	unitshapes[id] = WG.DrawUnitShapeGL4(unitDefID, px, py, pz, rotationY, opacity, teamID, nil, nil)
	return unitshapes[id]
end

function widget:DrawWorld()
	if not WG.StopDrawUnitShapeGL4 then return end

	-- draw pregamestart commander models at start positions
	local id
	for i = 1, #teamList do
		local teamID = teamList[i]
		local tsx, tsy, tsz = Spring.GetTeamStartPosition(teamID)
		if tsx and tsx > 0 then
			local startUnitDefID = Spring.GetTeamRulesParam(teamID, 'startUnit')
			if startUnitDefID then
				id = startUnitDefID..'_'..tsx..'_'..spGetGroundHeight(tsx, tsz)..'_'..tsz
				if teamStartPositions[teamID] ~= id then
					removeUnitShape(teamStartPositions[teamID])
					teamStartPositions[teamID] = id
					addUnitShape(id, startUnitDefID, tsx, spGetGroundHeight(tsx, tsz), tsz, 0, teamID, 1)
				end
			end
		end
	end
end

-- DraftOrder mod start
local sec = 0
function widget:Update(dt)
	if mySpec and not eligibleAsSub then
		return
	end
	if draftMode == nil or draftMode == "disabled" then
		widgetHandler:RemoveCallIn("Update")
		return
	end
	sec = sec + dt
	if sec >= 0.05 then -- 20 updates per second
		sec = 0
		if TeamPlacementUI ~= nil then
			glDeleteList(TeamPlacementUI)
			TeamPlacementUI = nil
			TeamPlacementUIshown = false
			DrawTeamPlacement()
		end
	end
end

function widget:RecvLuaMsg(msg, playerID)
	local words = {}
	for word in msg:gmatch("%S+") do
		tableInsert(words, word)
	end

	if words[1] == "DraftOrderPlayersOrder" then
		allyTeamID_about = tonumber(words[2] or -1)
		if allyTeamID_about ~= myAllyTeamID then return end
		if myTeamPlayersOrder == nil then
			myTeamPlayersOrder = {}
			if devUItestMode then
				local fakePlayers = mathRandom(16)
				for i = 1, fakePlayers do
					tableInsert(myTeamPlayersOrder, {id = 30+i, name = "Player"..tostring((i+9+mathRandom(1000000))) }) -- debug
				end
			end
			for i = 3, #words do
				local playerid = tonumber(words[i])
				tname = select(1, Spring.GetPlayerInfo(playerid, false))
				tname = ((WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(playerid)) or tname
				tableInsert(myTeamPlayersOrder, {id = playerid, name = tname })
			end
			if #myTeamPlayersOrder > bigTeamAmountOfPlayers then -- big team, not regular game
				turnTimeOut = turnTimeOutBigTeam
			end
			if devUItestMode then -- dev UI testing mode
				currentPlayerIndex = 1 -- simulating queue progress on local end only
				progressQueueLocally(0)
			end
			if (moreThanOneAlly or devUItestMode) then
				DrawTeamPlacement()
			end
			voteConTimeout = nil
		end
	elseif words[1] == "DraftOrderPlayerTurn" then
		allyTeamID_about = tonumber(words[2] or -1)
		if allyTeamID_about ~= myAllyTeamID then return end
		local oldIndex = currentPlayerIndex
		if not devUItestMode then -- production: trust the gadget
			currentPlayerIndex = tonumber(words[3] or -1)
			if myTeamPlayersOrder and oldIndex ~= currentPlayerIndex then
				if myTeamPlayersOrder[currentPlayerIndex] and myTeamPlayersOrder[currentPlayerIndex].id ~= nil then
					current_playerID = myTeamPlayersOrder[currentPlayerIndex].id
				else
					current_playerID = -1
				end
				if myTeamPlayersOrder[currentPlayerIndex+1] and myTeamPlayersOrder[currentPlayerIndex+1].id ~= nil then
					next_playerID = myTeamPlayersOrder[currentPlayerIndex+1].id
				else
					next_playerID = -1
				end

				if current_playerID == myPlayerID then
					myTurn = true
					PlayChooseStartLocSound()
				elseif next_playerID == myPlayerID then
					Spring.PlaySoundFile("beep6", 1, 'ui')
				elseif myTurn then
					myTurn = false
				end
				if current_playerID > -1 then
					currentTurnTimeout = os.clock() + turnTimeOut
					voteSkipTurnTimeout = os.clock() + turnTimeOut + VoteSkipTurnDelay -- skip last turn anyway if they don't place AND they are NOT connected
				end
			end
		end
	elseif words[1] == "DraftOrderAllyTeamJoined" then
		allyTeamID_about = tonumber(words[2] or -1)
		if (allyTeamID_about == myAllyTeamID) and (myAllyTeamJoined ~= true) then
			myAllyTeamJoined = true
			if draftMode == "fair" then
				PlayChooseStartLocSound()
			end
		end
	elseif words[1] == "DraftOrderShowCountdown" then
		allyTeamID_about = tonumber(words[2] or -1)
		if (allyTeamID_about == myAllyTeamID) and (myAllyTeamJoined ~= true) and (connectionTimeoutHappened == false) then
			voteConTimeout = os.clock() + connectionTimeOut
			connectionTimeoutHappened = true
		end
	elseif words[1]:sub(1, 11) == "DraftOrder_" then
		reloadedDraftMode = nil
		draftModeInited()
	end
end
-- DOM end

function widget:Shutdown()
	glDeleteList(buttonList)
	glDeleteList(buttonHoverList)
	glDeleteList(TeamPlacementUI)
	gl.DeleteFont(font)
	if WG['guishader'] then
		WG['guishader'].RemoveRect('pregameui_draft')
	end
	if WG.StopDrawUnitShapeGL4 then
		for id, _ in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
	WG['pregameui_draft'] = nil
end
