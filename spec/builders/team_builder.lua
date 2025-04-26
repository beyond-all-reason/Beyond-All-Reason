-- Team Builder
-- Builds individual team/player configurations with automatic ID generation

---@class UnitWrapper
---@field unitDefId string
---@field [string] any Additional unit definition properties when loaded

local Sides = require("gamedata/sides_enum")
local Definitions = require("luaui/Include/blueprint_substitution/definitions")

local sequence = require("spec/builders/sequence")

-- Global cache for unit definitions
local _globalUnitDefs = {}

---@class TeamBuilder
---@field id number Team ID assigned by SpringBuilder
---@field isHuman boolean
---@field playerName string
---@field metal ResourceData
---@field energy ResourceData
---@field units table<number, UnitWrapper> unitID -> wrapper object with unitDefId and splatted unitDef properties
---@field _unitIdSequence function: number
local TeamBuilder = {}
TeamBuilder.__index = TeamBuilder

---@type TeamData
local defaultData = {
    id = 0,
    isHuman = true,
    name = "Player",
    units = {},
    metal = {
        current = 1000,
        storage = 1000,
        pull = 0,
        income = 0,
        expense = 0,
        shareSlider = 100,
        sent = 0,
        received = 0
    },
    energy = {
        current = 1000,
        storage = 1000,
        pull = 0,
        income = 0,
        expense = 0,
        shareSlider = 100,
        sent = 0,
        received = 0
    },
}

local nextTeamId = sequence.sequence("team_id", { start = 0, format = function(p, n) return tostring(n) end })
local nextUnitId = sequence.sequence("unit_id", { start = 1, format = function(p, n) return tostring(n) end })

-- Create the builder using metatable approach
---@class TeamBuilder
local TeamBuilder = {}
TeamBuilder.__index = TeamBuilder

function TeamBuilder.new()
    local instance = {}

    -- Copy default data
    for k, v in pairs(defaultData) do
        if type(v) == "table" then
            local t = {}
            for k2, v2 in pairs(v) do t[k2] = v2 end
            instance[k] = t
        else
            instance[k] = v
        end
    end

    -- Assign unique ID immediately to prevent collisions
    instance.id = tonumber(nextTeamId())

    -- Unit IDs are now globally unique

    return setmetatable(instance, TeamBuilder)
end

function TeamBuilder:Build()
    -- If called on the class/table itself, create a proper instance first
    if self == TeamBuilder then
        local instance = TeamBuilder.new()
        instance.isHuman = self.isHuman or true
        instance.playerName = self.playerName
        return instance:Build()
    end

    local teamId = self.id
    local out = {
        id = teamId,
        isHuman = self.isHuman,
        playerName = self.playerName,
        units = self.units,
        metal = self.metal,
        energy = self.energy,
    }
    return out
end

function TeamBuilder:WithEnergy(energy)
    self.energy.current = energy
    return self
end

function TeamBuilder:WithEnergyStorage(storage)
    self.energy.storage = storage
    return self
end

function TeamBuilder:WithMetal(metal)
    self.metal.current = metal
    return self
end

function TeamBuilder:WithMetalStorage(storage)
    self.metal.storage = storage
    return self
end

-- Methods for setting complete resource data
function TeamBuilder:WithMetalData(metalData)
    self.metal = metalData
    return self
end

function TeamBuilder:WithEnergyData(energyData)
    self.energy = energyData
    return self
end

-- Methods for individual resource properties
function TeamBuilder:WithMetalPull(pull)
    self.metal.pull = pull
    return self
end

function TeamBuilder:WithMetalIncome(income)
    self.metal.income = income
    return self
end

function TeamBuilder:WithMetalExpense(expense)
    self.metal.expense = expense
    return self
end

function TeamBuilder:WithMetalShareSlider(shareSlider)
    self.metal.shareSlider = shareSlider
    return self
end

function TeamBuilder:WithMetalSent(sent)
    self.metal.sent = sent
    return self
end

function TeamBuilder:WithMetalReceived(received)
    self.metal.received = received
    return self
end

function TeamBuilder:WithEnergyPull(pull)
    self.energy.pull = pull
    return self
end

function TeamBuilder:WithEnergyIncome(income)
    self.energy.income = income
    return self
end

function TeamBuilder:WithEnergyExpense(expense)
    self.energy.expense = expense
    return self
end

function TeamBuilder:WithEnergyShareSlider(shareSlider)
    self.energy.shareSlider = shareSlider
    return self
end

function TeamBuilder:WithEnergySent(sent)
    self.energy.sent = sent
    return self
end

function TeamBuilder:WithEnergyReceived(received)
    self.energy.received = received
    return self
end

function TeamBuilder:Human()
    self.isHuman = true
    return self
end

function TeamBuilder:AI()
    self.isHuman = false
    return self
end

---@param unitDefId string
---@return table?
local function getUnitDef(unitDefId)
    -- Check global UnitDefs first (for test compatibility)
    if _G.UnitDefs and _G.UnitDefs[unitDefId] then
        return _G.UnitDefs[unitDefId]
    end

    -- Then check local cache
    if not _globalUnitDefs or next(_globalUnitDefs) == nil then
        return nil
    end

    local unitDef = _globalUnitDefs[unitDefId]
    if not unitDef then
        error("UnitDefId '" .. unitDefId .. "' not found")
    end
    return unitDef
end

function TeamBuilder:WithUnit(unitDefID, unitIdCallback)
    local unitDef = getUnitDef(unitDefID)
    local unitID = nextUnitId()

    -- Always create consistent wrapper object
    local unitWrapper = { unitDefId = unitDefID }

    -- Splat unitDef properties when available
    if unitDef then
        for k, v in pairs(unitDef) do
            unitWrapper[k] = v
        end
    end

    self.units[unitID] = unitWrapper

    if unitIdCallback then
        unitIdCallback(unitID)
    end

    return self
end

function TeamBuilder:WithUnitFromCategory(category, side)
    local actualSide = side or Sides.ARMADA
    local unitDefId = Definitions.getUnitByCategory(category, actualSide)
    if not unitDefId then
        error("WithUnitFromCategory: getUnitByCategory returned nil for category '" .. tostring(category) .. "' and side '" .. tostring(actualSide) .. "'")
    end

    return self:WithUnit(unitDefId)
end

return TeamBuilder