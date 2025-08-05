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

local playernames = {}		-- current game: playername to playerID
local validAccounts = {}	-- current game: accountID to playername
local ignoredAccounts = {}	-- globally ignored: accountID to playername
local ignoredAccountsAndNames = {} -- indexes by accountID and playername
local ignoredPlayers = {}	-- old playernames method, we'll keep storing and try to convert this to the new ignoredAccounts table based on accountID

-- late rejoined/added spectators dont get a their own accountid but the last assigned playerID one instead so we'll have to ignore those
-- THIS IS FUCKED UP BUT IT IS WHAT IT IS SOMEHOW
local playerList = Spring.GetPlayerList()
for _, playerID in ipairs(playerList) do
	local name, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID)
	accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
	if accountID and not validAccounts[accountID] then
		validAccounts[accountID] = name
	end
end

local function processPlayerlist()
	local playerList = Spring.GetPlayerList()
	for _, playerID in ipairs(playerList) do
		local name, _, _, _, _, _, _, _, _, _, playerInfo = Spring.GetPlayerInfo(playerID)
		playernames[name] = playerID
		local accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or nil
		if accountID and validAccounts[accountID] then
			-- when a playername was ignored by the old widget method or when their accountID wasnt known (being late rejoining spectator)
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

local function ignoreAccount(accountID)
	if type(tonumber(accountID)) == 'number' then
		accountID = tonumber(accountID)
		if not ignoredAccounts[accountID] and validAccounts[accountID] then
			-- ignore accountID
			ignoredAccounts[accountID] = (WG.playernames and WG.playernames.getPlayername) and WG.playernames.getPlayername(_,accountID) or ''
			ignoredAccountsAndNames[accountID] = ignoredAccounts[accountID]
			-- ignore playerinfo name
			local playerID = playernames[validAccounts[accountID]]
			ignoredAccountsAndNames[validAccounts[accountID]] = playerID or true
			-- ignore aliassed name
			ignoredAccountsAndNames[ignoredAccounts[accountID]] = playerID or true
			Spring.Echo(Spring.I18N('ui.ignore.ignored', { name = ignoredAccounts[accountID], accountID = accountID }))
		end
	elseif accountID ~= '' then -- if accountID wasnt known and player name was supplied instead
		local name = accountID
		if playernames[name] then
			ignoredPlayers[name] = true
			ignoredAccountsAndNames[name] = playernames[name]
			Spring.Echo(Spring.I18N('ui.ignore.ignored', { name = name, accountID = Spring.I18N('ui.ignore.unknown') }))
		end
	end
end

local function unignoreAccount(accountID)
	if type(tonumber(accountID)) == 'number' then
		accountID = tonumber(accountID)
		if ignoredAccounts[accountID] and validAccounts[accountID] then
			Spring.Echo(Spring.I18N('ui.ignore.unignored', { name = ignoredAccounts[accountID], accountID = accountID }))
			ignoredAccountsAndNames[accountID] = nil
			ignoredAccountsAndNames[ignoredAccounts[accountID]] = nil
			ignoredAccountsAndNames[validAccounts[accountID]] = nil
			ignoredAccounts[accountID] = nil
		end
	elseif accountID ~= '' then -- if accountID wasnt known and player name was supplied instead
		local name = accountID
		if playernames[name] then
			ignoredPlayers[name] = nil
			ignoredAccountsAndNames[name] = nil
			Spring.Echo(Spring.I18N('ui.ignore.unignored', { name = name, accountID = Spring.I18N('ui.ignore.unknown') }))
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
