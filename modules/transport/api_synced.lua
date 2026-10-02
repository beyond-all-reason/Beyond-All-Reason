-- Transport's api in the synced handle: what the gadget asks of the module that touches the synced engine. The
-- verdicts come from the neutral api; what follows a verdict — a carrier halting to load, what a passenger becomes
-- aboard and when set down, a nano turret nudged off an ally — is done here: the domain's rules first, the engine after.
local CMD = CMD
local GG = GG
local Game = Game
local Spring = Spring
local UnitDefs = UnitDefs

local Api = require("modules/transport/api")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Rules = require("modules/transport/lib/rules")
local state = require("modules/transport/state")

-- Stealth is a sourced attribute (GG.UnitAttributes): this is the source the carrier's stealth is set under, so no
-- other gadget's stealth is touched when the passenger leaves.
local STEALTH_SOURCE = "stealthy_passengers"
local Synced = {}

local Traits = require("modules/transport/lib/traits")

local MAP_SIZE_X, MAP_SIZE_Z = Game.mapSizeX, Game.mapSizeZ

local WAKE_MARGIN = 32
local wakeRadius = nil ---@type number|nil memoized: the widest nano search radius plus the margin

---@return number
local function getWakeRadius()
	if wakeRadius == nil then
		wakeRadius = WAKE_MARGIN
		for unitDefID, def in pairs(UnitDefs) do
			if def.customParams.isnanoturret then
				wakeRadius = math.max(wakeRadius, Traits.Of(unitDefID).unstackRadius + WAKE_MARGIN)
			end
		end
	end
	return wakeRadius
end

---@class TransportUnstack
local Unstack = {}
Synced.Unstack = Unstack

---@param unitID integer
---@return table<integer, integer> turrets nano turret -> its def
local function turretsUnder(unitID)
	local turrets = {}
	local x, _, z = Spring.GetUnitPosition(unitID)
	if x == nil then
		return turrets
	end
	for _, other in ipairs(Spring.GetUnitsInCylinder(x, z, getWakeRadius())) do
		local otherDefID = Spring.GetUnitDefID(other)
		if Traits.Of(otherDefID).isNano then
			turrets[other] = otherDefID
		end
	end
	return turrets
end

---@param unstacking table<integer, integer> nano turret -> its def
---@param unitID integer
function Unstack.Wake(unstacking, unitID)
	for turretID, turretDefID in pairs(turretsUnder(unitID)) do
		unstacking[turretID] = turretDefID
	end
end

---@param unitID integer
---@param unitDefID integer
---@return boolean done
function Unstack.Step(unitID, unitDefID)
	local traits = Traits.Of(unitDefID)
	local radius = traits.unstackRadius
	local x, _, z = Spring.GetUnitPosition(unitID)
	local allyTeam = Spring.GetUnitAllyTeam(unitID)
	local ax, az, nearestSq = nil, nil, radius * radius + 1
	for _, other in ipairs(Spring.GetUnitsInCylinder(x, z, radius)) do
		if
			other ~= unitID
			and Spring.GetUnitAllyTeam(other) == allyTeam
			and not Traits.Of(Spring.GetUnitDefID(other)).canMove
		then
			local ox, _, oz = Spring.GetUnitPosition(other)
			local ddx, ddz = ox - x, oz - z
			local distSq = ddx * ddx + ddz * ddz
			if distSq < nearestSq then
				ax, az, nearestSq = ox, oz, distSq
			end
		end
	end
	if ax == nil then
		return true
	end
	if Spring.GetUnitTransporter(unitID) then
		return false
	end
	local r = math.random(1, 3)
	local dx, dz = 0, 0
	if r == 1 then
		if x == ax or z == az then
			local testRange = radius * 2
			dx = math.random(-testRange, testRange)
			dz = math.random(-testRange, testRange)
		end
	elseif r == 2 then
		if x > ax then
			dx = math.random(1, 10)
		elseif x < ax then
			dx = -math.random(1, 10)
		end
	else
		if z > az then
			dz = math.random(1, 10)
		elseif z < az then
			dz = -math.random(1, 10)
		end
	end
	if dx == 0 and dz == 0 then
		return false
	end
	local tx, tz = x + dx, z + dz
	if tx < 0 or tx > MAP_SIZE_X or tz < 0 or tz > MAP_SIZE_Z then
		return false
	end
	local y = Spring.GetGroundHeight(tx, tz)
	if -traits.minWaterDepth > y and -traits.maxWaterDepth < y then
		Spring.SetUnitPosition(unitID, tx, tz)
	end
	return false
end

-- An air transport stops dead to load or set down.
---@param carrierID integer
function Synced.Halt(carrierID)
	Spring.SetUnitVelocity(carrierID, 0, 0, 0)
end

---@param unitID integer
---@param goalX number
---@param goalY number
---@param goalZ number
---@return number
local function distanceToGoal(unitID, goalX, goalY, goalZ)
	local x, y, z = Spring.GetUnitPosition(unitID)
	local dx, dy, dz = x - goalX, y - goalY, z - goalZ
	return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- May the carrier load the passenger at the goal it is arriving at; a carrier with reach halts to take it.
---@param carrierID integer
---@param carrierDefID integer
---@param passengerID integer
---@param passengerDefID integer
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean
function Synced.MayLoad(carrierID, carrierDefID, passengerID, passengerDefID, goalX, goalY, goalZ)
	---@type TransportContract
	local Transport = ModuleHandler.Contract(Modules.Transport)
	local reach = Traits.Of(carrierDefID).reach
	local allowed = ModuleHandler.Evaluate(Transport.Load, {
		carrierDef = UnitDefs[carrierDefID],
		passengerDef = UnitDefs[passengerDefID],
		goalY = goalY,
		height = Spring.GetUnitHeight(passengerID),
		reach = reach,
		distance = reach and distanceToGoal(carrierID, goalX, goalY, goalZ) or 0,
		allied = Spring.AreTeamsAllied(Spring.GetUnitTeam(carrierID), Spring.GetUnitTeam(passengerID)),
		passengerSpeed = select(4, Spring.GetUnitVelocity(passengerID)),
	}) == true
	if allowed and reach then
		Synced.Halt(carrierID)
	end
	return allowed
end

-- May the carrier set the passenger down at the goal; a carrier with reach halts to do it.
---@param carrierID integer
---@param carrierDefID integer
---@param passengerID integer
---@param goalX number
---@param goalY number
---@param goalZ number
---@return boolean
function Synced.MayUnload(carrierID, carrierDefID, passengerID, goalX, goalY, goalZ)
	---@type TransportContract
	local Transport = ModuleHandler.Contract(Modules.Transport)
	local reach = Traits.Of(carrierDefID).reach
	local allowed = ModuleHandler.Evaluate(Transport.Unload, {
		goalY = goalY,
		height = Spring.GetUnitHeight(passengerID),
		reach = reach,
		distance = reach and distanceToGoal(carrierID, goalX, goalY, goalZ) or 0,
	}) == true
	if allowed and reach then
		Synced.Halt(carrierID)
	end
	return allowed
end

-- A passenger came aboard: a flying carrier's loaded speed is recorded, a stealthy carrier hides the passenger, and a
-- passenger that leaves a ghost leaves none while carried.
---@param unitID integer the passenger
---@param unitDefID integer
---@param transportID integer the carrier
function Synced.Loaded(unitID, unitDefID, transportID)
	local carrier = Traits.OfUnit(transportID)
	if carrier == nil then
		return
	end
	local passenger = Traits.Of(unitDefID)
	if carrier.canFly then
		local speed = Api.LoadedSpeed(transportID)
		if speed ~= nil then
			state.loadedSpeed[transportID] = speed
		end
	end
	if carrier.stealthsPassengers and not passenger.isStealthy then
		GG.UnitAttributes.SetUnitAttribute(unitID, "stealth", true, STEALTH_SOURCE)
	end
	if passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(unitID, false, true)
	end
end

-- A passenger was set down: the carrier's speed is what it still carries, the passenger is seen and ghosts again, an
-- immobile one wakes the nano turrets it landed on, a paratrooper keeps a clamped fall, and anything else is pinned
-- where it landed for a few frames so it does not slide.
---@param unitID integer the passenger
---@param unitDefID integer
---@param transportID integer the carrier
function Synced.Unloaded(unitID, unitDefID, transportID)
	local carrier = Traits.OfUnit(transportID)
	if carrier == nil then
		return
	end
	local passenger = Traits.Of(unitDefID)
	if carrier.canFly then
		state.loadedSpeed[transportID] = Api.LoadedSpeed(transportID) or nil
	end
	if carrier.stealthsPassengers and not passenger.isStealthy then
		GG.UnitAttributes.SetUnitAttribute(unitID, "stealth", nil, STEALTH_SOURCE)
	end
	if passenger.leavesGhost then
		Spring.SetUnitLeavesGhost(unitID, true)
	end
	if not passenger.canMove then
		Unstack.Wake(state.unstacking, unitID)
	end
	if passenger.isParatrooper then
		local vx, vy, vz = Spring.GetUnitVelocity(transportID)
		vx, vz = Rules.ClampParatrooperVelocity(vx), Rules.ClampParatrooperVelocity(vz)
		local x, y, z = Spring.GetUnitPosition(unitID)
		if y - Spring.GetGroundHeight(x, z) < Rules.PARATROOPER_GROUND_MARGIN then
			vx, vy, vz = 0, 0, 0
		end
		Spring.SetUnitVelocity(unitID, vx, vy, vz)
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	local px, py, pz = Spring.GetUnitPosition(unitID)
	local dx, dy, dz, rx, ry, rz = Spring.GetUnitDirection(unitID)
	state.settling[unitID] = {
		px = px,
		py = py,
		pz = pz,
		dx = dx,
		dy = dy,
		dz = dz,
		rx = rx,
		ry = ry,
		rz = rz,
		frame = Spring.GetGameFrame() + Rules.UNLOAD_SETTLE_FRAMES,
	}
	Spring.SetUnitVelocity(unitID, 0, 0, 0)

	if not Spring.GetUnitRulesParam(unitID, "unit_effigy") then
		state.maybeDead[unitID] = transportID
	end
end

return Synced
