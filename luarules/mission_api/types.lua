--============================================================--

local trackedUnits = GG['MissionAPI'].tracker.units

--============================================================--

-- Validation

--============================================================--

local function ErrorMissingField(file, module, object, field)
    Spring.Log(file, LOG.ERROR, string.format("[%s] '%s' is missing field '%s'", module, object, field))
end

----------------------------------------------------------------

local function ErrorUnexpectedType(file, module, object, field, expected, got)
    Spring.Log(file, LOG.ERROR, string.format("[%s] Field '%s' in '%s' has unexpected type %s, expected %s", module, field, object, got, expected))
end

----------------------------------------------------------------

local function CheckField(fileName, moduleName, objectName, fieldName, field, expectedType, required)
    fileName = fileName or 'types.lua'
    moduleName = moduleName or 'Mission API'

    local out = true

    if required and field == nil then
        ErrorMissingField(fileName, moduleName, objectName, fieldName)
        out = false
    end

    if field and type(field) ~= expectedType then
        ErrorUnexpectedType(fileName, moduleName, objectName, fieldName, expectedType, type(field))
        out = false
    end

    return out
end

--============================================================--

-- Collider

--============================================================--

local Collider = { 
    x = 0,
    z = 0,
    width = 0,
    height = nil, -- nil or 0 height means cylinder collider

    team = 0,

    onEnter = nil, -- function
    onLeave = nil, -- function

    units = {},
}

----------------------------------------------------------------

function Collider:new(x, z, width, height, team, onEnter, onLeave)
    local out = {}
    setmetatable(out, self)
    self.__name = 'Collider'
    self.__index = self

    self.x = x or 0
    self.z = z or 0
    self.width = width or 0
    self.height = height

    self.team = team or Spring.ALL_UNITS

    self.onEnter = onEnter
    self.onLeave = onLeave

    self.units = {}
    return out
end

----------------------------------------------------------------

function Collider:validate(file, module)
    local out = true

    out = out and CheckField(file, module, self.__name, 'x', self.x, 'number', true)
    out = out and CheckField(file, module, self.__name, 'y', self.y, 'number', true)
    out = out and CheckField(file, module, self.__name, 'width', self.width, 'number', true)
    out = out and CheckField(file, module, self.__name, 'height', self.height, 'number', false)
    out = out and CheckField(file, module, self.__name, 'team', self.team, 'number', true)
    out = out and CheckField(file, module, self.__name, 'onEnter', self.onEnter, 'function', false)
    out = out and CheckField(file, module, self.__name, 'onLeave', self.onLeave, 'function', false)

    return out
end

----------------------------------------------------------------

function Collider:getUnits()
    local units = {}

    if not self.height then
        units = Spring.GetUnitsInCylinder(self.x, self.z, self.width, self.team)
    else
        units = Spring.GetUnitsInRectangle(self.x, self.z, self.x + self.width, self.z + self.height, self.team)
    end

    return units
end

----------------------------------------------------------------

function Collider:inTable(val, tab)
    for key, value in pairs(tab) do
        if value == val then
            return true
        end
    end

    return false
end

----------------------------------------------------------------

function Collider:poll()
    local currentUnits = self.getUnits()

    -- TODO: This could probably be faster
    if self.onEnter then
        for _, unitID in ipairs(currentUnits) do
            if not self.inTable(self.units, unitID) then
                self.onEnter(unitID)
            end
        end
    end

    if self.onLeave then
        for _, unitID in ipairs(self.units) do
            if not self.inTable(currentUnits, unitID) then
                self.onLeave(unitID)
            end
        end
    end

    self.units = currentUnits
end

--============================================================--

-- Timer

--============================================================--

local Timer = {
    count = 0,
    length = 0,

    loop = false,
    running = false,

    onUpdate = nil, -- function
    onFinished = nil, -- function
}

----------------------------------------------------------------

function Timer:new(length, loop, onUpdate, onFinished)
    local out = {}
    setmetatable(out, self)
    self.__index = self
    self.__name = 'Timer'

    self.count = 0
    self.length = length or 0

    self.loop = loop or false
    self.running = false

    self.onUpdate = onUpdate
    self.onFinished = onFinished

    return out
end

----------------------------------------------------------------

function Timer:validate(file, module)
    local out = true

    out = out and CheckField(file, module, self.__name, 'length', self.length, 'number', true)
    out = out and CheckField(file, module, self.__name, 'loop', self.loop, 'bool', false)
    out = out and CheckField(file, module, self.__name, 'onUpdate', self.onUpdate, 'function', false)
    out = out and CheckField(file, module, self.__name, 'onFinished', self.onFinished, 'function', false)

    return out
end

----------------------------------------------------------------

function Timer:start()
    self.running = true
end

----------------------------------------------------------------

function Timer:pause()
    self.running = false
end

----------------------------------------------------------------

function Timer:stop()
    self.count = 0
    self.running = false
end

----------------------------------------------------------------

function Timer:poll()
    if not self.running then return end

    self.count = self.count + 1

    if self.onUpdate then self.onUpdate(self.length / self.count) end

    if self.count == self.length then
        if self.onFinished then self.onFinished() end
        if not self.loop then self.running = false end
        self.count = 0
    end
end

--============================================================--

-- Unit

--============================================================--

local Unit = {
    TYPE = {
        NAME = 0,
        ID = 1,
        DEF_ID = 2,
        DEF_NAME = 3,
    },

    type = 0,
    ID = 0,
    team = 0,
}

----------------------------------------------------------------

function Unit:new(type, ID, team)
    local out = {}
    setmetatable(out, self)
    self.__index = self
    self.__name = 'Unit'

    self.type = type or Unit.TYPE.NAME
    self.ID = ID
    self.team = team or Spring.ALL_UNITS

    return out
end

----------------------------------------------------------------

function Unit:validate(file, module)
    file = file or 'types.lua'
    module = module or 'Mission API'

    if self.ID == nil then
        ErrorMissingField(file, module, self.__name, 'ID')
        return false
    end

    if self.type == self.TYPE.NAME or self.type == self.TYPE.DEF_NAME then
        if type(self.ID) ~= 'string' then
            Spring.Log(file, LOG.ERROR, string.format("[%s] Unit of type '%i' expects ID of type 'string', got %s instead", module, type(self.ID)))
            return false
        end
    elseif self.type == self.TYPE.ID or self.type == self.TYPE.DEF_ID then
        if type(self.ID) ~= 'string' then
            Spring.Log(file, LOG.ERROR, string.format("[%s] Unit of type %i expects ID of type 'number', got %s instead", module, type(self.ID)))
            return false
        end
    else
        Spring.Log(file, LOG.ERROR, string.format("[%s] Unit has unhandled type '%i'", module, self.type))
        return false
    end
    
    return true
end

----------------------------------------------------------------

function Unit:isUnit(unitID, unitDefID)
    if not self.teamIsTeam(self.team, Spring.GetUnitTeam(unitID)) then return false end

    if self.type == self.TYPES.NAME then
        for _, id in ipairs(trackedUnits[self.ID]) do
            if unitID == id then
                return true
            end
        end
    elseif self.type == self.TYPE.ID then
        return unitID == self.ID
    elseif self.type == self.TYPE.DEF_ID then
        return unitDefID == self.ID
    elseif self.type == self.TYPE.DEF_NAME then
        return UnitDefNames[self.ID] == unitDefID
    end
end

----------------------------------------------------------------

function Unit:getUnits() 
    if self.type == self.TYPE.name then
        return trackedUnits[self.ID]
    elseif self.type == self.TYPE.ID then
        return {self.ID}
    elseif self.type == self.TYPE.DEF_ID then
        return Spring.GetTeamUnitsByDefs(self.team, self.ID)
    elseif self.type == self.TYPE.DEF_NAME then
        return Spring.GetTeamUnitsByDefs(self.team, UnitDefNames[self.ID])
    end
end

----------------------------------------------------------------

function Unit:teamIsTeam(teamA, teamB)
    if teamA == teamB then return true end

    if teamA == Spring.ALL_UNITS or teamB == Spring.ALL_UNITS then
        return true
    end

    if teamA == Spring.MY_UNITS then
        for _, playerID in ipairs(Spring.GetPlayerList()) do
            local _, _, _, teamID, _ = Spring.GetPlayerInfo(playerID)
            if teamB == teamID then return true end
        end
    end

    if teamB == Spring.MY_UNITS then
        for _, playerID in ipairs(Spring.GetPlayerList()) do
            local _, _, _, teamID, _ = Spring.GetPlayerInfo(playerID)
            if teamA == teamID then return true end
        end

        return false
    end

    if teamA == Spring.ALLY_UNITS then
        return Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamB)
    end

    if teamB == Spring.ALLY_UNITS then
        return Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamA)
    end

    if teamA == Spring.ENEMY_UNITS then
        return not Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamB)
    end

    if teamB == Spring.ENEMY_UNITS then
        return not Spring.AreTeamsAllied(Spring.GetLocalTeamID(), teamA)
    end

    return false
end

--============================================================--

-- UnitDef

--============================================================--

local UnitDef = {
    TYPE = {
        NAME = 0,
        ID = 1
    },

    type = 0,
    ID = 0,
    team = 0,
}

----------------------------------------------------------------

function UnitDef:new(type, ID, team)
    local out = {}
    setmetatable(out, self)
    self.__index = self
    self.__name = 'UnitDef'

    self.type = type or UnitDef.TYPE.NAME
    self.ID = ID
    self.team = team or Spring.ALL_UNITS

    return out
end

----------------------------------------------------------------

function UnitDef:validate(file, module)
    file = file or 'types.lua'
    module = module or 'Mission API'

    if self.ID == nil then
        ErrorMissingField(file, module, self.__name, 'ID')
        return false
    end

    if self.type == self.TYPE.NAME then
        if type(self.ID) ~= 'string' then
            Spring.Log(file, Log.ERROR, string.format("[%s] UnitDef of type %i expects ID of type 'string', got %s instead", module, self.type, type(self.ID)))
            return false
        end
    elseif self.type == self.TYPE.ID then
        if type(self.ID) ~= 'number' then
            Spring.Log(file, Log.ERROR, string.format("[%s] UnitDef of type %i expects ID of type 'number', got %s instead", module, self.type, type(self.ID)))
            return false
        end
    else
        Spring.Log(file, LOG.ERROR, string.format("[%s] UnitDef has unhandled type '%i'", module, self.type))
        return false
    end

    return true
end

----------------------------------------------------------------

function UnitDef:getID()
    if self.type == self.TYPE.ID then 
        return self.ID
    elseif self.type == self.TYPE.NAME then 
        return UnitDefNames[self.ID]
    end
end

----------------------------------------------------------------

function UnitDef:getName()
    if self.type == self.TYPE.NAME then
        return self.ID
    elseif self.type == self.TYPE.ID then
        return UnitDefs[self.ID].name
    end
end

--============================================================--

-- Vec2

--============================================================--

local Vec2 = {
    x = 0,
    z = 0,
}

----------------------------------------------------------------

function Vec2:new(x, z)
    local out = {}

    setmetatable(out, self)
    self.__index = self
    self.__name = "Vec2"

    self.x = x or 0
    self.z = z or 0

    return out
end

----------------------------------------------------------------

function Vec2:validate(file, module)
    local out = true

    out = out and CheckField(file, module, self.__name, 'x', self.x, 'number', true)
    out = out and CheckField(file, module, self.__name, 'z', self.z, 'number', true)

    return out
end

--============================================================--

-- Vec3

--============================================================--

local Vec3 = {
    x = 0,
    y = 0,
    z = 0,
}

----------------------------------------------------------------

function Vec3:new(x, y, z)
    local out = {}

    setmetatable(out, self)
    self.__index = self
    self.__name = "Vec3"

    self.x = x or 0
    self.y = y or 0
    self.z = z or 0

    return out
end

----------------------------------------------------------------

function Vec2:validate(file, module)
    local out = true

    out = out and CheckField(file, module, self.__name, 'x', self.x, 'number', true)
    out = out and CheckField(file, module, self.__name, 'y', self.y, 'number', true)
    out = out and CheckField(file, module, self.__name, 'z', self.z, 'number', true)

    return out
end

--============================================================--

return {
    ['Collider'] = Collider,
    ['Timer'] = Timer,
    ['Unit'] = Unit,
    ['UnitDef'] = UnitDef,
    ['Vec2'] = Vec2,
    ['Vec3'] = Vec3,
}

--============================================================--