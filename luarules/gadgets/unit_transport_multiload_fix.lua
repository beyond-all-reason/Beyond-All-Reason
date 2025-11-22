local gadget = gadget

function gadget:GetInfo()
    return {
        name = "Multi Transport Fix",
        desc = "Improved multi-slot transport handling",
        author = "Codex",
        date = "2024",
        license = "GPLv2",
        layer = 0,
        enabled = true,
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

local modOptions = Spring.GetModOptions() or {}
local useFix = modOptions.fixtransportermultiload

if not useFix then
    return false
end

local maxSlots = {}
for id, def in pairs(UnitDefs) do
    if def.isTransport then
        maxSlots[id] = def.transportCapacity or 0
    end
end

local currentSlots = {}
local transported = {}

function gadget:AllowUnitTransportLoad(transID, transDefID, transTeam, unitID, unitDefID, unitTeam, x, y, z)
    if (currentSlots[transID] or 0) >= (maxSlots[transDefID] or 0) then
        return false
    end
    return true
end

function gadget:UnitLoaded(unitID, unitDefID, unitTeam, transID, transTeam)
    currentSlots[transID] = (currentSlots[transID] or 0) + 1
    transported[unitID] = transID
end

local function removeUnit(unitID)
    local transID = transported[unitID]
    if transID and currentSlots[transID] then
        currentSlots[transID] = currentSlots[transID] - 1
        if currentSlots[transID] <= 0 then
            currentSlots[transID] = nil
        end
    end
    transported[unitID] = nil
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transID)
    removeUnit(unitID)
end

function gadget:UnitDestroyed(unitID)
    removeUnit(unitID)
    currentSlots[unitID] = nil
end
