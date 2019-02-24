function widget:GetInfo()
	return {
	name      = "Ignore List API", --version 4.1
	desc      = "Adds /ignoreplayer <name>, /unignoreplayer <name>, /ignorelist\n(puts ignoredPlayers table into WG)",
	author    = "Bluestone",
	date      = "June 2014", --last change September 10,2009
	license   = "GNU GPL, v3 or later",
	layer     = 0,
	enabled   = true, --enabled by default
	handler   = true, --can use widgetHandler:x()
	}
end

--[[
NOTE: This widget will block map draw commands from ignored players.
      It is up to the chat console widget to check WG.ignoredPlayers[playerName] and block chat 
]]

local pID_table = {}
local ignoredPlayers = {}
local myName,_ = Spring.GetPlayerInfo(Spring.GetMyPlayerID())

local specColStr = "\255\255\255\1"
local whiteStr = "\255\255\255\1"

function CheckPIDs()
    local playerList = Spring.GetPlayerList()
    for _,pID in ipairs(playerList) do
        local name,_ = Spring.GetPlayerInfo(pID)
        pID_table[name] = pID
    end
end

function widget:Initialize()
    CheckPIDs()
    WG.ignoredPlayers = ignoredPlayers
end

function widget:PlayerChanged()
    CheckPIDs()
end

function colourPlayer(playerName)
        local playerID = pID_table[playerName]
        if not playerID then return whiteStr end
        
        local _,_,spec,teamID = Spring.GetPlayerInfo(playerID)
        if spec then return specColStr end
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

--ignore--
function widget:TextCommand(s)     
     local token = {}
	 local n = 0
	 --for w in string.gmatch(s, "%a+") do
	 for w in string.gmatch(s, "%S+") do
		n = n +1
		token[n] = w		
     end
	 
	--for i = 1,n do Spring.Echo (token[i]) end
	 
	 if (token[1] == "ignoreplayer" or token[1] == "ignoreplayers") then
		 for i = 2,n do
			IgnorePlayer(token[i])
		end
	end
	
	if (token[1] == "unignoreplayer" or token[1] == "unignoreplayers") then
        if n==1 then
            UnignoreAll() 
        else
            for i=2,n do
                UnignorePlayer(token[i])
            end
        end
    end
    
    if (token[1] == "toggleignore") and n>=2 then
        for i=2,n do
            local playerName = token[i]
            if ignoredPlayers[playerName] then
                UnignorePlayer(playerName)
            else
                IgnorePlayer(playerName)
            end               
        end
    end
        
	if (token[1] == "ignorelist") then
        ignoreList()
    end
end

function ignoreList ()
    local luaSucks = 0
    for _,iHateLua in pairs(ignoredPlayers) do
        luaSucks = 1
        break
    end
    if luaSucks>0 then
        Spring.Echo("Ignored players:")
        for playerName,_ in pairs(ignoredPlayers) do
            Spring.Echo(colourPlayer(playerName) .. playerName)
        end
    else
        Spring.Echo("No ignored players")
    end
end

function IgnorePlayer (playerName)
    if playerName==myName then
        Spring.Echo("You cannot ignore yourself")
        return
    end
    
	ignoredPlayers[playerName] = true
    WG.ignoredPlayers = ignoredPlayers
    Spring.Echo ("Ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignorePlayer (playerName)
	ignoredPlayers[playerName] = nil
    WG.ignoredPlayers = ignoredPlayers
    Spring.Echo("Un-ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignoreAll ()
    local luaSucks = 0
    for _,iHateLua in pairs(ignoredPlayers) do
        luaSucks = 1
        break
    end
    if luaSucks > 0 then
        local text = "Un-ignored "
        for playerName,_ in pairs(ignoredPlayers) do
            text = text .. colourPlayer(playerName) .. playerName .. ", "
        end
        text = string.sub(text, 1, string.len(text)-2) --remove final ", "
        Spring.Echo(text)
    else
        Spring.Echo("No players to unignore")
    end

	ignoredPlayers = {}
    WG.ignoredPlayers = ignoredPlayers    
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
    local name,_ = Spring.GetPlayerInfo(playerID)
    if ignoredPlayers[name] then
        return true
    end
    return nil
end

function widget:GetConfigData()
	return ignoredPlayers
end

function widget:SetConfigData(data)
    ignoredPlayers = data or {}
end