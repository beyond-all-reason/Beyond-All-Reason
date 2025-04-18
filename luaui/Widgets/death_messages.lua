local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Death Messages",
		desc      = "Displays a message upon player/team death",
		author    = "Bluestone",
		date      = "Sept 2013",
		license   = "GNU GPL, v2 or later, BA/BAR only",
		layer     = 0,
		enabled   = true
	}
end

local deathMessageKeys = {
	'bowOut',
	'gone',
	'conquer',
	'toast',
	'takenOut',
	'defeat',
	'bitterEnd',
	'rodeOff',
	'dismantle',
	'terminate',
	'annihilate',
	'crater',
}
local teamNames = {}

local function getTeamNames(teamID)
	local playerNames = {}
	local _, _, _, isAI = Spring.GetTeamInfo(teamID)

	if isAI then		
		local _, _, _, name = Spring.GetAIInfo(teamID)
		local niceName = Spring.GetGameRulesParam('ainame_' .. teamID)
		
		if niceName then
			name = niceName
		end

		table.insert(playerNames, name)
	else
		local players = Spring.GetPlayerList(teamID)
		
		for _, playerID in pairs(players) do
			local name = Spring.GetPlayerInfo(playerID)
			table.insert(playerNames, name)
		end
	end

	return playerNames
end

local function notifyTeamDeath(teamID)
	local playerNameList = teamNames[teamID]

	if playerNameList == nil or next(playerNameList) == nil then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Team " .. teamID .. ": no names in players list")
	else
		local playerNames = table.concat(playerNameList, ', ')
		local n = math.random(#deathMessageKeys)
		local message = Spring.I18N('tips.deathMessages.team.' .. deathMessageKeys[n], { playerList = playerNames })

		Spring.SendMessage(message)
	end
end

function widget:TeamDied(teamID)
	notifyTeamDeath(teamID)
end

function widget:Initialize()
	local teams = Spring.GetTeamList()

	for _, teamID in pairs(teams) do
		teamNames[teamID] = getTeamNames(teamID)
	end
end