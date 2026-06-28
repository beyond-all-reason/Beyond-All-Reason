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
local DEFENSIVE_FIRE_RANGE = 300
local DEFENSIVE_FIRE_RANGE_SQ = DEFENSIVE_FIRE_RANGE * DEFENSIVE_FIRE_RANGE
local INLOS = { inlos = true }

local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local settingEngineFirestate = false

local function setUserFirestate(unitID, state)
	local engineFirestate = Firestates.engineFirestateFor(state)
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
		if Firestates.isUserFacing(state) then
			setUserFirestate(unitID, state)
		end
		return false
	end

	if settingEngineFirestate then
		return true
	end

	if cmdID == CMD_FIRE_STATE then
		local state = Firestates.logicalFromEngineFirestate(cmdParams[1])
		spSetUnitRulesParam(unitID, Firestates.RULES_PARAM, state, INLOS)
	end
	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local firestate = spGetUnitStates(unitID, false)
	local state = Firestates.logicalFromEngineFirestate(firestate)
	spSetUnitRulesParam(unitID, Firestates.RULES_PARAM, state, INLOS)
end

function gadget:AllowWeaponTarget(attackerID, targetID, attackerWeaponNum, attackerWeaponDefID, defPriority)
	if spGetUnitRulesParam(attackerID, Firestates.RULES_PARAM) ~= Firestates.DEFENSIVE then
		return true
	end

	local attackerX, _, attackerZ = spGetUnitPosition(attackerID)
	local targetX, _, targetZ = spGetUnitPosition(targetID)
	if not attackerX or not targetX then
		return true
	end

	local distanceX = attackerX - targetX
	local distanceZ = attackerZ - targetZ
	if distanceX * distanceX + distanceZ * distanceZ > DEFENSIVE_FIRE_RANGE_SQ then
		return false
	end

	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_USER_FIRESTATE)
	gadgetHandler:RegisterAllowCommand(CMD_FIRE_STATE)
	gadgetHandler:RegisterAllowCommand(CMD_USER_FIRESTATE)
	for unitDefID, unitDef in pairs(UnitDefs) do
		local weapons = unitDef.weapons
		for weaponNum = 1, #weapons do
			local weaponDefID = weapons[weaponNum].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]
			if not weaponDef.customParams.bogus then
				Script.SetWatchAllowTarget(weaponDefID, true)
			end
		end
	end
end
