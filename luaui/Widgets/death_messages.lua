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

local deathMessages = VFS.Include("luarules/configs/death_messages.lua")
local allyTeamDeathInfo = {}

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

local function getAllyTeamNames(allyTeamID)
	local playerNames = {}
	local teams = Spring.GetTeamList(allyTeamID)

	for _, teamID in pairs(teams) do
		local teamPlayerNames = getTeamNames(teamID)

		for _, name in pairs(teamPlayerNames) do
			table.concat(playerNames, name)
		end
	end

	return playerNames
end

local function isAllyTeamDead(allyTeamID)
	local teams = Spring.GetTeamList(allyTeamID)

	for _, teamID in pairs(teams) do
		local _, _, isDead = Spring.GetTeamInfo(teamID)

		if not isDead then
			return false
		end
	end

	return true
end

local function notifyAllyTeamDeath(allyTeamID)
	local playerNameList = getAllyTeamNames(allyTeamID)

	if playerNameList == nil or next(playerNameList) == nil then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "AllyTeam " .. allyTeamID .. ": all teams have empty player names lists")
	else
		local playerNames = table.concat(playerNameList, ', ')
		local n = math.random(#deathMessages.allyTeam)
		local message = Spring.I18N('tips.deathMessages.allyTeam.' .. deathMessages.allyTeam[n], { team = allyTeamID, playerList = playerNames })
		Spring.SendMessage(message)
	end

	allyTeamDeathInfo[allyTeamID].notified = true
end

local function notifyTeamDeath(teamID)
	local playerNameList = getTeamNames(teamID)

	if playerNameList == nil or next(playerNameList) == nil then
		Spring.Log(widget:GetInfo().name, LOG.ERROR, "Team " .. teamID .. ": no names in players list")
	else
		local playerNames = table.concat(playerNameList, ', ')
		local n = math.random(#deathMessages.team)
		local message = Spring.I18N('tips.deathMessages.team.' .. deathMessages.team[n], { team = teamID, playerList = playerNames })

		Spring.SendMessage(message)
	end

	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID)

	if not allyTeamDeathInfo[allyTeamID].notified and isAllyTeamDead(allyTeamID) then
		notifyAllyTeamDeath(allyTeamID)
	end
end

function widget:TeamDied(teamID)
	Spring.Echo("Team Died: " .. teamID)
	notifyTeamDeath(teamID)
end

function widget:Initialize()
	local allyTeams = Spring.GetAllyTeamList()

	for _, allyTeamID in pairs(allyTeams) do
		allyTeamDeathInfo[allyTeamID] = {}
		allyTeamDeathInfo[allyTeamID].notified = false
	end
end