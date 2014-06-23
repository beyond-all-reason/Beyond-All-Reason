function widget:GetInfo()
	return {
	name      = "Mutelist", --version 4.1
	desc      = "Adds /muteplayer <name>, /unmuteplayer <name>, /mutelist\n(puts mutedPlayers table into WG)",
	author    = "Bluestone",
	date      = "June 2014", --last change September 10,2009
	license   = "GNU GPL, v3 or later",
	layer     = 0,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end

--[[
NOTE: This widget will block map draw commands from muted players.
      It is up to the chat console widget to check WG.mutedPlayers[playerName] and block chat 
]]

local pID_table = {}
local mutedPlayers = {}
WG.mutedPlayers = mutedPlayers

function CheckPIDs()
    local playerList = Spring.GetPlayerList()
    for _,pID in ipairs(playerList) do
        local name,_ = Spring.GetPlayerInfo(pID)
        pID_table[name] = pID
    end
end

function widget:Initialize()
    CheckPIDs()
end

function widget:PlayerChanged()
    CheckPIDs()
end

function colourPlayer(playerName)
        local playerID = pID_table[playerName]
        if not playerID then return "" end
        
        local _,_,_,teamID = Spring.GetPlayerInfo(playerID)
    	nameColourR,nameColourG,nameColourB,nameColourA = Spring.GetTeamColor(teamID)
		R255 = math.floor(nameColourR*255)  --the first \255 is just a tag (not colour setting) no part can end with a zero due to engine limitation (C)
        G255 = math.floor(nameColourG*255)
        B255 = math.floor(nameColourB*255)
        if ( R255%10 == 0) then
                R255 = R255+1
        end
        if( G255%10 == 0) then
                G255 = G255+1
        end
        if ( B255%10 == 0) then
                B255 = B255+1
        end
	return "\255"..string.char(R255)..string.char(G255)..string.char(B255) --works thanks to zwzsg
end 

--mute--
function widget:TextCommand(s)     
     local token = {}
	 local n = 0
	 --for w in string.gmatch(s, "%a+") do
	 for w in string.gmatch(s, "%S+") do
		n = n +1
		token[n] = w		
     end
	 
	--for i = 1,n do Spring.Echo (token[i]) end
	 
	 if (token[1] == "muteplayer" or token[1] == "muteplayers") then
		 for i = 2,n do
			MutePlayer (token[i])
		end
	end
	
	if (token[1] == "unmuteplayer" or token[1] == "unmuteplayers") then
        if n==1 then
            UnMuteAll() 
        else
            for i=2,n do
                UnMutePlayer(token[i])
            end
        end
    end
        
	if (token[1] == "mutelist") then
        MuteList()
    end
end

function MuteList ()
    local luaSucks = 0
    for _,iHateLua in pairs(mutedPlayers) do
        luaSucks = 1
        break
    end
    if luaSucks>0 then
        Spring.Echo("Muted players:")
        for playerName,_ in pairs(mutedPlayers) do
            Spring.Echo(colourPlayer(playerName) .. playerName)
        end
    else
        Spring.Echo("No muted players")
    end
end

function MutePlayer (playerName)
	mutedPlayers[playerName] = true
    WG.mutedPlayers = mutedPlayers
    Spring.Echo ("Muted " .. colourPlayer(playerName) .. playerName)
end

function UnMutePlayer (playerName)
	mutedPlayers[playerName] = nil
    WG.mutedPlayers = mutedPlayers
    Spring.Echo("Unmuted " .. colourPlayer(playerName) .. playerName)
end

function UnMuteAll ()
    local luaSucks = 0
    for _,iHateLua in pairs(mutedPlayers) do
        luaSucks = 1
        break
    end
    if luaSucks > 0 then
        local text = "Unmuted "
        for playerName,_ in pairs(mutedPlayers) do
            text = text .. colourPlayer(playerName) .. playerName .. ", "
        end
        text = string.sub(text, 1, string.len(text)-2) --remove final ", "
        Spring.Echo(text)
    else
        Spring.Echo("No players to unmute")
    end

	mutedPlayers = {}
    WG.mutedPlayers = mutedPlayers    
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
    local name,_ = Spring.GetPlayerInfo(playerID)
    if mutedPlayers[name] then
        return false
    end
    return true
end

function widget:GetConfigData()
	return mutedPlayers
end

function widget:SetConfigData(data)
    mutedPlayers = data or {}
end