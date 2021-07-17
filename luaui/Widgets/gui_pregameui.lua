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
local fontfileScale = (0.5 + (vsx * vsy / 5700000))
local fontfileSize = 50
local fontfileOutlineSize = 10
local fontfileOutlineStrength = 1.4
local font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)

local uiScale = (0.8 + (vsx * vsy / 5000000))
local myPlayerID = Spring.GetMyPlayerID()
local _, _, spec, myTeamID = Spring.GetPlayerInfo(myPlayerID, false)
local amNewbie
local ffaMode = (tonumber(Spring.GetModOptions().ffa_mode) or 0) == 1
local isReplay = Spring.IsReplay()

local readied = false --make sure we return true,true for newbies at least once
local startPointChosen = false

local NETMSG_STARTPLAYING = 4 -- see BaseNetProtocol.h, packetID sent during the 3.2.1 countdown
local SYSTEM_ID = -1 -- see LuaUnsyncedRead::GetPlayerTraffic, playerID to get hosts traffic from
local gameStarting
local timer = 0
local timer2 = 0

local buttonX = math.floor(vsx * 0.77)
local buttonY = math.floor(vsy * 0.77)

local orgbuttonH = 40
local orgbuttonW = 115

local buttonH = orgbuttonH * uiScale
local buttonW = orgbuttonW * uiScale

local buttonList, buttonHoverList

local RectRound = Spring.FlowUI.Draw.RectRound
local UiElement = Spring.FlowUI.Draw.Element
local UiButton = Spring.FlowUI.Draw.Button
local elementPadding = Spring.FlowUI.elementPadding
local uiPadding = math.floor(elementPadding * 4.5)

local function createButton()
	buttonList = gl.DeleteList(buttonList)
	buttonList = gl.CreateList(function()
		UiElement(buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding, 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2), 1, 1, 1, 1, 1, 1, 1, 1, nil, { 0.15, 0.11, 0, 1 }, { 0.28, 0.21, 0, 1 })
	end)
	buttonHoverList = gl.DeleteList(buttonHoverList)
	buttonHoverList = gl.CreateList(function()
		UiElement(buttonX - (buttonW / 2) - uiPadding, buttonY - (buttonH / 2) - uiPadding, buttonX + (buttonW / 2) + uiPadding, buttonY + (buttonH / 2) + uiPadding, 1, 1, 1, 1, 1, 1, 1, 1)
		UiButton(buttonX - (buttonW / 2), buttonY - (buttonH / 2), buttonX + (buttonW / 2), buttonY + (buttonH / 2), 1, 1, 1, 1, 1, 1, 1, 1, nil, { 0.25, 0.20, 0, 1 }, { 0.44, 0.35, 0, 1 })
	end)
end

function widget:ViewResize(viewSizeX, viewSizeY)
	vsx, vsy = Spring.GetViewGeometry()

	uiScale = (0.8 + (vsx * vsy / 5000000))

	buttonX = math.floor(vsx * 0.78)
	buttonY = math.floor(vsy * 0.78)

	orgbuttonW = font:GetTextWidth('       '..Spring.I18N('ui.initialSpawn.ready')) * 24
	buttonW = math.floor(orgbuttonW * uiScale / 2) * 2
	buttonH = math.floor(orgbuttonH * uiScale / 2) * 2

	local newFontfileScale = (0.5 + (vsx * vsy / 5700000))
	if fontfileScale ~= newFontfileScale then
		fontfileScale = newFontfileScale
		gl.DeleteFont(font)
		font = gl.LoadFont(fontfile, fontfileSize * fontfileScale, fontfileOutlineSize * fontfileScale, fontfileOutlineStrength)
	end

	UiElement = Spring.FlowUI.Draw.Element
	UiButton = Spring.FlowUI.Draw.Button
	elementPadding = Spring.FlowUI.elementPadding
	uiPadding = math.floor(elementPadding * 4.5)

	createButton()
end

function widget:GameSetup(state, ready, playerStates)

	-- check when the 3.2.1 countdown starts
	if gameStarting == nil and ((Spring.GetPlayerTraffic(SYSTEM_ID, NETMSG_STARTPLAYING) or 0) > 0) then
		--ugly but effective (can also detect by parsing state string)
		gameStarting = true
	end

	-- if we can't choose startpositions, no need for ready button etc
	if Game.startPosType ~= 2 or ffaMode then
		return true, true
	end

	-- set my readyState to true if i am a newbie, or if ffa
	if not readied or not ready then
		amNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1)
		if amNewbie or ffaMode then
			readied = true
			return true, true
		end
	end

	if not ready and readied then
		-- check if we just readied
		ready = true
	elseif ready and not readied then
		-- check if we just reconnected/dropped
		ready = false
	end

	return true, ready
end

function widget:MousePress(sx, sy)
	-- pressing ready element
	if sx > buttonX - (buttonW / 2) - uiPadding and sx < buttonX + (buttonW / 2) + uiPadding and sy > buttonY - (buttonH / 2) - uiPadding and sy < buttonY + (buttonH / 2) + uiPadding and Spring.GetGameFrame() <= 0 and Game.startPosType == 2 and gameStarting == nil and not spec then
		-- pressing ready button
		if sx > buttonX - (buttonW / 2) and sx < buttonX + (buttonW / 2) and sy > buttonY - (buttonH / 2) and sy < buttonY + (buttonH / 2) then
			if startPointChosen then
				readied = true
			else
				Spring.Echo(Spring.I18N('ui.initialSpawn.choosePoint'))
			end
		end
		return true
	end
	-- message when trying to place startpoint but can't
	if amNewbie then
		local target, _ = Spring.TraceScreenRay(sx, sy)
		if target == "ground" then
			Spring.Echo(Spring.I18N('ui.initialSpawn.newbiePlacer'))
		end
	end
end

function widget:MouseRelease(sx, sy)
	return false
end

local function checkStartPointChosen()
	local _, _, spec = Spring.GetPlayerInfo(myPlayerID, false)
	local isNewbie = (Spring.GetTeamRulesParam(myTeamID, 'isNewbie') == 1) -- =1 means the startpoint will be replaced and chosen by initial_spawn
	if not spec and not isNewbie then
		local x, y, z = Spring.GetTeamStartPosition(myTeamID)
		if x ~= nil and x > 0 and z > 0 then
			startPointChosen = true
		end
	end
end

function widget:Initialize()
	checkStartPointChosen()
	widget:ViewResize(vsx, vsy)
end

function widget:DrawScreen()

	if not startPointChosen then
		checkStartPointChosen()
	end

	if WG['guishader'] then
		WG['guishader'].RemoveRect('ready')
	end

	if not readied and buttonList and Game.startPosType == 2 and gameStarting == nil and not spec and not isReplay then
		--if not readied and buttonList and not spec and not isReplay then

		if WG['guishader'] then
			WG['guishader'].InsertRect(
				buttonX - ((buttonW / 2) + uiPadding),
				buttonY - ((buttonH / 2) + uiPadding),
				buttonX + ((buttonW / 2) + uiPadding),
				buttonY + ((buttonH / 2) + uiPadding),
				'ready'
			)
		end

		-- draw ready button and text
		local x, y = Spring.GetMouseState()
		local colorString
		if x > buttonX - (buttonW / 2) and x < buttonX + (buttonW / 2) and y > buttonY - (buttonH / 2) and y < buttonY + (buttonH / 2) then
			gl.CallList(buttonHoverList)
			colorString = "\255\255\222\0"
		else
			gl.CallList(buttonList)
			timer2 = timer2 + Spring.GetLastUpdateSeconds()
			colorString = timer % 0.75 <= 0.375 and "\255\255\233\33" or "\255\255\250\210"
		end
		font:Begin()
		font:Print(colorString .. Spring.I18N('ui.initialSpawn.ready'), buttonX, buttonY - (buttonH * 0.16), 24 * uiScale, "co")
		font:End()
		gl.Color(1, 1, 1, 1)
	end

	if gameStarting and not isReplay then
		timer = timer + Spring.GetLastUpdateSeconds()
		local colorString = timer % 0.75 <= 0.375 and "\255\255\233\33" or "\255\255\250\210"
		local text = colorString .. Spring.I18N('ui.initialSpawn.startCountdown', { time = math.max(1, 3 - math.floor(timer)) })
		font:Begin()
		font:Print(text, vsx * 0.5, vsy * 0.67, 18.5 * uiScale, "co")
		font:End()
	end

	if Spring.GetGameFrame() > 0 then
		widgetHandler:RemoveWidget()
		return
	end
end

function widget:Shutdown()
	gl.DeleteList(buttonList)
	gl.DeleteList(buttonHoverList)
	gl.DeleteFont(font)
	if WG['guishader'] then
		WG['guishader'].RemoveRect('ready')
	end
end
