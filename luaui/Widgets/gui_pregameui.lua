local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Pregame UI",
		desc = "",
		author = "Floris",
		date = "July 2021",
		license = "GNU GPL, v2 or later",
		layer = -3,
		enabled = true
	}
end

local draftMode = Spring.GetModOptions().draft_mode

local vsx, vsy = Spring.GetViewGeometry()

local uiScale = (0.7 + (vsx * vsy / 6500000))
local myPlayerID = Spring.GetMyPlayerID()
local _, _, mySpec, myTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local isFFA = Spring.Utilities.Gametype.IsFFA()
local isReplay = Spring.IsReplay()

local readyButtonColor = {0.05, 0.28, 0}
local unreadyButtonColor = {0.28, 0.05, 0}
local subButtonColor = {0.08, 0.22, 0}
local unsubButtonColor = {0.22, 0.08, 0}

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
local buttonX = math.floor(vsx * buttonPosX)
local buttonY = math.floor(vsy * buttonPosY)

local orgbuttonH = 40
local orgbuttonW = 115

local buttonW = math.floor(orgbuttonW * uiScale / 2) * 2
local buttonH = math.floor(orgbuttonH * uiScale / 2) * 2

local buttonList, buttonHoverList
local buttonText = ''
local buttonDrawn = false
local lockText = ''
local locked = false

local UiElement, UiButton, elementPadding, uiPadding

local enableSubbing = false
local eligibleAsSub = false
local offeredAsSub = false
--local allowUnready = false	-- not enabled cause unreadying doesnt work, have to do workaroud
local showLockButton = true

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

local function createButton()
	local color = { 0.15, 0.15, 0.15 }
	if not mySpec then
		if not locked then
			color = readyButtonColor
		else
			color = unreadyButtonColor
		end
	elseif eligibleAsSub then
		color = offeredAsSub and unsubButtonColor or subButtonColor
	end
	uiElementRect = { buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding }
	buttonRect = { buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2) }

	gl.DeleteList(buttonList)
	buttonList = gl.CreateList(function()
		UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.55, color[2]*0.55, color[3]*0.55, 1 }, { color[1], color[2], color[3], 1 })
	end)
	gl.DeleteList(buttonHoverList)
	buttonHoverList = gl.CreateList(function()
		UiElement(uiElementRect[1], uiElementRect[2], uiElementRect[3], uiElementRect[4], 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.85, color[2]*0.85, color[3]*0.85, 1 }, { color[1]*1.5, color[2]*1.5, color[3]*1.5, 1 })
	end)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	if mySpec then
		if not offeredAsSub then
			buttonText = Spring.I18N('ui.substitutePlayers.offer')
		else
			buttonText = Spring.I18N('ui.substitutePlayers.withdraw')
		end
	else
		if readied then
			if locked then
				buttonText = Spring.I18N('ui.initialSpawn.unlock')
			else
				buttonText = Spring.I18N('ui.initialSpawn.lock')
			end
		else
			buttonText = Spring.I18N('ui.initialSpawn.ready')
		end
	end

	vsx, vsy = Spring.GetViewGeometry()

	font = WG['fonts'].getFont(2)

	uiScale = (0.75 + (vsx * vsy / 6000000))
	buttonX = math.floor(vsx * buttonPosX)
	buttonY = math.floor(vsy * buttonPosY)
	orgbuttonW = font:GetTextWidth('       '..buttonText) * 24
	buttonW = math.floor(orgbuttonW * uiScale / 2) * 2
	buttonH = math.floor(orgbuttonH * uiScale / 2) * 2

	UiElement = WG.FlowUI.Draw.Element
	UiButton = WG.FlowUI.Draw.Button
	elementPadding = WG.FlowUI.elementPadding
	uiPadding = math.floor(elementPadding * 4.5)

	createButton()

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

	-- starts game after a specified amount of time after all players have joined
	if Spring.GetGameRulesParam("all_players_joined") == 1 and not gameStarting and auto_ready then
		auto_ready_timer = auto_ready_timer - Spring.GetLastUpdateSeconds()
	end
	if auto_ready_timer <=0 and auto_ready == true then
		return true, true
	end

	-- only return true, true once ALL players are ready
	ready = true
	local playerList = Spring.GetPlayerList()
	for _, playerID in pairs(playerList) do
		local _, _, spectator_flag = Spring.GetPlayerInfo(playerID)
		if spectator_flag == false then
			local is_player_ready = Spring.GetGameRulesParam("player_" .. playerID .. "_readyState")
			--Spring.Echo(#playerList, playerID, is_player_ready)
			if is_player_ready == 0 or is_player_ready == 4 then
				ready = false
			end
		end
	end

	return true, ready

end

function widget:MousePress(sx, sy)
	if buttonDrawn then

		-- pressing button element
		if sx > uiElementRect[1] and sx < uiElementRect[3] and sy > uiElementRect[2] and sy < uiElementRect[4] then
			-- pressing actual button
			if sx > buttonRect[1] and sx < buttonRect[3] and sy > buttonRect[2] and sy < buttonRect[4] then

				-- if not pressed on ready
				if not readied then
					if not mySpec then
						if not readied then
							if startPointChosen then
								pressedReady = true
								readied = true
								Spring.SendLuaRulesMsg("ready_to_start_game")
								-- also default lock player in place
								locked = true
								Spring.SendLuaRulesMsg("locking_in_place")
							else
								Spring.Echo(Spring.I18N('ui.initialSpawn.choosePoint'))
							end

						end

					-- substitute
					elseif eligibleAsSub then
						offeredAsSub = not offeredAsSub
						if offeredAsSub then
							Spring.Echo(Spring.I18N('ui.substitutePlayers.substitutionMessage'))
						else
							Spring.Echo(Spring.I18N('ui.substitutePlayers.offerWithdrawn'))
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

local function checkStartPointChosen()
	if not mySpec then
		local x, y, z = Spring.GetTeamStartPosition(myTeamID)
		if x ~= nil and x > 0 and z ~= nil and z > 0 then
			startPointChosen = true
		end
	end
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:GameFrame(gf)
	widgetHandler:RemoveWidget()
end

function widget:Initialize()
	if (Game.startPosType == 2) and draftMode ~= nil and draftMode ~= "disabled" then
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
	end

	widget:ViewResize(vsx, vsy)
	checkStartPointChosen()
end

function widget:DrawScreen()
	if not startPointChosen then
		checkStartPointChosen()
	end

	if WG['guishader'] then
		WG['guishader'].RemoveRect('pregameui')
	end

	buttonDrawn = false

	-- display autoready timer
	if Spring.GetGameRulesParam("all_players_joined") == 1 and not gameStarting and auto_ready then
		local colorString = auto_ready_timer % 0.75 <= 0.375 and "\255\233\233\233" or "\255\255\255\255"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = math.max(1, math.floor(auto_ready_timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()
	end

	local showbutton = false
	-- ((not readied or showLockButton) or (mySpec and eligibleAsSub)) and buttonList and Game.startPosType == 2
	if buttonList and Game.startPosType == 2 then
		if mySpec then
			if eligibleAsSub then
				showbutton = true
			end
		else
			if not readied or showLockButton then
				showbutton = true
			end
		end
	end

	if gameStarting then
		timer = timer + Spring.GetLastUpdateSeconds()
		local colorString = timer % 0.75 <= 0.375 and "\255\233\233\233" or "\255\255\255\255"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = math.max(1, 3 - math.floor(timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()

	elseif showbutton == true then

		local playerList = Spring.GetPlayerList()
		local numPlayers = #playerList
		local numPlayersReady = 0
		if numPlayers > 3 then
			for _, playerID in pairs(playerList) do
				local readystate = Spring.GetGameRulesParam("player_" .. tostring(playerID) .. "_readyState")
				if readystate == -1 or readystate == 1 or readystate == 2 then
					numPlayersReady = numPlayersReady + 1
				end
			end
			blinkButton = (numPlayers / numPlayersReady > 0.75)
		end

		buttonDrawn = true
		if WG['guishader'] then
			WG['guishader'].InsertRect(
				uiElementRect[1],
				uiElementRect[2],
				uiElementRect[3],
				uiElementRect[4],
				'pregameui'
			)
		end

		-- draw ready button and text
		local x, y = Spring.GetMouseState()
		local colorString
		if x > buttonRect[1] and x < buttonRect[3] and y > buttonRect[2] and y < buttonRect[4] then
			gl.CallList(buttonHoverList)
			colorString = "\255\210\210\210"
		else
			gl.CallList(buttonList)
			timer2 = timer2 + Spring.GetLastUpdateSeconds()
			if mySpec then
				colorString = offeredAsSub and "\255\255\255\225" or "\255\222\222\222"
			else
				colorString = os.clock() % 0.75 <= 0.375 and "\255\255\255\255" or "\255\222\222\222"
			end
			if readied then
				colorString = "\255\222\222\222"
			end
			if blinkButton and not readied and os.clock() % 0.75 <= 0.375 then
				local mult = 1.33
				UiButton(buttonRect[1], buttonRect[2], buttonRect[3], buttonRect[4], 1, 1, 1, 1, 1, 1, 1, 1, nil, { readyButtonColor[1]*0.55*mult, readyButtonColor[2]*0.55*mult, readyButtonColor[3]*0.55*mult, 1 }, { readyButtonColor[1]*mult, readyButtonColor[2]*mult, readyButtonColor[3]*mult, 1 })
			end
		end
		font:Begin()
		font:Print(colorString .. buttonText, buttonRect[1]+((buttonRect[3]-buttonRect[1])/2), (buttonRect[2]+((buttonRect[4]-buttonRect[2])/2)) - (buttonH * 0.16), 24 * uiScale, "co")
		font:End()
		gl.Color(1, 1, 1, 1)
	end
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
				id = startUnitDefID..'_'..tsx..'_'..Spring.GetGroundHeight(tsx, tsz)..'_'..tsz
				if teamStartPositions[teamID] ~= id then
					removeUnitShape(teamStartPositions[teamID])
					teamStartPositions[teamID] = id
					addUnitShape(id, startUnitDefID, tsx, Spring.GetGroundHeight(tsx, tsz), tsz, 0, teamID, 1)
				end
			end
		end
	end
end

function widget:Shutdown()
	gl.DeleteList(buttonList)
	gl.DeleteList(buttonHoverList)
	gl.DeleteFont(font)
	if WG['guishader'] then
		WG['guishader'].RemoveRect('pregameui')
	end
	if WG.StopDrawUnitShapeGL4 then
		for id, _ in pairs(unitshapes) do
			removeUnitShape(id)
		end
	end
end
