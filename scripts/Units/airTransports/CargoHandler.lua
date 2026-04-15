-- TODOs:
-- >> move command processing to gadget level entirely, script should just receive transportee and pos and perform load/unload
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
    for _, slotCfg in ipairs(setup.slots) do
        local pid  = nameToID[slotCfg.name]
        local reqs = {}
        for _, reqName in ipairs(slotCfg.requires) do
            reqs[#reqs + 1] = nameToID[reqName]
        end
        slots[pid] = {
            size     = slotCfg.size,  -- seat cost of a unit that fits this slot (1/4/8/16)
            cargo    = nil,           -- transporteeID currently occupying this slot, nil if empty
            requires = reqs,          -- list of slotIDs that must be empty for this slot to be usable
        }
    end

    local slotSizes = {}
    local slotSizesArr = {}
    for _, slotCfg in ipairs(setup.slots) do
        if not slotSizes[slotCfg.size] then
            slotSizes[slotCfg.size] = true
            slotSizesArr[#slotSizesArr + 1] = tostring(slotCfg.size)
        end
    end

    -- source of truth for all cargo tracking; all load/unload operations read and write this table.
    -- on save/load the engine is queried for current transportees and this table is rebuilt from scratch (see script.Create),
    -- but outside of that reload path this is the only authoritative record of what is loaded and where.
    local cargo = {
        unitID         = unitID,                    -- transporter unit ID
        slots          = slots,                     -- [slotID] = { size, cargo, requires } (see above)
        primarySlot    = nameToID[setup.primarySlot], -- slotID used for single-unit commands
        transportees   = {},                        -- [transporteeID] = teeData  ({ id, height, slotID, beamPieces, wbX/Y/Z, animProgress })
        count          = 0,                         -- number of units currently loaded
        usedSeats      = 0,                         -- sum of seat costs of all loaded units
        nSeats         = setup.nSeats,              -- total seat capacity of this transporter
        slotSizes      = slotSizes,                 -- set of slot sizes available, eg { [1]=true, [4]=true }
        loadingCount   = 0,                         -- number of load animations in progress
        unloadingCount = 0,                         -- number of unload animations in progress
    }

    -- set some initial unit rules params for the gadget to read, and for UI display
    SpSetUnitRulesParam(unitID, "nSeats",    setup.nSeats) -- used by gadget to determine if a transportee can be loaded, and by anim handler to determine whether to show hover effect
    SpSetUnitRulesParam(unitID, "usedSeats", 0) -- used by gadget to determine if a transportee can be loaded/unloaded, and by anim handler to determine whether to show hover effect
    SpSetUnitRulesParam(unitID, "slotSizes", table.concat(slotSizesArr, ",")) -- helps know what sizes of transportees we can expect to load, in case of ie 4x 1-sized spots but no 4 sized spot (2x8 transport vs 4x4)
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
    SpSetUnitRulesParam(unitID, "canLoad", bool and 1 or 0)
end

-- set the rules param the gadget reads to block or allow new unload attempts
function CargoHandler.CanUnload(bool)
    SpSetUnitRulesParam(unitID, "canUnload", bool and 1 or 0)
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

-- assigns a slot to the incoming transportee and returns its teeData, or nil if no slot is available.
-- if no direct slot match is found but reorganizing could make room, triggers ReorganizeAndLoad instead.
function CargoHandler.FindSlot(transporteeID, cargo, allowReorganize)
    local seats = TransportAPI.GetTransporteeSize(transporteeID)
    for slotID, slotData in pairs(cargo.slots) do
        if slotData.cargo == nil and slotData.size == seats then
            local ok = true
            for _, reqID in ipairs(slotData.requires) do
                if cargo.slots[reqID] and cargo.slots[reqID].cargo ~= nil then
                    ok = false
                    break
                end
            end
            if ok then
                slotData.cargo = transporteeID
                return { id = transporteeID, height = SpGetUnitHeight(transporteeID), slotID = slotID }
            end
        end
    end
    if allowReorganize and CargoHandler.HasSlotOfSize(seats, cargo)
           and cargo.usedSeats + seats <= cargo.nSeats then
        CargoHandler.ReorganizeAndLoad(cargo, transporteeID)
        return nil
    end
    return nil
end

-- instantly unloads all current cargo then reloads everything (including newTeeID) in decreasing size order,
-- so that larger units always claim the most appropriate slots first
function CargoHandler.ReorganizeAndLoad(cargo, newTeeID)
    -- kill all in-flight Load threads at once and repair the accounting they left dangling
    Signal(TransportAnimator.SIG_LOAD)
    cargo.loadingCount = 0
    CargoHandler.CanUnload(true)

    local toLoad = {}
    for teeID in pairs(cargo.transportees) do
        toLoad[#toLoad + 1] = teeID
    end
    toLoad[#toLoad + 1] = newTeeID
    table.sort(toLoad, function(a, b)
        return TransportAPI.GetTransporteeSize(a) > TransportAPI.GetTransporteeSize(b)
    end)

    local teeSnapshot = {}
    for teeID, teeData in pairs(cargo.transportees) do
        teeSnapshot[teeID] = teeData
    end
    for teeID, teeData in pairs(teeSnapshot) do
        local terX, terY, terZ = SpGetUnitPosition(cargo.unitID)
        TransportAnimator.Unload(teeData, terX, terY, terZ, false)
    end

    for _, teeID in ipairs(toLoad) do
        local teeData = CargoHandler.FindSlot(teeID, cargo)
        if teeData then
            StartThread(TransportAnimator.Load, teeData)
        end
    end
end

-- marks a slot as vacant; teeData is still held in cargo.transportees until Unregister cleans it up
function CargoHandler.ReleaseSlot(slotID, cargo)
    if cargo.slots[slotID] then
        cargo.slots[slotID].cargo = nil
    end
end

-- add a transportee entry to cargo.transportees and update seat/count accounting
function CargoHandler.Register(transporteeID, teeData, cargo)
    cargo.transportees[transporteeID] = teeData
    cargo.count     = cargo.count + 1
    cargo.usedSeats = cargo.usedSeats + (cargo.slots[teeData.slotID].size or 0)
    SpSetUnitRulesParam(cargo.unitID, "usedSeats", cargo.usedSeats)
    return cargo.count
end

-- remove a transportee entry from cargo.transportees, release its slot, and update seat/count accounting
function CargoHandler.Unregister(transporteeID, cargo)
    local teeData = cargo.transportees[transporteeID]
    if teeData and teeData.slotID then
        cargo.usedSeats = math.max(0, cargo.usedSeats - (cargo.slots[teeData.slotID].size or 0))
        SpSetUnitRulesParam(cargo.unitID, "usedSeats", cargo.usedSeats)
        CargoHandler.ReleaseSlot(teeData.slotID, cargo)
    end
    cargo.transportees[transporteeID] = nil
    cargo.count = math.max(0, cargo.count - 1)
    return cargo.count
end
