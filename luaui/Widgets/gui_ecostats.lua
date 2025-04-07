
--if #Spring.GetAllyTeamList()-1 > 16 then
--	return
--end

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ecostats",
		desc = "Display team eco",
		author = "Floris (original by Jools)",
		date = "nov, 2015",
		license = "GNU GPL, v2 or later",
		layer = 1,
		enabled = true
	}
end

local useRenderToTexture = Spring.GetConfigFloat("ui_rendertotexture", 0) == 1		-- much faster than drawing via DisplayLists only

local cfgResText = true
local cfgSticktotopbar = true
local cfgRemoveDead = false
local cfgTrackReclaim = true

local teamData = {}
local allyData = {}
local allyIDdata = {}
local reclaimerUnits = {}
local textLists = {}
local avgData = {}
local uiElementRects = {}
local tooltipAreas = {}
local guishaderRects = {}
local guishaderRectsDlists = {}
local lastTextListUpdate = os.clock() - 10
local lastBarsUpdate = os.clock() - 10
local gamestarted = false
local gameover = false
local inSpecMode = false
local isReplay = Spring.IsReplay()
local myAllyID = Spring.GetLocalAllyTeamID()
local vsx, vsy = Spring.GetViewGeometry()
local topbarShowButtons = true

local sin = math.sin
local floor = math.floor
local math_isInRect = math.isInRect

local GetGameSeconds = Spring.GetGameSeconds
local GetGameFrame = Spring.GetGameFrame
local glColor = gl.Color
local glTexRect = gl.TexRect

local GetGameSpeed = Spring.GetGameSpeed
local GetTeamUnitCount = Spring.GetTeamUnitCount
local GetMyAllyTeamID = Spring.GetMyAllyTeamID
local GetTeamList = Spring.GetTeamList
local GetTeamInfo = Spring.GetTeamInfo
local GetPlayerInfo = Spring.GetPlayerInfo
local GetTeamColor = Spring.GetTeamColor
local GetTeamResources = Spring.GetTeamResources
local GetUnitResources = Spring.GetUnitResources

local RectRound, UiElement

local font, teamCompositionList

local Button = {}

local lastPlayerChange = 0
local aliveAllyTeams = 0
local right = true
local widgetHeight = 0
local widgetWidth = 130
local tH = 40 -- team row height
local WBadge = 14 -- width of player badge (team rect)
local HBadge = 14 -- width of player badge (team rect)
local cW = 100 -- column width
local ctrlDown = false
local textsize = 14
local maxPlayers = 0
local refreshCaptions = false
local maxMetal, maxEnergy = 0, 0

local ui_scale = tonumber(Spring.GetConfigFloat("ui_scale", 1) or 1)

local maxTeamsize = 0
for i=1, #Spring.GetAllyTeamList()-1 do
	if #Spring.GetTeamList(i) > maxTeamsize then
		maxTeamsize = #Spring.GetTeamList(i)
	end
end
local playerScale = math.clamp(14 / maxTeamsize, 0.15, 1)

local widgetScale = 0.95 + (vsx * vsy / 7500000)        -- only used for rounded corners atm
local sizeMultiplier = 1
local borderPadding = 4.5
local avgFrames = 8
local xRelPos, yRelPos = 1, 1
local widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
local singleTeams = (#Spring.GetTeamList() - 1 == #Spring.GetAllyTeamList() - 1)
local enableStartposbuttons = not Spring.Utilities.Gametype.IsFFA()	-- spots wont match when ffa
local myFullview = select(2, Spring.GetSpectatingState())
local myTeamID = Spring.GetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local gaiaID = Spring.GetGaiaTeamID()
local gaiaAllyID = select(6, GetTeamInfo(gaiaID, false))

local images = {
	bar = "LuaUI/Images/ecostats/bar.png",
	barbg = "LuaUI/Images/ecostats/barbg.png",
	barglowcenter = ":n:LuaUI/Images/ecostats/barglow-center.png",
	barglowedge = ":n:LuaUI/Images/ecostats/barglow-edge.png",
}

local comDefs = {}
local reclaimerUnitDefs = {}
for udefID, def in ipairs(UnitDefs) do
	if def.isBuilder and not def.isFactory then
		reclaimerUnitDefs[udefID] = { def.metalMake, def.energyMake }
	end
	if def.customParams.iscommander then
		comDefs[udefID] = true
	end
end

local function getTeamSum(allyIndex, param)
	local tValue = 0
	local teamList = allyData[allyIndex].teams
	for _, tID in pairs(teamList) do
		if tID ~= gaiaID then
			tValue = tValue + (teamData[tID][param] or 0)
		end
	end
	return tValue
end

local function isTeamReal(allyID)
	if allyID == nil then
		return false
	end
	local leaderID, isDead, unitCount, leaderName
	for _, tID in ipairs(GetTeamList(allyID)) do
		_, leaderID, isDead = GetTeamInfo(tID, false)
		unitCount = GetTeamUnitCount(tID)
		leaderName = GetPlayerInfo(leaderID, false)
		if leaderName ~= nil or isDead or unitCount > 0 then
			return true
		end
	end
	return false
end

local function isTeamAlive(allyID)
	for _, tID in pairs(allyData[allyID + 1].teams) do
		if teamData[tID] and (not teamData[tID].isDead) then
			return true
		end
	end
	return false
end

local function getNbTeams()
	local nbTeams = 0
	for _, data in ipairs(allyData) do
		if #(data.teams) > 0 then
			nbTeams = nbTeams + 1
		end
	end
	return nbTeams
end

local function getMaxPlayers()
	local maxPlayers = 0
	local myNum
	for _, data in ipairs(allyData) do
		myNum = #data.teams
		if myNum > maxPlayers then
			maxPlayers = myNum
		end
	end
	return maxPlayers
end

local function getNbPlacedPositions(teamID)
	local nbPlayers = 0
	local startx, starty, active, leaderID, leaderName, isDead

	for _, pID in ipairs(GetTeamList(teamID)) do
		if teamData[pID] == nil then
			Spring.Echo("getNbPlacedPositions returned nil:", teamID)
			return nil
		end
		leaderID = teamData[pID].leaderID
		if leaderID == nil then
			Spring.Echo("getNbPlacedPositions returned nil:", teamID)
			return nil
		end
		startx = teamData[pID].startx or -1
		starty = teamData[pID].starty or -1
		active = teamData[pID].active
		leaderName, active = GetPlayerInfo(leaderID, false)

		isDead = teamData[pID].isDead
		if (active and startx >= 0 and starty >= 0 and leaderName ~= nil) or isDead then
			nbPlayers = nbPlayers + 1
		end
	end
	return nbPlayers
end

local function updateDrawPos()
	local drawpos = 0
	aliveAllyTeams = 0
	if WG.allyTeamRanking then
		for _, allyID in pairs(WG.allyTeamRanking) do
			local dataID = allyIDdata[allyID]
			if allyData[dataID] then
				if isTeamReal(allyID) and (allyID == GetMyAllyTeamID() or inSpecMode) and allyData[dataID].isAlive then
					aliveAllyTeams = aliveAllyTeams + 1
					drawpos = drawpos + 1
					allyData[dataID].drawpos = drawpos
				end
			end
		end
	else
		for _, data in ipairs(allyData) do
			local allyID = data.aID
			if isTeamReal(allyID) and (allyID == GetMyAllyTeamID() or inSpecMode) and data.isAlive then
				aliveAllyTeams = aliveAllyTeams + 1
				drawpos = drawpos + 1
			end
			data.drawpos = drawpos
		end
	end
end

local function updateButtons()
	if widgetPosX < 0 then
		widgetPosX = 0
	elseif widgetPosX + widgetWidth > vsx then
		widgetPosX = vsx - widgetWidth
	end

	if widgetPosY < 0 then
		widgetPosY = 0
	elseif widgetPosY + widgetHeight > vsy then
		widgetPosY = vsy - widgetHeight
	end

	if cfgSticktotopbar and WG['topbar'] ~= nil then
		local topbarArea = WG['topbar'].GetPosition()
		if not topbarShowButtons then
			topbarArea[2] = topbarArea[4]
		end
		widgetPosX = topbarArea[3] - widgetWidth
		widgetPosY = topbarArea[2] - widgetHeight
	end

	if widgetPosX + widgetWidth / 2 > vsx / 2 then
		right = true
	else
		right = false
	end

	updateDrawPos()
end

local function setDefaults()
	widgetWidth = 120    -- just the bars area
	right = true
	tH = 32
	widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
	borderPadding = 4.5
	HBadge = tH * 0.5
	WBadge = math.floor(HBadge * playerScale)
	cW = 88
	textsize = 14
end

local function processScaling()
	setDefaults()
	sizeMultiplier = ((vsy / 700) * 0.55) * (1 + (ui_scale - 1) / 1.5)
	local numAllyteams = #Spring.GetAllyTeamList()-1
	if numAllyteams > 5 then
		sizeMultiplier = sizeMultiplier * 0.96
	elseif numAllyteams > 8 then
		sizeMultiplier = sizeMultiplier * 0.88
	elseif numAllyteams > 11 then
		sizeMultiplier = sizeMultiplier * 0.82
	elseif numAllyteams > 14 then
		sizeMultiplier = sizeMultiplier * 0.77
	end

	tH = math.floor(tH * sizeMultiplier)
	widgetWidth = math.floor(widgetWidth * sizeMultiplier)
	HBadge = math.floor(HBadge * sizeMultiplier)
	WBadge = math.floor(HBadge * playerScale)
	cW = math.floor(cW * sizeMultiplier)
	textsize = math.floor(textsize * sizeMultiplier)
	borderPadding = math.floor(borderPadding * sizeMultiplier)
	widgetHeight = getNbTeams() * tH + (2 * sizeMultiplier)
end

local function getTeamReclaim(teamID)
	local totalEnergyReclaim, totalMetalReclaim = 0, 0
	if cfgTrackReclaim then
		if inSpecMode and reclaimerUnits[teamID] ~= nil then
			local teamUnits = reclaimerUnits[teamID]
			for unitID, unitDefID in pairs(teamUnits) do
				local metalMake, _, energyMake = GetUnitResources(unitID)
				if metalMake ~= nil then
					if metalMake > 0 then
						totalMetalReclaim = totalMetalReclaim + (metalMake - reclaimerUnitDefs[unitDefID][1])
					end
					if energyMake > 0 then
						totalEnergyReclaim = totalEnergyReclaim + (energyMake - reclaimerUnitDefs[unitDefID][2])
					end
				end
			end
		end
	end
	return totalEnergyReclaim, totalMetalReclaim
end

local function checkCommanderAlive(teamID)
	local hasCom = false
	for commanderDefID, _ in pairs(comDefs) do
		if Spring.GetTeamUnitDefCount(teamID, commanderDefID) > 0 then
			local unitList = Spring.GetTeamUnitsByDefs(teamID, commanderDefID)
			for i = 1, #unitList do
				if not Spring.GetUnitIsDead(unitList[i]) then
					hasCom = true
				end
			end
		end
	end
	return hasCom
end

local function setTeamTable(teamID)
	local minc, mrecl, einc, erecl
	local _, leaderID, isDead, isAI, aID = GetTeamInfo(teamID, false)
	local leaderName, active, spectator = GetPlayerInfo(leaderID, false)
	if teamID == gaiaID then
		leaderName = "(Gaia)"
	end

	local tred, tgreen, tblue = GetTeamColor(teamID)
	local luminance = (tred * 0.299) + (tgreen * 0.587) + (tblue * 0.114)
	if luminance < 0.2 then
		tred = tred + 0.25
		tgreen = tgreen + 0.25
		tblue = tblue + 0.25
	end

	_, _, _, minc = GetTeamResources(teamID, "metal")
	_, _, _, einc = GetTeamResources(teamID, "energy")
	erecl, mrecl = getTeamReclaim(teamID)

	if not teamData[teamID] then
		teamData[teamID] = {}
	end

	teamData[teamID].teamID = teamID
	teamData[teamID].allyID = aID
	teamData[teamID].red = tred
	teamData[teamID].green = tgreen
	teamData[teamID].blue = tblue
	if not teamData[teamID].startx then
		local x, _, y = Spring.GetTeamStartPosition(teamID)
		teamData[teamID].startx = x
		teamData[teamID].starty = y
	end
	teamData[teamID].isDead = teamData[teamID].isDead or isDead
	teamData[teamID].hasCom = checkCommanderAlive(teamID)
	teamData[teamID].minc = minc
	teamData[teamID].mrecl = mrecl
	teamData[teamID].einc = einc
	teamData[teamID].erecl = erecl
	teamData[teamID].leaderID = leaderID
	teamData[teamID].leaderName = leaderName
	teamData[teamID].active = active
	teamData[teamID].spectator = spectator
	teamData[teamID].isAI = isAI
end

local function setAllyData(allyID)
	if not allyID or allyID == gaiaAllyID then
		return
	end

	local index = allyID + 1
	if not allyData[index] then
		allyData[index] = {}
		local teamList = GetTeamList(allyID)
		allyData[index].teams = teamList
	end

	if not (allyData[index].teams and #allyData[index].teams > 0) then
		return
	end

	local teamList = allyData[index].teams
	local team1 = teamList[1] --leader id
	for _, tID in pairs(teamList) do
		if not teamData[tID] then
			setTeamTable(tID)
		end
	end

	allyIDdata[allyID] = index

	allyData[index].teams = teamList
	allyData[index].tE = getTeamSum(index, "einc")
	allyData[index].tEr = getTeamSum(index, "erecl")
	allyData[index].tM = getTeamSum(index, "minc")
	allyData[index].tMr = getTeamSum(index, "mrecl")
	allyData[index].isAlive = isTeamAlive(allyID)
	allyData[index].validPlayers = getNbPlacedPositions(allyID)
	allyData[index].x = getTeamSum(index, "startx")
	allyData[index].y = getTeamSum(index, "starty")
	allyData[index].leader = teamData[team1].leaderName or "N/A"
	allyData[index].aID = allyID
	allyData[index].exists = #teamList > 0

	if not allyData[index].isAlive and cfgRemoveDead then
		allyData[index] = nil
		guishaderRects['ecostats_' .. allyID] = nil
		if WG['guishader'] and guishaderRectsDlists['ecostats_' .. allyID] then
			WG['guishader'].DeleteDlist('ecostats_' .. allyID)
			guishaderRectsDlists['ecostats_' .. allyID] = nil
		end
	end
end

local function UpdateAllies()
	if not inSpecMode then
		setAllyData(myAllyID)
	else
		for _, data in ipairs(allyData) do
			setAllyData(data.aID)
		end
	end
end

local function Init()
	setDefaults()

	teamData = {}
	allyData = {}
	Button = {}

	right = widgetPosX / vsx > 0.5

	allyData = {}
	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			local teamList = GetTeamList(allyID)
			local allyDataIndex = allyID + 1
			allyData[allyDataIndex] = {}
			allyData[allyDataIndex].teams = teamList
			allyData[allyDataIndex].exists = #teamList > 0
			for _, teamID in pairs(teamList) do
				setTeamTable(teamID)
				Button[teamID] = {}
			end
			setAllyData(allyID)
		end
	end

	maxPlayers = getMaxPlayers()

	if maxPlayers == 1 then
		HBadge = 18
	elseif maxPlayers == 2 or maxPlayers == 3 then
		HBadge = 16
	else
		HBadge = 14
	end
	HBadge = HBadge * sizeMultiplier
	WBadge = math.floor(HBadge * playerScale)

	if maxPlayers * WBadge + (20 * sizeMultiplier) > widgetWidth then
		widgetWidth = math.ceil((20 * sizeMultiplier) + maxPlayers * WBadge)
	end

	processScaling()
	updateButtons()
	UpdateAllies()

	lastPlayerChange = GetGameFrame()
end

local function setReclaimerUnits()
	reclaimerUnits = {}
	local teamList = GetTeamList()
	for _, tID in pairs(teamList) do
		reclaimerUnits[tID] = {}
	end
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		local uDefID = Spring.GetUnitDefID(unitID)
		if reclaimerUnitDefs[uDefID] then
			local unitTeam = Spring.GetUnitTeam(unitID)
			reclaimerUnits[unitTeam][unitID] = uDefID
		end
	end
end

function widget:Initialize()
	if not (Spring.GetSpectatingState() or isReplay) then
		inSpecMode = false
	else
		inSpecMode = true
		setReclaimerUnits()
	end
	if GetGameSeconds() > 0 then
		gamestarted = true
	end

	WG['ecostats'] = {}
	WG['ecostats'].getShowText = function()
		return cfgResText
	end
	WG['ecostats'].setShowText = function(value)
		cfgResText = value
	end
	WG['ecostats'].getReclaim = function()
		return cfgTrackReclaim
	end
	WG['ecostats'].setReclaim = function(value)
		cfgTrackReclaim = value
	end

	Init()
	widget:ViewResize()
end

local function removeGuiShaderRects()
	if WG['guishader'] then
		for _, data in pairs(allyData) do
			local aID = data.aID
			if isTeamReal(aID) and (aID == GetMyAllyTeamID() or inSpecMode) and aID ~= gaiaAllyID then
				WG['guishader'].DeleteDlist('ecostats_' .. aID)
				guishaderRectsDlists['ecostats_' .. aID] = nil
				guishaderRects['ecostats_' .. aID] = nil
			end
		end
	end

	if WG['tooltip'] ~= nil then
		for _, data in pairs(allyData) do
			local aID = data.aID
			if isTeamReal(aID) and (aID == GetMyAllyTeamID() or inSpecMode) and (aID ~= gaiaAllyID) then
				if tooltipAreas['ecostats_' .. aID] ~= nil then
					WG['tooltip'].RemoveTooltip('ecostats_' .. aID)
					tooltipAreas['ecostats_' .. aID] = nil
					local teams = Spring.GetTeamList(aID)
					for _, tID in ipairs(teams) do
						WG['tooltip'].RemoveTooltip('ecostats_team_' .. tID)
					end
				end
			end
		end
	end
end

function widget:Shutdown()
	removeGuiShaderRects()
	if teamCompositionList then
		gl.DeleteList(teamCompositionList)
	end
	for k,v in pairs(textLists) do
		gl.DeleteList(v)
	end
	if uiBgTex then
		gl.DeleteTextureFBO(uiBgTex)
	end
	if uiTex then
		gl.DeleteTextureFBO(uiTex)
	end
	WG['ecostats'] = nil
end

local areaRect = {}
local prevAreaRect = {}
local function makeTeamCompositionList()
	if not inSpecMode then
		return
	end
	if useRenderToTexture then
		if #uiElementRects == 0 then
			DrawTeamComposition()	-- need to run once so uiElementRects gets filled
		end
		areaRect = {}
		for id, rect in pairs(uiElementRects) do
			if not areaRect[1] then
				areaRect = { rect[1], rect[2], rect[3], rect[4] }
			else
				if rect[1] < areaRect[1] then
					areaRect[1] = rect[1]
				end
				if rect[2] < areaRect[2] then
					areaRect[2] = rect[2]
				end
				if rect[3] > areaRect[3] then
					areaRect[3] = rect[3]
				end
				if rect[4] > areaRect[4] then
					areaRect[4] = rect[4]
				end
			end
		end
		local rectAreaChange = false
		if not prevAreaRect[1] or (areaRect[1] ~= prevAreaRect[1] or areaRect[2] ~= prevAreaRect[2] or areaRect[3] ~= prevAreaRect[3] or areaRect[4] ~= prevAreaRect[4]) then
			rectAreaChange = true
		end
		prevAreaRect = areaRect

		if not uiBgTex or not rectAreaChange then
			if uiBgTex then
				gl.DeleteTextureFBO(uiBgTex)
			end
			uiBgTex = gl.CreateTexture(math.floor(areaRect[3]-areaRect[1]), math.floor(areaRect[4]-areaRect[2]), {
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})
			if uiTex then
				gl.DeleteTextureFBO(uiTex)
			end
			uiTex = gl.CreateTexture(math.floor(areaRect[3]-areaRect[1]), math.floor(areaRect[4]-areaRect[2]), {
				target = GL.TEXTURE_2D,
				format = GL.ALPHA,
				fbo = true,
			})
		end
		if uiBgTex then
			gl.RenderToTexture(uiBgTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.Color(1,1,1,1)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (areaRect[3]-areaRect[1]), 2 / (areaRect[4]-areaRect[2]),	0)
				gl.Translate(-areaRect[1], -areaRect[2], 0)
				for id, rect in pairs(uiElementRects) do
					UiElement(rect[1], rect[2], rect[3], rect[4], (widgetPosY+widgetHeight > rect[4]+1 and 1 or 0), 0, 0, 1, 0, 1, 1, 1, nil, nil, nil, nil, useRenderToTexture)
				end
				gl.PopMatrix()
			end)
		end
		if uiTex then
			gl.RenderToTexture(uiTex, function()
				gl.Clear(GL.COLOR_BUFFER_BIT, 0, 0, 0, 0)
				gl.Color(1,1,1,1)
				gl.PushMatrix()
				gl.Translate(-1, -1, 0)
				gl.Scale(2 / (areaRect[3]-areaRect[1]), 2 / (areaRect[4]-areaRect[2]),	0)
				gl.Translate(-areaRect[1], -areaRect[2], 0)
				DrawTeamComposition()
				gl.PopMatrix()
			end)
		end
	else
		if teamCompositionList then
			gl.DeleteList(teamCompositionList)
		end
		teamCompositionList = gl.CreateList(DrawTeamComposition)
	end
	if WG['guishader'] then
		for id, rect in pairs(guishaderRects) do
			if guishaderRectsDlists[id] then
				gl.DeleteList(guishaderRectsDlists[id])
			end
			guishaderRectsDlists[id] = gl.CreateList(function()
				RectRound(rect[1], rect[2], rect[3], rect[4], rect[5], 1, 0, 0, 1)
			end)
			WG['guishader'].InsertDlist(guishaderRectsDlists[id], id)
		end
	end
end

local function UpdateAllTeams()
	for _, data in ipairs(allyData) do
		for _, teamID in pairs(data.teams) do
			if inSpecMode or teamData[teamID] and teamData[teamID].allyID == myAllyID then
				setTeamTable(teamID)
			end
		end
	end
end

local function Reinit()
	maxPlayers = getMaxPlayers()

	if maxPlayers == 1 then
		HBadge = 18 * sizeMultiplier
	elseif maxPlayers == 2 or maxPlayers == 3 then
		HBadge = 16 * sizeMultiplier
	else
		HBadge = 14 * sizeMultiplier
	end
	WBadge = math.floor(HBadge * playerScale)

	if maxPlayers * WBadge + (20 * sizeMultiplier) > widgetWidth then
		widgetWidth = (20 * sizeMultiplier) + maxPlayers * WBadge
	end
	if widgetPosX + widgetWidth > vsx then
		widgetPosX = vsx - widgetWidth
	end
	if widgetPosX < 0 then
		widgetPosX = 0
	end

	for _, allyID in ipairs(Spring.GetAllyTeamList()) do
		if allyID ~= gaiaAllyID then
			local teamList = GetTeamList(allyID)
			if not allyData[allyID + 1] then
				allyData[allyID + 1] = {}
			end
			allyData[allyID + 1].teams = teamList
			allyData[allyID + 1].exists = #teamList > 0
		end
	end

	uiElementRects = {}

	processScaling()
	UpdateAllTeams()
	UpdateAllies()
	updateButtons()
	refreshTeamCompositionList = true
end

function widget:GetConfigData(data)
	return {
		xRelPos = xRelPos,
		yRelPos = yRelPos,
		cfgRemoveDeadOn = cfgRemoveDead,
		cfgResText2 = cfgResText,
		cfgTrackReclaim = cfgTrackReclaim,
		right = right,
	}
end

function widget:SetConfigData(data)
	cfgResText = data.cfgResText2 or cfgResText
	cfgTrackReclaim = data.cfgTrackReclaim or cfgTrackReclaim
	cfgSticktotopbar = data.cfgSticktotopbar or true
	cfgRemoveDead = false
	xRelPos = data.xRelPos or xRelPos
	yRelPos = data.yRelPos or yRelPos
	widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
end

function widget:TextCommand(command)
	if string.sub(command,1, 13) == "ecostatstext" then
		cfgResText = not cfgResText
		Spring.Echo('ecostats: text: '..(cfgResText and 'enabled' or 'disabled'))
	end
	if string.sub(command,1, 16) == "ecostatsreclaim" then
		cfgTrackReclaim = not cfgTrackReclaim
		Spring.Echo('ecostats: reclaim: '..(cfgTrackReclaim and 'enabled' or 'disabled'))
	end
end

local function DrawEText(numberE, vOffset)
	local label = string.formatSI(numberE)
	font:Begin()
	font:SetTextColor({ 1, 1, 0, 1 })
	font:Print(label or "", widgetPosX + widgetWidth - (5 * sizeMultiplier), widgetPosY + widgetHeight - vOffset + (tH * 0.22), tH / 2.3, 'rs')
	font:End()
end

local function DrawMText(numberM, vOffset)
	local label = string.formatSI(numberM)
	font:Begin()
	font:SetTextColor({ 0.85, 0.85, 0.85, 1 })
	font:Print(label or "", widgetPosX + widgetWidth - (5 * sizeMultiplier), widgetPosY + widgetHeight - vOffset + (borderPadding * 0.5) + (tH * 0.58), tH / 2.3, 'rs')
	font:End()
end

local function DrawEBar(tE, tEp, vOffset)
	-- where tE = team Energy = [0,1]
	vOffset = math.floor(vOffset - (borderPadding * 0.5))
	tE = math.max(tE, 0)
	tEp = math.max(tEp, 0)

	local dx = math.floor(15 * sizeMultiplier)
	local dy = math.floor(tH * 0.43)
	local maxW = widgetWidth - (30 * sizeMultiplier)
	local barheight = 1 + math.floor(tH * 0.08)
	if cfgResText then
		dx = math.floor(11 * sizeMultiplier)
		maxW = (widgetWidth / 1.95)
	end

	-- background
	glColor(0.8, 0.8, 0, 0.13)
	gl.Texture(images.barbg)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)
	-- energy total
	glColor(0.7, 0.7, 0.7, 1)
	gl.Texture(images.bar)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + tE * maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)
	-- energy production
	glColor(1, 1, 0, 1)
	gl.Texture(images.bar)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + tEp * maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)

	if tE * maxW > 0.9 then
		local glowsize = 23 * sizeMultiplier
		-- energy total
		glColor(1, 1, 0, 0.032)
		gl.Texture(images.barglowcenter)
		glTexRect(
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tE * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx - (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx + tE * maxW + (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tE * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		-- energy production
		glColor(1, 1, 0, 0.032)
		gl.Texture(images.barglowcenter)
		glTexRect(
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tEp * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx - (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx + tEp * maxW + (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tEp * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
	end
	gl.Texture(false)
	glColor(1, 1, 1, 1)
end

local function DrawMBar(tM, tMp, vOffset)
	-- where tM = team Metal = [0,1]
	vOffset = math.floor(vOffset - (borderPadding * 0.5))
	tM = math.max(tM, 0)
	tMp = math.max(tMp, 0)

	local dx = math.floor(15 * sizeMultiplier)
	local dy = math.floor(tH * 0.67)
	local maxW = widgetWidth - (30 * sizeMultiplier)
	local barheight = 1 + math.floor(tH * 0.08)

	if cfgResText then
		dx = math.floor(11 * sizeMultiplier)
		maxW = (widgetWidth / 1.95)
	end
	-- background
	glColor(0.8, 0.8, 0.8, 0.13)
	gl.Texture(images.barbg)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)
	-- metal total
	glColor(0.7, 0.7, 0.7, 1)
	gl.Texture(images.bar)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + tM * maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)
	-- metal production
	glColor(1, 1, 1, 1)
	gl.Texture(images.bar)
	glTexRect(
			widgetPosX + dx,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + dx + tMp * maxW,
			widgetPosY + widgetHeight - vOffset + dy - barheight
	)
	if tM * maxW > 0.9 then
		local glowsize = 26 * sizeMultiplier
		-- metal total
		glColor(1, 1, 1, 0.032)
		gl.Texture(images.barglowcenter)
		glTexRect(
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tM * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx - (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx + tM * maxW + (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tM * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		-- metal production
		glColor(1, 1, 1, 0.032)
		gl.Texture(images.barglowcenter)
		glTexRect(
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tMp * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx - (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
		gl.Texture(images.barglowedge)
		glTexRect(
				widgetPosX + dx + tMp * maxW + (glowsize * 1.8),
				widgetPosY + widgetHeight - vOffset + dy + glowsize,
				widgetPosX + dx + tMp * maxW,
				widgetPosY + widgetHeight - vOffset + dy - barheight - glowsize
		)
	end
	gl.Texture(false)
	glColor(1, 1, 1)
end

local function DrawBackground(posY, allyID, teamWidth)
	local y1 = math.ceil((widgetPosY - posY) + widgetHeight)
	local y2 = math.ceil((widgetPosY - posY) + tH + widgetHeight)
	local area = { widgetPosX, y1, widgetPosX + widgetWidth, y2 }

	uiElementRects[#uiElementRects+1] = { widgetPosX + teamWidth, y1, widgetPosX + widgetWidth, y2, allyID }

	if not useRenderToTexture then
		UiElement(widgetPosX + teamWidth, y1, widgetPosX + widgetWidth, y2, (posY > tH and 1 or 0), 0, 0, 1, 0, 1, 1, 1, nil, nil, nil, nil, useRenderToTexture)
	end

	guishaderRects['ecostats_' .. allyID] = { widgetPosX + teamWidth, y1, widgetPosX + widgetWidth, y2, 4 * widgetScale }

	area[1] = area[1] + (widgetWidth / 12)
	if WG['tooltip'] ~= nil and (tooltipAreas['ecostats_' .. allyID] == nil or tooltipAreas['ecostats_' .. allyID] ~= area[1] .. '_' .. area[2] .. '_' .. area[3] .. '_' .. area[4] or refreshCaptions) then
		refreshCaptions = false
		WG['tooltip'].AddTooltip('ecostats_' .. allyID, area, Spring.I18N('ui.teamEconomy.tooltip'), nil, Spring.I18N('ui.teamEconomy.tooltipTitle'))
		tooltipAreas['ecostats_' .. allyID] = area[1] .. '_' .. area[2] .. '_' .. area[3] .. '_' .. area[4]
	end
end

local function DrawBox(hOffset, vOffset, r, g, b)
	local w = tH * 0.36 * playerScale
	local h = tH * 0.36
	local dx = 0
	local dy = tH - (tH * 0.5)
	RectRound(
			widgetPosX + hOffset + dx - w,
			widgetPosY + widgetHeight - vOffset + dy,
			widgetPosX + hOffset + dx,
			widgetPosY + widgetHeight - vOffset + dy + h,
			h * 0.055,
			1, 1, 1, 1, { r * 0.75, g * 0.75, b * 0.75, 0.4 }, { r, g, b, 0.4 }
	)
	glColor(1, 1, 1, 1)
end

local function DrawTeamCompositionTeam(hOffset, vOffset, r, g, b, a, small, mouseOn, t, isDead, tID)
	local w, h, dx, dy
	if small then
		w = floor((tH * 0.36) + 0.5) * playerScale
		h = floor((tH * 0.36) + 0.5)
		dx = -floor((tH * 0.06) + 0.5)
		dy = floor((tH - (tH * 0.43)) + 0.5)
	else
		w = floor((tH * 0.46) + 0.5) * playerScale
		h = floor((tH * 0.46) + 0.5)
		dx = 0
		dy = floor((tH - h) + 0.5)
	end

	if not inSpecMode then
		dx = floor(dx - (10 * sizeMultiplier))
	end

	if mouseOn and not isDead then
		if ctrlDown then
			glColor(1, 1, 1, a)
		else
			local gs, _, _ = GetGameSpeed() or 1
			glColor(r - 0.2 * sin(10 * t / gs), g - 0.2 * sin(10 * t / gs), b, a)
		end
	else
		glColor(r, g, b, a)
	end
	local area = {
		floor((widgetPosX + hOffset + dx - w) + 0.5),
		floor((widgetPosY + widgetHeight - vOffset + dy) + 0.5),
		floor((widgetPosX + hOffset + dx) + 0.5),
		floor((widgetPosY + widgetHeight - vOffset + dy + h) + 0.5),
	}
	if enableStartposbuttons then
		Button[tID].x1 = area[1]
		Button[tID].y1 = area[2]
		Button[tID].x2 = area[3]
		Button[tID].y2 = area[4]
		Button[tID].pID = tID
	end
	if WG['tooltip'] then
		WG['tooltip'].AddTooltip('ecostats_team_' .. tID, area, teamData[tID].leaderName)
	end

	RectRound(
			area[1], area[2] + floor(borderPadding * 0.5), area[3], area[4] + floor(borderPadding * 0.5),
			(area[3] - area[1]) * 0.055,
			1, 1, 1, 1, { r * 0.75, g * 0.75, b * 0.75, 1 }, { r, g, b, 1 }
	)
end

function DrawTeamComposition()
	-- do dynamic stuff without display list
	local t = GetGameSeconds()
	uiElementRects = {}
	for _, data in pairs(allyData) do
		local aID = data.aID
		local drawpos = data.drawpos
		if data.exists and drawpos and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID) and data.isAlive then

			local posy = tH * (drawpos) + (4 * sizeMultiplier)
			local hasCom

			local teamWidth = 0
			for i, tID in pairs(data.teams) do
				if tID ~= gaiaID then
					teamWidth = -(WBadge * (i)) - (WBadge * 0.3)
				end
			end

			if type(data.tE) == "number" and drawpos and #(data.teams) > 0 then
				DrawBackground(posy - (4 * sizeMultiplier), aID, math.floor(teamWidth))
			end

			-- team rectangles
			for i, tID in pairs(data.teams) do
				if tID ~= gaiaID then
					local tData = teamData[tID]
					local r = tData.red or 1
					local g = tData.green or 1
					local b = tData.blue or 1
					local alpha
					local posx = floor(-(WBadge * (i - 1)) + (WBadge * 0.3))
					hasCom = tData.hasCom
					if GetGameSeconds() > 0 then
						if not tData.isDead then
							alpha = tData.active and 1 or 0.3
							DrawTeamCompositionTeam(posx, posy + floor(tH * 0.125), r, g, b, alpha, not hasCom, Button[tID].mouse, t, false, tID)
						else
							alpha = 0.8
							DrawTeamCompositionTeam(posx, posy + floor(tH * 0.125), r, g, b, alpha, true, Button[tID].mouse, t, true, tID) --dead, big icon
						end
					else
						DrawBox(posx, posy, r, g, b)
					end
				end
			end
		end
	end
end

local function drawListStandard()
	if not gamestarted then
		updateButtons()
	end

	local updateTextLists = false
	if os.clock() > lastTextListUpdate + 0.5 then
		updateTextLists = true
		lastTextListUpdate = os.clock()
	end

	if os.clock() > lastBarsUpdate + 0.15 then
		lastBarsUpdate = os.clock()
		maxMetal, maxEnergy = 0, 0
		for _, data in ipairs(allyData) do
			local aID = data.aID
			if data.exists and type(data.tE) == "number" and isTeamReal(aID) and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID) then
				if avgData[aID] == nil then
					avgData[aID] = {}
					avgData[aID].tE = data.tE
					avgData[aID].tEr = data.tEr
					avgData[aID].tM = data.tM
					avgData[aID].tMr = data.tMr
				else
					avgData[aID].tE = avgData[aID].tE + ((data.tE - avgData[aID].tE) / avgFrames)
					avgData[aID].tEr = avgData[aID].tEr + ((data.tEr - avgData[aID].tEr) / avgFrames)
					avgData[aID].tM = avgData[aID].tM + ((data.tM - avgData[aID].tM) / avgFrames)
					avgData[aID].tMr = avgData[aID].tMr + ((data.tMr - avgData[aID].tMr) / avgFrames)
				end
				if avgData[aID].tM and avgData[aID].tM > maxMetal then
					maxMetal = avgData[aID].tM
				end
				if avgData[aID].tE and avgData[aID].tE > maxEnergy then
					maxEnergy = avgData[aID].tE
				end
			end
		end
	end

	for _, data in ipairs(allyData) do
		local aID = data.aID
		if aID ~= nil then
			local drawpos = data.drawpos

			if data.exists and type(data.tE) == "number" and drawpos and #(data.teams) > 0 and (aID == myAllyID or inSpecMode) and (aID ~= gaiaAllyID) then
				if not data.isAlive then
					data.isAlive = isTeamAlive(aID)
				end
				local posy = tH * (drawpos)
				local t = GetGameSeconds()
				if data.isAlive and t > 0 and gamestarted and not gameover then
					if maxEnergy > 0 then
						DrawEBar(avgData[aID].tE / maxEnergy, (avgData[aID].tE - avgData[aID].tEr) / maxEnergy, posy - 1)
					end
					if maxMetal > 0 then
						DrawMBar(avgData[aID].tM / maxMetal, (avgData[aID].tM - avgData[aID].tMr) / maxMetal, posy + 2)
					end
				end
				if updateTextLists then
					textLists[aID] = gl.CreateList(function()
						if cfgResText and data.isAlive and t > 0 and gamestarted and not gameover then
							DrawEText(avgData[aID].tE, posy)
							DrawMText(avgData[aID].tM, posy)
						end
					end)
			   end
			   gl.CallList(textLists[aID])
			end
		end
	end
end

function widget:UnitCreated(uID, uDefID, uTeam, builderID)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] then
		if not reclaimerUnits[uTeam] then
			reclaimerUnits[uTeam] = {}
		end
		reclaimerUnits[uTeam][uID] = uDefID
	end
end

function widget:UnitDestroyed(uID, uDefID, uTeam)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] and reclaimerUnits[uTeam] then
		reclaimerUnits[uTeam][uID] = nil
	end
end

function widget:UnitGiven(uID, uDefID, uTeamNew, uTeam)
	if inSpecMode and myFullview and reclaimerUnitDefs[uDefID] then
		if reclaimerUnits[uTeam] then
			reclaimerUnits[uTeam][uID] = nil
			if not reclaimerUnits[uTeamNew] then
				reclaimerUnits[uTeamNew] = {}
			end
			reclaimerUnits[uTeamNew][uID] = uDefID
		end
	end
end

function widget:PlayerChanged(playerID)
	local doReinit = false
	if myFullview ~= select(2, Spring.GetSpectatingState()) then
		if myFullview then
			doReinit = true
		else
			removeGuiShaderRects()
		end
	end
	if myFullview and not singleTeams and WG['playercolorpalette'] ~= nil and WG['playercolorpalette'].getSameTeamColors() then
		if myTeamID ~= Spring.GetMyTeamID() then
			UpdateAllTeams()
			refreshTeamCompositionList = true
		end
	end
	myFullview = select(2, Spring.GetSpectatingState())
	myTeamID = Spring.GetMyTeamID()

	if myFullview then
		lastPlayerChange = GetGameFrame()
		if not (Spring.GetSpectatingState() or isReplay) then
			inSpecMode = false
			UpdateAllies()
		else
			inSpecMode = true
			setReclaimerUnits()
			doReinit = true
		end
		if playerID == myPlayerID then
			doReinit = true
		end
	end

	if doReinit then
		Reinit()
	end
end

function widget:GameOver()
	gameover = true
	UpdateAllTeams()
end

function widget:TeamDied(teamID)
	if teamData[teamID] then
		teamData[teamID].isDead = true
	end

	lastPlayerChange = GetGameFrame()

	removeGuiShaderRects()

	if not (Spring.GetSpectatingState() or isReplay) then
		inSpecMode = false
		UpdateAllies()
		UpdateAllTeams()
	else
		inSpecMode = true
		UpdateAllTeams()
		Reinit()
	end
end

function widget:MapDrawCmd(playerID, cmdType, px, py, pz, labeltext)
	if not gamestarted then
		UpdateAllies()
	end
end

function widget:KeyPress(key, mods, isRepeat)
	if key == 0x132 and not isRepeat and not mods.shift and not mods.alt then
		ctrlDown = true
	end
	return false
end

function widget:KeyRelease(key)
	if key == 0x132 then
		ctrlDown = false
	end
	return false
end

function widget:MousePress(x, y, button)
	if not inSpecMode or not myFullview then
		return
	end

	if button == 1 then
		for teamID, button in pairs(Button) do
			button.click = false
			if button.x1 and math_isInRect(x, y, button.x1, button.y1, button.x2, button.y2) then

				if ctrlDown and teamData[teamID].hasCom then
					local com
					for commanderDefID, _ in ipairs(comDefs) do
						com = Spring.GetTeamUnitsByDefs(teamID, commanderDefID)[1] or com
					end

					if com then
						local cx, cy, cz
						local camState = Spring.GetCameraState()
						cx, cy, cz = Spring.GetUnitPosition(com)
						if camState and cx then
							camState.px = cx
							camState.py = cy
							camState.pz = cz
							camState.height = 800

							Spring.SetCameraState(camState, 0.75)
							if inSpecMode then
								Spring.SelectUnitArray({ com })
							end
						elseif cx then
							Spring.SetCameraTarget(cx, cy, cz, 0.5)
						end
					end
				elseif not ctrlDown then
					local sx = teamData[teamID].startx
					local sz = teamData[teamID].starty
					if sx ~= nil and sz ~= nil then
						local sy = Spring.GetGroundHeight(sx, sz)
						local camState = Spring.GetCameraState()
						if camState and sx and sz and sx > 0 and sz > 0 then
							camState.px = sx
							camState.py = sy
							camState.pz = sz
							camState.height = 5000
							Spring.SetCameraState(camState, 2)
						elseif sx then
							Spring.SetCameraTarget(sx, sy, sz, 0.5)
						end
					end
				end
				return true
			end
		end
	end
	if math_isInRect(x, y, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) then
		return true
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	widgetPosX, widgetPosY = xRelPos * vsx, yRelPos * vsy
	widgetScale = (((vsy) / 2000) * 0.5) * (0.95 + (ui_scale - 1) / 1.5)        -- only used for rounded corners atm

	RectRound = WG.FlowUI.Draw.RectRound
	UiElement = WG.FlowUI.Draw.Element

	font = WG['fonts'].getFont()
	Reinit()
end


local sec = 0
local sec1 = 0
local sec2 = 0
function widget:Update(dt)
	if not inSpecMode or not myFullview then
		return
	end
	
	local gf = Spring.GetGameFrame()
	if not gamestarted and gf > 0 then
		gamestarted = true
	end
	if gf - lastPlayerChange == 40 then
		lastPlayerChange = lastPlayerChange - 1	-- prevent repeat execution cause this is in widget:Update
		-- check for dead teams
		for teamID in pairs(teamData) do
			teamData[teamID].isDead = select(3, GetTeamInfo(teamID, false))
		end
		UpdateAllies()
		refreshTeamCompositionList = true
	end

	sec1 = sec1 + dt
	if sec1 > 0.5 then
		sec1 = 0
		UpdateAllTeams()
	end

	sec2 = sec2 + dt
	if sec2 > 0.3 then
		sec2 = 0
		-- set/update player resources
		for teamID, data in pairs(teamData) do
			data.minc = select(4, GetTeamResources(teamID, "metal")) or 0
			data.einc = select(4, GetTeamResources(teamID, "energy")) or 0
			data.erecl, data.mrecl = getTeamReclaim(teamID)
		end
		updateButtons()
		UpdateAllies()
	end

	sec = sec + dt
	if sec > 3 then
		sec = 0
		if WG.allyTeamRanking then
			updateDrawPos()
		end
		refreshTeamCompositionList = true
	end

	local prevTopbarShowButtons = topbarShowButtons
	topbarShowButtons = WG['topbar'] and WG['topbar'].getShowButtons()
	if topbarShowButtons ~= prevTopbarShowButtons or not prevTopbar and (WG['topbar'] ~= nil) or prevTopbar ~= (WG['topbar'] ~= nil) then
		Reinit()
		lastTextListUpdate = 0
	end
	prevTopbar = WG['topbar'] ~= nil and true or false
end

function widget:DrawScreen()
	if not myFullview or not inSpecMode then
		return
	end
	
	if aliveAllyTeams > 16 then
		return
	end
	
	if refreshTeamCompositionList then
		refreshTeamCompositionList = false
		makeTeamCompositionList()
	end

	if useRenderToTexture and uiBgTex then
		-- background element
		gl.Color(1,1,1,Spring.GetConfigFloat("ui_opacity", 0.7)*1.1)
		gl.Texture(uiBgTex)
		gl.TexRect(areaRect[1], areaRect[2], areaRect[3], areaRect[4], false, true)
		-- content
		gl.Color(1,1,1,1)
		gl.Texture(uiTex)
		gl.TexRect(areaRect[1], areaRect[2], areaRect[3], areaRect[4], false, true)
		gl.Texture(false)
	end

	gl.PolygonOffset(-7, -10)
	gl.PushMatrix()
	if not useRenderToTexture then
		gl.CallList(teamCompositionList)
	end
	drawListStandard()
	gl.PopMatrix()

	local mx, my = Spring.GetMouseState()
	if math_isInRect(mx, my, widgetPosX, widgetPosY, widgetPosX + widgetWidth, widgetPosY + widgetHeight) then
		Spring.SetMouseCursor('cursornormal')
	end
end

function widget:LanguageChanged()
	refreshCaptions = true
	Reinit()
end
