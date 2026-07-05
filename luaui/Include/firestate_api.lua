local Firestates = VFS.Include("modules/firestates.lua")

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE

local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit = Spring.GiveOrderToUnit

WG['firestate'] = WG['firestate'] or {}
WG['firestate'].stagedFirestateByUnitId = WG['firestate'].stagedFirestateByUnitId or {}

local function stageFirestateContext(unitIDs, userState, userInitiated)
	for index = 1, #unitIDs do
		WG['firestate'].stagedFirestateByUnitId[unitIDs[index]] = {
			userState = userState,
			userInitiated = userInitiated,
		}
	end
end

local function consumeStagedFirestateContext(unitID)
	local stagedContext = WG['firestate'].stagedFirestateByUnitId[unitID]
	WG['firestate'].stagedFirestateByUnitId[unitID] = nil
	return stagedContext
end

local function issueToUnit(unitID, userState, userInitiated)
	local engineFirestate = Firestates.toEngineFirestate(userState)
	if engineFirestate == nil then
		return false
	end
	if Spring.GetModOptions().experimental_defend_firestate then
		spGiveOrderToUnit(unitID, CMD_USER_FIRESTATE, Firestates.buildUserFirestateParams(userState, userInitiated), 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { engineFirestate }, 0)
	end
	return true
end

local function notifyUserInitiatedFirestate(unitIDs, userState, userInitiated)
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

local function giveFirestateToSelection(userState, unitIDs, opts)
	if userState == nil or not unitIDs or #unitIDs == 0 then
		return false
	end
	opts = opts or {}
	local userInitiated = opts.userInitiated and true or false
	stageFirestateContext(unitIDs, userState, userInitiated)
	notifyUserInitiatedFirestate(unitIDs, userState, userInitiated)
	if Spring.GetModOptions().experimental_defend_firestate then
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

local function setFirestateForUnits(userState, unitIDs, opts)
	if userState == nil or not unitIDs then
		return false
	end
	opts = opts or {}
	local userInitiated = opts.userInitiated and true or false
	stageFirestateContext(unitIDs, userState, userInitiated)
	notifyUserInitiatedFirestate(unitIDs, userState, userInitiated)
	for index = 1, #unitIDs do
		issueToUnit(unitIDs[index], userState, userInitiated)
	end
	return true
end

local function parseFirestateCommandContext(cmdID, cmdParams, unitID)
	if cmdID == CMD_USER_FIRESTATE then
		local userState, userInitiated = Firestates.parseUserFirestateParams(cmdParams)
		return userState, userInitiated, true
	end
	if cmdID == CMD_FIRE_STATE then
		local stagedContext = consumeStagedFirestateContext(unitID)
		local wasStagedByApi = stagedContext ~= nil
		local userInitiated = stagedContext and stagedContext.userInitiated == true
		local userState = stagedContext and stagedContext.userState
		if userState == nil then
			userState = Firestates.fromEngineFirestate(cmdParams and cmdParams[1])
		end
		return userState, userInitiated, wasStagedByApi
	end
	return nil, false, false
end

WG['firestate'].giveFirestateToSelection = giveFirestateToSelection
WG['firestate'].setFirestateForUnits = setFirestateForUnits
WG['firestate'].parseFirestateCommandContext = parseFirestateCommandContext

return WG['firestate']
