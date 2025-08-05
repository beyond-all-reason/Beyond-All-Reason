local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ignore List API",
		desc = "This widget will block map draw commands from ignored players + provide API for other widgets to check if a player is ignored",
		author = "Bluestone, Floris",
		date = "June 2014",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- TODO: use i18n for ignore/unignore messages

local playernames = {}		-- current game: playername to playerID
local ignoredAccounts = {}	-- globally ignored: accountID to playername
local ignoredAccountsAndNames = {} -- indexes by accountID and playername
local ignoredPlayers = {}	-- old playernames method, we'll keep storing and try to convert this to the new ignoredAccounts table based on accountID

local _, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(Spring.GetMyPlayerID(), false)
local myAccountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or nil
playerInfo = nil

-- late rejoined/added spectators dont get a their own accountid but the last assigned playerID one instead so we'll have to ignore those
-- THIS IS FUCKED UP BUT IT IS WHAT IT IS SOMEHOW
local validAccounts = {}	-- accountID to playerID
local playerList = Spring.GetPlayerList()
for _, playerID in ipairs(playerList) do
	local name, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID)
	accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
	if accountID and not validAccounts[accountID] then
		validAccounts[accountID] = playerID
	end
end

for _, playerID in ipairs(playerList) do
	local name, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID)
	accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
	if accountID and not validAccounts[accountID] then
		validAccounts[accountID] = playerID
		ignoredAccountsAndNames[accountID] = playerID
	end
end
local function processPlayerlist()
	local playerList = Spring.GetPlayerList()
	for _, playerID in ipairs(playerList) do
		local name, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID)
		playernames[name] = playerID
		local accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or nil
		if accountID and validAccounts[accountID] then
			-- if this player was ignored by the old playernames method, add to new accountID method
			if ignoredPlayers[name] then
				ignoredPlayers[name] = nil
				ignoredAccounts[accountID] = name
			end
			if ignoredAccounts[accountID] then
				ignoredAccountsAndNames[accountID] = playerID
				ignoredAccountsAndNames[name] = playerID
			end
		end
	end
end

local function colourPlayer(playerName)
	local playerID = playernames[playerName]
	if not playerID then
		return "\255\255\255\1"
	end
	local _, _, _, teamID = Spring.GetPlayerInfo(playerID, false)
	return Spring.Utilities.Color.ToString(Spring.GetTeamColor(teamID))
end

local function ignoreAccount(accountID)
	if type(tonumber(accountID)) == 'number' then
		accountID = tonumber(accountID)
		if not ignoredAccounts[accountID] and validAccounts[accountID] then
			ignoredAccounts[accountID] = (WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(_,accountID) or ''
			ignoredAccountsAndNames[accountID] = ignoredAccounts[accountID]
			ignoredAccountsAndNames[ignoredAccounts[accountID]] = true
			Spring.Echo("Ignored " .. colourPlayer(ignoredAccounts[accountID]) .. ignoredAccounts[accountID] .. "  (" .. accountID .. ")")
		end
	elseif accountID ~= '' then -- if accountID wasnt known and player name was supplied instead
		local name = accountID
		if playernames[name] then
			ignoredPlayers[name] = true
			ignoredAccountsAndNames[name] = playernames[name]
			Spring.Echo("Ignored " .. colourPlayer(name) .. name .. "  (unknown accountID)")
		end
	end
end

local function unignoreAccount(accountID)
	if type(tonumber(accountID)) == 'number' then
		accountID = tonumber(accountID)
		if ignoredAccounts[accountID] and validAccounts[accountID] then
			Spring.Echo("Un-ignored " .. colourPlayer(ignoredAccounts[accountID]) .. ignoredAccounts[accountID] .. "  (" .. accountID .. ")")
			ignoredAccountsAndNames[ignoredAccounts[accountID]] = nil
			ignoredAccounts[accountID] = nil
			ignoredAccountsAndNames[accountID] = nil
		end
	elseif accountID ~= '' then -- if accountID wasnt known and player name was supplied instead
		local name = accountID
		if playernames[name] then
			ignoredPlayers[name] = nil
			ignoredAccountsAndNames[name] = nil
			Spring.Echo("Un-ignored " .. colourPlayer(name) .. name .. "  (unknown accountID)")
		end
	end
end

local function toggleignoreCmd(_, _, params)
	for i=1, #params do
		if params[i] then
			if ignoredAccounts[tonumber(params[i])] or ignoredPlayers[params[i]] then
				unignoreAccount(params[i])
			else
				ignoreAccount(params[i])
			end
		end
	end
end

function widget:Initialize()
	-- add all other ignored account names that arent in the current game but might be in the lobby
	for accountID, name in pairs(ignoredAccounts) do
		local pname = WG.playernames and WG.playernames.getPlayername(_, accountID, true)
		if not ignoredAccountsAndNames[accountID] then	-- if not already added/in the game
			ignoredAccountsAndNames[pname and pname or name] = true
		end
	end
	processPlayerlist()
	WG.ignoredAccounts = ignoredAccountsAndNames
	widgetHandler:AddAction("toggleignore", toggleignoreCmd, nil, 't')
end

function widget:Shutdown()
	widgetHandler:RemoveAction("toggleignore")
	WG.ignoredAccounts = nil
end

function widget:PlayerChanged()
	processPlayerlist()
end

function widget:MapDrawCmd(playerID, cmdType, startx, starty, startz, a, b, c)
	local _, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID, false)
	local accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or nil
	if accountID and ignoredAccounts[accountID] then
		return true
	end
	return nil
end

function widget:GetConfigData()
	ignoredPlayers[1] = ignoredAccounts
	return ignoredPlayers
end

function widget:SetConfigData(data)
	ignoredAccounts = data[1] and data[1] or {}
	data[1] = nil
	ignoredPlayers = data
	for name, _ in pairs(ignoredPlayers) do
		if not ignoredAccountsAndNames[name] then
			ignoredAccountsAndNames[name] = true
		end
	end
end
