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

-- SPRING API LOCALS
local spGetUnitPosition        = Spring.GetUnitPosition
local spGetUnitRotation        = Spring.GetUnitRotation
local spGetUnitRulesParam      = Spring.GetUnitRulesParam
local spValidUnitID            = Spring.ValidUnitID
local spGetUnitDefID           = Spring.GetUnitDefID
local spGetUnitHeight          = Spring.GetUnitHeight
local spGetUnitCommands        = Spring.GetUnitCommands
local spGetUnitIsTransporting  = Spring.GetUnitIsTransporting
local spGetGroundHeight        = Spring.GetGroundHeight
local spEcho                   = Spring.Echo
local spSetUnitBuildParams     = Spring.SetUnitBuildParams
local spSetUnitUseWeapons      = Spring.SetUnitUseWeapons

-- CUSTOM SETTINGS
-- (none)

-- CONSTANTS
local SEATS_TO_PAD_SIZE = { -- footprint size of the unload pad to spawn for a given transporterSeats value; used by GetUnloadPadType and GetBiggestUnloadPadType
	[0]  = 0,
	[1]  = 4,
	[2]  = 6,  [3]  = 6,  [4]  = 6,
	[5]  = 8,  [6]  = 8,  [7]  = 8,
	[8]  = 10, [9]  = 10, [10] = 10, [11] = 10, [12] = 10,
	[13] = 12,
	[14] = 10,
	[15] = 12,
	[16] = 10,
}

-- VARIABLES
local cachedUnitSizes = {} -- unitDefID -> size, cached for performance
local cachedCos, cachedSin = {}, {} -- angle -> cos/sin(angle), cached for performance

-- LOCAL HELPERS
-- local function cachedCosSin(...)  -- Return cos/sin of angle, caching results to avoid repeated trig calls
-- local function shortAngle(...)    -- Normalize angle to (-pi, pi]

-- note: might've become stale code since MovePieceWS has been removed
---@param angle number
---@return number cos, number sin
local function cachedCosSin(angle)
	angle = math.floor(angle*100)/100 -- round to 2 decimals to limit cache size; should be enough for smooth animations and avoid visible jumps
	if not cachedCos[angle] then
		cachedCos[angle], cachedSin[angle] = math.cos(angle), math.sin(angle)
	end
	return cachedCos[angle], cachedSin[angle]
end

---@param a number
---@return number
local function shortAngle(a)
    a = a % (2 * math.pi)
    if a > math.pi then a = a - 2 * math.pi end
    return a
end

-- MODULE FUNCTIONS
-- function TransportAPI.HasAmphibCargo(...)              -- Return true if any passenger is amphibious or hover
-- function TransportAPI.GetUnloadTargets(...)            -- Return filtered list of passengers valid to unload at goal position
-- function TransportAPI.GetPassengerSize(...)            -- Return seat cost of a unit based on footprint or customParams.nseats
-- function TransportAPI.GetUnloadPadType(...)            -- Return unload pad defID for a given transporter and optional passenger
-- function TransportAPI.GetBiggestUnloadPadType(...)     -- Return unload pad defID for the largest transporter in a selection
-- function TransportAPI.CanPassengerFitInTransporter(...)-- Return true if the passenger can fit in the transporter
-- function TransportAPI.IsTransportFull(...)             -- Return true if the transporter has no remaining seat capacity
-- function TransportAPI.GetPassengerWeight(...)          -- Return passenger weight (seat cost × oversize multiplier)
-- function TransportAPI.IsPassengerCommander(...)        -- Return true if the passenger is a commander unit
-- function TransportAPI.EnablePassenger(...)             -- Restore build range and weapons after transport
-- function TransportAPI.DisablePassenger(...)            -- Remove build range and weapons during transport
-- function TransportAPI.CalculateTransporterSpeed(...)   -- Return speed multiplier based on cargo weight and mode settings

---@param passengers table|nil
---@return boolean hasAmphibCargo
function TransportAPI.HasAmphibCargo(passengers)
	if not passengers or #passengers == 0 then return false end
	for _, passengerID in ipairs(passengers) do
		local udefID = spGetUnitDefID(passengerID)
		if udefID then
			local def = UnitDefs[udefID]
			if def.modCategories["canbeuw"] == true or def.modCategories["hover"] == true then
				return true
			end
		end
	end
	return false
end

-- Precompute easing curves for smooth load animations: avoids per-frame curve calculation.
-- Curve uses cubic easing-in for first half, cubic easing-out for second half.
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

---@param transporterID number
---@param passengerID number
---@param goalX number
---@param goalY number
---@param goalZ number
---@return table passengerIDs
function TransportAPI.GetUnloadTargets(transporterID, passengerID, goalX, goalY, goalZ)
	local Q = spGetUnitCommands(transporterID, 2)
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
		local units = spGetUnitIsTransporting(transporterID)
		local writeIndex = 1
		local passengerIDs = {}
		local gy = spGetGroundHeight(goalX, goalZ)
		for idx = 1, #units do
			local uID = units[idx]
			if TransportAPI.HasAmphibCargo({uID}) then
			-- Amphibious units float at water level (y=0); land units need ground contact.
				passengerIDs[writeIndex] = uID
				writeIndex = writeIndex + 1
			else
				-- land units require valid ground position, exclude from unloadees if this is not the case
				local uHeight = spGetUnitHeight(uID)
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

---@param unitID number
---@return number size
function TransportAPI.GetPassengerSize(unitID)
	local udefID = spGetUnitDefID(unitID)
	if not udefID then -- dead unit/invalid, treat as size 0
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

	-- fall back method to determine size based on footprint, this is UNWANTED!
	local footprint = math.max(def.xsize, def.zsize) / 2
	if     footprint <= 2  then cachedUnitSizes[udefID] = 1
	elseif footprint <= 4  then cachedUnitSizes[udefID] = 4
	elseif footprint <= 8  then cachedUnitSizes[udefID] = 16 
	elseif footprint <= 16 then cachedUnitSizes[udefID] = 64 -- ?
	else                        cachedUnitSizes[udefID] = 256 -- ?
	end
	return cachedUnitSizes[udefID]
end

---@param transporterID number
---@param passengerID number|nil
---@return number|nil padTypeDefID
function TransportAPI.GetUnloadPadType(transporterID, passengerID)
	local transporterSeats = spGetUnitRulesParam(transporterID, "transporterSeats") -- set by CargoHandler
	if not transporterSeats then
		spEcho("Error, GetUnloadPadType expects a valid transporter ID as 1st arg, transporterID "..transporterID.." does not point to a valid transporter ID")
		return nil
	end
	local passengers = passengerID and {passengerID} or spGetUnitIsTransporting(transporterID)
	local suffix = TransportAPI.HasAmphibCargo(passengers) and "_amphib" or ""
	local padSize = SEATS_TO_PAD_SIZE[transporterSeats] or 10
	local padString = "unloadsize"..tostring(padSize)..suffix
	if UnitDefNames[padString] then
		return UnitDefNames[padString].id
	end
	-- suffix variant not defined: fall back to land pad of the same size
	return UnitDefNames["unloadsize"..tostring(padSize)].id
end

---@param units table
---@return number|nil padTypeDefID
function TransportAPI.GetBiggestUnloadPadType(units)
	if not units or #units == 0 then return nil end
	-- find the largest seat count across all transporters in the selection
	local transporterSeats = 0
	for i = 1, #units do
		local thisSeats = spGetUnitRulesParam(units[i], "transporterSeats") or 0 -- set by CargoHandler
		if thisSeats > transporterSeats then
			transporterSeats = thisSeats
		end
	end
	if transporterSeats == 0 then
		spEcho("Error, GetBiggestUnloadPadType: no valid transporters in units table")
		return nil
	end
	-- aggregate all passengers across every transporter in the selection
	local allPassengers = {}
	for i = 1, #units do
		local passengers = spGetUnitIsTransporting(units[i])
		if passengers and #passengers > 0 then
			for _, passengerID in ipairs(passengers) do
				allPassengers[#allPassengers + 1] = passengerID
			end
		end
	end
	local suffix = TransportAPI.HasAmphibCargo(allPassengers) and "_amphib" or ""
	local padSize = SEATS_TO_PAD_SIZE[transporterSeats] or 10
	local padString = "unloadsize"..tostring(padSize)..suffix
	if UnitDefNames[padString] then
		return UnitDefNames[padString].id
	end
	-- suffix variant not defined: fall back to land pad of the same size
	return UnitDefNames["unloadsize"..tostring(padSize)].id
end

---@param transporterID number
---@param passengerID number
---@param transporterDefID number
---@param passengerSize number
---@param queuedSize number
---@return boolean canFit
function TransportAPI.CanPassengerFitInTransporter(transporterID, passengerID, transporterDefID, passengerSize, queuedSize)
	if not spValidUnitID(passengerID) then
		return false
	end
	local transporterSeats    = spGetUnitRulesParam(transporterID, "transporterSeats")    or 0 -- set by CargoHandler
	local transporterUsedSeats = spGetUnitRulesParam(transporterID, "transporterUsedSeats") or 0 -- set by CargoHandler
	local queuedSize = queuedSize or 0
	if transporterSeats - transporterUsedSeats - queuedSize < passengerSize then
		return false
	end
	-- Verify the transporter has an actual slot that can hold this size (set by CargoHandler).
	-- Seats alone don't guarantee space; slots ensure both capacity and physical compatibility.
	local rulesParamString = "transporterHasSlotOfSize"..passengerSize -- set by CargoHandler
	local foundSlot = spGetUnitRulesParam(transporterID, rulesParamString) == true
	return foundSlot
end

---@param transporterID number
---@param queuedSize number
---@return boolean isFull
function TransportAPI.IsTransportFull(transporterID, queuedSize)
	local transporterSeats    = spGetUnitRulesParam(transporterID, "transporterSeats")    or 0 -- set by CargoHandler
	local transporterUsedSeats = spGetUnitRulesParam(transporterID, "transporterUsedSeats") or 0 -- set by CargoHandler
	local queuedSize = queuedSize or 0
	return transporterUsedSeats + queuedSize >= transporterSeats
end

---@param passengerID number
---@param cargo table
---@return number weight
function TransportAPI.GetPassengerWeight(passengerID, cargo)
	local weight = TransportAPI.GetPassengerSize(passengerID)
	local oversized = UnitDefs[spGetUnitDefID(passengerID)].customParams.oversized == "1"
	local undersized = UnitDefs[spGetUnitDefID(passengerID)].customParams.oversized == "-1"
	weight = weight * (oversized and (1.5) or undersized and (0.5) or 1)  -- weight of passengerSize or passengerSize * 1.5 depending on oversized tag
	return weight
end

---@param passengerID number
---@return boolean isCommander
function TransportAPI.IsPassengerCommander(passengerID)
	local isCommander = UnitDefs[spGetUnitDefID(passengerID)].customParams.iscommander
	return isCommander
end

---@param passengerID number
function TransportAPI.EnablePassenger(passengerID)
	local defs = UnitDefs[spGetUnitDefID(passengerID)]
	if defs.buildSpeed > 0 then
		spSetUnitBuildParams(passengerID, "buildRange", defs.buildDistance)
	end
	if defs.weapons and #defs.weapons > 0 then
		spSetUnitUseWeapons(passengerID, false, true)
	end
end

---@param passengerID number
function TransportAPI.DisablePassenger(passengerID)
	local defs = UnitDefs[spGetUnitDefID(passengerID)]
	if defs.buildSpeed > 0 then
		spSetUnitBuildParams(passengerID, "buildRange", 0)
	end
	if defs.weapons and #defs.weapons > 0 then
		spSetUnitUseWeapons(passengerID, false, false)
	end
end

---@param cargo table
---@return number speedMultiplier
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