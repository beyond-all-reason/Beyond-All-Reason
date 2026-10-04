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


-- Localized functions for performance
local tableInsert = table.insert
local tableSort = table.sort
local stringFormat = string.format
local stringGmatch = string.gmatch
local tableConcat = table.concat

-- Localized Spring API for performance
local spEcho = Spring.Echo

local applyFirstEncounteredName = false
local maxHistorySize = 3000	 -- max number of accounts in history
local maxNamesSize = 4500	 -- max number of names in history
local cleanupAmount = 300

local history = {}
local validAccounts = {}	-- accountID to playerID
local currentNames = {}		-- playerID to name
local currentAccounts = {}	-- accountID to name

local reconnected = false	-- flag to track if this is a reconnection/reload

local spGetPlayerInfo = Spring.GetPlayerInfo

local packedHistoryFormatVersion = 2

local function escapeField(str)
	return (tostring(str):gsub("%%", "%%25"):gsub("|", "%%7C"):gsub(";", "%%3B"):gsub(",", "%%2C"):gsub("\n", "%%0A"))
end

local function unescapeField(str)
	if not str or str == "" then
		return ""
	end
	return (str:gsub("%%(%x%x)", function(hex)
		return string.char(tonumber(hex, 16))
	end))
end

local function splitByDelimiter(str, delimiter)
	if not str or str == "" then
		return {}
	end
	local out = {}
	local pattern = stringFormat("([^%s]+)", delimiter)
	for token in stringGmatch(str, pattern) do
		out[#out + 1] = token
	end
	return out
end

local function packNameMap(nameMap)
	if not nameMap then
		return nil
	end
	local records = {}
	for id, name in pairs(nameMap) do
		if type(id) == "number" and type(name) == "string" then
			records[#records + 1] = stringFormat("%d|%s", id, escapeField(name))
		end
	end
	if #records == 0 then
		return nil
	end
	tableSort(records)
	return tableConcat(records, ";")
end

local function unpackNameMap(packed)
	if type(packed) ~= "string" or packed == "" then
		return nil
	end
	local nameMap = {}
	for _, record in ipairs(splitByDelimiter(packed, ";")) do
		local fields = splitByDelimiter(record, "|")
		if #fields == 2 then
			local id = tonumber(fields[1])
			if id then
				nameMap[id] = unescapeField(fields[2])
			end
		end
	end
	return nameMap
end

local function packHistory(historyTable)
	if not historyTable then
		return nil
	end

	local records = {}
	for accountID, data in pairs(historyTable) do
		if type(accountID) == "number" and type(data) == "table" then
			local names = {}
			for k, v in pairs(data) do
				if type(k) == "number" and type(v) == "string" then
					names[#names + 1] = { idx = k, name = v }
				end
			end
			tableSort(names, function(a, b) return a.idx < b.idx end)

			local nameParts = {}
			for i = 1, #names do
				nameParts[i] = escapeField(names[i].name)
			end

			records[#records + 1] = stringFormat(
				"%d|%d|%d|%s|%s",
				accountID,
				tonumber(data.i) or 1,
				tonumber(data.d) or 0,
				escapeField(data.alias or ""),
				tableConcat(nameParts, ",")
			)
		end
	end

	if #records == 0 then
		return nil
	end
	tableSort(records)
	return tableConcat(records, ";")
end

local function unpackHistory(packed)
	if type(packed) ~= "string" or packed == "" then
		return nil
	end

	local historyTable = {}
	for _, record in ipairs(splitByDelimiter(packed, ";")) do
		-- Parse fixed 5-field record while preserving empty alias field.
		local accountIDStr, gamesStr, dateStr, aliasStr, packedNames = string.match(record, "^([^|]*)|([^|]*)|([^|]*)|([^|]*)|(.*)$")
		if accountIDStr then
			local accountID = tonumber(accountIDStr)
			if accountID then
				local entry = {
					i = tonumber(gamesStr) or 1,
					d = tonumber(dateStr) or 0,
				}
				local alias = unescapeField(aliasStr)
				if alias ~= "" then
					entry.alias = alias
				end

				if packedNames ~= "" then
					local idx = 1
					for _, packedName in ipairs(splitByDelimiter(packedNames, ",")) do
						entry[idx] = unescapeField(packedName)
						idx = idx + 1
					end
				end

				historyTable[accountID] = entry
			end
		end
	end
	return historyTable
end

local function getPlayername(playerID, accountID, skipAlias)
	if playerID then
		accountID = nil
	elseif accountID then
		playerID = nil
	end

	local name, playerInfo
	if playerID then
		-- provide name from cache first
		if currentNames[playerID] then
			return currentNames[playerID]
		end
		name, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(playerID)
		accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid) or false
		if validAccounts[accountID] ~= playerID then
			accountID = nil	-- skip late added spectators that use an already existing accountID
		end
	end

	if name ~= 'unknown' then
		if accountID then
			-- find if name exists inhistory
			local inHistory = false
			if history[accountID] then
				for i, historyName in pairs(history[accountID]) do	-- using pairs only in case people carelessly delete names from widgetconfig (BYAR.lua)
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
				else
					-- add new name to existing history
					tableInsert(history[accountID], name)
				end
			end
			-- pick name from history
			if history[accountID] then
				if not skipAlias and history[accountID].alias then
					name = history[accountID].alias
				else
					if applyFirstEncounteredName then
						name = history[accountID][1]
					end
				end
			end
			currentAccounts[accountID] = name
		end
		-- cache the name for playerID
		if playerID then
			currentNames[playerID] = name
		end

		return name
	end
end

local function getAccountHistory(accountID, full)
	if history[accountID] then
		if full then
			return history[accountID]
		else
			local accountHistory = {}
			for k, v in pairs(history[accountID]) do
				accountHistory[k] = v
			end
			return accountHistory
		end
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
				tableInsert(accountsByDate, {accountID = accountID, date = tonumber(data.d)})
			else
				-- if no date, treat as very old (assign a very old date)
				tableInsert(accountsByDate, {accountID = accountID, date = 1})
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

local function setaliasCmd(_, _, params)
	if params[1] then
		local playerID
		if type(tonumber(params[1])) == 'number' then
			playerID = tonumber(params[1])
		else
			for pID, name in pairs(currentNames) do
				if name == params[1] then
					playerID = pID
					break
				end
			end
		end
		if playerID then
			local name, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(playerID)
			local accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
			if accountID then
				local alias = params[2]
				if alias then
					spEcho(Spring.I18N('ui.playernames.setalias', { name = name, accountID = accountID, alias = alias }))
					-- ensure history entry exists
					if not history[accountID] then
						history[accountID] = { i = 1, d = tonumber(os.date("%y%m%d")), [1] = name }
					end
					history[accountID].alias = alias
					currentAccounts[accountID] = alias
					currentNames[playerID] = alias
				else
					-- ensure history entry exists before accessing alias
					if history[accountID] and history[accountID].alias then
						spEcho(Spring.I18N('ui.playernames.removealias', { name = name, accountID = accountID, alias = history[accountID].alias }))
						currentNames[playerID] = name
						currentAccounts[accountID] = name
						history[accountID].alias = nil
					end
				end
				-- reload the whole UI
				-- TODO: add a small delay to allow the echo to be readable
				Spring.SendCommands("luaui reload")
			end
		else

			spEcho(Spring.I18N('ui.playernames.notfound', { param = params[1] }))
		end
	end
end

function widget:Initialize()
	local playerList = Spring.GetPlayerList()
	for _, playerID in ipairs(playerList) do
		local _, _, _, _, _, _, _, _, _, _, playerInfo = spGetPlayerInfo(playerID)
		local accountID = (playerInfo and playerInfo.accountid) and tonumber(playerInfo.accountid)
		if accountID and not validAccounts[accountID] then
			-- late rejoined/added spectators dont get a their own accountid but the last assigned playerID one instead so we'll have to ignore those duplicates
			-- THIS ISO FUCKED UP BUT IT IS WHAT IT IS SOMEHOW
			validAccounts[accountID] = playerID
		end
		currentNames[playerID] = getPlayername(playerID)
	end

	WG.playernames = {}
	WG.playernames.getPlayername = function(playerID, accountID, skipAlias)
		return getPlayername(playerID, accountID, skipAlias)
	end
	WG.playernames.getAccountHistory = function(accountID, full)
		return getAccountHistory(accountID, full)
	end
	WG.playernames.setUseFirstEncounter = function(value)
		applyFirstEncounteredName = value
	end
	WG.playernames.getUseFirstEncounter = function()
		return applyFirstEncounteredName
	end
	widgetHandler:AddAction("setalias", setaliasCmd, nil, 't')
end

function widget:Shutdown()
	WG.playernames = nil
	widgetHandler:RemoveAction("setalias")
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
		historyPacked = packHistory(history),
		historyPackedFormat = packedHistoryFormatVersion,
		currentNamesPacked = packNameMap(currentNames),
		currentAccountsPacked = packNameMap(currentAccounts),
	}
end

function widget:SetConfigData(data)
	history = unpackHistory(data.historyPacked) or data.history or {}
	if data.gameID and data.gameID == (Game.gameID and Game.gameID or Spring.GetGameRulesParam("GameID")) then
		currentNames = unpackNameMap(data.currentNamesPacked) or data.currentNames or {}
		currentAccounts = unpackNameMap(data.currentAccountsPacked) or data.currentAccounts or {}
		reconnected = true
	end
	if data.applyFirstEncounteredName ~= nil then
		applyFirstEncounteredName = data.applyFirstEncounteredName
	end
end
