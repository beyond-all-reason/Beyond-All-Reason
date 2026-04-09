local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name    = "Bomber Targeting State",
		desc    = "Adds Manual/Auto targeting toggle for bombers",
		author  = "Pexo",
		date    = "2026-03-03",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local CMD_BOMBER_TARGETING = GameCMD.BOMBER_TARGETING

local STATE_MANUAL = 0
local STATE_AUTO = 1
local DEFAULT_STATE = STATE_AUTO

local RULESPARAM_NAME = "bomberTargetingState"

local CMDTYPE_ICON_MODE = CMDTYPE.ICON_MODE

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spRemoveUnitCmdDesc = Spring.RemoveUnitCmdDesc
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spGetUnitRulesParam = Spring.GetUnitRulesParam

local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_MOVE_STATE = CMD.MOVE_STATE

local isBomberDef = {}

local function isBomberUnitDef(ud)
	if not ud or not ud.weapons then
		return false
	end

	for i = 1, #ud.weapons do
		local weaponDef = WeaponDefs[ud.weapons[i].weaponDef]
		if weaponDef and weaponDef.type == "AircraftBomb" then
			return true
		end
	end

	return false
end

for unitDefID, unitDef in pairs(UnitDefs) do
	if isBomberUnitDef(unitDef) then
		isBomberDef[unitDefID] = true
	end
end

local function getCmdDesc(state)
	return {
		id = CMD_BOMBER_TARGETING,
		type = CMDTYPE_ICON_MODE,
		name = "bomber_targeting",
		action = "bomber_targeting",
		tooltip = "bomber_targeting_tooltip",
		params = { state or DEFAULT_STATE, "Hold fire", "Fire at will" },
	}
end

local function applyTargetingState(unitID, state)
	local targetingState = state == STATE_MANUAL and STATE_MANUAL or STATE_AUTO

	spSetUnitRulesParam(unitID, RULESPARAM_NAME, targetingState, { allied = true })

	if targetingState == STATE_MANUAL then
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { 0 }, 0)
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 0 }, 0)
	else
		spGiveOrderToUnit(unitID, CMD_FIRE_STATE, { 2 }, 0)
		spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, 0)
	end

	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_BOMBER_TARGETING)
	if cmdDescID then
		spEditUnitCmdDesc(unitID, cmdDescID, getCmdDesc(targetingState))
	end
end

local function ensureCmdDesc(unitID, state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_BOMBER_TARGETING)
	if cmdDescID then
		spEditUnitCmdDesc(unitID, cmdDescID, getCmdDesc(state))
	else
		spInsertUnitCmdDesc(unitID, getCmdDesc(state))
	end
end

local function hideMoveState(unitID)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_MOVE_STATE)
	if cmdDescID then
		spRemoveUnitCmdDesc(unitID, cmdDescID)
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if not isBomberDef[unitDefID] then
		return
	end

	local storedState = spGetUnitRulesParam(unitID, RULESPARAM_NAME)
	local initialState = storedState or DEFAULT_STATE

	hideMoveState(unitID)
	ensureCmdDesc(unitID, initialState)
	applyTargetingState(unitID, initialState)
end

function gadget:UnitGiven(unitID, unitDefID)
	if not isBomberDef[unitDefID] then
		return
	end

	local storedState = spGetUnitRulesParam(unitID, RULESPARAM_NAME) or DEFAULT_STATE
	hideMoveState(unitID)
	ensureCmdDesc(unitID, storedState)
	applyTargetingState(unitID, storedState)
end

function gadget:UnitTaken(unitID, unitDefID)
	if not isBomberDef[unitDefID] then
		return
	end

	local storedState = spGetUnitRulesParam(unitID, RULESPARAM_NAME) or DEFAULT_STATE
	hideMoveState(unitID)
	ensureCmdDesc(unitID, storedState)
	applyTargetingState(unitID, storedState)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams)
	if cmdID == CMD_BOMBER_TARGETING and isBomberDef[unitDefID] then
		applyTargetingState(unitID, cmdParams and cmdParams[1])
		return false
	end
	return true
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_BOMBER_TARGETING)

	for _, unitID in ipairs(spGetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		if isBomberDef[unitDefID] then
			-- reuse any stored state or fall back to default
			local storedState = spGetUnitRulesParam(unitID, RULESPARAM_NAME) or DEFAULT_STATE
			hideMoveState(unitID)
			ensureCmdDesc(unitID, storedState)
			applyTargetingState(unitID, storedState)
		end
	end
end