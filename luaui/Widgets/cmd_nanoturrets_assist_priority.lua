local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Priority Construction Turrets",
		desc = "When a new turret is started, local turrets on patrol will target it",
		author = "Phinks",
		date = "2023-05-05",
		layer = 0,
		enabled = true,
	}
end

local GetUnitPosition = Spring.GetUnitPosition
local GetUnitsInSphere = Spring.GetUnitsInSphere
local GetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitDefID = Spring.GetUnitDefID
local GetUnitBuildeeRadius = Spring.GetUnitBuildeeRadius

local CMD_REPAIR = CMD.REPAIR
local CMD_FIGHT = CMD.FIGHT
local CMD_INSERT = CMD.INSERT

local myTeam = Spring.GetLocalTeamID()

local nanoDefs = {}
local buildDistanceMax = 0
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isBuilder and unitDef.isImmobile and not unitDef.isFactory then
		nanoDefs[unitDefID] = unitDef.buildDistance
		buildDistanceMax = math.max(buildDistanceMax, unitDef.buildDistance)
	end
end

local insertParams = { 0, CMD_REPAIR, 0, 0 }
local insertOptions = CMD.OPT_ALT

local function shouldAssist(builderID, x, y, z, buildeeRadius)
	local buildDistance = nanoDefs[GetUnitDefID(builderID)]
	if buildDistance == nil then
		return
	end
	local builderX, builderY, builderZ = GetUnitPosition(builderID)
	local dx, dy, dz = builderX - x, builderY - y, builderZ - z
	local range = buildDistance + buildeeRadius
	return dx * dx + dy * dy + dz * dz <= range * range
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if unitTeam ~= myTeam or nanoDefs[unitDefID] == nil then
		return
	end

	local x, y, z = GetUnitPosition(unitID)
	local buildeeRadius = GetUnitBuildeeRadius(unitID)
	if not buildeeRadius then
		return
	end

	insertParams[4] = unitID

	for _, allyID in ipairs(GetUnitsInSphere(x, y, z, buildDistanceMax + buildeeRadius, -3)) do
		if allyID ~= unitID and shouldAssist(allyID, x, y, z, buildeeRadius) then
			local inCommand = GetUnitCurrentCommand(allyID, 1)
			if inCommand == nil or inCommand == CMD_FIGHT or GetUnitCurrentCommand(allyID, 2) == CMD_FIGHT then
				GiveOrderToUnit(allyID, CMD_INSERT, insertParams, insertOptions)
			end
		end
	end
end
