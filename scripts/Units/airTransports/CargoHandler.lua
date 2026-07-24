CargoHandler = {}

-- SPRING API LOCALS
local spGetUnitDefID              = Spring.GetUnitDefID
local spGetUnitPiecePosDir        = Spring.GetUnitPiecePosDir
local spGetUnitPosition           = Spring.GetUnitPosition
local spGetUnitRotation           = Spring.GetUnitRotation
local spGetUnitHeight             = Spring.GetUnitHeight
local spGetUnitRadius             = Spring.GetUnitRadius
local spSetUnitRulesParam         = Spring.SetUnitRulesParam
local spMoveCtrlSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData

-- CUSTOM SETTINGS
-- (none)

-- CONSTANTS
-- (none)

-- LOCAL HELPERS
-- local function RequiresMet(...)           -- Returns true if every required slot is currently empty
-- local function PassengerToSlotDistSq(...) -- Returns squared XZ distance from passenger to a slot piece

-- MODULE FUNCTIONS
-- function CargoHandler.Init(...)                -- Initialize cargo and slot tables from setup config; return the cargo table
-- function CargoHandler.HideSlots(...)           -- Hide all slot pieces at startup so they only appear during loading
-- function CargoHandler.HasSlotOfSize(...)       -- Return true if this transporter has any slot accepting the given seat cost
-- function CargoHandler.CanLoad(...)             -- Set the rulesParam the gadget reads to block or allow new load attempts
-- function CargoHandler.CanUnload(...)           -- Set the rulesParam the gadget reads to block or allow new unload attempts
-- function CargoHandler.BeginLoading(...)        -- Increment loading count; block unloading while animations are in progress
-- function CargoHandler.EndLoading(...)          -- Decrement loading count; recompute speed damping and re-enable unloading when done
-- function CargoHandler.BeginUnloading(...)      -- Increment unloading count; apply slow damping and block loading
-- function CargoHandler.EndUnloading(...)        -- Decrement unloading count; re-enable loading when all unloads complete
-- function CargoHandler.FindSlot(...)            -- Assign closest valid slot to passenger; trigger ReorganizeAndLoad if only overlapping slots remain
-- function CargoHandler.ReorganizeAndLoad(...)   -- Instantly unload all cargo then reload greedy-closest; give new passenger first pick
-- function CargoHandler.ReleaseSlot(...)         -- Mark a slot as vacant without removing passenger from cargo.passengers
-- function CargoHandler.SetSpeedDamping(...)     -- Apply speedMod to max speed, acc, and turn rate; optionally adjust altitude
-- function CargoHandler.Register(...)            -- Add passenger to cargo.passengers and update seat/weight/commander accounting
-- function CargoHandler.Unregister(...)          -- Remove passenger from cargo.passengers, release its slot, and update accounting

---@param setup table  slot and speed-damping config from <unitName>/setup.lua
---@return table cargo  initialized cargo state table
function CargoHandler.Init(setup)
	-- resolve piece name strings from setup into piece IDs
	local nameToID = {}
	local function res(name)
		if not nameToID[name] then nameToID[name] = piece(name) end
		return nameToID[name]
	end

	for _, slot in ipairs(setup.slots) do res(slot.name) end

	local slots = {}
	local slotsBySize = {}  -- [size] = array of slotIDs
	for _, slotCfg in ipairs(setup.slots) do
		local pid  = nameToID[slotCfg.name]
		local reqs = {}
		for _, reqName in ipairs(slotCfg.requires) do
			reqs[#reqs + 1] = nameToID[reqName]
		end
		slots[pid] = {
			size        = slotCfg.size,        -- seat cost of a unit that fits this slot (1/4/8/16)
			cargo       = nil,                  -- passengerID currently occupying this slot, nil if empty
			requires    = reqs,                 -- list of slotIDs that must be empty for this slot to be usable
			overlapping = slotCfg.overlapping,  -- true if this slot physically overlaps a non-overlapping slot of the same size
		}
		if not slotsBySize[slotCfg.size] then slotsBySize[slotCfg.size] = {} end
		slotsBySize[slotCfg.size][#slotsBySize[slotCfg.size] + 1] = pid
	end

	local slotSizes = {}
	for size in pairs(slotsBySize) do
		slotSizes[size] = true
	end

	-- source of truth for all cargo tracking; all load/unload operations read and write this table.
	-- on save/load the engine is queried for current passengers and this table is rebuilt from scratch (see script.Create),
	-- but outside of that reload path this is the only authoritative record of what is loaded and where.
	local uDef = UnitDefs[spGetUnitDefID(transporterID)]
	local cargo = {
		transporterID                  = transporterID,                       -- transporter unit ID
		slots                   = slots,                        -- [slotID] = { size, cargo, requires, overlapping } (see above)
		slotsBySize             = slotsBySize,                  -- [size] = array of slotIDs of that size
		passengers              = {},                           -- [passengerID] = passengerData  ({ id, height, slotID, beamPieces, wbX/Y/Z, animProgress })
		count                   = 0,                            -- number of units currently loaded
		transporterUsedSeats    = 0,                            -- sum of seat costs of all loaded units
		transporterSeats        = tonumber(uDef.customParams.transporterseats or 0),       -- total seat capacity of this transporter
		transporterMaxSpeed		= uDef.speed, -- base max speed of the transporter, used for speed calculations
		transporterAccRate		= uDef.maxAcc, -- base acceleration of the transporter, used for speed calculations
		transporterDecRate		= uDef.maxDec, -- base deceleration of the transporter, used for speed calculations
		transporterTurnRate		= uDef.turnRate, -- base turn rate of the transporter, used for speed calculations
		loadedCommandersCount	= 0,							-- number of loaded commanders
		passengersTotalWeight	= 0,                            -- sum of "weights" of all loaded units, used for speed slowing
		transporterSpeedModMode = tonumber(uDef.customParams.transporterspeedmodmode or 0),
		-- type of speed modification to apply:
		-- 0 = no speed modification
		-- 1 = speedNerf = (usedSeats/nSeats) * transporterSpeedModStrength
		-- 2 = speedNerf = ((passengersTotalWeight-transporterSeats) / (transporterSeats * 0.5)) * transporterSpeedModStrength
		-- passengersTotalWeight = sum(passengerSize * ((oversized and 1.5) or 1))
		-- this makes the slowdown based on excess, not cargo
		transporterSpeedModStrength = tonumber(uDef.customParams.transporterspeedmodstrength or 0), -- strength of speed modification, used as multiplier for the calculated speed mod in all modes
		-- set to > 0 value to enable; effect depends on transporterSpeedModMode
		transporterComSpeedModStrength = tonumber(uDef.customParams.transportercomspeedmodstrength or 0), -- separate speed mod strength for commanders, used in modes 1 and 3 as an override if it's higher than the regular mod strength
		-- set to > 0 value to enable; slows down the transporter if it has a loaded commander
		-- the resultant speedNerf value is then math.max(speedNerf, comSpeedNerf)
		transporterAltitude		= tonumber(uDef.wantedHeight or 100), -- wanted height of the transporter, used for move type data and can be modified by passengers
		slotSizes               = slotSizes,                    -- set of slot sizes available, eg { [1]=true, [4]=true }
		loadingCount            = 0,                            -- number of load animations in progress
		unloadingCount          = 0,                            -- number of unload animations in progress
	}
	cargo.currentMaxPassengerHeight = function() -- helper to get the current max passenger height for anim purposes, based on current cargo
			local maxHeight = 0
			for _, passengerData in pairs(cargo.passengers) do
				if passengerData.height and passengerData.height > maxHeight then
					maxHeight = passengerData.height
				end
			end
			return maxHeight
		end

	-- set some initial unit rules params for the gadget to read, and for UI display
	for size, bool in pairs (slotSizes) do
		local rulesParamString = "transporterHasSlotOfSize"..size
		spSetUnitRulesParam(transporterID, rulesParamString, bool)
	end
	CargoHandler.SetSpeedDamping(1.0, cargo, true) -- make sure no silent damping stays after a reload, will be reapplied if necessary.
	spSetUnitRulesParam(transporterID, "transporterSeats",    cargo.transporterSeats) -- used by gadget to determine if a passenger can be loaded, and by anim handler to determine whether to show hover effect
	spSetUnitRulesParam(transporterID, "transporterUsedSeats", 0) -- used by gadget to determine if a passenger can be loaded/unloaded, and by anim handler to determine whether to show hover effect
	CargoHandler.CanLoad(true)
	CargoHandler.CanUnload(true)
	return cargo
end


---@param cargo table
function CargoHandler.HideSlots(cargo)
	for slotID in pairs(cargo.slots) do
		Hide(slotID)
	end
end

---@param size number  seat cost to check for
---@param cargo table
---@return boolean
function CargoHandler.HasSlotOfSize(size, cargo)
	return cargo.slotSizes[size] == true
end

---@param bool boolean  true to allow loading, false to block
function CargoHandler.CanLoad(bool)
	spSetUnitRulesParam(transporterID, "canLoad", bool and 1 or 0)
end

---@param bool boolean  true to allow unloading, false to block
function CargoHandler.CanUnload(bool)
	spSetUnitRulesParam(transporterID, "canUnload", bool and 1 or 0)
end

---@param cargo table
function CargoHandler.BeginLoading(cargo)
	cargo.loadingCount = cargo.loadingCount + 1
	if cargo.loadingCount == 1 then
		CargoHandler.CanUnload(false)
	end
end

---@param cargo table
function CargoHandler.EndLoading(cargo)
	cargo.loadingCount = math.max(0, cargo.loadingCount - 1)
	if cargo.loadingCount == 0 then
		local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
		CargoHandler.SetSpeedDamping(speedMod, cargo, true)
		CargoHandler.CanUnload(true)
	end
end

---@param cargo table
function CargoHandler.BeginUnloading(cargo)
	cargo.unloadingCount = cargo.unloadingCount + 1
	CargoHandler.SetSpeedDamping(0.2, cargo, false)
	if cargo.unloadingCount == 1 then
		CargoHandler.CanLoad(false)
	end
end

---@param cargo table
function CargoHandler.EndUnloading(cargo)
	cargo.unloadingCount = math.max(0, cargo.unloadingCount - 1)
	if cargo.unloadingCount == 0 then
		CargoHandler.CanLoad(true)
	end
end

---@param slotData table
---@param slots table
---@return boolean
local function RequiresMet(slotData, slots)
	for _, reqID in ipairs(slotData.requires) do
		if slots[reqID] and slots[reqID].cargo ~= nil then
			return false
		end
	end
	return true
end

---@param passengerID number
---@param slotID number
---@return number distanceSq
local function PassengerToSlotDistSq(passengerID, slotID)
	local px, _, pz = spGetUnitPosition(passengerID)
	local sx, _, sz = spGetUnitPiecePosDir(transporterID, slotID)
	local dx, dz = px - sx, pz - sz
	return dx * dx + dz * dz
end

---@param passengerID number
---@param cargo table
---@param allowReorganize boolean|nil
---@param fromReorganize boolean|nil
---@return table|nil passengerData
function CargoHandler.FindSlot(passengerID, cargo, allowReorganize, fromReorganize)
	local seats = TransportAPI.GetPassengerSize(passengerID)
	local sizeList = cargo.slotsBySize[seats]
	if not sizeList then return nil end

	local bestSlotID   = nil
	local bestDistSq   = math.huge
	local hasOverlap   = false  -- true if an overlapping slot is available but a non-overlapping one isn't

	for _, slotID in ipairs(sizeList) do
		local slotData = cargo.slots[slotID]
		if slotData.cargo == nil and RequiresMet(slotData, cargo.slots) then
			if slotData.overlapping then
				if not fromReorganize then
					hasOverlap = true  -- note it but keep looking for a clean slot
				end
			else
				local dSq = PassengerToSlotDistSq(passengerID, slotID)
				if dSq < bestDistSq then
					bestDistSq = dSq
					bestSlotID = slotID
				end
			end
		end
	end

	-- a non-overlapping slot is available: claim it
	if bestSlotID then
		cargo.slots[bestSlotID].cargo = passengerID
		return { id = passengerID, height = spGetUnitHeight(passengerID), radius = spGetUnitRadius(passengerID), slotID = bestSlotID }
	end

	-- only overlapping slots are available: try one (closest)
	if not fromReorganize and hasOverlap then
		for _, slotID in ipairs(sizeList) do
			local slotData = cargo.slots[slotID]
			if slotData.cargo == nil and slotData.overlapping and RequiresMet(slotData, cargo.slots) then
				local dSq = PassengerToSlotDistSq(passengerID, slotID)
				if dSq < bestDistSq then
					bestDistSq = dSq
					bestSlotID = slotID
				end
			end
		end
		if bestSlotID then
			cargo.slots[bestSlotID].cargo = passengerID
			return { id = passengerID, height = spGetUnitHeight(passengerID), radius = spGetUnitRadius(passengerID), slotID = bestSlotID }
		end
	end

	-- no slot at all: maybe reorganize can make room
	if allowReorganize and CargoHandler.HasSlotOfSize(seats, cargo)
		and cargo.transporterUsedSeats + seats <= cargo.transporterSeats then
		CargoHandler.ReorganizeAndLoad(cargo, passengerID)
	end
	return nil
end

---@param cargo table
---@param newPassengerID number
function CargoHandler.ReorganizeAndLoad(cargo, newPassengerID)
	-- kill all in-flight Load threads at once and repair the accounting they left dangling
	Signal(TransportAnimator.SIG_LOAD)
	cargo.loadingCount = 0
	CargoHandler.CanUnload(true)

	-- build the reload list: new unit first within its size tier, then existing cargo
	local newSize = TransportAPI.GetPassengerSize(newPassengerID)
	local toLoad = { newPassengerID }
	for passengerID in pairs(cargo.passengers) do
		toLoad[#toLoad + 1] = passengerID
	end
	-- sort descending by size; within the same size newPassengerID stays first (it was inserted first)
	table.sort(toLoad, function(a, b)
		local sa = TransportAPI.GetPassengerSize(a)
		local sb = TransportAPI.GetPassengerSize(b)
		if sa ~= sb then return sa > sb end
		-- keep newPassengerID at front of its size group
		if a == newPassengerID then return true end
		if b == newPassengerID then return false end
		return false
	end)

	local passengerSnapshot = {}
	for passengerID, passengerData in pairs(cargo.passengers) do
		passengerSnapshot[passengerID] = passengerData
	end
	for passengerID, passengerData in pairs(passengerSnapshot) do
		local tx, ty, tz = spGetUnitPosition(cargo.transporterID)
		TransportAnimator.Unload(passengerData, tx, ty, tz, false)
	end

	-- greedy closest non-overlapping slot, slots are marked taken as each unit is assigned
	for _, passengerID in ipairs(toLoad) do
		local passengerData = CargoHandler.FindSlot(passengerID, cargo, false, true)
		if passengerData then
			StartThread(TransportAnimator.Load, passengerData)
		end
	end
end

---@param slotID number
---@param cargo table
function CargoHandler.ReleaseSlot(slotID, cargo)
	if cargo.slots[slotID] then
		cargo.slots[slotID].cargo = nil
	end
end

---@param speedMod number
---@param cargo table
---@param changeAltitude boolean
function CargoHandler.SetSpeedDamping(speedMod, cargo, changeAltitude)
	spMoveCtrlSetGunshipMoveTypeData(cargo.transporterID, "maxWantedSpeed", speedMod * cargo.transporterMaxSpeed)
	spMoveCtrlSetGunshipMoveTypeData(cargo.transporterID, "maxSpeed", speedMod * cargo.transporterMaxSpeed)
	spMoveCtrlSetGunshipMoveTypeData(cargo.transporterID, "accRate", speedMod * cargo.transporterAccRate)
	spMoveCtrlSetGunshipMoveTypeData(cargo.transporterID, "turnRate", speedMod * cargo.transporterTurnRate)
	if changeAltitude then
		spMoveCtrlSetGunshipMoveTypeData(cargo.transporterID, "wantedHeight", math.max(cargo.currentMaxPassengerHeight() + 10, speedMod * cargo.transporterAltitude))	
	end
end

---@param passengerID number
---@param passengerData table
---@param cargo table
---@return number count  total passengers currently loaded
function CargoHandler.Register(passengerID, passengerData, cargo)
	cargo.passengers[passengerID] = passengerData
	cargo.count     = cargo.count + 1
	cargo.transporterUsedSeats = cargo.transporterUsedSeats + (cargo.slots[passengerData.slotID].size or 0)
	spSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
	cargo.passengersTotalWeight = cargo.passengersTotalWeight + (TransportAPI.GetPassengerWeight(passengerID, cargo) or 0)
	cargo.loadedCommandersCount = cargo.loadedCommandersCount + (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0)
	CargoHandler.SetSpeedDamping(0.2, cargo, false)
	return cargo.count
end

---@param passengerID number
---@param cargo table
---@return number count  total passengers currently loaded
function CargoHandler.Unregister(passengerID, cargo) -- marks the end of unloading
	local passengerData = cargo.passengers[passengerID]
	if passengerData and passengerData.slotID then
		cargo.transporterUsedSeats = math.max(0, cargo.transporterUsedSeats - (cargo.slots[passengerData.slotID].size or 0))
		spSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
		CargoHandler.ReleaseSlot(passengerData.slotID, cargo)
	end
	cargo.passengers[passengerID] = nil
	cargo.count = math.max(0, cargo.count - 1)
	cargo.passengersTotalWeight = math.max(0, cargo.passengersTotalWeight - (TransportAPI.GetPassengerWeight(passengerID,cargo) or 0))
	cargo.loadedCommandersCount = math.max(0, cargo.loadedCommandersCount - (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0))
	local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
	CargoHandler.SetSpeedDamping(speedMod, cargo, true)
	return cargo.count
end
