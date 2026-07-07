local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE

local spGiveOrder = Spring.GiveOrder
local spGiveOrderToUnit = Spring.GiveOrderToUnit

WG['firestate'] = WG['firestate'] or {}
WG['firestate'].stagedFirestateByUnitId = WG['firestate'].stagedFirestateByUnitId or {}

local function stageFirestate(unitIDs, userState, userInitiated)
	for index = 1, #unitIDs do
		WG['firestate'].stagedFirestateByUnitId[unitIDs[index]] = {
			userState = userState,
			userInitiated = userInitiated,
		}
	end
end

local function consumeStagedFirestate(unitID)
	local stagedFirestate = WG['firestate'].stagedFirestateByUnitId[unitID]
	WG['firestate'].stagedFirestateByUnitId[unitID] = nil
	return stagedFirestate
end

local function issueToUnit(unitID, userState, userInitiated)
	local engineFirestate = CustomFirestateDefs.toEngineFirestate(userState)
	if engineFirestate == nil then
		return false
	end
	if Spring.GetModOptions().experimental_defend_firestate then
		spGiveOrderToUnit(unitID, CMD_USER_FIRESTATE, CustomFirestateDefs.buildUserFirestateParams(userState, userInitiated), 0)
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
	stageFirestate(unitIDs, userState, userInitiated)
	notifyUserInitiatedFirestate(unitIDs, userState, userInitiated)
	if Spring.GetModOptions().experimental_defend_firestate then
		spGiveOrder(CMD_USER_FIRESTATE, CustomFirestateDefs.buildUserFirestateParams(userState, userInitiated), 0)
	else
		local engineFirestate = CustomFirestateDefs.toEngineFirestate(userState)
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
	stageFirestate(unitIDs, userState, userInitiated)
	notifyUserInitiatedFirestate(unitIDs, userState, userInitiated)
	for index = 1, #unitIDs do
		issueToUnit(unitIDs[index], userState, userInitiated)
	end
	return true
end

local function decodeFirestateUnitCommand(cmdID, cmdParams, unitID)
	if cmdID == CMD_USER_FIRESTATE then
		local userState, userInitiated = CustomFirestateDefs.parseUserFirestateParams(cmdParams)
		return userState, userInitiated, true
	end
	if cmdID == CMD_FIRE_STATE then
		local stagedFirestate = consumeStagedFirestate(unitID)
		local wasStagedByApi = stagedFirestate ~= nil
		local userInitiated = stagedFirestate and stagedFirestate.userInitiated == true
		local userState = stagedFirestate and stagedFirestate.userState
		if userState == nil then
			userState = CustomFirestateDefs.fromEngineFirestate(cmdParams and cmdParams[1])
		end
		return userState, userInitiated, wasStagedByApi
	end
	return nil, false, false
end

WG['firestate'].giveFirestateToSelection = giveFirestateToSelection
WG['firestate'].setFirestateForUnits = setFirestateForUnits
WG['firestate'].decodeFirestateUnitCommand = decodeFirestateUnitCommand

return WG['firestate']
