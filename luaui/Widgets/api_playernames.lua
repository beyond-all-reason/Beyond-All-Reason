local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Playernames API",
		desc = "Provides (historic/custom) playername for other widgets",
		author = "Floris",
		date = "August 2025",
		license = "GNU GPL, v2 or later",
		layer = -9999999,
		enabled = true,
	}
end

local applyFirstEncounteredName = false
local maxHistorySize = 3000	 -- max number of accounts in history
local maxNamesSize = 4500	 -- max number of names in history
local cleanupAmount = 300

local history = {}
local currentNames = {}		-- playerID to name
local currentAccounts = {}	-- accountID to name

local spGetPlayerInfo = Spring.GetPlayerInfo

-- late rejoined/added spectators dont get a their own accountid but the last assigned playerID one instead so we'll have to ignore those
-- THIS IS FUCKED UP BUT IT IS WHAT IT IS SOMEHOW
local validAccounts = {}	-- accountID to playerID
local playerList = Spring.GetPlayerList()
for _, playerID in ipairs(playerList) do
	local _, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(playerID)
	accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
	if accountID and not validAccounts[accountID] then
		validAccounts[accountID] = playerID
	end
end

local function getPlayername(playerID, accountID)
	if playerID then
		accountID = nil
	elseif accountID then
		playerID = nil
	end
	local name
	if playerID then
		if currentNames[playerID] then
			return currentNames[playerID]
		end
		name, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(playerID)
		accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or false

		-- skip an rejoined/added spec that use already existing accountID
		if validAccounts[accountID] ~= playerID then
			accountID = nil
		end
	end

	if accountID then
		-- find if name exists inhistory
		local inHistory = false
		if history[accountID] then
			for i, historyName in ipairs(history[accountID]) do
				if historyName == name then
					inHistory = true
					break
				end
			end
		end
		-- add to history
		if not inHistory then
			if not history[accountID] then
				history[accountID] = { i = 1, d = tonumber(os.date("%y%m%d")), [1] = name }
			end
		end
		-- pick name from history
		if history[accountID] then
			if history[accountID].alias then
				name = history[accountID].alias
			else
				if applyFirstEncounteredName then
					name = history[accountID][1]
				else
					name = history[accountID][#history[accountID]]
				end
			end
		end
		currentAccounts[accountID] = name
	end
	if playerID then
		currentNames[playerID] = name
	end
	-- if accountID is given and not in history yet, get name from ingame playerlist
	if not name and accountID then
		local playerList = Spring.GetPlayerList()
		for _, pID in ipairs(playerList) do
			local pname, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(pID)
			pAccountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
			if pAccountID and pAccountID == accountID then
				name = pname
				break
			end
		end
	end
	return name
end

local function getAccountHistory(accountID)
	if history[accountID] then
		local accountHistory = history[accountID]
		accountHistory.d = nil
		accountHistory.i = nil
		accountHistory.alias = nil
		return accountHistory
	end
end

local function update()
	local playerList = Spring.GetPlayerList()
	for _, playerID in ipairs(playerList) do
		currentNames[playerID] = getPlayername(playerID)
	end
end

-- update gamecount (i) and date (d) per accountid (we can use this to clean up history at a later point)
local function actualizeHistory()
	for accountID, name in pairs(currentAccounts) do
		if history[accountID] then
			history[accountID].i = history[accountID].i and history[accountID].i + 1 or 1
			history[accountID].d = tonumber(os.date("%y%m%d"))
		end
	end
	-- cleanup history
	local numAccounts, numNames = 0, 0
	for _, names in pairs(history) do
		numAccounts = numAccounts + 1
		numNames = numNames + #names	-- wont count custom alias
	end
	if numAccounts > maxHistorySize or numNames > maxNamesSize then
		-- cleanup logic: remove oldest entries based on date
		local accountsByDate = {}
		for accountID, data in pairs(history) do
			if data.d then
				table.insert(accountsByDate, {accountID = accountID, date = data.d})
			else
				-- if no date, treat as very old (assign a very old date)
				table.insert(accountsByDate, {accountID = accountID, date = "000000"})
			end
		end

		-- sort by date (oldest first)
		table.sort(accountsByDate, function(a, b)
			return a.date < b.date
		end)

		-- remove oldest entries until we're under the limits
		local removedAccounts, removedNames = 0, 0
		for _, entry in ipairs(accountsByDate) do
			if numAccounts - removedAccounts <= maxHistorySize - cleanupAmount or numNames - removedNames <= maxNamesSize - cleanupAmount then
				break
			end

			local accountID = entry.accountID
			local accountData = history[accountID]
			if accountData and not accountData.alias then  -- don't remove accounts with aliases
				removedAccounts = removedAccounts + 1
				removedNames = removedNames + #accountData
				history[accountID] = nil
			end
		end
	end
end

function widget:Initialize()
	update()
	WG.playernames = {}
	WG.playernames.getPlayername = function(playerID, accountID)
		return getPlayername(playerID, accountID)
	end
	WG.playernames.getAccountHistory = function(accountID)
		return getAccountHistory(accountID)
	end
	WG.playernames.setUseFirstEncounter = function(value)
		applyFirstEncounteredName = value
	end
	WG.playernames.getUseFirstEncounter = function()
		return applyFirstEncounteredName
	end
end

function widget:Shutdown()
	WG.playernames = nil
end

function widget:PlayerAdded(playerID)
	currentNames[playerID] = getPlayername(playerID)
end

function widget:GameStart()
	if reconnected then
		return
	end
	actualizeHistory()
end

function widget:GetConfigData()
	return {
		gameID = Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"),
		applyFirstEncounteredName = applyFirstEncounteredName,
		currentNames = currentNames,
		currentAccounts = currentAccounts,
		history = history,
	}
end

function widget:SetConfigData(data)
	history = data.history or {}
	if Spring.GetGameFrame() > 0 or (data.gameID and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID"))) then
		currentNames = data.currentNames or {}
		currentAccounts = data.currentAccounts or {}
		reconnected = true
	end
	if data.applyFirstEncounteredName ~= nil then
		applyFirstEncounteredName = data.applyFirstEncounteredName
	end
end
