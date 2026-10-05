--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    registered_callins.lua
--  brief:   per-ID subscriber lists for callins that many gadgets register
--
--  Gadgets register their wanted ID lists and receive filtered callin events
--  that contain only those IDs. Callins with no registered IDs get a warning.

local ANY = Game.anyID
local isSynced = Script.GetSynced()
local math_floor = math.floor

--------------------------------------------------------------------------------
--  Declarations  --------------------------------------------------------------

---@class CallinRegistration
---@field idSetName string
---@field callins string[]
---@field filtersOn string only used for log messages
---@field sentinelIDs table<string, true>? excluding ANY which always counts
---@field negativeIDs (integer|string)?
---@field minimumID integer?
---@field syncedOnly boolean?

---@type table<string, CallinRegistration>
local registrations = {
	AllowCommand = {
		idSetName = "_allowCommandIDs",
		callins = { "AllowCommand" },
		filtersOn = "commands",
		sentinelIDs = { [CMD.BUILD] = true, [CMD.NIL] = true },
		negativeIDs = CMD.BUILD,
	},
	UnitCommand = {
		idSetName = "_unitCommandIDs",
		callins = { "UnitCommand" },
		filtersOn = "commands",
		sentinelIDs = { [CMD.BUILD] = true },
		negativeIDs = CMD.BUILD,
	},
}

--------------------------------------------------------------------------------
--  Subscriber lists  ----------------------------------------------------------

---@alias CallinListsByID table<integer|string, table[]>

local callinRegistration = {} ---@type table<string, CallinRegistration?>
local callinLists = {} ---@type table<string, CallinListsByID>
local callinGadgets = {} ---@type table<string, table[]>
local callinSubscribed = {} ---@type table<string, table<table, true?>>
local insertedGadgets = {} ---@type table[]

for _, registration in pairs(registrations) do
	for _, callin in ipairs(registration.callins) do
		callinRegistration[callin] = registration
		callinLists[callin] = { [ANY] = {} }
		callinGadgets[callin] = {}
		callinSubscribed[callin] = {}
	end
end

---@param registration CallinRegistration
local function rebuildIDList(callin, registration, id)
	local idSetName, negativeIDs = registration.idSetName, registration.negativeIDs
	local isNegative = negativeIDs ~= nil and type(id) == "number" and id < 0
	local list, registered = {}, false

	for _, g in ipairs(callinGadgets[callin]) do
		local ids = g[idSetName]
		if ids then
			local wanted = ids[id] or (isNegative and ids[negativeIDs])
			if wanted then
				registered = true
			end
			if wanted or ids[ANY] then
				list[#list + 1] = g
			end
		end
	end

	if registered or id == ANY or id == negativeIDs then
		callinLists[callin][id] = list
	else
		callinLists[callin][id] = nil
	end
end

---Creates and recreates the hash maps between IDs and their callins.
---@param registration CallinRegistration
local function rebuildCallinLists(callin, registration)
	local idSetName, lists = registration.idSetName, callinLists[callin]
	local ids = { [ANY] = true }

	if registration.negativeIDs then
		ids[registration.negativeIDs] = true
	end
	for _, g in ipairs(callinGadgets[callin]) do
		local registered = g[idSetName]
		if registered then
			for id in pairs(registered) do
				ids[id] = true
			end
		end
	end

	for key in pairs(lists) do
		lists[key] = nil
	end
	for id in pairs(ids) do
		rebuildIDList(callin, registration, id)
	end
end

---@param registration CallinRegistration
local function collectListedGadgets(registration, gadgets)
	local idSetName, listed = registration.idSetName, {}
	for _, g in ipairs(gadgets) do
		local ids = g[idSetName]
		if ids and next(ids) ~= nil then
			listed[#listed + 1] = g
		end
	end
	return listed
end

---@param registration CallinRegistration
local function refreshCallinGadgets(handler, callin, registration)
	local current, previous = handler[callin .. "List"], callinGadgets[callin]

	local changed = #current ~= #previous
	if not changed then
		for i = 1, #current do
			if current[i] ~= previous[i] then
				changed = true
				break
			end
		end
	end
	if not changed then
		return
	end

	local gadgets, subscribed = {}, {}
	for i, g in ipairs(current) do
		gadgets[i] = g
		subscribed[g] = true
	end
	callinGadgets[callin] = gadgets
	callinSubscribed[callin] = subscribed

	-- Gadgets with no registered IDs are in no list, so only the order of the others matters.
	local before, after = collectListedGadgets(registration, previous), collectListedGadgets(registration, gadgets)
	local relisted = #before ~= #after
	local i = 1
	while not relisted and i <= #after do
		relisted = before[i] ~= after[i]
		i = i + 1
	end
	if relisted then
		rebuildCallinLists(callin, registration)
	end
end

local function refreshAllCallinGadgets(handler)
	for callin, registration in pairs(callinRegistration) do
		refreshCallinGadgets(handler, callin, registration)
	end
end

---@param registration CallinRegistration
local function rebuildSubscribedCallins(registration, gadget)
	for _, callin in ipairs(registration.callins) do
		if callinSubscribed[callin][gadget] then
			rebuildCallinLists(callin, registration)
		end
	end
end

---@param registration CallinRegistration
local function rebuildRegisteredID(registration, gadget, id)
	if id == ANY or id == registration.negativeIDs then
		rebuildSubscribedCallins(registration, gadget)
	else
		for _, callin in ipairs(registration.callins) do
			if callinSubscribed[callin][gadget] then
				rebuildIDList(callin, registration, id)
			end
		end
	end
end

---@param registration CallinRegistration
local function isRegistrableID(registration, id)
	if type(id) == "number" then
		return id == math_floor(id) and id >= (registration.minimumID or id)
	end
	return id == ANY or (registration.sentinelIDs ~= nil and registration.sentinelIDs[id] == true)
end

local function getGadgetName(gadget)
	-- A gadget that registers from its file's main chunk has no ghInfo until the chunk returns.
	local ghInfo = gadget.ghInfo
	return ghInfo and ghInfo.basename or "?"
end

---@param registration CallinRegistration
local function registerGadgetID(registration, gadget, id)
	local section = registration.callins[1] --[[@as string]]
	local basename = getGadgetName(gadget)
	Spring.Log(section, LOG.INFO, "<" .. basename .. "> Register " .. tostring(id))
	if registration.syncedOnly and not isSynced then
		Spring.Log(section, LOG.ERROR, "<" .. basename .. "> " .. section .. " runs only in synced code")
		return
	end
	if not isRegistrableID(registration, id) then
		Spring.Log(section, LOG.ERROR, "<" .. basename .. "> Invalid ID " .. tostring(id))
		return
	end

	local ids = gadget[registration.idSetName]
	if not ids then
		ids = {}
		gadget[registration.idSetName] = ids
	elseif ids[id] then
		return
	end
	ids[id] = true

	rebuildRegisteredID(registration, gadget, id)
end

---@param registration CallinRegistration
local function deregisterGadgetID(registration, gadget, id)
	local ids = gadget[registration.idSetName]
	if not ids or not ids[id] then
		return
	end
	ids[id] = nil

	rebuildRegisteredID(registration, gadget, id)
end

local function registerInsertedGadgets()
	local gadgets = insertedGadgets
	insertedGadgets = {}

	for _, gadget in ipairs(gadgets) do
		for _, registration in pairs(registrations) do
			if not gadget[registration.idSetName] and (isSynced or not registration.syncedOnly) then
				for _, callin in ipairs(registration.callins) do
					if callinSubscribed[callin][gadget] then
						local filtersOn = registration.filtersOn
						local message = callin .. " defined but didn't register any " .. filtersOn
						message = message .. ". Autoregistering for all " .. filtersOn .. "!"
						Spring.Log(callin, LOG.WARNING, "<" .. gadget.ghInfo.basename .. "> " .. message)
						registerGadgetID(registration, gadget, ANY)
						break
					end
				end
			end
		end
	end
end

--------------------------------------------------------------------------------
--  Exports  -------------------------------------------------------------------

---Limits gadget:AllowCommand to only registered commands.
---@param gadget table
---@param cmdID integer|string A commandID or one of CMD.ANY, CMD.BUILD, CMD.NIL
local function registerAllowCommand(_, gadget, cmdID)
	registerGadgetID(registrations.AllowCommand, gadget, cmdID)
end

---@param gadget table
---@param cmdID integer|string
local function deregisterAllowCommand(_, gadget, cmdID)
	deregisterGadgetID(registrations.AllowCommand, gadget, cmdID)
end

---Limits gadget:UnitCommand to only registered commands.
---@param gadget table
---@param cmdID integer|string A commandID or one of CMD.ANY, CMD.BUILD
local function registerUnitCommand(_, gadget, cmdID)
	registerGadgetID(registrations.UnitCommand, gadget, cmdID)
end

---@param gadget table
---@param cmdID integer|string
local function deregisterUnitCommand(_, gadget, cmdID)
	deregisterGadgetID(registrations.UnitCommand, gadget, cmdID)
end

---@param callin string
---@return CallinListsByID
local function getLists(callin)
	return callinLists[callin]
end

--------------------------------------------------------------------------------
--  Install  -------------------------------------------------------------------

local function install(handler)
	handler.RegisterAllowCommand = registerAllowCommand
	handler.DeregisterAllowCommand = deregisterAllowCommand
	handler.RegisterUnitCommand = registerUnitCommand
	handler.DeregisterUnitCommand = deregisterUnitCommand

	-- Once installed, wraps the UpdateCallIn method.
	local updateCallIn = handler.UpdateCallIn
	function handler:UpdateCallIn(name)
		local registration = callinRegistration[name]
		if registration then
			refreshCallinGadgets(self, name, registration)
		end
		return updateCallIn(self, name)
	end

	-- Removing a gadget or its callins during its Initialize is applied by reordering.
	local insertGadgetRaw, performReorders = handler.InsertGadgetRaw, handler.PerformReorders
	function handler:InsertGadgetRaw(gadget)
		insertGadgetRaw(self, gadget)
		insertedGadgets[#insertedGadgets + 1] = gadget
	end
	function handler:PerformReorders()
		performReorders(self)
		registerInsertedGadgets()
	end

	-- Reordering moves gadgets within the callin lists without updating any callin.
	local raiseGadgetRaw, lowerGadgetRaw = handler.RaiseGadgetRaw, handler.LowerGadgetRaw
	function handler:RaiseGadgetRaw(gadget)
		raiseGadgetRaw(self, gadget)
		refreshAllCallinGadgets(self)
	end
	function handler:LowerGadgetRaw(gadget)
		lowerGadgetRaw(self, gadget)
		refreshAllCallinGadgets(self)
	end
end

---Registration of gadgets for the IDs that their callins want, for gadgets.lua.
---@class RegisteredCallinsAPI
local registered = {
	install = install,
	getLists = getLists,
}

return registered
