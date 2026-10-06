local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Sensor Suspend",
		desc = "Pauses the sensors of units whose energy upkeep goes unpaid, and of jammers for deactivate_time after a hit, without switching them off",
		author = "Floris",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- The engine keeps a unit's sensors on while it can't pay its upkeep, and switching it off would flip the player's
-- on/off button, so a pause zeroes the sensor radii and puts them back afterwards. Stunned units lose their sensors
-- in the engine already. The jammer unit scripts only animate the hit pause.

local CHECK_INTERVAL = 15 -- frames, the engine's unit slow update: each unit pays half its upkeep once per interval
local SETTLE_FRAMES = 4 * CHECK_INTERVAL -- after being switched off, stunned or built: until two payments are recorded

-- engines with the sensors.requireUpkeep modrule pause unpaid sensors themselves
local engineRequiresUpkeep = Game.sensorsRequireUpkeep == true

local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitResources = Spring.GetUnitResources
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spSetUnitSensorRadius = Spring.SetUnitSensorRadius
local spIsNoCostEnabled = Spring.IsNoCostEnabled
local spGetGameFrame = Spring.GetGameFrame

-- unit def sensor range key per switchable sensor (los and air los keep working while a unit is off)
local sensorKeys = {
	radar = "radarDistance",
	sonar = "sonarDistance",
	seismic = "seismicDistance",
	radarJammer = "radarDistanceJam",
	sonarJammer = "sonarDistanceJam",
}

-- unitDefID -> upkeep (energy per second), hit pause (frames, jammers only) and switchable sensors
local suspendDefs = {} ---@type table<number, table?>
for unitDefID, unitDef in pairs(UnitDefs) do
	local sensors = {}
	for sensor, key in pairs(sensorKeys) do
		if (unitDef[key] or 0) > 0 then
			sensors[#sensors + 1] = sensor
		end
	end
	local upkeep = engineRequiresUpkeep and 0 or math.max(unitDef.energyUpkeep or 0, 0)
	local hitFrames = 0
	if (unitDef.radarDistanceJam or 0) > 0 or (unitDef.sonarDistanceJam or 0) > 0 then
		hitFrames = math.floor((tonumber(unitDef.customParams.deactivate_time) or 0) * Game.gameSpeed + 0.5)
	end
	if #sensors > 0 and (upkeep > 0 or hitFrames > 0) then
		suspendDefs[unitDefID] = { upkeep = upkeep, hitFrames = hitFrames, sensors = sensors }
	end
end
if not next(suspendDefs) then
	return false
end

-- unitID -> { def, hitUntil = frame, unpowered = bool, settleFrame = frame, radii = { sensor -> radius while paused } }
local units = {} ---@type table<UnitID, table>
local nextHitEnd = math.huge

-- Zeroes the sensors while paused (after a hit or with the upkeep unpaid), restores them afterwards
local function apply(unitID, unit, frame)
	local paused = frame < unit.hitUntil or unit.unpowered
	for _, sensor in ipairs(unit.def.sensors) do
		if paused then
			local radius = spGetUnitSensorRadius(unitID, sensor)
			if radius > 0 then -- also takes over a radius set by something else meanwhile
				unit.radii[sensor] = radius
				spSetUnitSensorRadius(unitID, sensor, 0)
			end
		elseif unit.radii[sensor] then
			spSetUnitSensorRadius(unitID, sensor, unit.radii[sensor])
			unit.radii[sensor] = nil
		end
	end
end

-- Unpaid when the unit's energy use (its last two half-second payments) falls short of its upkeep
local function checkPower(unitID, unit, frame)
	if spGetUnitIsStunned(unitID) or not spGetUnitIsActive(unitID) then
		unit.settleFrame = frame + SETTLE_FRAMES -- no upkeep is charged meanwhile
	elseif frame >= unit.settleFrame then
		local _, _, _, energyUse = spGetUnitResources(unitID)
		unit.unpowered = (energyUse or 0) < unit.def.upkeep * 0.99 and not spIsNoCostEnabled()
	end
end

local function addUnit(unitID, unitDefID)
	local def = suspendDefs[unitDefID]
	if def then
		units[unitID] = {
			def = def,
			hitUntil = -1,
			unpowered = false,
			settleFrame = spGetGameFrame() + SETTLE_FRAMES,
			radii = {},
		}
	end
end

function gadget:UnitFinished(unitID, unitDefID)
	addUnit(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID)
	units[unitID] = nil
end

function gadget:UnitDamaged(unitID)
	local unit = units[unitID]
	if unit and unit.def.hitFrames > 0 then
		local frame = spGetGameFrame()
		unit.hitUntil = frame + unit.def.hitFrames
		nextHitEnd = math.min(nextHitEnd, unit.hitUntil)
		apply(unitID, unit, frame)
	end
end

function gadget:GameFrame(frame)
	if frame >= nextHitEnd then
		nextHitEnd = math.huge
		for unitID, unit in pairs(units) do
			if unit.hitUntil > frame then
				nextHitEnd = math.min(nextHitEnd, unit.hitUntil)
			else
				apply(unitID, unit, frame)
			end
		end
	end
	if frame % CHECK_INTERVAL == 0 then
		for unitID, unit in pairs(units) do
			if unit.def.upkeep > 0 then
				local wasUnpowered = unit.unpowered
				checkPower(unitID, unit, frame)
				if unit.unpowered or wasUnpowered then
					apply(unitID, unit, frame)
				end
			end
		end
	end
end

function gadget:Initialize()
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		if not Spring.GetUnitIsBeingBuilt(unitID) then
			addUnit(unitID, Spring.GetUnitDefID(unitID))
		end
	end
end

function gadget:Shutdown()
	for unitID, unit in pairs(units) do
		for sensor, radius in pairs(unit.radii) do
			spSetUnitSensorRadius(unitID, sensor, radius)
		end
	end
end
