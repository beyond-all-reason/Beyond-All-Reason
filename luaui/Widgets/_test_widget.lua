if not RmlUi then
	Spring.Echo("RmlUi not loaded")
	return false
else
	Spring.Echo("RmlUi is ok")
end

function widget:GetInfo()
	return {
		name = "Demo RML Gui",
		desc = "A sandbox for the Rml powered GUI.",
		author = "ChrisFloofyKitsune",
		date = "2024-03-17",
		license = "https://unlicense.org/",
		layer = -828888,
		enabled = true,
	}
end

local document
widget.rmlContext = nil

local playerListByTeam = {} -- does not contain specs

-- this can be overwritten later to change what code exampleEventHook calls
local eventCallback = function(ev, ...)
	Spring.Echo("orig function says", ...)
end

local isVisible = false
local dm_handle

local threshold = 150000

local modelForPresenter = {
	resourcesDestroyed = {
		visible = false,
		firstLeader = {
			playerName = "Test",
			score = 123111,
			playerColor = ""
		},
		otherOrderedLeaders = {
			{
				playerName = "Test-second",
				score = 12133,
				playerColor = ""
			},
			{
				playerName = "Test-third",
				score = 12130,
				playerColor = ""
			}
		}
	},
	enemiesDestroyed = {},
	resourcesEfficiency = {},
	traitor = {},
	goldenCow = {},
	ecoAward = {},
	damageRecieved = {},
	commanderSleep = {
		playerName = "SleepTest",
		score = 123221,
		visible = false,
	}
}

local function initializeContext()
	widget.rmlContext = RmlUi.CreateContext(widget.whInfo.name)
	-- use the DataModel handle to set values
	-- only keys declared at the DataModel's creation can be used
	dm_handle = widget.rmlContext:OpenDataModel("data_model_test", {
		model = modelForPresenter,
		exampleValue = "Changes when clicked",
		-- Functions inside a DataModel cannot be changed later
		-- so instead a function variable external to the DataModel is called and _that_ can be changed
		exampleEventHook = function(...)
			eventCallback(...)
		end,
	})

	eventCallback = function(ev, ...)
		Spring.Echo(ev.parameters.mouse_x, ev.parameters.mouse_y, ev.parameters.button, ...)
		local options = { "ow", "oof!", "stop that!", "clicking go brrrr" }
		dm_handle.exampleValue = options[math.random(1, 4)]
	end
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

local function putAwardIntoModel(award, num, winnersTable)
	local teamID = winnersTable[num].teamID
	local score = winnersTable[num].score

	if teamID < 0 then
		return
	end

	local name = findPlayerName(teamID)

	if num == 1 then
		modelForPresenter[award].firstLeader.score = score
		modelForPresenter[award].firstLeader.playerName = name
	else
		modelForPresenter[award].otherOrderedLeaders[num].score = score
		modelForPresenter[award].otherOrderedLeaders[num].playerName = name
	end
end

local function createAward(award, winnersTable)
	putAwardIntoModel(award, 1, winnersTable)
	putAwardIntoModel(award, 2, winnersTable)
	putAwardIntoModel(award, 3, winnersTable)
end

local function ProcessAwards(awards)
	if not awards then
		return
	end
	WG.awards = awards
	local traitorWinner = awards.traitor[1]
	local cowAwardWinner = awards.goldenCow[1].teamID
	local compoundAwards = {}
	table.insert(compoundAwards, awards.eco[1])
	table.insert(compoundAwards, awards.damageReceived[1])
	table.insert(compoundAwards, awards.sleep[1])
	-- if awards.ecoKill[1].teamID >= 0 then
	-- 	createAward("resourcesDestroyed", awards.ecoKill)
	-- end
	-- if awards.eco[1].teamID >= 0 then
	-- 	createAward("ecoAward", awards.ecoKill)
	-- end
	-- if awards.damageReceived[1].teamID >= 0 then
	-- 	createAward("damageRecieved", awards.ecoKill)
	-- end
	-- if awards.sleep[1].teamID >= 0 then
	-- 	createAward("sleep", awards.ecoKill)
	-- end
	dm_handle.model = modelForPresenter
end

function showDocument()
	document = widget.rmlContext:LoadDocument("LuaUI/Widgets/rml_assets/simple_demo.rml", widget)
	document:ReloadStyleSheet()
	document:Show()
end

function hideDocument()
	if document then
		document:Close()
	end
end

local function initializeWidget()
	initializeContext()
	WG["rml_ui_widget"] = {}
	WG["rml_ui_widget"].toggle = function()
		if isVisible == false then
			showDocument()
			isVisible = true
		else
			hideDocument()
			isVisible = false
		end
	end
	WG["rml_ui_widget"].isvisible = function()
		return isVisible
	end
end

local function disableShowEndGraph()
	Spring.SendCommands("endgraph 2")
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
	widgetHandler:RegisterGlobal("GadgetReceiveAwardsNew", ProcessAwards)
	Spring.Echo("Registered gnew ")
end

function widget:Initialize()
	disableShowEndGraph()
	registerGlobalFunctionForReceivingAwardsFromHandler()
	initializeWidget()
	initializeTeamList()
	-- ProcessAwards(WG.awards)
end

function widget:Shutdown()
	if document then
		document:Close()
	end
	if widget.rmlContext then
		RmlUi.RemoveContext(widget.whInfo.name)
	end
	widgetHandler:DeregisterGlobal("GadgetReceiveAwardsNew")
end
