CargoHandler = {}

local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPiecePosDir = Spring.GetUnitPiecePosDir
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitRotation = Spring.GetUnitRotation
local spGetUnitHeight = Spring.GetUnitHeight
local spGetUnitRadius = Spring.GetUnitRadius
local spSetUnitRulesParam = Spring.SetUnitRulesParam
local spMoveCtrlSetGunshipMoveTypeData = Spring.MoveCtrl.SetGunshipMoveTypeData

---@param setup table  slot and speed-damping config from <unitName>/setup.lua
---@return table cargo  initialized cargo state table
function CargoHandler.Init(setup)
	local nameToID = {}
	local function res(name)
		if not nameToID[name] then
			nameToID[name] = piece(name)
		end
		return nameToID[name]
	end

	for _, slot in ipairs(setup.slots) do
		res(slot.name)
	end

	local slots = {}
	local slotsBySize = {}
	for _, slotCfg in ipairs(setup.slots) do
		local pid = nameToID[slotCfg.name]
		local reqs = {}
		for _, reqName in ipairs(slotCfg.requires) do
			reqs[#reqs + 1] = nameToID[reqName]
		end
		slots[pid] = {
			size = slotCfg.size,
			cargo = nil,
			requires = reqs,
			overlapping = slotCfg.overlapping,
		}
		if not slotsBySize[slotCfg.size] then
			slotsBySize[slotCfg.size] = {}
		end
		slotsBySize[slotCfg.size][#slotsBySize[slotCfg.size] + 1] = pid
	end

	local slotSizes = {}
	for size in pairs(slotsBySize) do
		slotSizes[size] = true
	end

	local uDef = UnitDefs[spGetUnitDefID(transporterID)]
	local cargo = {
		transporterID = transporterID,
		slots = slots,
		slotsBySize = slotsBySize,
		passengers = {},
		count = 0,
		transporterUsedSeats = 0,
		transporterSeats = tonumber(uDef.customParams.transporterseats or 0),
		transporterMaxSpeed = uDef.speed,
		transporterAccRate = uDef.maxAcc,
		transporterDecRate = uDef.maxDec,
		transporterTurnRate = uDef.turnRate,
		loadedCommandersCount = 0,
		passengersTotalWeight = 0,
		transporterSpeedModMode = tonumber(uDef.customParams.transporterspeedmodmode or 0),
		transporterSpeedModStrength = tonumber(uDef.customParams.transporterspeedmodstrength or 0),
		transporterComSpeedModStrength = tonumber(uDef.customParams.transportercomspeedmodstrength or 0),
		transporterAltitude = tonumber(uDef.wantedHeight or 100),
		slotSizes = slotSizes,
		loadingCount = 0,
		unloadingCount = 0,
	}
	cargo.currentMaxPassengerHeight = function()
		local maxHeight = 0
		for _, passengerData in pairs(cargo.passengers) do
			if passengerData.height and passengerData.height > maxHeight then
				maxHeight = passengerData.height
			end
		end
		return maxHeight
	end

	for size, bool in pairs(slotSizes) do
		local rulesParamString = "transporterHasSlotOfSize" .. size
		spSetUnitRulesParam(transporterID, rulesParamString, bool)
	end
	CargoHandler.SetSpeedDamping(1.0, cargo, true)
	spSetUnitRulesParam(transporterID, "transporterSeats", cargo.transporterSeats)
	spSetUnitRulesParam(transporterID, "transporterUsedSeats", 0)
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
	if not sizeList then
		return nil
	end

	local bestSlotID = nil
	local bestDistSq = math.huge
	local hasOverlap = false

	for _, slotID in ipairs(sizeList) do
		local slotData = cargo.slots[slotID]
		if slotData.cargo == nil and RequiresMet(slotData, cargo.slots) then
			if slotData.overlapping then
				if not fromReorganize then
					hasOverlap = true
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

	if bestSlotID then
		cargo.slots[bestSlotID].cargo = passengerID
		return {
			id = passengerID,
			height = spGetUnitHeight(passengerID),
			radius = spGetUnitRadius(passengerID),
			slotID = bestSlotID,
		}
	end

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
			return {
				id = passengerID,
				height = spGetUnitHeight(passengerID),
				radius = spGetUnitRadius(passengerID),
				slotID = bestSlotID,
			}
		end
	end

	if
		allowReorganize
		and CargoHandler.HasSlotOfSize(seats, cargo)
		and cargo.transporterUsedSeats + seats <= cargo.transporterSeats
	then
		CargoHandler.ReorganizeAndLoad(cargo, passengerID)
	end
	return nil
end

---@param cargo table
---@param newPassengerID number
function CargoHandler.ReorganizeAndLoad(cargo, newPassengerID)
	Signal(TransportAnimator.SIG_LOAD)
	cargo.loadingCount = 0
	CargoHandler.CanUnload(true)

	local newSize = TransportAPI.GetPassengerSize(newPassengerID)
	local toLoad = { newPassengerID }
	for passengerID in pairs(cargo.passengers) do
		toLoad[#toLoad + 1] = passengerID
	end
	table.sort(toLoad, function(a, b)
		local sa = TransportAPI.GetPassengerSize(a)
		local sb = TransportAPI.GetPassengerSize(b)
		if sa ~= sb then
			return sa > sb
		end
		if a == newPassengerID then
			return true
		end
		if b == newPassengerID then
			return false
		end
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
		spMoveCtrlSetGunshipMoveTypeData(
			cargo.transporterID,
			"wantedHeight",
			math.max(cargo.currentMaxPassengerHeight() + 10, speedMod * cargo.transporterAltitude)
		)
	end
end

---@param passengerID number
---@param passengerData table
---@param cargo table
---@return number count  total passengers currently loaded
function CargoHandler.Register(passengerID, passengerData, cargo)
	cargo.passengers[passengerID] = passengerData
	cargo.count = cargo.count + 1
	cargo.transporterUsedSeats = cargo.transporterUsedSeats + (cargo.slots[passengerData.slotID].size or 0)
	spSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
	cargo.passengersTotalWeight = cargo.passengersTotalWeight
		+ (TransportAPI.GetPassengerWeight(passengerID, cargo) or 0)
	cargo.loadedCommandersCount = cargo.loadedCommandersCount
		+ (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0)
	CargoHandler.SetSpeedDamping(0.2, cargo, false)
	return cargo.count
end

---@param passengerID number
---@param cargo table
---@return number count  total passengers currently loaded
function CargoHandler.Unregister(passengerID, cargo)
	local passengerData = cargo.passengers[passengerID]
	if passengerData and passengerData.slotID then
		cargo.transporterUsedSeats =
			math.max(0, cargo.transporterUsedSeats - (cargo.slots[passengerData.slotID].size or 0))
		spSetUnitRulesParam(cargo.transporterID, "transporterUsedSeats", cargo.transporterUsedSeats)
		CargoHandler.ReleaseSlot(passengerData.slotID, cargo)
	end
	cargo.passengers[passengerID] = nil
	cargo.count = math.max(0, cargo.count - 1)
	cargo.passengersTotalWeight =
		math.max(0, cargo.passengersTotalWeight - (TransportAPI.GetPassengerWeight(passengerID, cargo) or 0))
	cargo.loadedCommandersCount =
		math.max(0, cargo.loadedCommandersCount - (TransportAPI.IsPassengerCommander(passengerID) and 1 or 0))
	local speedMod = TransportAPI.CalculateTransporterSpeed(cargo)
	CargoHandler.SetSpeedDamping(speedMod, cargo, true)
	return cargo.count
end
