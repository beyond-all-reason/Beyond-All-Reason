function widget:GetInfo()
	return {
		name = "Awards",
		desc = "UI with awards after game ends",
		author = "Floris (original: Bluestone)",
		date = "July 2021",
		license = "GNU GPL, v2 or later",
		layer = -3,
		enabled = true,
	}
end

local document
widget.rmlContext = nil

local playerListByTeam = {}
local isVisible = false
local documentModelHandle
local chobbyLoaded = (Spring.GetMenuName and string.find(string.lower(Spring.GetMenuName()), "chobby") ~= nil)

local injectableRml = {
	player = "<span class=\"other-awards-leader\" style=\"color: %s;\">%s</span>",
	score = "<span class=\"other-awards-score\">%s</span>"
}

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
	documentModelHandle = widget.rmlContext:OpenDataModel("data_model_test", {
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
		-- First player(num = 1) corresponds to firstLeader. Other players in otherLeadersOrdered. Thus array element is [num -1]
		-- second player in leaderboard corresponds to first player in otherLeadersOrdered
		-- third player in leaderboard corresponds to second player in list
		playerToSet = modelForPresenter[award].otherLeadersOrdered[num - 1]
	end
	playerToSet.score = score
	playerToSet.playerName = name
	playerToSet.playerColor = RmlUi.ColorUtils.getCSSColorByPlayer(teamID)
	modelForPresenter[award].visible = true
end

local function createCowAward(winnersTable)
	local award = "goldenCow"
	local teamID = winnersTable[1].teamID

	if teamID < 0 then
		return
	end

	local name = findPlayerName(teamID)
	local playerToSet = modelForPresenter[award].leader
	playerToSet.playerName = name
	playerToSet.playerColor = RmlUi.ColorUtils.getCSSColorByPlayer(teamID)
	modelForPresenter[award].visible = true
end

local function calculateAwardScore(award, score)
	if award == "commanderSleepAward" then
		return math.round(score / 60)
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
	local playerColor = RmlUi.ColorUtils.getCSSColorByPlayer(teamID)
	local name = findPlayerName(teamID)
	local playerRmlTag = string.format(injectableRml.player, playerColor, name)
	local scoreRmlTag = string.format(injectableRml.score, score)
	local awardText = Spring.I18N("ui.awards." .. award, {
		player = playerRmlTag,
		score = scoreRmlTag,
	})

	table.insert(modelForPresenter.otherAwards, awardText)
end

local function createMainAward(award, winnersTable)
	putMainAwardIntoModel(award, 1, winnersTable)
	putMainAwardIntoModel(award, 2, winnersTable)
	putMainAwardIntoModel(award, 3, winnersTable)
end

local function createOtherAward(award, winnersTable)
	putOtherAwardIntoModel(award, winnersTable)
end

local function processAwards(awards)
	if not awards then
		return
	end
	WG.awards = awards
	createMainAward("resourcesDestroyed", awards.ecoKill)
	createMainAward("enemiesDestroyed", awards.fightKill)
	createMainAward("resourcesEfficiency", awards.efficiency)
	createMainAward("traitor", awards.traitor)
	createOtherAward("resourcesProduced", awards.eco)
	createOtherAward("damageTaken", awards.damageReceived)
	createOtherAward("sleptLongest", awards.sleep)
	createCowAward(awards.goldenCow)
	documentModelHandle.model = modelForPresenter
end

local function showDocument()
	Spring.SendCommands("endgraph 0")
	if isVisible == false then
		isVisible = true
		document = widget.rmlContext:LoadDocument("LuaUI/RmlWidgets/gui_awards/gui_awards.rml", widget)
		document:ReloadStyleSheet()
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

local function registerGlobals()
	widgetHandler:RegisterGlobal("GadgetReceiveAwards", processAwards)
	widgetHandler:RegisterGlobal("ShowEndgameAwards", showDocument)
end

function widget:Initialize()
	disableShowEndGraph()
	registerGlobals()
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
