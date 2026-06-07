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
		transporterTurnRate		= UnitDefs[Spring.GetUnitDefID(transporterID)].turnRate, -- base turn rate of the transporter, used for speed calculations
		loadedCommandersCount	= 0,							-- number of loaded commanders
		passengersTotalWeight	= 0,                            -- sum of "weights" of all loaded units, used for speed slowing
		transporterSpeedModMode = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transporterspeedmodmode or 0),
		-- type of speed modification to apply:
		-- 0 = no speed modification
		-- 1 = speedNerf = (usedSeats/nSeats) * transporterSpeedModStrength
		-- 2 = speedNerf = ((passengersTotalWeight-transporterSeats) / (transporterSeats * 0.5)) * transporterSpeedModStrength
		-- passengersTotalWeight = sum(passengerSize * ((oversized and 1.5) or 1))
		-- this makes the slowdown based on excess, not cargo
		transporterSpeedModStrength = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transporterspeedmodstrength or 0), -- strength of speed modification, used as multiplier for the calculated speed mod in all modes
		-- set to > 0 value to enable; effect depends on transporterSpeedModMode
		transporterComSpeedModStrength = tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].customParams.transportercomspeedmodstrength or 0), -- separate speed mod strength for commanders, used in modes 1 and 3 as an override if it's higher than the regular mod strength
		-- set to > 0 value to enable; slows down the transporter if it has a loaded commander
		-- the resultant speedNerf value is then math.max(speedNerf, comSpeedNerf)
		transporterAltitude		= tonumber(UnitDefs[Spring.GetUnitDefID(transporterID)].wantedHeight or 100), -- wanted height of the transporter, used for move type data and can be modified by passengers
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
		SpSetUnitRulesParam(transporterID, rulesParamString, bool)
	end
	CargoHandler.SetSpeedDamping(1.0, cargo, true) -- make sure no silent damping stays after a reload, will be reapplied if necessary.
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
		local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
		CargoHandler.SetSpeedDamping(speedMod, cargo, true)
		CargoHandler.CanUnload(true)
	end
end

function CargoHandler.BeginUnloading(cargo)
	cargo.unloadingCount = cargo.unloadingCount + 1
	CargoHandler.SetSpeedDamping(0.2, cargo, false)
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
local function PassengerToSlotDistSq(passengerID, slotID)
	local px, _, pz = SpGetUnitPosition(passengerID)
	local sx, _, sz = Spring.GetUnitPiecePosDir(transporterID, slotID)
	local dx, dz = px - sx, pz - sz
	return dx * dx + dz * dz
end

-- axis-weighted distance: penalizes lateral movement (orthogonal to the transporter's main axis)
-- via 1/|dot(forwardDir, displacementDir)|, biasing displaced passengers toward moving along
-- the transport axis rather than crossing to the opposite side of the aircraft.
-- guards against NaN: clamps the denominator to MIN_COS so factor never exceeds 1/MIN_COS.
local AXIS_WEIGHT_MIN_COS = 0.15  -- movements beyond ~81 deg off-axis capped at ~6.7x penalty
local function PassengerToSlotAxisWeightedDistSq(passengerID, slotID)
	local px, _, pz = SpGetUnitPosition(passengerID)
	local sx, _, sz = Spring.GetUnitPiecePosDir(transporterID, slotID)
	local dx, dz = sx - px, sz - pz
	local dSq = dx * dx + dz * dz
	if dSq < 1e-4 then return 0 end  -- passenger already at slot: no penalty
	-- transporter forward in XZ: (sin rotY, cos rotY) at rotY=0 faces +Z
	local _, rotY, _ = SpGetUnitRotation(transporterID)
	local fwdX, fwdZ = math.sin(rotY), math.cos(rotY)
	local dLen    = math.sqrt(dSq)
	local cosTheta = (fwdX * dx + fwdZ * dz) / dLen  -- dot(forward, normalizedDisplacement)
	local factor  = 1 / math.max(math.abs(cosTheta), AXIS_WEIGHT_MIN_COS)
	return dSq * factor
end

-- Assigns the closest slot of the right size to passengerID and returns passengerData, or nil.
-- Fast path: closest slot is free and all requirements met — claim immediately, no side effects.
-- Cascade path: new passenger unconditionally takes the closest slot; only directly conflicting
-- passengers are displaced (occupant of claimed slot + occupants of ANY slot now blocked by it,
-- regardless of size), cascading outward until all conflicts are resolved. Each displaced passenger
-- picks the slot nearest to THEMSELVES (axis-weighted to avoid visual cross-overs), searching only
-- slots of their own size.
-- Fully attached passengers (animProgress == 1) are silently detached then re-animated to their
-- new slot. Mid-load passengers (animProgress < 1) receive a redirectSlot that their running
-- Load thread picks up on its next frame, reorienting the animation in-place with no restart.
function CargoHandler.FindSlot(passengerID, cargo)
	local seats = TransportAPI.GetPassengerSize(passengerID)
	local sizeList = cargo.slotsBySize[seats]
	if not sizeList then return nil end

	-- build slot list sorted by distance to the incoming passenger
	local orderedSlots = {}
	for _, slotID in ipairs(sizeList) do
		orderedSlots[#orderedSlots + 1] = { slotID = slotID, dSq = PassengerToSlotDistSq(passengerID, slotID) }
	end
	table.sort(orderedSlots, function(a, b) return a.dSq < b.dSq end)

	-- fast path: closest slot is free and all requirements met
	local closest = orderedSlots[1]
	if closest then
		local slotData = cargo.slots[closest.slotID]
		if slotData.cargo == nil and RequiresMet(slotData, cargo.slots) then
			cargo.slots[closest.slotID].cargo = passengerID
			return { id = passengerID, height = SpGetUnitHeight(passengerID), radius = SpGetUnitRadius(passengerID), slotID = closest.slotID }
		end
	end
	if not closest then return nil end

	-- cascade path ----------------------------------------------------------
	-- closeAndPropagate: marks sid unavailable and enqueues the occupant of sid
	-- plus occupants of any slot now blocked because sid is taken.
	local closedSlots   = {}
	local assignments   = {}  -- [passengerID] = slotID
	local displaceQueue = {}
	local alreadyQueued = { [passengerID] = true }

	local function closeAndPropagate(sid)
		closedSlots[sid] = true
		local occ = cargo.slots[sid].cargo
		if occ and not alreadyQueued[occ] then
			displaceQueue[#displaceQueue + 1] = occ
			alreadyQueued[occ] = true
		end
		-- slots that sid requires to be empty are now blocked
		for _, reqID in ipairs(cargo.slots[sid].requires) do
			if not closedSlots[reqID] then
				closedSlots[reqID] = true
				local occ2 = cargo.slots[reqID].cargo
				if occ2 and not alreadyQueued[occ2] then
					displaceQueue[#displaceQueue + 1] = occ2
					alreadyQueued[occ2] = true
				end
			end
		end
		-- slots that require sid to be empty are now blocked; search ALL slots regardless of size
		for slotID, slotData in pairs(cargo.slots) do
			if not closedSlots[slotID] then
				for _, reqID in ipairs(slotData.requires) do
					if reqID == sid then
						closedSlots[slotID] = true
						local occ3 = slotData.cargo
						if occ3 and not alreadyQueued[occ3] then
							displaceQueue[#displaceQueue + 1] = occ3
							alreadyQueued[occ3] = true
						end
						break
					end
				end
			end
		end
	end

	-- new passenger unconditionally takes the closest slot
	assignments[passengerID] = closest.slotID
	closeAndPropagate(closest.slotID)

	-- cascade: each displaced passenger picks the nearest available slot to THEMSELVES
	local idx = 1
	while idx <= #displaceQueue do
		local pid = displaceQueue[idx]
		idx = idx + 1

		-- each displaced passenger searches slots of THEIR OWN size, axis-weighted
		local pidSize     = TransportAPI.GetPassengerSize(pid)
		local pidSizeList = cargo.slotsBySize[pidSize]
		if not pidSizeList then
			Spring.Echo("CargoHandler.FindSlot: displaced passenger " .. pid .. " has no slots of its size")
		else
			local pidSlots = {}
			for _, slotID in ipairs(pidSizeList) do
				pidSlots[#pidSlots + 1] = { slotID = slotID, dSq = PassengerToSlotAxisWeightedDistSq(pid, slotID) }
			end
			table.sort(pidSlots, function(a, b) return a.dSq < b.dSq end)

			local chosenSlot = nil
			for _, e in ipairs(pidSlots) do
				if not closedSlots[e.slotID] and not cargo.slots[e.slotID].overlapping then
					chosenSlot = e.slotID ; break
				end
			end
			if not chosenSlot then
				for _, e in ipairs(pidSlots) do
					if not closedSlots[e.slotID] then
						chosenSlot = e.slotID ; break
					end
				end
			end
			if chosenSlot then
				assignments[pid] = chosenSlot
				closeAndPropagate(chosenSlot)
			else
				Spring.Echo("CargoHandler.FindSlot: no available slot for displaced passenger " .. pid)
			end
		end
	end

	-- snapshot pd references and attachment state before any mutations
	local pdSnap     = {}
	local wasAttached = {}
	for _, pid in ipairs(displaceQueue) do
		local pd = cargo.passengers[pid]
		pdSnap[pid]      = pd
		wasAttached[pid] = pd and (pd.animProgress == 1)
	end

	-- apply phase 1: release all displaced passengers from their current slots.
	-- all releases happen before any new claims to avoid clobbering when passengers swap slots.
	local tx, ty, tz = SpGetUnitPosition(cargo.transporterID)
	for _, pid in ipairs(displaceQueue) do
		local pd = pdSnap[pid]
		if pd then
			if wasAttached[pid] then
				-- fully attached: silent detach-in-place; Unregister releases slot and cargo.passengers
				TransportAnimator.Unload(pd, tx, ty, tz, false)
				pd.unloading = nil
			else
				-- mid-load: Load thread is still alive; vacate the slot record so phase 2 can claim it
				cargo.slots[pd.slotID].cargo = nil
			end
		end
	end

	-- apply phase 2: claim new slots and redirect or restart animations
	for _, pid in ipairs(displaceQueue) do
		local pd      = pdSnap[pid]
		local newSlot = assignments[pid]
		if pd and newSlot then
			cargo.slots[newSlot].cargo = pid
			if wasAttached[pid] then
				-- Unload removed pd from cargo.passengers; restart Load from current detached position
				pd.slotID = newSlot
				StartThread(TransportAnimator.Load, pd)
			else
				-- pre-position new slot to -height immediately so beam rendering is correct
				-- before the Load thread picks up the redirect on its next Sleep boundary
				Move(newSlot, 1, 0)  Move(newSlot, 2, -pd.height)  Move(newSlot, 3, 0)
				Turn(newSlot, 1, 0)  Turn(newSlot, 2, 0)           Turn(newSlot, 3, 0)
				pd.redirectSlot = newSlot
			end
		end
	end

	-- claim slot for new passenger and return passengerData; PerformLoad starts its Load thread
	local newSlot = assignments[passengerID]
	if not newSlot then return nil end
	cargo.slots[newSlot].cargo = passengerID
	return { id = passengerID, height = SpGetUnitHeight(passengerID), radius = SpGetUnitRadius(passengerID), slotID = newSlot }
end

-- marks a slot as vacant; passengerData is still held in cargo.passengers until Unregister cleans it up
function CargoHandler.ReleaseSlot(slotID, cargo)
	if cargo.slots[slotID] then
		cargo.slots[slotID].cargo = nil
	end
end

function CargoHandler.SetSpeedDamping(speedMod, cargo, changeAltitude)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "maxWantedSpeed", speedMod * cargo.transporterMaxSpeed)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "maxSpeed", speedMod * cargo.transporterMaxSpeed)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "accRate", speedMod * cargo.transporterAccRate)
	Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "turnRate", speedMod * cargo.transporterTurnRate)
	if changeAltitude then
		Spring.MoveCtrl.SetGunshipMoveTypeData(cargo.transporterID, "wantedHeight", math.max(cargo.currentMaxPassengerHeight() + 10, speedMod * cargo.transporterAltitude))	
	end
end

-- add a passenger entry to cargo.passengers and update seat/count accounting
function CargoHandler.Register(passengerID, passengerData, cargo) -- marks the start of begin loading
	cargo.passengers[passengerID] = passengerData
	cargo.count     = cargo.count + 1
	cargo.transporterUsedSeats = cargo.transporterUsedSeats + (cargo.slots[passengerData.slotID].size or 0)
	SpSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
	cargo.passengersTotalWeight = cargo.passengersTotalWeight + (TransportAPI.GetPassengerWeight(passengerID, cargo) or 0)
	cargo.loadedCommandersCount = cargo.loadedCommandersCount + (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0)
	local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
	CargoHandler.SetSpeedDamping(0.2, cargo, false)
	return cargo.count
end

-- remove a passenger entry from cargo.passengers, release its slot, and update seat/count accounting
function CargoHandler.Unregister(passengerID, cargo) -- marks the end of unloading
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
	CargoHandler.SetSpeedDamping(speedMod, cargo, true)
	return cargo.count
end
