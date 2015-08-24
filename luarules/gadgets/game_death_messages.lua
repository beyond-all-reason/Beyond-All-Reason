function gadget:GetInfo()
	return {
		name      = "Death Messages",
		desc      = "Makes callins for death messages",
		author    = "Bluestone",
		date      = "Sept 2013",
		license   = "GNU GPL, v2 or later, BA only",
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

local slen = string.len
local ssub = string.sub
local sgsub = string.gsub

local playerListByTeam = {} --loaded up at game start, doesn't include specs, doesn't change over time
local toMsg = {}
local msg

--include the teamDeathMessages and allyTeamDeathMessages tables
--format is table[i]="deathmsg"
include("luarules/configs/death_messages.lua")
local numTeamDeathMsgs = #teamDeathMessages
local numAllyTeamDeathMsgs = #allyTeamDeathMessages
local msgColour = "\255\255\255\255" 

--construct death message for team
function TeamDeathMessage(teamID)
	--choose msg
	local n = math.random(numTeamDeathMsgs)
	local msg = teamDeathMessages[n]
	if msg == nil then 
		return "Team " .. teamID .. " got an error (no msg) instead of a death message!"
	end

	local plList = playerListByTeam[teamID]
	if plList == nil then
		return --this team has already received a death message
	end
	
	--fill in XX 
	local plNames = ""
	for _,name in pairs(plList) do
		plNames = plNames .. name .. ", "
	end
	if slen(plNames)-2 < 1 then
		return "Team " .. teamID .. " got an error (no names) instead of a death message!"
	end
	plNames = ssub(plNames, 1, slen(plNames)-2) --remove final ", "
	if plNames ~= "" then
		plNames = " (" .. plNames .. ")"
	end
	local toCut = "XX" 
	local toPaste = "Team " .. teamID .. plNames 
	local msg,_ = sgsub(msg, toCut, toPaste)

	--send msg
	msg = msgColour .. msg
	Spring.SendMessage(msg)
	
	--remove names from playerListByTeam
	playerListByTeam[teamID] = nil
end

function AllyTeamDeathMessage(allyTeamID)
	--choose msg
	local n = math.random(numAllyTeamDeathMsgs)
	local msg = allyTeamDeathMessages[n]
	if msg == nil then 
		return "Allyteam " .. allyTeamID .. " got an error (no msg) instead of a death message!"
	end
	
	--fill in XX 	
	local teamList = Spring.GetTeamList(allyTeamID)	
	local plNames = ""
	for _,teamID in pairs(teamList) do
		local plList = playerListByTeam[teamID]
		if plList ~= nil then --this team already received a death msg (and is dead), don't include it in the allyteam msg
			for _,name in pairs(plList) do
				plNames = plNames .. name .. ", "
			end
			playerListByTeam[teamID] = nil --don't let this team get any more death messages
		end
	end
	if slen(plNames)-2 < 1 then
		return "Allyteam " .. allyTeamID .. " got an error (no names) instead of a death message!"
	end
	plNames = ssub(plNames, 1, slen(plNames)-2) --remove final ", "
	if plNames ~= "" then
		plNames = " (" .. plNames .. ")"
	end
	local toCut = "XX" 
	local toPaste = "Allyteam " .. allyTeamID .. plNames 
	local msg,_ = sgsub(msg, toCut, toPaste)

	--send msg
	msg = msgColour .. msg
	Spring.SendMessage(msg)	
end

function gadget:Initialize()
	--load a list of players for each team into playerListByTeam
	local teamList = Spring.GetTeamList()
	for _,teamID in pairs(teamList) do
		local playerList = Spring.GetPlayerList(teamID)
		local list = {} --without specs
		for _,playerID in pairs(playerList) do
			local name, _, isSpec = Spring.GetPlayerInfo(playerID)
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






