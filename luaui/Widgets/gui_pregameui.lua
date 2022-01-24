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

local fontfile = "fonts/" .. Spring.GetConfigString("bar_font2", "Exo2-SemiBold.otf")
local vsx, vsy = Spring.GetViewGeometry()
local fontfileScale = (0.5 + (vsx * vsy / 6200000))
local fontfileSize = 50
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local uiScale = (0.7 + (vsx * vsy / 6500000))
local myPlayerID = Spring.GetMyPlayerID()
local _, _, mySpec, myTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local ffaMode = Spring.GetModOptions().ffa_mode
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

local buttonX = math.floor(vsx * 0.8)
local buttonY = math.floor(vsy * 0.77)

local orgbuttonH = 40
local orgbuttonW = 115

local buttonH = orgbuttonH * uiScale
local buttonW = orgbuttonW * uiScale

local buttonList, buttonHoverList
local buttonText = ''
local buttonDrawn = false

local RectRound, UiElement, UiButton, elementPadding, uiPadding

local eligibleAsSub = false
local offeredAsSub = false
local allowUnready = false	-- not enabled cause unreadying doesnt work

local numPlayers = Spring.Utilities.GetPlayerCount()

local shapeOpacity = 0.6
local unitshapes = {}
local teamStartPositions = {}
local buildQueueShapes = {}
local teamList = Spring.GetTeamList()

local function createButton()
	local color = { 0.15, 0.15, 0.15 }
	if not mySpec then
		color = readied and unreadyButtonColor or readyButtonColor
	elseif eligibleAsSub then
		color = offeredAsSub and unsubButtonColor or subButtonColor
	end
	gl.DeleteList(buttonList)
	buttonList = gl.CreateList(function()
		UiElement(buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding, 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2), 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.55, color[2]*0.55, color[3]*0.55, 1 }, { color[1], color[2], color[3], 1 })
	end)
	gl.DeleteList(buttonHoverList)
	buttonHoverList = gl.CreateList(function()
		UiElement(buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding, 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2), 1, 1, 1, 1, 1, 1, 1, 1, nil, { color[1]*0.85, color[2]*0.85, color[3]*0.85, 1 }, { color[1]*1.5, color[2]*1.5, color[3]*1.5, 1 })
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
			buttonText = Spring.I18N('ui.initialSpawn.unready')
		else
			buttonText = Spring.I18N('ui.initialSpawn.ready')
		end
	end

	vsx, vsy = Spring.GetViewGeometry()
	uiScale = (0.75 + (vsx * vsy / 6000000))
	buttonX = math.floor(vsx * 0.78)
	buttonY = math.floor(vsy * 0.78)
	orgbuttonW = font:GetTextWidth('       '..buttonText) * 24
	buttonW = math.floor(orgbuttonW * uiScale / 2) * 2
	buttonH = math.floor(orgbuttonH * uiScale / 2) * 2

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
	uiPadding = math.floor(elementPadding * 4.5)

	createButton()
end

function widget:GameSetup(state, ready, playerStates)

	-- check when the 3.2.1 countdown starts
	if not gameStarting and ((Spring.GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0) > 0) then
		gameStarting = true		-- ugly but effective (can also detect by parsing state string)
	end

	-- if we can't choose startpositions, no need for ready button etc
	if Game.startPosType ~= 2 or ffaMode then
		return true, true
	end

	-- set my readyState to true if ffa
	if ffaMode and (not readied or not ready) then
		readied = true
		return true, true
	end

	if not ready and pressedReady then	-- check if we just readied
		ready = true
	elseif ready and not pressedReady then 	-- check if we just reconnected/dropped
		ready = false
	end

	pressedReady = playerStates[Spring.GetMyPlayerID()] == 'ready'
	local prevReadied = readied
	readied = pressedReady
	if prevReadied ~= ready then
		widget:ViewResize(vsx, vsy)
	end
	--Spring.Echo(ready, pressedReady, os.clock(), Spring.Debug.TableEcho(playerStates)) --, Spring.Debug.TableEcho(playerStates)
	return true, ready
end

function widget:MousePress(sx, sy)
	if buttonDrawn then

		-- pressing element
		if sx > buttonX - (buttonW / 2) - uiPadding and sx < buttonX + (buttonW / 2) + uiPadding and sy > buttonY - (buttonH / 2) - uiPadding and sy < buttonY + (buttonH / 2) + uiPadding then
			-- pressing button
			if sx > buttonX - (buttonW / 2) and sx < buttonX + (buttonW / 2) and sy > buttonY - (buttonH / 2) and sy < buttonY + (buttonH / 2) then

				-- ready
				if not mySpec then
					if not readied then
						if startPointChosen then
							pressedReady = true
						else
							Spring.Echo(Spring.I18N('ui.initialSpawn.choosePoint'))
						end
					else
						readied = false
						pressedReady = false
						--Spring.SendLuaRulesMsg( ) -- if it doesnt work, try implementing this
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
		if x ~= nil and x > 0 and z > 0 then
			startPointChosen = true
		end
	end
end

function widget:LanguageChanged()
	widget:ViewResize()
end

function widget:Initialize()
	if mySpec then
		if not mySpec or numPlayers <= 4 or isReplay or ffaMode or Spring.GetGameFrame() > 0 then
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
	if isReplay then
		return
	end
	if not startPointChosen then
		checkStartPointChosen()
	end

	if WG['guishader'] then
		WG['guishader'].RemoveRect('pregameui')
	end

	buttonDrawn = false

	if gameStarting then
		timer = timer + Spring.GetLastUpdateSeconds()
		local colorString = timer % 0.75 <= 0.375 and "\255\233\233\233" or "\255\255\255\255"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = math.max(1, 3 - math.floor(timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()

	elseif (not readied or allowUnready) and buttonList and Game.startPosType == 2 and (not mySpec or eligibleAsSub) then
		buttonDrawn = true
		if WG['guishader'] then
			WG['guishader'].InsertRect(
				buttonX - ((buttonW / 2) + uiPadding),
				buttonY - ((buttonH / 2) + uiPadding),
				buttonX + ((buttonW / 2) + uiPadding),
				buttonY + ((buttonH / 2) + uiPadding),
				'pregameui'
			)
		end

		-- draw button and text
		local x, y = Spring.GetMouseState()
		local colorString
		if x > buttonX - (buttonW / 2) and x < buttonX + (buttonW / 2) and y > buttonY - (buttonH / 2) and y < buttonY + (buttonH / 2) then
			gl.CallList(buttonHoverList)
			colorString = "\255\210\210\210"
		else
			gl.CallList(buttonList)
			timer2 = timer2 + Spring.GetLastUpdateSeconds()
			if mySpec then
				colorString = offeredAsSub and "\255\255\255\225" or "\255\222\222\222"
			else
				colorString = timer % 0.75 <= 0.375 and "\255\222\222\222" or "\255\255\255\255"
			end
		end
		font:Begin()
		font:Print(colorString .. buttonText, buttonX, buttonY - (buttonH * 0.16), 24 * uiScale, "co")
		font:End()
		gl.Color(1, 1, 1, 1)
	end

	if Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
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
