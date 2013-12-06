function gadget:GetInfo()
	return {
		name      = "Death Messages",
		desc      = "Makes death messages",
		author    = "Bluestone",
		date      = "Sept 2013",
		license   = "GNU GPL, v2 or later, BA only",
		layer     = 0,
		enabled   = true  --  loaded by default?
	}
end

-- synced only
if (not gadgetHandler:IsSyncedCode()) then
	return false
end

local slen = string.len
local ssub = string.sub
local sgsub = string.gsub

local playerListByTeam = {} --loaded up at game start, doesn't include specs, doesn't change over time

--include the table messages from gui_red_death_messages.lua 
--format is messages[i]="deathmsg"
include("luarules/configs/death_messages.lua")
local numDeathMsgs = #messages
local msgColour = "\255\255\255\255" 

--construct death message for team
function GetDeathMessage(teamID)
	--choose msg
	local n = math.random(numDeathMsgs)
	local msg = messages[n]
	local plList = playerListByTeam[teamID]
	if msg == nil or plList == nil then 
		return "Team " .. teamID .. " got an error (no msg) instead of a death message!"
	end
	
	--fill in XX 
	local plNames = ""
	for _,name in pairs(plList) do
		plNames = plNames .. name .. ", "
	end
	if slen(plNames)-2 < 1 then
		return "Team " .. teamID .. " got an error (no name) instead of a death message!"
	end
	plNames = ssub(plNames, 1, slen(plNames)-2) --remove final ", "
	if plNames ~= "" then
		plNames = " (" .. plNames .. ")"
	end
	local toCut = "XX" 
	local toPaste = "Team " .. teamID .. plNames 
	local msg,_ = sgsub(msg, toCut, toPaste)

	return msgColour .. msg
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
end


function gadget:TeamDied(teamID)
	--check it wasn't an AI team
	local _,_,_,isAiTeam = Spring.GetTeamInfo(teamID) 
	if isAiTeam then return end --fixme? this covers any team with an AI (even if it has human players too)
	
	--send death message
	local frame = Spring.GetGameFrame()
	if frame > 0 then
		local msg = GetDeathMessage(teamID)
		Spring.SendMessage(msg)
	end
end


function gadget:PlayerChanged(playerID)
	--send message to others in coop on resign from coop (if the coop team still has players left)
	--send message to all on resign before game start
	local name,teamID = Spring.GetPlayerInfo(playerID)
	if not name or not teamID then return end
	local team = Spring.GetTeamList(teamID)
	if not team then return end
	local frame = Spring.GetGameFrame()
	
	
	local resignedFromCoop = (#(playerListByTeam[teamID]) > 1)
	local msg = "Player " .. playerID .. " (" .. name .. ") resigned from coop (Team " .. teamID ..")"
	if not frame or frame==0 then
		Spring.SendMessage(msg)
	elseif resignedFromCoop and #team > 0 then
		Spring.SendMessageToTeam(teamID,msg)
	end
end
