--DEFEND FIRESTATE REWORK: Remove guard; handler is always required
if not Spring.GetModOptions().experimental_defend_firestate then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Firestate Handler",
		desc = "Handles customized firestate behavior",
		author = "SethDGamre",
		date = "2026.06.28",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE
local Firestates = VFS.Include("modules/firestates.lua")
local INLOS = { inlos = true }

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local settingEngineFirestate = false

local function setUserFirestate(unitID, state)
	local engineFirestate = Firestates.toEngineFirestate(state)
	if not engineFirestate then
		return
	end
	spSetUnitRulesParam(unitID, Firestates.RULES_PARAM, state, INLOS)
	settingEngineFirestate = true
	spGiveOrderToUnit(unitID, CMD_FIRE_STATE, engineFirestate, 0)
	settingEngineFirestate = false
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
	if cmdID == CMD_USER_FIRESTATE then
		local state = cmdParams[1]
		if Firestates.toEngineFirestate(state) ~= nil then
			setUserFirestate(unitID, state)
		end
		return false
	end

	if settingEngineFirestate then
		return true
	end

	if cmdID == CMD_FIRE_STATE then
		local state = Firestates.fromEngineFirestate(cmdParams[1])
		spSetUnitRulesParam(unitID, Firestates.RULES_PARAM, state, INLOS)
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	local state
	local builderDefID = builderID and spGetUnitDefID(builderID)
	if builderDefID and UnitDefs[builderDefID].isFactory then
		state = spGetUnitRulesParam(builderID, Firestates.RULES_PARAM)
			or Firestates.fromEngineFirestate(spGetUnitStates(builderID, false))
	end
	if state == nil then
		state = Firestates.fromEngineFirestate(spGetUnitStates(unitID, false))
	end
	spSetUnitRulesParam(unitID, Firestates.RULES_PARAM, state, INLOS)
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_USER_FIRESTATE)
	gadgetHandler:RegisterAllowCommand(CMD_FIRE_STATE)
	gadgetHandler:RegisterAllowCommand(CMD_USER_FIRESTATE)
end
