if not RmlUi then
	return false
end

function widget:GetInfo()
	return {
		name = "Awards",
		desc = "UI with awards after game ends",
		author = "Floris (original: Bluestone)",
		date = "July 2021",
		license = "GNU GPL, v2 or later",
		layer = -3,
		enabled = true
	}
end

local document
widget.rmlContext = nil

local playerListByTeam = {}
local isVisible = false
local dm_handle
local chobbyLoaded = (Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), "chobby") ~= nil)

local modelForPresenter = {
	resourcesDestroyed = {
		visible = false,
		size = 3,
		firstLeader = {
			playerName = "Test",
			score = -1,
			playerColor = "rgb(255,0,0)",
		},
		otherLeadersOrdered = {
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
		},
	},
	enemiesDestroyed = {
		visible = false,
		size = 3,
		firstLeader = {
			playerName = "Test",
			score = -1,
			playerColor = "rgb(255,0,0)",
		},
		otherLeadersOrdered = {
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
		},
	},
	resourcesEfficiency = {
		visible = false,
		size = 3,
		firstLeader = {
			playerName = "Test",
			score = -1,
			playerColor = "rgb(255,0,0)",
		},
		otherLeadersOrdered = {
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
		},
	},
	traitor = {
		visible = false,
		size = 3,
		firstLeader = {
			playerName = "Test",
			score = -1,
			playerColor = "rgb(255,0,0)",
		},
		otherLeadersOrdered = {
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
			{
				playerName = "Test",
				score = -1,
				playerColor = "rgb(255,0,0)",
			},
		},
	},
	goldenCow = {
		visible = false,
		leader = {
			playerName = "Test",
			playerColor = "rgb(255,0,0)",
		},
	},
	otherAwards = {},
}

local function getCSSColorByPlayer(teamID)
	if teamID < 0 then
		return "rgb(0,0,0)"
	end
	local redF, greenF, blueF, opacity = Spring.GetTeamColor(teamID)
	local redNumColor = math.floor(redF * 255)
	local greenNumColor = math.floor(greenF * 255)
	local blueNumColor = math.floor(blueF * 255)
	return string.format("rgb(%d, %d, %d)", redNumColor, greenNumColor, blueNumColor)
end

local function leave()
	if chobbyLoaded then
		Spring.Reload("")
	else
		Spring.SendCommands("quitforce")
	end
end

local function showGraph()
	document:Close()
	Spring.SendCommands("endgraph 2")
end

local function initializeRmlContext()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)
	-- use the DataModel handle to set values
	-- only keys declared at the DataModel's creation can be used
	dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		model = modelForPresenter,
		onLeaveClick = function()
			leave()
		end,
		onShowGraphClick = function()
			showGraph()
		end,
	})
end

local function findPlayerName(teamID)
	local plList = playerListByTeam[teamID]
	local name

	if plList[1] then
		name = plList[1]
		if #plList > 1 then
			name = Spring.I18N("ui.awards.coop", { name = name })
		end
	else
		name = Spring.I18N("ui.awards.unknown")
	end

	return name
end

local function putMainAwardIntoModel(award, num, winnersTable)
	if num > modelForPresenter[award].size then
		return
	end
	local teamID = winnersTable[num].teamID
	local score = winnersTable[num].score

	if teamID < 0 then
		return
	end

	local name = findPlayerName(teamID)

	local playerToSet
	if num == 1 then
		playerToSet = modelForPresenter[award].firstLeader
	else
		playerToSet = modelForPresenter[award].otherOrderedLeaders[num]
	end
	playerToSet.score = score
	playerToSet.playerName = name
	playerToSet.playerColor = getCSSColorByPlayer(teamID)
	modelForPresenter[award].visible = true
end

local function calculateAwardScore(award, score)
	if award == "commanderSleepAward" then
		return math.round(score / 60) .. " minutes"
	else
		return math.floor(score)
	end
end

local function putOtherAwardIntoModel(award, winnersTable)
	local teamID = winnersTable[1].teamID
	local score = calculateAwardScore(award, winnersTable[1].score)
	if teamID < 0 then
		return
	end
	local name = findPlayerName(teamID)
	table.insert(modelForPresenter.otherAwards, {
		visible = true,
		award = award,
		leader = {
			playerName = name,
			score = score,
			playerColor = getCSSColorByPlayer(teamID),
		},
	})
end

local function createMainAward(award, winnersTable)
	putMainAwardIntoModel(award, 1, winnersTable)
	putMainAwardIntoModel(award, 2, winnersTable)
	putMainAwardIntoModel(award, 3, winnersTable)
end

local function createOtherAward(award, winnersTable)
	putOtherAwardIntoModel(award, winnersTable)
end

local function ProcessAwards(awards)
	if not awards then
		return
	end
	WG.awards = awards
	createMainAward("resourcesDestroyed", awards.ecoKill)
	createMainAward("enemiesDestroyed", awards.fightKill)
	createMainAward("resourcesEfficiency", awards.efficiency)
	createMainAward("traitor", awards.traitor)
	createOtherAward("ecoAward", awards.eco)
	createOtherAward("damageReceivedAward", awards.damageReceived)
	createOtherAward("commanderSleepAward", awards.sleep)
	dm_handle.model = modelForPresenter
end

local function showDocument()
	Spring.SendCommands("endgraph 0")
	if isVisible == false then
		isVisible = true
		document = widget.rmlContext:LoadDocument("LuaUI/Widgets/rml_assets/endscreen_awards.rml", widget)
		document:Show()
	end
end

local function hideDocument()
	if isVisible == true then
		isVisible = false
		document:Close()
	end
end

local function initializeWidget()
	initializeRmlContext()
	WG["endgame_awards_widget"] = {}
	WG["endgame_awards_widget"].toggle = function()
		if isVisible == false then
			showDocument()
		else
			hideDocument()
		end
	end
	WG["endgame_awards_widget"].show = function()
		showDocument()
	end
	WG["endgame_awards_widget"].hide = function()
		hideDocument()
	end
	WG["endgame_awards_widget"].isvisible = function()
		return isVisible
	end
end

local function disableShowEndGraph()
	Spring.SendCommands("endgraph 0")
end

local function initializeTeamList()
	local teamList = Spring.GetTeamList()
	for _, teamID in pairs(teamList) do
		local playerList = Spring.GetPlayerList(teamID)
		local list = {} --without specs
		for _, playerID in pairs(playerList) do
			local name, _, isSpec = Spring.GetPlayerInfo(playerID, false)
			if not isSpec then
				table.insert(list, name)
			end
		end
		playerListByTeam[teamID] = list
	end
end

local function registerGlobalFunctionForReceivingAwardsFromHandler()
	widgetHandler:RegisterGlobal("GadgetReceiveAwards", ProcessAwards)
	widgetHandler:RegisterGlobal("ShowEndgameAwards", showDocument)
end

function widget:Initialize()
	disableShowEndGraph()
	registerGlobalFunctionForReceivingAwardsFromHandler()
	initializeWidget()
	initializeTeamList()
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
	widgetHandler:DeregisterGlobal("GadgetReceiveAwards")
	widgetHandler:DeregisterGlobal("ShowEndgameAwards")
end
