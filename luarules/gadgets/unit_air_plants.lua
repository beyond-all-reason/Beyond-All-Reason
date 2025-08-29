local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "AirPlantParents",
		desc = "Adds options to air plants, makes building aircraft neutral",
		author = "TheFatController",
		date = "15 Dec 2008",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

-- `unit_airunitsturnradius.lua` sets an arbitrary attack radius
-- which influences how air units pursue and satisfy move goals.
local bomberAttackTurnRadius = 500 ---@type number
-- Move goals issued don't represent real tasks so can be loose.
local moveGoalLeashRadius = 4 * Game.squareSize ---@type number

local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local GiveOrderToUnit = Spring.GiveOrderToUnit
local SetUnitNeutral = Spring.SetUnitNeutral

local CMD_AUTOREPAIRLEVEL = CMD.AUTOREPAIRLEVEL
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_LAND_AT = GameCMD.LAND_AT
local CMD_AIR_REPAIR = GameCMD.AIR_REPAIR

local isAirplant = {}
local unitMoveRadius = {} -- largest of the radii to avoid dipping or clashing
local factoryMoveRadius = {} -- consistent minimum spread across factory units

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory and unitDef.buildOptions[1] then
		local airOptionOnly = true
		local unitRadiusMax = 0
		for _, optionID in ipairs(unitDef.buildOptions) do
			local option = UnitDefs[optionID]
			if option.isAirUnit then
				unitRadiusMax = math.max(option.radius, unitRadiusMax)
			else
				airOptionOnly = false
				break
			end
		end
		if airOptionOnly then
			isAirplant[unitDefID] = true
			factoryMoveRadius[unitDefID] = unitDef.radius + unitRadiusMax + moveGoalLeashRadius
		end
	end
	if unitDef.isAirUnit and unitDef.canMove then
		-- Dipping is tied to turn radius, clashing approximately to unit radius.
		unitMoveRadius[unitDefID] = math.max(unitDef.turnRadius, unitDef.radius)
	end
end

local plantList = {}
local buildingUnits = {}

local landCmd = {
	id = CMD_LAND_AT,
	name = "apLandAt",
	action = "apLandAt",
	type = CMDTYPE.ICON_MODE,
	tooltip = "setting for Aircraft leaving the plant",
	params = { '1', ' Fly ', 'Land' }
}

local airCmd = {
	id = CMD_AIR_REPAIR,
	name = "apAirRepair",
	action = "apAirRepair",
	type = CMDTYPE.ICON_MODE,
	tooltip = "return to base and land on air repair pad below this health percentage",
	params = { '1', 'LandAt 0', 'LandAt 30', 'LandAt 50', 'LandAt 80' }
}

-- Fallback method to make sure units don't land atop their origin plant.
local function moveFromPlant(unitID, radius)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local theta = math.random() * math.tau
	local tx = ux + radius * math.sin(theta)
	local tz = uz + radius * math.cos(theta)
	local ty = Spring.GetGroundHeight(tx, tz)
	GiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.MOVE, 0, tx, ty, tz }, 0)
end

-- Prevent air units from relaxing their target height when leaving the plant.
local function moveToCommand(unitID, command, factoryRadius)
	-- Within a short distance, air units do not dip when leaving the plant.
	-- Generally consider the turnRadius as though it were a dynamic value:
	local distanceMin = Spring.GetUnitMoveTypeData(unitID).turnRadius or 0
	if distanceMin == 0 or distanceMin == bomberAttackTurnRadius then
		distanceMin = unitMoveRadius[Spring.GetUnitDefID(unitID)]
	end
	distanceMin = math.max(distanceMin, factoryRadius)

	local tx, ty, tz
	if command then
		if #command.params == 1 then
			if command.params[1] > Game.maxUnits then
				tx, ty, tz = Spring.GetFeaturePosition(command.params[1])
			else
				tx, ty, tz = Spring.GetUnitPosition(command.params[1])
			end
		elseif #command.params >= 3 then
			tx, tz = command.params[1], command.params[3]
		end
	end

	if not tx then
		moveFromPlant(unitID, distanceMin)
		return
	end

	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local dx = tx - ux
	local dz = tz - uz
	local distanceXZ = math.diag(dx, dz)

	if distanceXZ > distanceMin then
		-- Nudge the unit toward its command without sending it too far.
		local scale = distanceMin / distanceXZ
		tx = ux + dx * scale
		tz = uz + dz * scale
		Spring.SetUnitMoveGoal(unitID, tx, uy, tz, moveGoalLeashRadius)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isAirplant[unitDefID] then
		InsertUnitCmdDesc(unitID, 500, landCmd)
		InsertUnitCmdDesc(unitID, 500, airCmd)
		plantList[unitID] = { landAt = 1, repairAt = 1 }
	elseif plantList[builderID] then
		GiveOrderToUnit(unitID, CMD_AUTOREPAIRLEVEL, { plantList[builderID].repairAt }, 0)
		GiveOrderToUnit(unitID, CMD_IDLEMODE, {plantList[builderID].landAt}, 0)
		SetUnitNeutral(unitID, true)
		buildingUnits[unitID] = factoryMoveRadius[builderID]
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	plantList[unitID] = nil
	buildingUnits[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildingUnits[unitID] then
		SetUnitNeutral(unitID, false)
		local commands = Spring.GetUnitCommands(unitID, 1)
		if commands ~= nil then
			moveToCommand(unitID, commands[1], buildingUnits[unitID])
		end
		buildingUnits[unitID] = nil
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LAND_AT)
	gadgetHandler:RegisterAllowCommand(CMD_AIR_REPAIR)

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		-- Prevent nil access error in UnitCreated by passing an invalid builderID
		---@diagnostic disable-next-line: param-type-mismatch -- and ignore unitTeam
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), nil, -1)
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if isAirplant[unitDefID] and plantList[unitID] then
		if cmdID == CMD_LAND_AT then
			local cmdDescID = FindUnitCmdDesc(unitID, CMD_LAND_AT)
			landCmd.params[1] = cmdParams[1]
			EditUnitCmdDesc(unitID, cmdDescID, landCmd)
			plantList[unitID].landAt = cmdParams[1]
			landCmd.params[1] = 1
		else -- CMD_AIR_REPAIR
			local cmdDescID = FindUnitCmdDesc(unitID, CMD_AIR_REPAIR)
			airCmd.params[1] = cmdParams[1]
			EditUnitCmdDesc(unitID, cmdDescID, airCmd)
			plantList[unitID].repairAt = cmdParams[1]
			airCmd.params[1] = 1
		end
		return false
	end
	return true
end
