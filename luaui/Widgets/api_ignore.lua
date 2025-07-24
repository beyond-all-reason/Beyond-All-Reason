local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ignore List API", --version 4.1
		desc = "Adds /ignoreplayer <name>, /unignoreplayer <name>, /ignorelist\n(puts ignoredPlayers table into WG)",
		author = "Bluestone",
		date = "June 2014", --last change September 10,2009
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

--[[
NOTE: This widget will block map draw commands from ignored players.
      It is up to the chat console widget to check WG.ignoredPlayers[playerName] and block chat
]]

local pID_table = {}
local ignoredPlayers = {}
local myName, _ = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
local isSpec = Spring.GetSpectatingState()
local ColorString = Spring.Utilities.Color.ToString

local specColStr = "\255\255\255\1"
local whiteStr = "\255\255\255\1"

local anonymousMode = Spring.GetModOptions().teamcolors_anonymous_mode
local anonymousTeamColor = {Spring.GetConfigInt("anonymousColorR", 255)/255, Spring.GetConfigInt("anonymousColorG", 0)/255, Spring.GetConfigInt("anonymousColorB", 0)/255}

function CheckPIDs()
	local playerList = Spring.GetPlayerList()
	for _, pID in ipairs(playerList) do
		pID_table[select(1, Spring.GetPlayerInfo(pID, false))] = pID
	end
end

local function ignoreplayerCmd(_, _, params)
	for i=1, #params do
		IgnorePlayer(token[i])
	end
end

local function unignoreplayerCmd(_, _, params)
	if params[1] then
		for i=1, #params do
			UnignorePlayer(params[i])
		end
	else
		UnignoreAll()
	end
end

local function toggleignoreCmd(_, _, params)
	for i=1, #params do
		local playerName = params[i]
		if ignoredPlayers[playerName] then
			UnignorePlayer(playerName)
		else
			IgnorePlayer(playerName)
		end
	end
end

local function ignorelistCmd(_, _, params)
	local luaSucks = 0
	for _, iHateLua in pairs(ignoredPlayers) do
		luaSucks = 1
		break
	end
	if luaSucks > 0 then
		Spring.Echo("Ignored players:")
		for playerName, _ in pairs(ignoredPlayers) do
			Spring.Echo(colourPlayer(playerName) .. playerName)
		end
	else
		Spring.Echo("No ignored players")
	end
end

function widget:Initialize()
	CheckPIDs()
	WG.ignoredPlayers = ignoredPlayers
	widgetHandler:AddAction("ignoreplayer", ignoreplayerCmd, nil, 't')
	widgetHandler:AddAction("unignoreplayer", unignoreplayerCmd, nil, 't')
	widgetHandler:AddAction("toggleignore", toggleignoreCmd, nil, 't')
	widgetHandler:AddAction("ignorelist", ignorelistCmd, nil, 't')
end

function widget:Shutdown()
	widgetHandler:RemoveAction("ignoreplayer")
	widgetHandler:RemoveAction("unignoreplayer")
	widgetHandler:RemoveAction("toggleignore")
	widgetHandler:RemoveAction("ignorelist")
end

function widget:PlayerChanged()
	isSpec = Spring.GetSpectatingState()
	CheckPIDs()
end

function colourPlayer(playerName)
	local playerID = pID_table[playerName]
	if not playerID then
		return whiteStr
	end

	local _, _, spec, teamID = Spring.GetPlayerInfo(playerID, false)
	if spec then
		return specColStr
	end
	local nameColourR, nameColourG, nameColourB, _ = Spring.GetTeamColor(teamID)
	if (not isSpec) and anonymousMode ~= "disabled" then
		nameColourR, nameColourG, nameColourB = anonymousTeamColor[1], anonymousTeamColor[2], anonymousTeamColor[3]
	end
	return ColorString(nameColourR, nameColourG, nameColourB)
end


function IgnorePlayer (playerName)
	if playerName == myName then
		Spring.Echo("You cannot ignore yourself")
		return
	end

	ignoredPlayers[playerName] = true
	WG.ignoredPlayers = ignoredPlayers
	Spring.Echo("Ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignorePlayer (playerName)
	ignoredPlayers[playerName] = nil
	WG.ignoredPlayers = ignoredPlayers
	Spring.Echo("Un-ignored " .. colourPlayer(playerName) .. playerName)
end

function UnignoreAll ()
	local luaSucks = 0
	for _, iHateLua in pairs(ignoredPlayers) do
		luaSucks = 1
		break
	end
	if luaSucks > 0 then
		local text = "Un-ignored "
		for playerName, _ in pairs(ignoredPlayers) do
			text = text .. colourPlayer(playerName) .. playerName .. ", "
		end
		text = string.sub(text, 1, string.len(text) - 2) --remove final ", "
		Spring.Echo(text)
	else
		Spring.Echo("No players to unignore")
	end

	ignoredPlayers = {}
	WG.ignoredPlayers = ignoredPlayers
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	if ignoredPlayers[select(1, Spring.GetPlayerInfo(playerID, false))] then
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
