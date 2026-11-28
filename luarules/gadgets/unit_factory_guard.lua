if not gadgetHandler:IsSyncedCode() then
	return
end

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Factory Guard",
		desc = "Adds a factory guard state command to factories",
		author = "Hobo Joe",
		date = "Feb 2024",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc = Spring.FindUnitCmdDesc
local spTestMoveOrder = Spring.TestMoveOrder

local CMD_FACTORY_GUARD = GameCMD.FACTORY_GUARD
local CMD_GUARD = CMD.GUARD
local CMD_MOVE = CMD.MOVE

-- state N has N in every 4 of the builders guard (0: off, 4: all of them); names are translation keys
local MAX_STATE = 4
local factoryGuardCmdDesc = {
	id = CMD_FACTORY_GUARD,
	type = CMDTYPE.ICON_MODE,
	tooltip = "factoryguard_tooltip",
	name = "factoryguard",
	cursor = "cursornormal",
	action = "factoryguard",
	params = { 0, "factoryguard_0", "factoryguard_1", "factoryguard_2", "factoryguard_3", "factoryguard_4" },
}

local isFactory = {}
local isAssistBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory and unitDef.canBeAssisted then
		local buildOptions = unitDef.buildOptions

		for i = 1, #buildOptions do
			local buildOptDefID = buildOptions[i]
			local buildOpt = UnitDefs[buildOptDefID]

			if buildOpt and buildOpt.isBuilder and buildOpt.canAssist then
				isFactory[unitDefID] = true -- only factories that can build builders are included
				break
			end
		end
	end
	if unitDef.isBuilder and unitDef.canAssist then
		isAssistBuilder[unitDefID] = true
	end
end

local guardState = {} -- factoryID -> its state, absent while off
local buildersOut = {} -- factoryID -> builders without orders it made since its state was set

local function setFactoryGuardState(unitID, state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_FACTORY_GUARD)
	if cmdDescID then
		factoryGuardCmdDesc.params[1] = state
		spEditUnitCmdDesc(unitID, cmdDescID, { params = factoryGuardCmdDesc.params })
		guardState[unitID] = state > 0 and state or nil
		buildersOut[unitID] = nil -- (the next builder guards)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	--accepts: CMD_FACTORY_GUARD
	if isFactory[unitDefID] then
		local state = cmdParams[1]
		if state and state >= 0 and state <= MAX_STATE and state % 1 == 0 then
			setFactoryGuardState(unitID, state)
		end
		return false -- command was used
	end
	return true -- command was not used
end

--------------------------------------------------------------------------------
-- Guard Command Handling

local function GuardFactory(unitID, unitDefID, factID)
	local x, y, z = spGetUnitPosition(factID)
	if not x then
		return
	end

	local radius = spGetUnitRadius(factID)
	if not radius then
		return
	end
	local dist = radius * 2

	local facing = spGetUnitBuildFacing(factID)
	if not facing then
		return
	end

	-- facing values { S = 0, E = 1, N = 2, W = 3 }
	local dx, dz -- down vector
	local rx, rz -- right vector
	if facing == 0 then
		dx, dz = 0, dist
		rx, rz = dist, 0
	elseif facing == 1 then
		dx, dz = dist, 0
		rx, rz = 0, -dist
	elseif facing == 2 then
		dx, dz = 0, -dist
		rx, rz = -dist, 0
	else
		dx, dz = -dist, 0
		rx, rz = 0, dist
	end

	local OrderUnit = spGiveOrderToUnit

	OrderUnit(unitID, CMD_MOVE, { x + dx, y, z + dz }, { "" })
	if spTestMoveOrder(unitDefID, x + dx + rx, y, z + dz + rz) then
		OrderUnit(unitID, CMD_MOVE, { x + dx + rx, y, z + dz + rz }, { "shift" })
		if spTestMoveOrder(unitDefID, x + rx, y, z + rz) then
			OrderUnit(unitID, CMD_MOVE, { x + rx, y, z + rz }, { "shift" })
		end
	elseif spTestMoveOrder(unitDefID, x + dx - rx, y, z + dz - rz) then
		OrderUnit(unitID, CMD_MOVE, { x + dx - rx, y, z + dz - rz }, { "shift" })
		if spTestMoveOrder(unitDefID, x - rx, y, z - rz) then
			OrderUnit(unitID, CMD_MOVE, { x - rx, y, z - rz }, { "shift" })
		end
	end
	OrderUnit(unitID, CMD_GUARD, { factID }, { "shift" })
end

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	if userOrders then
		return -- already has user assigned orders
	end
	local share = guardState[factID]
	if not share or not isAssistBuilder[unitDefID] then
		return
	end
	-- `share` of every 4 guard, spread out and the first one guarding (1/4: G..., 2/4: G.G., 3/4: G.GG);
	-- the others are left free
	local out = buildersOut[factID] or 0
	buildersOut[factID] = (out + 1) % MAX_STATE
	if (out * share) % MAX_STATE < share then
		GuardFactory(unitID, unitDefID, factID)
	end
end

--------------------------------------------------------------------------------
-- Unit Handling

function gadget:UnitCreated(unitID, unitDefID, _)
	if isFactory[unitDefID] then
		factoryGuardCmdDesc.params[1] = 0
		spInsertUnitCmdDesc(unitID, factoryGuardCmdDesc)
	end
end

function gadget:UnitDestroyed(unitID)
	guardState[unitID] = nil
	buildersOut[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_FACTORY_GUARD)
	local allUnits = Spring.GetAllUnits()
	for i = 1, #allUnits do
		gadget:UnitCreated(allUnits[i], Spring.GetUnitDefID(allUnits[i]))
	end
end
--------------------------------------------------------------------------------
