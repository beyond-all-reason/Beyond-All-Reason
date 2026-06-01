-- TODOs:
-- >> maybe move slots hiding logic to generic_air_transport_lus instead. Or maybe even erase it since link pieces are empty by definition (no model piece)

CargoHandler = {}

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
	local cargo = {
		transporterID                  = transporterID,                       -- transporter unit ID
		slots                   = slots,                        -- [slotID] = { size, cargo, requires, overlapping } (see above)
		slotsBySize             = slotsBySize,                  -- [size] = array of slotIDs of that size
		passengers              = {},                           -- [passengerID] = passengerData  ({ id, height, slotID, beamPieces, wbX/Y/Z, animProgress })
		count                   = 0,                            -- number of units currently loaded
		transporterUsedSeats    = 0,                            -- sum of seat costs of all loaded units
		transporterSeats        = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transporterseats or 0),       -- total seat capacity of this transporter
		transporterMaxSpeed		= UnitDefs[Spring.GetUnitDefID(transporterID)].speed, -- base max speed of the transporter, used for speed calculations
		transporterAccRate		= UnitDefs[Spring.GetUnitDefID(transporterID)].maxAcc, -- base acceleration of the transporter, used for speed calculations
		transporterDecRate		= UnitDefs[Spring.GetUnitDefID(transporterID)].maxDec, -- base deceleration of the transporter, used for speed calculations
		loadedCommandersCount	= 0,							-- number of loaded commanders
		passengersTotalWeight	= 0,                            -- sum of "weights" of all loaded units, used for speed slowing
		transporterSpeedModMode = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transporterspeedmodmode or 0),
		-- type of speed modification to apply:
		-- 0 = no speed modification
		-- 1 = if loadedCommandersCount > 0 then speed = maxSpeed * (1-transporterSpeedModStrength)
		-- 2 = speed = maxSpeed * (1 - (usedSeats/nSeats) * transporterSpeedModStrength)
		-- 3 = modified usedSeats/nSeats; 
		-- passengerWeight = passengerSize * (oversized and (1 + transporterSpeedModStrength) or 1)
		-- speed = math.min(maxSpeed, maxSpeed * (1 - ((totalWeight/nSeats) - 1)))
		-- this makes the slowdown based on excess, not cargo

		-- all these data can be set from tweakDefs/tweakUnits without requirements for an update; so they will be testable/tweakable until a "final" setting is decided upon.
		transporterSpeedModStrength = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transporterspeedmodstrength or 0.5), -- strength of speed modification, used as multiplier for the calculated speed mod in all modes
		transporterAltitude		= tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].wantedHeight or 100), -- wanted height of the transporter, used for move type data and can be modified by passengers
		slotSizes               = slotSizes,                    -- set of slot sizes available, eg { [1]=true, [4]=true }
		loadingCount            = 0,                            -- number of load animations in progress
		unloadingCount          = 0,                            -- number of unload animations in progress
	}

	-- set some initial unit rules params for the gadget to read, and for UI display
	for size, bool in pairs (slotSizes) do
		local rulesParamString = "transporterHasSlotOfSize"..size
		SpSetUnitRulesParam(transporterID, rulesParamString, bool)
	end
	SpSetUnitRulesParam(transporterID, "transporterSeats",    cargo.transporterSeats) -- used by gadget to determine if a passenger can be loaded, and by anim handler to determine whether to show hover effect
	SpSetUnitRulesParam(transporterID, "transporterUsedSeats", 0) -- used by gadget to determine if a passenger can be loaded/unloaded, and by anim handler to determine whether to show hover effect
	CargoHandler.CanLoad(true)
	CargoHandler.CanUnload(true)
	return cargo
end


-- hide all slot pieces at startup so they only appear when a unit is being loaded into them
function CargoHandler.HideSlots(cargo)
	for slotID in pairs(cargo.slots) do
		Hide(slotID)
	end
end

-- returns true if this transporter has any slot that accepts units of the given seat cost
function CargoHandler.HasSlotOfSize(size, cargo)
	return cargo.slotSizes[size] == true
end

-- set the rules param the gadget reads to block or allow new load attempts
function CargoHandler.CanLoad(bool)
	SpSetUnitRulesParam(transporterID, "canLoad", bool and 1 or 0)
end

-- set the rules param the gadget reads to block or allow new unload attempts
function CargoHandler.CanUnload(bool)
	SpSetUnitRulesParam(transporterID, "canUnload", bool and 1 or 0)
end

-- track in-progress animation counts to gate CanLoad/CanUnload:
-- loading blocks unloading and vice versa, but multiple simultaneous animations of the same type are allowed
function CargoHandler.BeginLoading(cargo)
	cargo.loadingCount = cargo.loadingCount + 1
	if cargo.loadingCount == 1 then
		CargoHandler.CanUnload(false)
	end
end

function CargoHandler.EndLoading(cargo)
	cargo.loadingCount = math.max(0, cargo.loadingCount - 1)
	if cargo.loadingCount == 0 then
		CargoHandler.CanUnload(true)
	end
end

function CargoHandler.BeginUnloading(cargo)
	cargo.unloadingCount = cargo.unloadingCount + 1
	if cargo.unloadingCount == 1 then
		CargoHandler.CanLoad(false)
	end
end

function CargoHandler.EndUnloading(cargo)
	cargo.unloadingCount = math.max(0, cargo.unloadingCount - 1)
	if cargo.unloadingCount == 0 then
		CargoHandler.CanLoad(true)
	end
end

-- returns true if every slotID in slotData.requires is currently empty
local function RequiresMet(slotData, slots)
	for _, reqID in ipairs(slotData.requires) do
		if slots[reqID] and slots[reqID].cargo ~= nil then
			return false
		end
	end
	return true
end

-- returns the squared XZ distance between passengerID and a slot piece on the transporter
local function SlotDistSq(passengerID, slotID)
	local px, _, pz = SpGetUnitPosition(passengerID)
	local sx, _, sz = Spring.GetUnitPiecePosDir(transporterID, slotID)
	local dx, dz = px - sx, pz - sz
	return dx * dx + dz * dz
end

-- assigns the closest valid slot of the right size to passengerID and returns passengerData, or nil.
-- when allowReorganize is true and only overlapping slots remain available, triggers ReorganizeAndLoad.
-- when fromReorganize is true, overlapping slots are excluded from the search entirely.
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
				local dSq = SlotDistSq(passengerID, slotID)
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
		return { id = passengerID, height = SpGetUnitHeight(passengerID), radius = SpGetUnitRadius(passengerID), slotID = bestSlotID }
	end

	-- only overlapping slots are available: try one (closest)
	if not fromReorganize and hasOverlap then
		for _, slotID in ipairs(sizeList) do
			local slotData = cargo.slots[slotID]
			if slotData.cargo == nil and slotData.overlapping and RequiresMet(slotData, cargo.slots) then
				local dSq = SlotDistSq(passengerID, slotID)
				if dSq < bestDistSq then
					bestDistSq = dSq
					bestSlotID = slotID
				end
			end
		end
		if bestSlotID then
			cargo.slots[bestSlotID].cargo = passengerID
			return { id = passengerID, height = SpGetUnitHeight(passengerID), radius = SpGetUnitRadius(passengerID), slotID = bestSlotID }
		end
	end

	-- no slot at all: maybe reorganize can make room
	if allowReorganize and CargoHandler.HasSlotOfSize(seats, cargo)
		and cargo.transporterUsedSeats + seats <= cargo.transporterSeats then
		CargoHandler.ReorganizeAndLoad(cargo, passengerID)
	end
	return nil
end

-- instantly unloads all current cargo then reloads everything (including newPassengerID) onto non-overlapping
-- slots only, using a greedy closest-slot pass in descending size order.
-- newPassengerID gets first pick (its slot is assigned before all others of the same size).
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
		local tx, ty, tz = SpGetUnitPosition(cargo.transporterID)
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

-- marks a slot as vacant; passengerData is still held in cargo.passengers until Unregister cleans it up
function CargoHandler.ReleaseSlot(slotID, cargo)
	if cargo.slots[slotID] then
		cargo.slots[slotID].cargo = nil
	end
end

-- add a passenger entry to cargo.passengers and update seat/count accounting
function CargoHandler.Register(passengerID, passengerData, cargo)
	cargo.passengers[passengerID] = passengerData
	cargo.count     = cargo.count + 1
	cargo.transporterUsedSeats = cargo.transporterUsedSeats + (cargo.slots[passengerData.slotID].size or 0)
	SpSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
	cargo.passengersTotalWeight = cargo.passengersTotalWeight + (TransportAPI.GetPassengerWeight(passengerID, cargo) or 0)
	cargo.loadedCommandersCount = cargo.loadedCommandersCount + (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0)
	local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "maxSpeed", speedMod * cargo.transporterMaxSpeed)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "accRate", speedMod * cargo.transporterAccRate)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "decRate", speedMod * cargo.transporterDecRate)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "wantedHeight", speedMod * cargo.transporterAltitude)
	return cargo.count
end

-- remove a passenger entry from cargo.passengers, release its slot, and update seat/count accounting
function CargoHandler.Unregister(passengerID, cargo)
	local passengerData = cargo.passengers[passengerID]
	if passengerData and passengerData.slotID then
		cargo.transporterUsedSeats = math.max(0, cargo.transporterUsedSeats - (cargo.slots[passengerData.slotID].size or 0))
		SpSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
		CargoHandler.ReleaseSlot(passengerData.slotID, cargo)
	end
	cargo.passengers[passengerID] = nil
	cargo.count = math.max(0, cargo.count - 1)
	cargo.passengersTotalWeight = math.max(0, cargo.passengersTotalWeight - (TransportAPI.GetPassengerWeight(passengerID,cargo) or 0))
	cargo.loadedCommandersCount = math.max(0, cargo.loadedCommandersCount - (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0))
	local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "maxSpeed", speedMod * cargo.transporterMaxSpeed)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "accRate", speedMod * cargo.transporterAccRate)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "decRate", speedMod * cargo.transporterDecRate)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "wantedHeight", speedMod * cargo.transporterAltitude)	
	return cargo.count
end
