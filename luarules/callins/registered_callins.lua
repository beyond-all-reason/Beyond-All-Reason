--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    registered_callins.lua
--  brief:   per-ID subscriber lists for callins that many gadgets register
--
--  Gadgets register their wanted ID lists and receive filtered callin events
--  that contain only those IDs. Callins with no registered IDs get a warning.
--  Replaces the local Script.SetWatch* calls in each gadget via registration.

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
---@field maximumID integer?
---@field syncedOnly boolean?
---@field watcher fun(defID: integer, watch: boolean)?
---@field watched table<integer, true?>?

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
	Projectile = {
		idSetName = "_projectileIDs",
		callins = { "ProjectileCreated", "ProjectileDestroyed" },
		filtersOn = "weapons",
		minimumID = -1, -- for piece projectiles
		maximumID = #WeaponDefs,
		syncedOnly = true,
		watcher = Script.SetWatchProjectile,
		watched = {},
	},
	Explosion = {
		idSetName = "_explosionIDs",
		callins = { "Explosion" },
		filtersOn = "weapons",
		minimumID = 0,
		maximumID = #WeaponDefs,
		syncedOnly = true,
		watcher = Script.SetWatchExplosion,
		watched = {},
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

---@param registration CallinRegistration
local function fillUnregisteredIDs(registration, lists)
	local minimumID, maximumID = registration.minimumID, registration.maximumID
	if minimumID and maximumID then
		local anyList = lists[ANY]
		for id = minimumID, maximumID do
			if lists[id] == nil then
				lists[id] = anyList
			end
		end
	end
end

for _, registration in pairs(registrations) do
	for _, callin in ipairs(registration.callins) do
		callinRegistration[callin] = registration
		callinLists[callin] = { [ANY] = {} }
		callinGadgets[callin] = {}
		callinSubscribed[callin] = {}
		fillUnregisteredIDs(registration, callinLists[callin])
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

	local lists = callinLists[callin]
	if registered or id == ANY or id == negativeIDs then
		lists[id] = list
	elseif registration.maximumID then
		lists[id] = lists[ANY]
	else
		lists[id] = nil
	end
end

---@param registration CallinRegistration
local function updateWatchedID(registration, id)
	local watcher, watched = registration.watcher, registration.watched
	if not watcher or not watched or id == ANY then
		return
	end

	local wanted = false
	for _, callin in ipairs(registration.callins) do
		local lists = callinLists[callin]
		if lists[id] ~= nil and lists[id] ~= lists[ANY] then
			wanted = true
		end
	end

	if wanted and not watched[id] then
		watched[id] = true
		watcher(id, true)
	elseif not wanted and watched[id] then
		watched[id] = nil
		watcher(id, false)
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
	if registration.watched then
		for id in pairs(registration.watched) do
			ids[id] = true
		end
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
	rebuildIDList(callin, registration, ANY)
	for id in pairs(ids) do
		if id ~= ANY then
			rebuildIDList(callin, registration, id)
		end
	end
	fillUnregisteredIDs(registration, lists)
	for id in pairs(ids) do
		updateWatchedID(registration, id)
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

---Callin lists rebuild extremely slowly unless we collect on IDs first when a gadget deregisters a callin.
---Currently very slow still for range-based registrations like ANY and negative IDs for build orders.
---@param registration CallinRegistration
local function collectRelistedIDs(registration, before, after)
	local wasListed, isListed = {}, {}
	for _, g in ipairs(before) do
		wasListed[g] = true
	end
	for _, g in ipairs(after) do
		isListed[g] = true
	end

	-- Keep the order of other gadgets when ID lists change.
	local i, j = 1, 1
	repeat
		while before[i] and not isListed[before[i]] do
			i = i + 1
		end
		while after[j] and not wasListed[after[j]] do
			j = j + 1
		end
		if before[i] ~= after[j] then
			return
		end
		i, j = i + 1, j + 1
	until before[i - 1] == nil

	local relistedGadgets = {}
	for _, g in ipairs(before) do
		if not isListed[g] then
			relistedGadgets[#relistedGadgets + 1] = g
		end
	end
	for _, g in ipairs(after) do
		if not wasListed[g] then
			relistedGadgets[#relistedGadgets + 1] = g
		end
	end

	local idSetName, negativeIDs, relisted = registration.idSetName, registration.negativeIDs, {}
	for _, g in ipairs(relistedGadgets) do
		for id in pairs(g[idSetName]) do
			if id == ANY or id == negativeIDs then
				return -- every list needs rebuilding
			end
			relisted[id] = true
		end
	end
	return relisted
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
	local relisted = collectRelistedIDs(registration, before, after)
	if relisted == nil then
		rebuildCallinLists(callin, registration)
	else
		for id in pairs(relisted) do
			rebuildIDList(callin, registration, id)
			updateWatchedID(registration, id)
		end
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
		updateWatchedID(registration, id)
	end
end

---@param registration CallinRegistration
local function isRegistrableID(registration, id)
	if type(id) ~= "number" then
		local sentinelIDs = registration.sentinelIDs
		return id == ANY or (sentinelIDs ~= nil and sentinelIDs[id] == true)
	elseif id ~= math_floor(id) then
		return false
	end
	local minimumID, maximumID = registration.minimumID, registration.maximumID
	return (minimumID == nil or id >= minimumID) and (maximumID == nil or id <= maximumID)
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
						if registration.watched then
							message = message .. ". Autoregistering for the " .. filtersOn .. " other gadgets register!"
						else
							message = message .. ". Autoregistering for all " .. filtersOn .. "!"
						end
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
---@param cmdID integer|string A commandID or one of CMD.ANY, CMD.BUILD, CMD.NIL
local function registerUnitCommand(_, gadget, cmdID)
	registerGadgetID(registrations.UnitCommand, gadget, cmdID)
end

---@param gadget table
---@param cmdID integer|string
local function deregisterUnitCommand(_, gadget, cmdID)
	deregisterGadgetID(registrations.UnitCommand, gadget, cmdID)
end

---Limits gadget:ProjectileCreated and gadget:ProjectileDestroyed to the registered weapons.
---Piece projectiles are weapon -1. Game.anyID receives the weapons other gadgets register.
---@param gadget table
---@param weaponDefID integer|string
local function registerProjectile(_, gadget, weaponDefID)
	registerGadgetID(registrations.Projectile, gadget, weaponDefID)
end

---@param gadget table
---@param weaponDefID integer|string
local function deregisterProjectile(_, gadget, weaponDefID)
	deregisterGadgetID(registrations.Projectile, gadget, weaponDefID)
end

---Limits gadget:Explosion to the registered weapons.
---Game.anyID receives the weapons other gadgets register.
---@param gadget table
---@param weaponDefID integer|string
local function registerExplosion(_, gadget, weaponDefID)
	registerGadgetID(registrations.Explosion, gadget, weaponDefID)
end

---@param gadget table
---@param weaponDefID integer|string
local function deregisterExplosion(_, gadget, weaponDefID)
	deregisterGadgetID(registrations.Explosion, gadget, weaponDefID)
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
	handler.RegisterProjectile = registerProjectile
	handler.DeregisterProjectile = deregisterProjectile
	handler.RegisterExplosion = registerExplosion
	handler.DeregisterExplosion = deregisterExplosion

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
