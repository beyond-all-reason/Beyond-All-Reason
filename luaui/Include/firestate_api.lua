local Firestates = VFS.Include("modules/firestates.lua")

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE

local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit = Spring.GiveOrderToUnit

WG['firestate'] = WG['firestate'] or {}
WG['firestate'].pendingCommandMeta = WG['firestate'].pendingCommandMeta or {}

local function getPendingStore()
	return WG['firestate'].pendingCommandMeta
end

local function defendFirestateEnabled()
	return Spring.GetModOptions().experimental_defend_firestate
end

local function stagePendingMeta(unitIDs, userState, userInitiated)
	local pendingCommandMeta = getPendingStore()
	for index = 1, #unitIDs do
		pendingCommandMeta[unitIDs[index]] = {
			userState = userState,
			userInitiated = userInitiated,
		}
	end
end

local function takePendingMeta(unitID)
	local pendingCommandMeta = getPendingStore()
	local pendingMeta = pendingCommandMeta[unitID]
	pendingCommandMeta[unitID] = nil
	return pendingMeta
end

local function issueToUnit(unitID, userState, userInitiated)
	local engineFirestate = Firestates.toEngineFirestate(userState)
	if engineFirestate == nil then
		return false
	end
	if defendFirestateEnabled() then
		spGiveOrderToUnit(unitID, CMD_USER_FIRESTATE, Firestates.buildUserFirestateParams(userState, userInitiated), 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { engineFirestate }, 0)
	end
	return true
end

local function notifyUserFirestate(unitIDs, userState, userInitiated)
	if not userInitiated then
		return
	end
	local onUserFirestate = WG['firestate'].onUserFirestate
	if not onUserFirestate then
		return
	end
	for index = 1, #unitIDs do
		onUserFirestate(unitIDs[index], userState)
	end
end

local function giveFirestate(userState, unitIDs, opts)
	if userState == nil or not unitIDs or #unitIDs == 0 then
		return false
	end
	opts = opts or {}
	local userInitiated = opts.userInitiated and true or false
	stagePendingMeta(unitIDs, userState, userInitiated)
	notifyUserFirestate(unitIDs, userState, userInitiated)
	if defendFirestateEnabled() then
		spGiveOrder(CMD_USER_FIRESTATE, Firestates.buildUserFirestateParams(userState, userInitiated), 0)
	else
		local engineFirestate = Firestates.toEngineFirestate(userState)
		if engineFirestate == nil then
			return false
		end
		spGiveOrder(CMD_FIRE_STATE, { engineFirestate }, 0)
	end
	return true
end

local function setState(userState, unitIDs, opts)
	if userState == nil or not unitIDs then
		return false
	end
	opts = opts or {}
	local userInitiated = opts.userInitiated and true or false
	stagePendingMeta(unitIDs, userState, userInitiated)
	notifyUserFirestate(unitIDs, userState, userInitiated)
	for index = 1, #unitIDs do
		issueToUnit(unitIDs[index], userState, userInitiated)
	end
	return true
end

local function parseCommandMeta(cmdID, cmdParams, unitID)
	if cmdID == CMD_USER_FIRESTATE then
		local userState, userInitiated = Firestates.parseUserFirestateParams(cmdParams)
		return userState, userInitiated, true
	end
	if cmdID == CMD_FIRE_STATE then
		local pendingMeta = takePendingMeta(unitID)
		local hadPending = pendingMeta ~= nil
		local userInitiated = pendingMeta and pendingMeta.userInitiated == true
		local userState = pendingMeta and pendingMeta.userState
		if userState == nil then
			userState = Firestates.fromEngineFirestate(cmdParams and cmdParams[1])
		end
		return userState, userInitiated, hadPending
	end
	return nil, false, false
end

WG['firestate'].giveFirestate = giveFirestate
WG['firestate'].setState = setState
WG['firestate'].parseCommandMeta = parseCommandMeta

return WG['firestate']
