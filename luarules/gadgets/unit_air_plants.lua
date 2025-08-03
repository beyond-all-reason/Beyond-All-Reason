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

local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local FindUnitCmdDesc = Spring.FindUnitCmdDesc
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc
local GiveOrderToUnit = Spring.GiveOrderToUnit
local SetUnitNeutral = Spring.SetUnitNeutral
local CMD_AUTOREPAIRLEVEL = CMD.AUTOREPAIRLEVEL
local CMD_IDLEMODE = CMD.IDLEMODE
local CMD_LAND_AT = GameCMD.LAND_AT
local CMD_AIR_REPAIR = GameCMD.AIR_REPAIR

local isAirplantNames = {
	corap = true,
	coraap = true,
	corplat = true,
	corapt3 = true,

	armap = true,
	armaap = true,
	armplat = true,
	armapt3 = true,

	legap = true,
	legaap = true,
	legapt3 = true,
}
local isAirplantNamesCopy = table.copy(isAirplantNames)
for name,v in pairs(isAirplantNamesCopy) do
	isAirplantNames[name..'_scav'] = true
end
-- convert unitname -> unitDefID
local isAirplant = {}
for unitName, params in pairs(isAirplantNames) do
	if UnitDefNames[unitName] then
		isAirplant[UnitDefNames[unitName].id] = params
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

local function moveFromPlant(unitID, factoryRadius)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local theta = math.random() * 2 * math.pi
	local radius = 2.5 * factoryRadius
	local tx, tz = ux + radius * math.sin(theta), uz + radius * math.cos(theta)
	local ty = Spring.GetGroundHeight(tx, tz)
	GiveOrderToUnit(unitID, CMD.INSERT, { 0, CMD.MOVE, 0, tx, ty, tz }, 0)
end

local function moveToCommand(unitID, command, factoryRadius)
	local tx, ty, tz
	if command then
		if #command.params == 1 then
			if command.params[1] > Game.maxUnits then
				tx, ty, tz = Spring.GetFeaturePosition(command.params[1])
			else
				tx, ty, tz = Spring.GetUnitPosition(command.params[1])
			end
		elseif #command.params >= 3 then
			tx, ty, tz = command.params[1], command.params[2], command.params[3]
		end
	end

	if not tx then
		moveFromPlant(unitID, factoryRadius)
		return
	end

	-- Within a certain distance, air units do not dip when leaving the plant.
	-- The actual rules for air move types are a bit elaborate; this is close:
	local distanceMin = Spring.GetUnitMoveTypeData(unitID).turnRadius
	if not distanceMin then
		distanceMin = UnitDefs[Spring.GetUnitDefID(unitID)].turnRadius or 200
	end
	distanceMin = math.max(distanceMin, factoryRadius) -- Maybe plus padding.

	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	local dx = tx - ux
	local dy = ty - uy
	local dz = tz - uz
	local distanceSq = dx * dx + dy * dy + dz * dz

	if distanceSq > distanceMin * distanceMin then
		-- Nudge the unit toward its command, but not too far away.
		local scale = math.sqrt(distanceMin * distanceMin / distanceSq)
		tx = ux + dx * scale
		ty = uy + dy * scale
		tz = uz + dz * scale
		Spring.SetUnitMoveGoal(unitID, tx, ty, tz, Game.squareSize)
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
		buildingUnits[unitID] = math.max(Spring.GetUnitRadius(builderID) or 0, 120)
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
		gadget:UnitCreated(unitID, Spring.GetUnitDefID(unitID), -1, -1)
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
