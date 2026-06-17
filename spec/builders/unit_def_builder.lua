-- Unit Def Builder
-- Fluent builder for fake UnitDef entries used in unsynced widget tests.
-- Reads close to a one-line spec:
--   UnitDef.new("armcon"):WithDefID(100):WithSpeed(100):Builds(10, 11)

---@class UnitDefBuilder
---@field _def table
---@field _defID number|nil
local UDB = {}
UDB.__index = UDB

---@param name string
---@return UnitDefBuilder
function UDB.new(name)
    return setmetatable({
        _def = {
            name         = name,
            buildSpeed   = 0,
            buildOptions = {},
            cost         = 0,
            xsize        = 1,
            zsize        = 1,
        },
        _defID = nil,
    }, UDB)
end

---@param defID number
---@return UnitDefBuilder
function UDB:WithDefID(defID)
    self._defID = defID
    return self
end

---@param buildSpeed number
---@return UnitDefBuilder
function UDB:WithSpeed(buildSpeed)
    self._def.buildSpeed = buildSpeed
    return self
end

---@param cost number
---@return UnitDefBuilder
function UDB:WithCost(cost)
    self._def.cost = cost
    return self
end

---@param xsize number
---@param zsize number
---@return UnitDefBuilder
function UDB:WithFootprint(xsize, zsize)
    self._def.xsize = xsize
    self._def.zsize = zsize
    return self
end

---List the defIDs this unit can construct.
---@param ... number
---@return UnitDefBuilder
function UDB:Builds(...)
    self._def.buildOptions = { ... }
    return self
end

---@return number
function UDB:GetDefID()
    if not self._defID then
        error("UnitDefBuilder for '" .. tostring(self._def.name) .. "' is missing defID; call :WithDefID(n)")
    end
    return self._defID
end

---@return table
function UDB:GetDef()
    return self._def
end

return UDB
