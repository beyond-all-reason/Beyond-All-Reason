-- Team Builder
-- Builds individual team/player configurations with automatic ID generation

local Sides = require("gamedata/sides_enum")
local Definitions = require("luaui/Include/blueprint_substitution/definitions")

local sequence = require("spec/builders/sequence")

---@class TeamBuilder
---@field id number Team ID assigned by SpringBuilder
---@field name string Team name
---@field isHuman boolean
---@field playerName string
---@field leader number
---@field isDead boolean
---@field side string
---@field allyTeam number
---@field units table<number, UnitWrapper> unitID -> wrapper object with unitDefId and splatted unitDef properties
---@field metal ResourceData
---@field energy ResourceData
local TeamBuilder = {}
TeamBuilder.__index = TeamBuilder

---@type TeamData
local defaultData = {
    id = 0,
    name = "Team",
    isHuman = true,
    playerName = "Player",
    leader = 0,
    isDead = false,
    isAI = false,
    side = Sides.ARMADA,
    allyTeam = 0,
    units = {},
    players = {},
    metal = {
        current = 1000,
        storage = 1000,
        pull = 0,
        income = 0,
        expense = 0,
        shareSlider = 100,
        sent = 0,
        received = 0,
        excess = 0,
    },
    energy = {
        current = 1000,
        storage = 1000,
        pull = 0,
        income = 0,
        expense = 0,
        shareSlider = 100,
        sent = 0,
        received = 0,
        excess = 0,
    },
}

local nextTeamId = sequence.sequence("team_id", { start = 0, format = function(p, n) return tostring(n) end })
local nextUnitId = sequence.sequence("unit_id", { start = 1, format = function(p, n) return tostring(n) end })

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
    instance.leader = instance.id
    instance.allyTeam = instance.id

    -- Initialize default leader player for this team
    instance.players = {
        {
            id = instance.leader,
            name = instance.playerName,
            active = true,
            spectator = false,
            pingTime = 0,
            cpuUsage = 0,
            country = "XX",
            rank = 0,
            hasSkirmishAIsInTeam = false,
            playerOpts = {},
            desynced = false,
        }
    }

    return setmetatable(instance, { __index = TeamBuilder })
end

function TeamBuilder:Build()
    ---@type TeamData
    local out = {
        id = self.id,
        name = self.name,
        isHuman = self.isHuman,
        playerName = self.playerName,
        leader = self.leader,
        isDead = self.isDead,
        isAI = not self.isHuman,
        side = self.side,
        allyTeam = self.allyTeam,
        units = self.units,
        players = self.players,
        metal = self.metal,
        energy = self.energy,
    }
    return out
end

---@param self TeamBuilder
---@param metal number
---@return TeamBuilder
function TeamBuilder:WithMetal(metal)
    self.metal.current = metal
    return self
end

---@param self TeamBuilder
---@param unitDefID string
---@param unitIdCallback fun(unitID: number)|nil
---@return TeamBuilder
function TeamBuilder:WithUnit(unitDefID, unitIdCallback)
    local rawUnitId = nextUnitId()
    local unitID = tonumber(rawUnitId)
    if unitID == nil then
        error(string.format("Generated unit ID '%s' is not numeric", tostring(rawUnitId)))
    end

    -- Create wrapper object with just the unitDefId - real data populated later by SpringBuilder
    local unitWrapper = { unitDefId = unitDefID }

    local units = self.units
    if units == nil then
        units = {}
        self.units = units
    end
    units[unitID] = unitWrapper

    if unitIdCallback then
        unitIdCallback(unitID)
    end

    return self
end

---@param self TeamBuilder
---@return TeamBuilder
function TeamBuilder:AI()
    self.isHuman = false
    return self
end

---@param self TeamBuilder
---@return TeamBuilder
function TeamBuilder:Human()
    self.isHuman = true
    return self
end

---@param self TeamBuilder
---@param energy number
---@return TeamBuilder
function TeamBuilder:WithEnergy(energy)
    self.energy.current = energy
    return self
end

---@param self TeamBuilder
---@param storage number
---@return TeamBuilder
function TeamBuilder:WithEnergyStorage(storage)
    self.energy.storage = storage
    return self
end

function TeamBuilder:WithMetalStorage(storage)
    self.metal.storage = storage
    return self
end

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

---@param self TeamBuilder
---@param playerId number
---@param opts table|nil
---@return TeamBuilder
function TeamBuilder:WithPlayer(playerId, opts)
    local player = {
        id = playerId,
        name = (opts and opts.name) or self.playerName,
        active = (opts and opts.active) ~= false,
        spectator = (opts and opts.spectator) or false,
        pingTime = (opts and opts.pingTime) or 0,
        cpuUsage = (opts and opts.cpuUsage) or 0,
        country = (opts and opts.country) or "XX",
        rank = (opts and opts.rank) or 0,
        hasSkirmishAIsInTeam = (opts and opts.hasSkirmishAIsInTeam) or false,
        playerOpts = (opts and opts.playerOpts) or {},
        desynced = (opts and opts.desynced) or false,
    }
    for i, p in ipairs(self.players) do
        if p.id == playerId then
            self.players[i] = player
            return self
        end
    end
    table.insert(self.players, player)
    return self
end

---@param self TeamBuilder
---@param playerId number
---@return TeamBuilder
function TeamBuilder:WithLeader(playerId)
    self.leader = playerId
    local exists = false
    for _, p in ipairs(self.players) do
        if p.id == playerId then
            exists = true
            break
        end
    end
    if not exists then
        self:WithPlayer(playerId, { name = self.playerName, active = true, spectator = false })
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