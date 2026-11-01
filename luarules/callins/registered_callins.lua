--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    registered_callins.lua
--  brief:   per-ID subscriber lists for callins that many gadgets register
--
--  Gadgets register their wanted ID lists and receive filtered callin events
--  that contain only those IDs. Callins that never registered get a warning.
--  Replaces the local Script.SetWatch* calls in each gadget via registration.

local math_floor = math.floor
local ANY = Game.anyID
local NONE = Game.noneID

--------------------------------------------------------------------------------
--  Declarations  --------------------------------------------------------------

---@class CallinRegistration
---@field callins string[]
---@field idSetName string
---@field filtersOn string only used for log messages
---@field negativeRange string?
---@field minimumID integer?
---@field maximumID integer?
---@field nilID string?
---@field syncedOnly boolean?
---@field watcher fun(defID: integer, watch: boolean)?
---@field watched table<integer, true?>?
---@field virtualIDs table<string, integer>? some callins force watching a proxy ID

---@type table<string, CallinRegistration>
local registrations = {
	AllowCommand = {
		callins = { "AllowCommand" },
		idSetName = "_allowCommandIDs",
		filtersOn = "commands",
		negativeRange = CMD.BUILD,
		nilID = CMD.NIL,
	},
	UnitCommand = {
		callins = { "UnitCommand" },
		idSetName = "_unitCommandIDs",
		filtersOn = "commands",
		negativeRange = CMD.BUILD,
	},
	Projectile = {
		callins = { "ProjectileCreated", "ProjectileDestroyed" },
		idSetName = "_projectileIDs",
		filtersOn = "weapons",
		minimumID = -1, -- for piece projectiles
		maximumID = #WeaponDefs,
		syncedOnly = true,
		watcher = Script.SetWatchProjectile,
		watched = {},
	},
	Explosion = {
		callins = { "Explosion" },
		idSetName = "_explosionIDs",
		filtersOn = "weapons",
		minimumID = 0,
		maximumID = #WeaponDefs,
		syncedOnly = true,
		watcher = Script.SetWatchExplosion,
		watched = {},
	},
	WeaponTarget = {
		callins = { "AllowWeaponTargetCheck", "AllowWeaponTarget", "AllowWeaponInterceptTarget" },
		idSetName = "_weaponTargetIDs",
		filtersOn = "weapons",
		minimumID = 0,
		maximumID = #WeaponDefs,
		syncedOnly = true,
		watcher = Script.SetWatchAllowTarget,
		watched = {},
		virtualIDs = { UnitAutoTargetRange = 0 }, -- the engine asks for auto-target ranges as weapon 0
	},
}

--------------------------------------------------------------------------------
--  Subscriber lists  ----------------------------------------------------------

---@alias CallinListsByID table<integer|string, table[]>

local callinRegistration = {} ---@type table<string, CallinRegistration?>
local callinLists = {} ---@type table<string, CallinListsByID>
local callinGadgets = {} ---@type table<string, table[]>
local callinSubscribed = {} ---@type table<string, table<table, true?>>
local virtualRegistration = {} ---@type table<string, CallinRegistration?>
local virtualCallins = {} ---@type table<string, true?>
local insertedGadgets = {} ---@type table[]

local isSynced = Script.GetSynced()

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
		if registration.negativeRange then
			callinLists[callin][registration.negativeRange] = {}
		end
		callinGadgets[callin] = {}
		callinSubscribed[callin] = {}
		fillUnregisteredIDs(registration, callinLists[callin])
	end
	if registration.watcher and registration.virtualIDs then
		for callin in pairs(registration.virtualIDs) do
			virtualRegistration[callin] = registration
		end
	end
end

---@param registration CallinRegistration
local function rebuildIDList(callin, registration, id)
	local idSetName, negativeRange = registration.idSetName, registration.negativeRange
	local isNegative = negativeRange ~= nil and type(id) == "number" and id < 0
	local list, registered = {}, false

	for _, g in ipairs(callinGadgets[callin]) do
		local ids = g[idSetName]
		if ids then
			local wanted = ids[id] or (isNegative and ids[negativeRange])
			if wanted then
				registered = true
			end
			if wanted or ids[ANY] then
				list[#list + 1] = g
			end
		end
	end

	local lists = callinLists[callin]
	if registered or id == ANY or id == negativeRange then
		lists[id] = list
	elseif registration.maximumID then
		lists[id] = lists[ANY]
	else
		lists[id] = nil
	end
end

---In-place add/remove of a gadget registered for ANY to every list of a callin.
---@param registration CallinRegistration
local function updateAny(callin, registration, gadget)
	local lists, negativeRange = callinLists[callin], registration.negativeRange
	local idSet = gadget[registration.idSetName]
	local subscribed = callinSubscribed[callin][gadget] == true and idSet ~= nil
	local any = lists[ANY]

	local gadgetToIndex = {}
	for i, g in ipairs(callinGadgets[callin]) do
		gadgetToIndex[g] = i
	end

	for id, list in pairs(lists) do
		-- unregistered IDs share the ANY list, so we only visit it through its exact key
		if list ~= any or id == ANY then
			local wanted = subscribed and idSet[ANY] == true
			if subscribed and not wanted and list ~= any then
				local isNegative = negativeRange ~= nil and type(id) == "number" and id < 0
				wanted = idSet[id] == true or (isNegative and idSet[negativeRange] == true)
			end

			local listIndex
			for i = 1, #list do
				if list[i] == gadget then
					listIndex = i
					break
				end
			end

			if wanted and not listIndex then
				local insertIndex, currentIndex = #list + 1, gadgetToIndex[gadget]
				for i = 1, #list do
					if gadgetToIndex[list[i]] > currentIndex then
						insertIndex = i
						break
					end
				end
				table.insert(list, insertIndex, gadget)
			elseif listIndex and not wanted then
				table.remove(list, listIndex)
			end
		end
	end
end

---@param registration CallinRegistration
local function updateWatchedID(registration, id)
	local watcher, watched = registration.watcher, registration.watched
	if not watcher or not watched or id == ANY then
		return
	end

	local wanted = false
	local virtualIDs = registration.virtualIDs
	if virtualIDs then
		for callin, virtualID in pairs(virtualIDs) do
			if virtualID == id and virtualCallins[callin] then
				wanted = true
			end
		end
	end
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

	if registration.negativeRange then
		ids[registration.negativeRange] = true
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

---True when the lists were kept in the same order as each other.
local function haveSharedOrder(before, after, beforeSet, afterSet)
	local i, j = 1, 1
	repeat
		while before[i] and not afterSet[before[i]] do
			i = i + 1
		end
		while after[j] and not beforeSet[after[j]] do
			j = j + 1
		end
		if before[i] ~= after[j] then
			return false
		end
		i, j = i + 1, j + 1
	until before[i - 1] == nil
	return true
end

---Rebuilding callin lists is slow unless we collect on IDs first when a gadget deregisters a callin.
---Currently very slow still for range-based registrations like CMD.BUILD (but not ANY).
---@param registration CallinRegistration
local function collectRelistedIDs(registration, before, after)
	-- Most ID lists remain the same before and after a gadget deregisters a callin.
	-- Try to work out which ones changed so that only those will be rebuilt after.
	local beforeSet, afterSet = {}, {}
	for _, g in ipairs(before) do
		beforeSet[g] = true
	end
	for _, g in ipairs(after) do
		afterSet[g] = true
	end
	if not haveSharedOrder(before, after, beforeSet, afterSet) then
		return -- do full rebuild
	end

	local relistedGadgets = {}
	for _, g in ipairs(before) do
		if not afterSet[g] then
			relistedGadgets[#relistedGadgets + 1] = g
		end
	end
	for _, g in ipairs(after) do
		if not beforeSet[g] then
			relistedGadgets[#relistedGadgets + 1] = g
		end
	end

	local idSetName, negativeRange, relisted, relistedAny = registration.idSetName, registration.negativeRange, {}, {}
	for _, g in ipairs(relistedGadgets) do
		local ids = g[idSetName]
		if negativeRange ~= nil and ids[negativeRange] then
			return -- do full rebuild
		end
		if ids[ANY] then
			relistedAny[#relistedAny + 1] = g
		end
		for id in pairs(ids) do
			if id ~= ANY then
				relisted[id] = true
			end
		end
	end
	return relisted, relistedAny
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
	local relisted, relistedAny = collectRelistedIDs(registration, before, after)
	if relisted == nil then
		rebuildCallinLists(callin, registration)
	else
		for id in pairs(relisted) do
			rebuildIDList(callin, registration, id)
			updateWatchedID(registration, id)
		end
		for _, g in ipairs(relistedAny) do
			updateAny(callin, registration, g)
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
	if id == ANY then
		for _, callin in ipairs(registration.callins) do
			if callinSubscribed[callin][gadget] then
				updateAny(callin, registration, gadget)
			end
		end
	elseif id == registration.negativeRange then
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
	if id == nil then
		return false
	elseif type(id) ~= "number" then
		return id == ANY or id == NONE or id == registration.negativeRange or id == registration.nilID
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
	if id == NONE then
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
---@param cmdID integer|string A command ID, CMD.ANY, CMD.NONE, CMD.BUILD, or CMD.NIL
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
---@param cmdID integer|string A command ID, CMD.ANY, CMD.NONE, CMD.BUILD, or CMD.NIL
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

---Limits gadget:AllowWeaponTargetCheck and gadget:AllowWeaponTarget to the registered weapons.
---gadget:AllowWeaponInterceptTarget receives no weaponDefID, so it is called for every registered weapon.
---Game.anyID receives the weapons other gadgets register.
---@param gadget table
---@param weaponDefID integer|string
local function registerWeaponTarget(_, gadget, weaponDefID)
	registerGadgetID(registrations.WeaponTarget, gadget, weaponDefID)
end

---@param gadget table
---@param weaponDefID integer|string
local function deregisterWeaponTarget(_, gadget, weaponDefID)
	deregisterGadgetID(registrations.WeaponTarget, gadget, weaponDefID)
end

---@param callin string
---@return CallinListsByID
local function getLists(callin)
	return callinLists[callin]
end

--------------------------------------------------------------------------------
--  Install  -------------------------------------------------------------------

local function install(handler)
	if isSynced then
		for _, name in ipairs({ "SetWatchWeapon", "SetWatchProjectile", "SetWatchExplosion", "SetWatchAllowTarget" }) do
			if Script[name] then
				Script[name] = function()
					local message = name .. " is deprecated. Watch IDs using gadgetHandler:Register<CallinName>."
					Spring.Log("registered_callins", LOG.ERROR, message)
				end
			end
		end
	end

	handler.RegisterAllowCommand = registerAllowCommand
	handler.DeregisterAllowCommand = deregisterAllowCommand
	handler.RegisterUnitCommand = registerUnitCommand
	handler.DeregisterUnitCommand = deregisterUnitCommand
	handler.RegisterProjectile = registerProjectile
	handler.DeregisterProjectile = deregisterProjectile
	handler.RegisterExplosion = registerExplosion
	handler.DeregisterExplosion = deregisterExplosion
	handler.RegisterWeaponTarget = registerWeaponTarget
	handler.DeregisterWeaponTarget = deregisterWeaponTarget

	-- Once installed, wraps the UpdateCallIn method.
	local updateCallIn = handler.UpdateCallIn
	function handler:UpdateCallIn(name)
		local registration = callinRegistration[name]
		if registration then
			refreshCallinGadgets(self, name, registration)
		end
		registration = virtualRegistration[name]
		if registration then
			local virtual = #self[name .. "List"] > 0 or nil
			if virtualCallins[name] ~= virtual then
				virtualCallins[name] = virtual
				---@cast registration.virtualIDs -nil
				updateWatchedID(registration, registration.virtualIDs[name])
			end
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
