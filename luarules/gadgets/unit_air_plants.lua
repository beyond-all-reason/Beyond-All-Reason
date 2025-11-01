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
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_LAND_AT = GameCMD.LAND_AT

local isAirplant = {}
local airUnitMoveRadius = {} -- largest of the radii to avoid dipping or clashing
local factoryMoveRadius = {} -- consistent minimum spread across factory units

for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isFactory and unitDef.buildOptions[1] then
		local airOptionOnly = true
		local unitRadiusMax = 0
		for _, optionID in ipairs(unitDef.buildOptions) do
			local option = UnitDefs[optionID]
			if option.isAirUnit then
				unitRadiusMax = math.max(option.radius, unitRadiusMax)
				airUnitMoveRadius[optionID] = math.max(option.turnRadius, option.radius)
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
end

local plantList = {}
local buildingUnits = {}
local waterLevel = Spring.GetWaterPlaneLevel()

local landCmd = {
	id = CMD_LAND_AT,
	name = "apLandAt",
	action = "apLandAt",
	type = CMDTYPE.ICON_MODE,
	tooltip = "setting for Aircraft leaving the plant",
	params = { '1', ' Fly ', 'Land' }
}

local function createAirPlant(unitID)
	InsertUnitCmdDesc(unitID, 500, landCmd)
	landCmd.params[1] = 1
	plantList[unitID] = 1
end

local function createAirUnit(unitID, builderID)
	SetUnitNeutral(unitID, true)
	buildingUnits[unitID] = builderID or true
	if builderID ~= nil then
		GiveOrderToUnit(unitID, CMD_IDLEMODE, plantList[builderID], 0)
	end
end

local function getCommandPosition(command)
	local tx, ty, tz
	if command then
		if #command.params == 1 then
			if command.params[1] > Game.maxUnits then
				tx, ty, tz = Spring.GetFeaturePosition(command.params[1] - Game.maxUnits)
			else
				tx, ty, tz = Spring.GetUnitPosition(command.params[1])
			end
		elseif #command.params >= 3 then
			tx, tz = command.params[1], command.params[3]
		end
	end
	return tx, ty, tz
end

-- Nudge the unit toward its command without sending it too far.
local function moveToCommand(unitID, tx, tz, radiusMin)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local dx = tx - ux
	local dz = tz - uz
	local radiusXZ = math.diag(dx, dz)
	if radiusXZ <= moveGoalLeashRadius or radiusXZ > radiusMin then
		local scale = radiusMin / radiusXZ
		tx = ux + dx * scale
		tz = uz + dz * scale
	end
	local ty = math.max(Spring.GetGroundHeight(tx, tz), waterLevel)
	Spring.SetUnitMoveGoal(unitID, tx, ty, tz, moveGoalLeashRadius)
end

-- Fallback method to make sure units don't land atop their origin plant.
local function moveFromPlant(unitID, radius)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local theta = math.random() * math.tau
	local tx = ux + radius * math.sin(theta)
	local tz = uz + radius * math.cos(theta)
	local ty = math.max(Spring.GetGroundHeight(tx, tz), waterLevel)
	Spring.SetUnitMoveGoal(unitID, tx, ty, tz, moveGoalLeashRadius)
end

-- Prevent air units from relaxing their target height when leaving the plant.
local function launchAirUnit(unitID, builderID)
	-- Within a short distance, air units do not dip when leaving the plant.
	-- Generally consider the turnRadius as though it were a dynamic value:
	local distanceMin = Spring.GetUnitMoveTypeData(unitID).turnRadius or 0
	if distanceMin == 0 or distanceMin == bomberAttackTurnRadius then
		distanceMin = airUnitMoveRadius[Spring.GetUnitDefID(unitID)]
	end
	distanceMin = math.max(distanceMin, factoryMoveRadius[builderID] or 0)

	local command = Spring.GetUnitCommands(unitID, 1)
	local tx, ty, tz = getCommandPosition(command)

	if tx and tz then
		moveToCommand(unitID, tx, tz, distanceMin)
	else
		moveFromPlant(unitID, distanceMin)
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if isAirplant[unitDefID] then
		createAirPlant(unitID)
	elseif plantList[builderID] then
		createAirUnit(unitID, builderID)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
	plantList[unitID] = nil
	buildingUnits[unitID] = nil
end

function gadget:UnitFinished(unitID, unitDefID, unitTeam)
	if buildingUnits[unitID] then
		SetUnitNeutral(unitID, false)
		launchAirUnit(unitID, buildingUnits[unitID])
		buildingUnits[unitID] = nil
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_LAND_AT)

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		if isAirplant[unitDefID] then
			createAirPlant(unitID)
		elseif UnitDefs[unitDefID].isAirUnit and Spring.GetUnitIsBeingBuilt(unitID) then
			createAirUnit(unitID)
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if isAirplant[unitDefID] and plantList[unitID] then
		local cmdDescID = FindUnitCmdDesc(unitID, CMD_LAND_AT)
		landCmd.params[1] = cmdParams[1]
		EditUnitCmdDesc(unitID, cmdDescID, landCmd)
		plantList[unitID] = cmdParams[1]
		return false
	end
	return true
end
