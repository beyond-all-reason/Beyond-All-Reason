-- Firestate visibility/control bridge is always required (ally/godmode filtering).
-- Defend combat stance behavior stays behind experimental_defend_firestate.

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Handler",
		desc = "Handles customized firestate behavior",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true
	}
end

local CustomFirestateDefs = VFS.Include("modules/custom_firestate_defs.lua")
local UNKNOWN = CustomFirestateDefs.UNKNOWN

if gadgetHandler:IsSyncedCode() then

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitStates = Spring.GetUnitStates
local spGetAllUnits = Spring.GetAllUnits
local spGetUnitTeam = Spring.GetUnitTeam
local SendToUnsynced = SendToUnsynced
local settingEngineFirestate = false
local userFirestateByUnitID = {}
local needsDump = true

local function sendFirestateUpdate(unitID, state, unitTeam)
	SendToUnsynced("firestateUpdate", unitID, state, unitTeam)
end

local function getUnitUserFirestate(unitID)
	return userFirestateByUnitID[unitID]
end

local function storeUserFirestate(unitID, state, unitTeam)
	userFirestateByUnitID[unitID] = state
	sendFirestateUpdate(unitID, state, unitTeam or spGetUnitTeam(unitID))
end

local function setUnitUserFirestate(unitID, state)
	local engineFirestate = CustomFirestateDefs.toEngineFirestate(state)
	if engineFirestate == nil then
		return false
	end
	storeUserFirestate(unitID, state, spGetUnitTeam(unitID))
	settingEngineFirestate = true
	spGiveOrderToUnit(unitID, CMD_FIRE_STATE, engineFirestate, 0)
	settingEngineFirestate = false
	return true
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	if cmdID == CMD_USER_FIRESTATE then
		local state = cmdParams[1]
		if CustomFirestateDefs.toEngineFirestate(state) ~= nil then
			setUnitUserFirestate(unitID, state)
		end
		return false
	end

	if settingEngineFirestate then
		return true
	end

	if cmdID == CMD_FIRE_STATE then
		local state = CustomFirestateDefs.fromEngineFirestate(cmdParams[1])
		storeUserFirestate(unitID, state, teamID)
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local state
	local builderDefID = builderID and spGetUnitDefID(builderID)
	if builderDefID and UnitDefs[builderDefID].isFactory then
		state = getUnitUserFirestate(builderID)
			or CustomFirestateDefs.fromEngineFirestate(spGetUnitStates(builderID, false))
	end
	if state == nil then
		state = CustomFirestateDefs.fromEngineFirestate(spGetUnitStates(unitID, false))
	end
	storeUserFirestate(unitID, state, unitTeam)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	local state = getUnitUserFirestate(unitID)
	if state == nil then
		state = CustomFirestateDefs.fromEngineFirestate(spGetUnitStates(unitID, false))
		userFirestateByUnitID[unitID] = state
	end
	sendFirestateUpdate(unitID, state, newTeam)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeam, newTeam)
	local state = getUnitUserFirestate(unitID)
	if state == nil then
		state = CustomFirestateDefs.fromEngineFirestate(spGetUnitStates(unitID, false))
		userFirestateByUnitID[unitID] = state
	end
	sendFirestateUpdate(unitID, state, newTeam)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	userFirestateByUnitID[unitID] = nil
	sendFirestateUpdate(unitID, UNKNOWN, unitTeam)
end

local function dumpAllFirestates()
	local allUnits = spGetAllUnits()
	for index = 1, #allUnits do
		local unitID = allUnits[index]
		local state = getUnitUserFirestate(unitID)
		if state == nil then
			state = CustomFirestateDefs.fromEngineFirestate(spGetUnitStates(unitID, false))
			userFirestateByUnitID[unitID] = state
		end
		sendFirestateUpdate(unitID, state, spGetUnitTeam(unitID))
	end
end

function gadget:GameFrame(frame)
	if needsDump then
		needsDump = false
		dumpAllFirestates()
	end
end

function gadget:Initialize()
	GG.getUnitUserFirestate = getUnitUserFirestate
	GG.setUnitUserFirestate = setUnitUserFirestate
	gadgetHandler:RegisterCMDID(CMD_USER_FIRESTATE)
	gadgetHandler:RegisterAllowCommand(CMD_FIRE_STATE)
	gadgetHandler:RegisterAllowCommand(CMD_USER_FIRESTATE)
	dumpAllFirestates()
end

function gadget:GameStart()
	dumpAllFirestates()
end

function gadget:Shutdown()
	GG.getUnitUserFirestate = nil
	GG.setUnitUserFirestate = nil
end

else

local spGetMyTeamID = Spring.GetMyTeamID
local spGetSpectatingState = Spring.GetSpectatingState
local spIsGodModeEnabled = Spring.IsGodModeEnabled
local spAreTeamsAllied = Spring.AreTeamsAllied

local allFirestates = {}
local lastSentToUi = {}
local myTeamID = spGetMyTeamID()
local isSpectating = select(1, spGetSpectatingState())
local isGodMode = spIsGodModeEnabled()
local luaUiReady = false

local function refreshAccessState()
	myTeamID = spGetMyTeamID()
	isSpectating = select(1, spGetSpectatingState())
	isGodMode = spIsGodModeEnabled()
end

local function canKnow(unitTeam)
	if isSpectating or isGodMode then
		return true
	end
	if myTeamID == nil or unitTeam == nil then
		return false
	end
	return spAreTeamsAllied(unitTeam, myTeamID)
end

local function publish(unitID)
	local entry = allFirestates[unitID]
	if not entry then
		return
	end
	local desired = entry.state
	if not canKnow(entry.teamID) then
		desired = UNKNOWN
	end
	if desired == lastSentToUi[unitID] then
		return
	end
	if not Script.LuaUI('FirestateUpdate') then
		return
	end
	lastSentToUi[unitID] = desired
	Script.LuaUI.FirestateUpdate(unitID, desired)
end

local function publishAll()
	for unitID in pairs(allFirestates) do
		publish(unitID)
	end
end

local function firestateUpdate(_, unitID, state, unitTeam)
	if state == UNKNOWN then
		allFirestates[unitID] = nil
		if lastSentToUi[unitID] ~= UNKNOWN and Script.LuaUI('FirestateUpdate') then
			lastSentToUi[unitID] = UNKNOWN
			Script.LuaUI.FirestateUpdate(unitID, UNKNOWN)
		end
		return
	end
	allFirestates[unitID] = {
		state = state,
		teamID = unitTeam,
	}
	publish(unitID)
end

function gadget:PlayerChanged(playerID)
	refreshAccessState()
	publishAll()
end

function gadget:Update()
	local previousGodMode = isGodMode
	local previousSpectating = isSpectating
	refreshAccessState()
	if isGodMode ~= previousGodMode or isSpectating ~= previousSpectating then
		publishAll()
	end
	local isReady = Script.LuaUI('FirestateUpdate') and true or false
	if isReady and not luaUiReady then
		luaUiReady = true
		publishAll()
	elseif not isReady then
		luaUiReady = false
	end
end

function gadget:Initialize()
	refreshAccessState()
	gadgetHandler:AddSyncAction("firestateUpdate", firestateUpdate)
end

function gadget:Shutdown()
	gadgetHandler:RemoveSyncAction("firestateUpdate")
end

end
