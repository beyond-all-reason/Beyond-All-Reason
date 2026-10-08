-- Transport's api in the synced handle: what the gadget asks of the module that touches the synced engine. The
-- verdicts come from the neutral api; what follows a verdict — a carrier halting to load, what a passenger becomes
-- aboard and when set down, a nano turret nudged off an ally — is done here: the domain's rules first, the engine after.
local CMD = CMD
local GG = GG
local Game = Game
local Spring = Spring --[[@as Recoil.Synced]]
local UnitDefs = UnitDefs

local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local Rules = require("modules/transport/lib/rules")
local state = require("modules/transport/state")

-- Stealth is a sourced attribute (GG.UnitAttributes): this is the source the carrier's stealth is set under, so no
-- other gadget's stealth is touched when the passenger leaves.
local STEALTH_SOURCE = "stealthy_passengers"
local Synced = {}

local Traits = require("modules/transport/lib/traits")

---@param unitID integer a unit that exists
---@return number x
---@return number y
---@return number z
local function positionOf(unitID)
	local x, y, z = Spring.GetUnitPosition(unitID)
	---@cast x number
	---@cast y number
	---@cast z number
	return x, y, z
end

local MAP_SIZE_X, MAP_SIZE_Z = Game.mapSizeX, Game.mapSizeZ

-- Structures a builder placed passed the engine's build test, which knows yardmaps (open corners, stackable mex and
-- geo cells), so any overlap they have is legal. Only placements that skip that test can stack: a transport's unload,
-- checked against model radius rather than footprint, and a unit Lua spawned without a builder. Those wake the nano
-- turrets around them, and a woken turret is pushed off the structure it overlaps most, every frame until clear.
local OVERLAP_TOLERANCE = 16 -- elmos per axis: legal overlaps through open yardmap cells stay within one footprint cell
local MIDPOS_MARGIN = 32 -- area queries test midPos, which can sit off the footprint center
local MAX_PUSHES = 16 -- give up on a turret that keeps landing on other structures

local widestHalf = nil ---@type number|nil memoized: the widest immobile footprint half, over every def
local widestTurretHalf = nil ---@type number|nil memoized: the widest nano turret footprint half

---@return number widestHalf
---@return number widestTurretHalf
local function widestHalves()
	if widestHalf == nil or widestTurretHalf == nil then
		widestHalf, widestTurretHalf = 0, 0
		for unitDefID in pairs(UnitDefs) do
			local traits = Traits.Of(unitDefID)
			if not traits.canMove then
				widestHalf = math.max(widestHalf, traits.halfX, traits.halfZ)
				if traits.isNano then
					widestTurretHalf = math.max(widestTurretHalf, traits.halfX, traits.halfZ)
				end
			end
		end
	end
	return widestHalf, widestTurretHalf
end

---@class TransportUnstack
local Unstack = {}
Synced.Unstack = Unstack

local pushes = {} ---@type table<integer, integer> a woken turret -> pushes onto another structure since it woke

---@param unitID integer
---@param traits TransportDefTraits
---@return number halfX as the unit stands
---@return number halfZ
local function footprint(unitID, traits)
	if (Spring.GetUnitBuildFacing(unitID) or 0) % 2 == 1 then
		return traits.halfZ, traits.halfX
	end
	return traits.halfX, traits.halfZ
end

-- The blocking immobile unit whose footprint overlaps the given one the most, with its center and half sizes;
-- allyTeam limits the search to that ally team.
---@param unitID integer
---@param x number
---@param z number
---@param hx number
---@param hz number
---@param allyTeam integer|nil
---@return integer|nil worst
---@return number x
---@return number z
---@return number halfX
---@return number halfZ
local function worstOverlap(unitID, x, z, hx, hz, allyTeam)
	local widest = widestHalves()
	local rx = hx + widest + MIDPOS_MARGIN
	local rz = hz + widest + MIDPOS_MARGIN
	local worst = nil ---@type integer|nil
	local worstArea, wx, wz, whx, whz = 0, 0, 0, 0, 0 ---@type number, number, number, number, number
	for _, other in ipairs(Spring.GetUnitsInRectangle(x - rx, z - rz, x + rx, z + rz)) do
		local otherTraits = Traits.OfUnit(other)
		if
			otherTraits ~= nil
			and other ~= unitID
			and not otherTraits.canMove
			and (allyTeam == nil or Spring.GetUnitAllyTeam(other) == allyTeam)
			and Spring.GetUnitBlocking(other)
		then
			local ox, _, oz = positionOf(other)
			local ohx, ohz = footprint(other, otherTraits)
			local overlapX = hx + ohx - math.abs(ox - x)
			local overlapZ = hz + ohz - math.abs(oz - z)
			if overlapX > OVERLAP_TOLERANCE and overlapZ > OVERLAP_TOLERANCE and overlapX * overlapZ > worstArea then
				worst, worstArea = other, overlapX * overlapZ
				wx, wz, whx, whz = ox, oz, ohx, ohz
			end
		end
	end
	return worst, wx, wz, whx, whz
end

---@param traits TransportDefTraits
---@param x number
---@param z number
---@param hx number
---@param hz number
---@return boolean
local function canStandAt(traits, x, z, hx, hz)
	if x - hx < 0 or x + hx > MAP_SIZE_X or z - hz < 0 or z + hz > MAP_SIZE_Z then
		return false
	end
	local y = Spring.GetGroundHeight(x, z)
	return y < -traits.minWaterDepth and y > -traits.maxWaterDepth
end

-- A unit that skipped the build test may overlap the turrets around it: they wake. A turret set down wakes itself
-- alone, never the legally placed ones under it.
---@param unstacking table<integer, integer> nano turret -> its def
---@param unitID integer
function Unstack.Wake(unstacking, unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	local traits = unitDefID and Traits.Of(unitDefID) or nil
	if traits == nil or traits.canMove then
		return
	end
	if traits.isNano then
		unstacking[unitID] = unitDefID
		pushes[unitID] = pushes[unitID] or 0
		return
	end
	local x, _, z = Spring.GetUnitPosition(unitID)
	if x == nil then
		return
	end
	local hx, hz = footprint(unitID, traits)
	local _, widestTurret = widestHalves()
	local rx = hx + widestTurret + MIDPOS_MARGIN
	local rz = hz + widestTurret + MIDPOS_MARGIN
	for _, other in ipairs(Spring.GetUnitsInRectangle(x - rx, z - rz, x + rx, z + rz)) do
		local otherDefID = Spring.GetUnitDefID(other)
		if otherDefID ~= nil and Traits.Of(otherDefID).isNano then
			unstacking[other] = otherDefID
			pushes[other] = pushes[other] or 0
		end
	end
end

-- Moves the turret off the allied structure it overlaps most, to the nearest spot touching that structure, preferring
-- a spot clear of every structure. Done when it stands clear, is carried again, or has been pushed too often.
---@param unitID integer
---@param unitDefID integer
---@return boolean done
function Unstack.Step(unitID, unitDefID)
	if Spring.GetUnitTransporter(unitID) then
		pushes[unitID] = nil
		return true -- set down again, it wakes again
	end
	local traits = Traits.Of(unitDefID)
	local x, _, z = positionOf(unitID)
	local hx, hz = footprint(unitID, traits)
	local other, ox, oz, ohx, ohz = worstOverlap(unitID, x, z, hx, hz, Spring.GetUnitAllyTeam(unitID))
	if other == nil then
		pushes[unitID] = nil
		return true
	end
	local bestX, bestZ, bestDist, fallX, fallZ, fallDist
	for side = 1, 4 do
		local cx, cz = x, z
		if side == 1 then
			cx = ox + hx + ohx
		elseif side == 2 then
			cx = ox - hx - ohx
		elseif side == 3 then
			cz = oz + hz + ohz
		else
			cz = oz - hz - ohz
		end
		local dist = math.abs(cx - x) + math.abs(cz - z)
		if canStandAt(traits, cx, cz, hx, hz) then
			if fallDist == nil or dist < fallDist then
				fallX, fallZ, fallDist = cx, cz, dist
			end
			if (bestDist == nil or dist < bestDist) and worstOverlap(unitID, cx, cz, hx, hz) == nil then
				bestX, bestZ, bestDist = cx, cz, dist
			end
		end
	end
	if bestX ~= nil and bestZ ~= nil then
		Spring.SetUnitPosition(unitID, bestX, bestZ, traits.floatOnWater)
		pushes[unitID] = nil
		return true
	end
	if fallX ~= nil and fallZ ~= nil then
		-- every way out lands on another structure: take the nearest, and resolve that next frame
		Spring.SetUnitPosition(unitID, fallX, fallZ, traits.floatOnWater)
		local count = (pushes[unitID] or 0) + 1
		pushes[unitID] = count
		if count < MAX_PUSHES then
			return false
		end
	end
	pushes[unitID] = nil
	return true
end

---@param unitID integer a turret that is gone
function Unstack.Forget(unitID)
	pushes[unitID] = nil
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
	local x, y, z = positionOf(unitID)
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
		allied = Spring.AreTeamsAllied(
			Spring.GetUnitTeam(carrierID) --[[@as TeamID]],
			Spring.GetUnitTeam(passengerID) --[[@as TeamID]]
		),
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

-- A passenger came aboard: a stealthy carrier hides the passenger, and a passenger that leaves a ghost leaves none
-- while carried.
---@param unitID integer the passenger
---@param unitDefID integer
---@param transportID integer the carrier
function Synced.Loaded(unitID, unitDefID, transportID)
	local carrier = Traits.OfUnit(transportID)
	if carrier == nil then
		return
	end
	local passenger = Traits.Of(unitDefID)
	if carrier.stealthsPassengers and not passenger.isStealthy then
		GG.UnitAttributes.SetUnitAttribute(unitID, "stealth", true, STEALTH_SOURCE)
	end
	if passenger.leavesGhost then
		---@diagnostic disable-next-line: redundant-parameter, param-type-mismatch -- the library's signature lacks the unitID
		Spring.SetUnitLeavesGhost(unitID, false, true)
	end
end

-- A passenger was set down: it is seen and ghosts again, an immobile one wakes the nano turrets it landed on, a
-- paratrooper keeps a clamped fall, and anything else is pinned where it landed for a few frames so it does not slide.
---@param unitID integer the passenger
---@param unitDefID integer
---@param transportID integer the carrier
function Synced.Unloaded(unitID, unitDefID, transportID)
	local carrier = Traits.OfUnit(transportID)
	if carrier == nil then
		return
	end
	local passenger = Traits.Of(unitDefID)
	if carrier.stealthsPassengers and not passenger.isStealthy then
		GG.UnitAttributes.SetUnitAttribute(unitID, "stealth", nil, STEALTH_SOURCE)
	end
	if passenger.leavesGhost then
		---@diagnostic disable-next-line: param-type-mismatch -- the library's signature lacks the unitID
		Spring.SetUnitLeavesGhost(unitID, true)
	end
	if not passenger.canMove then
		-- a structure cannot slide, and pinning it where it landed would undo the push off whatever it was set down on
		Unstack.Wake(state.unstacking, unitID)
		if not Spring.GetUnitRulesParam(unitID, "unit_effigy") then
			state.maybeDead[unitID] = transportID
		end
		return
	end
	if passenger.isCarrierDrone then
		return
	end
	if passenger.isParatrooper then
		local vx, vy, vz = Spring.GetUnitVelocity(transportID)
		vx, vy, vz = Rules.ClampParatrooperVelocity(vx or 0), vy or 0, Rules.ClampParatrooperVelocity(vz or 0)
		local x, y, z = positionOf(unitID)
		if y - Spring.GetGroundHeight(x, z) < Rules.PARATROOPER_GROUND_MARGIN then
			vx, vy, vz = 0, 0, 0
		end
		Spring.SetUnitVelocity(unitID, vx, vy, vz)
		Spring.GiveOrderToUnit(unitID, CMD.STOP, {}, 0)
		return
	end

	local px, py, pz = positionOf(unitID)
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
