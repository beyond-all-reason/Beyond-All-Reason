
if not gadgetHandler:IsSyncedCode() then
	return
end


local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name      = "Factory Guard",
		desc      = "Adds a factory guard state command to factories",
		author    = "Hobo Joe",
		date      = "Feb 2024",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end


local spGetUnitBuildFacing = Spring.GetUnitBuildFacing
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRadius = Spring.GetUnitRadius
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spInsertUnitCmdDesc  = Spring.InsertUnitCmdDesc
local spEditUnitCmdDesc    = Spring.EditUnitCmdDesc
local spFindUnitCmdDesc    = Spring.FindUnitCmdDesc

local CMD_FACTORY_GUARD = GameCMD.FACTORY_GUARD
local CMD_GUARD = CMD.GUARD
local CMD_MOVE = CMD.MOVE

local factoryGuardCmdDesc = {
	id = CMD_FACTORY_GUARD,
	type = CMDTYPE.ICON_MODE,
	tooltip = 'factoryguard_tooltip',
	name = 'factoryguard',
	cursor = 'cursornormal',
	action = 'factoryguard',
	params = { 0, "factoryguard", "factoryguard" }, -- named like this for translation - 0 is off, 1 is on
}


local isFactory = {}
local isAssistBuilder = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		local buildOptions = unitDef.buildOptions

		for i = 1, #buildOptions do
			local buildOptDefID = buildOptions[i]
			local buildOpt = UnitDefs[buildOptDefID]

			if (buildOpt and buildOpt.isBuilder and buildOpt.canAssist) then
				isFactory[unitDefID] = true  -- only factories that can build builders are included
				break
			end
		end
	end
	if unitDef.isBuilder and unitDef.canAssist then
		isAssistBuilder[unitDefID] = true
	end
end


local function setFactoryGuardState(unitID, state)
	local cmdDescID = spFindUnitCmdDesc(unitID, CMD_FACTORY_GUARD)
	if cmdDescID then
		factoryGuardCmdDesc.params[1] = state
		spEditUnitCmdDesc(unitID, cmdDescID, {params = factoryGuardCmdDesc.params})
	end
end


function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	--accepts: CMD_FACTORY_GUARD
	if isFactory[unitDefID] then
		setFactoryGuardState(unitID, cmdParams[1])
		return false  -- command was used
	end
	return true  -- command was not used
end


--------------------------------------------------------------------------------
-- Guard Command Handling

local function GuardFactory(unitID, unitDefID, factID, factDefID)

	if not isFactory[factDefID] then
		-- is this a factory?
		return
	end
	if not isAssistBuilder[unitDefID] then
		-- can this unit assist?
		return
	end

	local x, y, z = spGetUnitPosition(factID)
	if (not x) then
		return
	end

	local radius = spGetUnitRadius(factID)
	if (not radius) then
		return
	end
	local dist = radius * 2

	local facing = spGetUnitBuildFacing(factID)
	if (not facing) then
		return
	end

	-- facing values { S = 0, E = 1, N = 2, W = 3 }
	local dx, dz -- down vector
	local rx, rz -- right vector
	if (facing == 0) then
		dx, dz = 0, dist
		rx, rz = dist, 0
	elseif (facing == 1) then
		dx, dz = dist, 0
		rx, rz = 0, -dist
	elseif (facing == 2) then
		dx, dz = 0, -dist
		rx, rz = -dist, 0
	else
		dx, dz = -dist, 0
		rx, rz = 0, dist
	end

	local OrderUnit = spGiveOrderToUnit

	OrderUnit(unitID, CMD_MOVE, { x + dx, y, z + dz }, { "" })
	if Spring.TestMoveOrder(unitDefID, x + dx + rx, y, z + dz + rz) then
		OrderUnit(unitID, CMD_MOVE, { x + dx + rx, y, z + dz + rz }, { "shift" })
		if Spring.TestMoveOrder(unitDefID, x + rx, y, z + rz) then
			OrderUnit(unitID, CMD_MOVE, { x + rx, y, z + rz }, { "shift" })
		end
	elseif Spring.TestMoveOrder(unitDefID, x + dx - rx, y, z + dz - rz) then
		OrderUnit(unitID, CMD_MOVE, { x + dx - rx, y, z + dz - rz }, { "shift" })
		if Spring.TestMoveOrder(unitDefID, x - rx, y, z - rz) then
			OrderUnit(unitID, CMD_MOVE, { x - rx, y, z - rz }, { "shift" })
		end
	end
	OrderUnit(unitID, CMD_GUARD, { factID }, { "shift" })
end


function gadget:UnitFromFactory(unitID, unitDefID, unitTeam,
								factID, factDefID, userOrders)
	if (userOrders) then
		return -- already has user assigned orders
	end

	local factoryGuardCmdDescID = Spring.FindUnitCmdDesc(factID, CMD_FACTORY_GUARD) -- get CmdDescID
	local cmdDesc = Spring.GetUnitCmdDescs(factID, factoryGuardCmdDescID)[1] -- use CmdDescID to get state of that cmd (comes back as a table, we get the first element)
	local factoryGuardEnabled = cmdDesc.params[1] == "1"
	if not cmdDesc or not factoryGuardEnabled then -- if state is missing or false, do nothing
		return
	end

	GuardFactory(unitID, unitDefID, factID, factDefID)
end


--------------------------------------------------------------------------------
-- Unit Handling

function gadget:UnitCreated(unitID, unitDefID, _)
	if isFactory[unitDefID] then
		factoryGuardCmdDesc.params[1] = 0
		spInsertUnitCmdDesc(unitID, factoryGuardCmdDesc)
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_FACTORY_GUARD)
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID))
	end
end
--------------------------------------------------------------------------------
