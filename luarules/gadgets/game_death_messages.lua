function gadget:GetInfo()
	return {
		name      = "Death Messages",
		desc      = "Makes callins for death messages",
		author    = "Bluestone",
		date      = "Sept 2013",
		license   = "GNU GPL, v2 or later, BA/BAR only",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

--This gadget makes callins for death messages accessible via Script.LuaRules
--The callins are called from within game_end

--Each team can be part of precisely one death messages
--This death message can be either just for itself (if it resigns/etc) or as part of its allyteam message (if it is alive when its allyteam dies)
--Whichever call comes first will be the death message for that team

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local playerListByTeam = {} --loaded up at game start, doesn't include specs, doesn't change over time

include("luarules/configs/death_messages.lua")
local messageColour = "\255\255\255\255"

--construct death message for team
function TeamDeathMessage(teamID)
	local playerList = playerListByTeam[teamID]

	if playerList == nil then
		return --this team has already received a death message
	end
	
	if next(playerList) == nil then
		return Spring.I18N('deathMessages.error', { team = teamID })
	end
	
	local playerNames = table.concat(playerList, ", ")	
	local n = math.random(#teamDeathMessages)
	local message = Spring.I18N('deathMessages.team.' .. teamDeathMessages[n], { team = teamID, playerList = playerNames })
	
	message = messageColour .. message
	Spring.SendMessage(message)

	--remove names from playerListByTeam
	playerListByTeam[teamID] = nil
end

function AllyTeamDeathMessage(allyTeamID)
	local teamList = Spring.GetTeamList(allyTeamID)
	local playerNames = ""
	for _,teamID in pairs(teamList) do
		local playerList = playerListByTeam[teamID]
		
		if next(playerList) == nil then
			return Spring.I18N('deathMessages.error', { team = allyTeamID })
		end
		
		if playerList ~= nil then --this team already received a death msg (and is dead), don't include it in the allyteam msg
			playerNames = table.concat(playerList, ", ")
			playerListByTeam[teamID] = nil --don't let this team get any more death messages
		end
	end
	
	local n = math.random(#allyTeamDeathMessages)
	local message = Spring.I18N('deathMessages.allyTeam.' .. allyTeamDeathMessages[n], { team = allyTeamID, playerList = playerNames })

	message = messageColour .. message
	Spring.SendMessage(message)
end

function gadget:Initialize()
	--load a list of players for each team into playerListByTeam
	local teamList = Spring.GetTeamList()
	for _,teamID in pairs(teamList) do
		local playerList = Spring.GetPlayerList(teamID)
		local list = {} --without specs
		for _,playerID in pairs(playerList) do
			local name, _, isSpec = Spring.GetPlayerInfo(playerID,false)
			if not isSpec then
				table.insert(list, name)
			end
		end
		playerListByTeam[teamID] = list
	end

	--register functions so as they can be called from game_end (call as e.g. Script.LuaRules.TeamDeathMessage(teamID))
	gadgetHandler:RegisterGlobal('TeamDeathMessage', TeamDeathMessage)
	gadgetHandler:RegisterGlobal('AllyTeamDeathMessage', AllyTeamDeathMessage)
end

function gadget:Shutdown()
	gadgetHandler:DeregisterGlobal('TeamDeathMessage')
	gadgetHandler:DeregisterGlobal('AllyTeamDeathMessage')
end
