local upget = gadget or widget ---@type Addon
local globalScope = gadget and GG or WG
local desc = gadget and "Helpers for the Transport Handler gadget and tractor beam unit scripts" or "Helpers for transportation-related widgets"

function upget:GetInfo()
	return {
		name    = "Transport Handler API",
		desc    = desc,
		author  = "DoodVanDaag",
		date    = "2026",
		license = "GNU GPL, v2 or later",
		layer   = -1, -- must be < 0: before unit_script and transport handler upgets
		enabled = true,
	}
end

if gadget and not gadgetHandler:IsSyncedCode() then
	return false
end

if Spring.GetModOptions and Spring.GetModOptions().beta_tractorbeam == false then
	Spring.Echo("Custom transports disabled via modoption, skipping transport API upget")
	return false
end

globalScope.TransportAPI = {}
local TransportAPI = globalScope.TransportAPI
local cachedUnitSizes = {}
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation
local cachedCos, cachedSin = {}, {}
local unloadPad = {}
local spGetUnitRulesParam = Spring.GetUnitRulesParam

-- Maps transporterSeats (1-16) to unloadpad footprint size.
-- Derived from universalPadGenerator.py: pad = (max(beam_footprint_w, beam_footprint_h) + 32) / 16
local seatsToPadSize = {
	[1]  = 4,
	[2]  = 6,  [3]  = 6,  [4]  = 6,
	[5]  = 8,  [6]  = 8,  [7]  = 8,
	[8]  = 10, [9]  = 10, [10] = 10, [11] = 10, [12] = 10,
	[13] = 12,
	[14] = 10,
	[15] = 12,
	[16] = 10,
}
local spValidUnitID = Spring.ValidUnitID

local function cachedCosSin(angle)
	angle = math.floor(angle*100)/100 -- round to 2 decimals to limit cache size; should be enough for smooth animations and avoid visible jumps
	if not cachedCos[angle] then
		cachedCos[angle], cachedSin[angle] = math.cos(angle), math.sin(angle)
	end
	return cachedCos[angle], cachedSin[angle]
end

local function shortAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

-- Returns true if any passenger in the list is hover or amphib (canbeuw), false otherwise.
function TransportAPI.HasAmphibCargo(passengers)
	if not passengers or #passengers == 0 then return false end
	for _, passengerID in ipairs(passengers) do
		local udefID = Spring.GetUnitDefID(passengerID)
		if udefID then
			local def = UnitDefs[udefID]
			if def.modCategories["canbeuw"] == true or def.modCategories["hover"] == true then
				return true
			end
		end
	end
	return false
end

TransportAPI.precomputedProgress = {}
for uDefID, def in pairs(UnitDefs) do
	if def.customParams and def.customParams.loadtime then
		local loadTime = tonumber(def.customParams.loadtime)
		local curve = {}
		for f = 0, loadTime do
			local t = f / loadTime
			if t < 0.5 then
				curve[f] = 4*t*t*t
			else
				local u = 2 - 2*t
				curve[f] = 1 - u*u*u * 0.5
			end
		end
		TransportAPI.precomputedProgress[uDefID] = curve
	end
end

-- Inspects the transporter's command queue to detect area-unload orders.
-- Returns all currently loaded passengers for area-unload, or {passengerID} for single-unload.
function TransportAPI.GetUnloadTargets(transporterID, passengerID, goalX, goalY, goalZ)
	local Q = Spring.GetUnitCommands(transporterID, 2) -- we only need the first two
	local isAreaUnload = Q and Q[1] and (
		Q[1].id == CMD.UNLOAD_UNITS or
		(
			Q[1].id == CMD.UNLOAD_UNIT and
			(
				(#Q > 1 and Q[2] and Q[2].id == CMD.UNLOAD_UNITS) or
				Q[1].params[4] == nil -- no defined unitID: issued by customFormation/areaUnload widgets
			)
		)
	)
	if isAreaUnload then
		-- multi passengers, filter per unit
		local units = Spring.GetUnitIsTransporting(transporterID)
		local writeIndex = 1
		local passengerIDs = {}
		local gy = Spring.GetGroundHeight(goalX, goalZ)
		for idx = 1, #units do
			local uID = units[idx]
			if TransportAPI.HasAmphibCargo({uID}) then
				-- hover and amphib units are dropped at water surface (y=0); they float or sink naturally
				passengerIDs[writeIndex] = uID
				writeIndex = writeIndex + 1
			else
				-- land unit: skip if the ground is below water and the unit would be submerged
				local uHeight = Spring.GetUnitHeight(uID)
				if uHeight + gy > 0 then
					passengerIDs[writeIndex] = uID
					writeIndex = writeIndex + 1
				end
			end
		end
		return passengerIDs
	end
	-- only one passenger, no filter needed
	return { passengerID }
end

function TransportAPI.GetPassengerSize(unitID) -- minimal perf improvement: cache per unitDefID
	local udefID = Spring.GetUnitDefID(unitID)
	if not udefID then
		-- we're being called on a unit that just died but hasn't been cleaned yet from the transporterClaims lists
		-- (ie during a releaseClaim iteration or an ExecuteSuccessiveLoadUnits or ExecuteLoadUnits) iteration, 
		-- after being flagged for removal, but not yet removed. we can safely return 0
		return 0 
	end 
	if cachedUnitSizes[udefID] then
		return cachedUnitSizes[udefID]
	end
	local def = UnitDefs[udefID]
	if def.customParams.nseats then
		cachedUnitSizes[udefID] = tonumber(def.customParams.nseats)
		return cachedUnitSizes[udefID]
	end
	local footprint = math.max(def.xsize, def.zsize) / 2
	if     footprint <= 2  then cachedUnitSizes[udefID] = 1
	elseif footprint <= 4  then cachedUnitSizes[udefID] = 4
	elseif footprint <= 8  then cachedUnitSizes[udefID] = 16 
	-- that's HUGE, sounds already way over the limit of what could be reasonably transported considering our models.
	-- but i chose to keep defining those regardless, in case of some special event unit for experimental transportations.
	elseif footprint <= 16 then cachedUnitSizes[udefID] = 64 -- ?
	else                        cachedUnitSizes[udefID] = 256 -- ?
	end
	return cachedUnitSizes[udefID]
end

-- passengerID is optional: when provided, pad type is based solely on that unit (for single-unload cmds).
-- When nil, all currently loaded passengers are checked (for area unloads).
function TransportAPI.GetUnloadPadType(transporterID, passengerID)
	local transporterSeats = Spring.GetUnitRulesParam(transporterID, "transporterSeats")
	if not transporterSeats then
		Spring.Echo("Error, GetUnloadPadType expects a valid transporter ID as 1st arg, transporterID "..transporterID.." does not point to a valid transporter ID")
		return nil
	end
	local passengers = passengerID and {passengerID} or Spring.GetUnitIsTransporting(transporterID)
	local suffix = TransportAPI.HasAmphibCargo(passengers) and "_amphib" or ""
	local padSize = seatsToPadSize[transporterSeats] or 10
	local padString = "unloadsize"..tostring(padSize)..suffix
	if UnitDefNames[padString] then
		return UnitDefNames[padString].id
	end
	-- suffix variant not defined: fall back to land pad of the same size
	return UnitDefNames["unloadsize"..tostring(padSize)].id
end

function TransportAPI.GetBiggestUnloadPadType(units)
	if not units or #units == 0 then return nil end
	-- find the largest seat count across all transporters in the selection
	local transporterSeats = 0
	for i = 1, #units do
		local thisSeats = Spring.GetUnitRulesParam(units[i], "transporterSeats") or 0
		if thisSeats > transporterSeats then
			transporterSeats = thisSeats
		end
	end
	if transporterSeats == 0 then
		Spring.Echo("Error, GetBiggestUnloadPadType: no valid transporters in units table")
		return nil
	end
	-- aggregate all passengers across every transporter in the selection
	local allPassengers = {}
	for i = 1, #units do
		local passengers = Spring.GetUnitIsTransporting(units[i])
		if passengers then
			for _, passengerID in ipairs(passengers) do
				allPassengers[#allPassengers + 1] = passengerID
			end
		end
	end
	local suffix = TransportAPI.HasAmphibCargo(allPassengers) and "_amphib" or ""
	local padSize = seatsToPadSize[transporterSeats] or 10
	local padString = "unloadsize"..tostring(padSize)..suffix
	if UnitDefNames[padString] then
		return UnitDefNames[padString].id
	end
	-- suffix variant not defined: fall back to land pad of the same size
	return UnitDefNames["unloadsize"..tostring(padSize)].id
end


--- @param transporterID number
--- @param passengerID number
--- @param transporterDefID number
--- @param passengerSize number
--- @param queuedSize number
--- @return boolean
function TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, queuedSize)
	if not spValidUnitID(passengerID) then
		return false
	end
	local transporterSeats    = spGetUnitRulesParam(transporterID, "transporterSeats")    or 0
	local transporterUsedSeats = spGetUnitRulesParam(transporterID, "transporterUsedSeats") or 0
	local queuedSize = queuedSize or 0
	if transporterSeats - transporterUsedSeats - queuedSize < passengerSize then
		return false
	end
	local rulesParamString = "transporterHasSlotOfSize"..passengerSize
	local foundSlot = spGetUnitRulesParam(transporterID, rulesParamString) == true
	return foundSlot
end

--- @param transporterID number
--- @param queuedSize number
--- @return boolean isFull
function TransportAPI.IsTransportFull(transporterID, queuedSize)
	local transporterSeats    = spGetUnitRulesParam(transporterID, "transporterSeats")    or 0
	local transporterUsedSeats = spGetUnitRulesParam(transporterID, "transporterUsedSeats") or 0
	local queuedSize = queuedSize or 0
	return transporterUsedSeats + queuedSize >= transporterSeats
end

function TransportAPI.GetPassengerWeight(passengerID, cargo)
	local weight = TransportAPI.GetPassengerSize(passengerID)
	local oversized = UnitDefs[Spring.GetUnitDefID(passengerID)].customParams.oversized == "1"
	weight = weight * (oversized and (1.5) or 1)  -- weight of passengerSize or passengerSize * 1.5 depending on oversized tag
	return weight
end

function TransportAPI.IsPassengerCommander(passengerID)
	local isCommander = UnitDefs[Spring.GetUnitDefID(passengerID)].customParams.iscommander
	return isCommander
end

function TransportAPI.EnablePassenger(passengerID)
	local defs = UnitDefs[Spring.GetUnitDefID(passengerID)]
	if defs.buildSpeed > 0 then
		Spring.SetUnitBuildParams(passengerID, "buildRange", defs.buildDistance)
	end
	if defs.weapons and #defs.weapons > 0 then
		Spring.SetUnitUseWeapons(passengerID, false, true)
	end
end

function TransportAPI.DisablePassenger(passengerID)
	local defs = UnitDefs[Spring.GetUnitDefID(passengerID)]
	if defs.buildSpeed > 0 then
		Spring.SetUnitBuildParams(passengerID, "buildRange", 0)
	end
	if defs.weapons and #defs.weapons > 0 then
		Spring.SetUnitUseWeapons(passengerID, false, false)
	end
end

function TransportAPI.CalculateTransporterSpeed(cargo)
	local speedNerf = 0
	local transporterSpeedModMode = cargo.transporterSpeedModMode or 0
	if transporterSpeedModMode == 1 then
		speedNerf = (cargo.transporterUsedSeats / cargo.transporterSeats) * cargo.transporterSpeedModStrength
	elseif transporterSpeedModMode == 2 then
		local maxWeight = cargo.transporterSeats -- max capacity
		local maxOverWeight = maxWeight * 0.5
		speedNerf = ((cargo.passengersTotalWeight - maxWeight) / maxOverWeight) * cargo.transporterSpeedModStrength
	end
	local comSpeedNerf = cargo.loadedCommandersCount > 0 and cargo.transporterComSpeedModStrength or 0
	speedNerf = math.max(speedNerf, comSpeedNerf)
	return math.max(0, 1 - speedNerf) -- final speed multiplier, between 0 and 1
end