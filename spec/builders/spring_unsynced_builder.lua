-- Spring Unsynced (Widget) Builder
-- Builds a sandboxed widget execution environment for unsynced/LuaUI tests.
-- Mirrors SpringSyncedBuilder but for widgets that consume widget context globals
-- (widget, widgetHandler, WG, GL, gl, Platform, UnitDefs) and Spring unsynced
-- functions like GiveOrderToUnit / TestBuildOrder.

local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")

---@class UnsyncedWidgetMock
---@field env table  the sandboxed environment the widget chunk runs in
---@field WG any     the WG table populated by widget:Initialize() (typed `any` so widget-specific keys aren't checked against the global WG type)
---@field captureArrayOrders fun(): table[]  installs spy on Spring.GiveOrderArrayToUnitArray, returns recorded calls
---@field captureUnitOrders fun(): table[]   installs spy on Spring.GiveOrderToUnit, returns recorded calls

---@class SpringUnsyncedBuilder
---@field unitDefs UnitDefsBuilder
---@field springOverrides table<string, function|table>
---@field vfsIncludeOverrides table<string, any|fun(path:string, ...):any>
---@field headless boolean
local SUB = {}
SUB.__index = SUB

function SUB.new()
    return setmetatable({
        unitDefs = UnitDefsBuilder.new(),
        springOverrides = {},
        vfsIncludeOverrides = {},
        headless = true,
    }, SUB)
end

---Register a unit definition. Delegates to the underlying UnitDefsBuilder.
---@overload fun(self: SpringUnsyncedBuilder, udb: UnitDefBuilder): SpringUnsyncedBuilder
---@param defID number
---@param def table
---@return SpringUnsyncedBuilder
function SUB:WithUnitDef(defID, def)
    self.unitDefs:WithUnitDef(defID, def)
    return self
end

---Place a live unit instance on the map. Errors if the def is not registered.
---@param unitID number
---@param defIDOrName number|string
---@return SpringUnsyncedBuilder
function SUB:WithUnit(unitID, defIDOrName)
    self.unitDefs:WithUnit(unitID, defIDOrName)
    return self
end

---Load real BAR UnitDefs from gamedata into the registry.
---@return SpringUnsyncedBuilder
function SUB:WithRealUnitDefs()
    self.unitDefs:WithRealUnitDefs()
    return self
end

---@param name string
---@param fn function|table
---@return SpringUnsyncedBuilder
function SUB:WithSpringFn(name, fn)
    self.springOverrides[name] = fn
    return self
end

---Override what VFS.Include(path) returns inside the sandbox.
---value may be a literal table or a function called with the original args.
---@param path string
---@param value any
---@return SpringUnsyncedBuilder
function SUB:WithVFSInclude(path, value)
    self.vfsIncludeOverrides[path] = value
    return self
end

---@param headless boolean|nil  defaults to true
---@return SpringUnsyncedBuilder
function SUB:WithHeadless(headless)
    self.headless = headless ~= false
    return self
end

local function makeEnv(self)
    local env = setmetatable({}, { __index = _G })

    ---@diagnostic disable-next-line: missing-fields
    env.widget = {}
    env.GL = {}
    env.Platform = { gl = not self.headless }
    env.WG = {}
    env.widgetHandler = {
        RemoveWidget = function() end,
        AddAction = function() end,
    }
    env.UnitDefs = self.unitDefs:GetUnitDefsByID()
    env.UnitDefNames = self.unitDefs:GetUnitDefNames()
    env.gl = {
        LuaShader = function() end,
        InstanceVBOTable = {
            pushElementInstance = function() end,
            popElementInstance = function() end,
        },
    }

    local unitDefs = self.unitDefs
    local springTable = {
        Utilities                 = { IsDevMode = function() return false end },
        Echo                      = function() end,
        GetUnitDefID              = function(id) return unitDefs:GetUnitDefID(id) end,
        ValidUnitID               = function() return false end,
        GiveOrderToUnit           = function() end,
        GiveOrderArrayToUnitArray = function() end,
        GetGroundHeight           = function() return 0 end,
        Pos2BuildPos              = function(_, x, y, z) return x, y, z end,
        GetUnitBuildFacing        = function() return 0 end,
        GetUnitPosition           = function() return 0, 0, 0 end,
        TestBuildOrder            = function() return 0 end,
        GetMyTeamID               = function() return 0 end,
    }
    for k, v in pairs(self.springOverrides) do
        springTable[k] = v
    end
    env.Spring = setmetatable(springTable, { __index = _G.Spring })

    local realInclude = _G.VFS and _G.VFS.Include
    local includeOverrides = self.vfsIncludeOverrides
    env.VFS = setmetatable({
        Include = function(path, ...)
            local override = includeOverrides[path]
            if override ~= nil then
                if type(override) == "function" then
                    return override(path, ...)
                end
                return override
            end
            if realInclude then
                return realInclude(path, ...)
            end
        end,
    }, { __index = _G.VFS })

    return env
end

---Load the widget at widgetPath into a fresh sandboxed env and call its Initialize.
---@param widgetPath string
---@return UnsyncedWidgetMock
function SUB:LoadWidget(widgetPath)
    local env = makeEnv(self)

    local chunk = assert(loadfile(widgetPath))
    setfenv(chunk, env)
    chunk()
    env.widget:Initialize()

    local mock = {
        env = env,
        WG = env.WG,
    }

    function mock.captureArrayOrders()
        local calls = {}
        env.Spring.GiveOrderArrayToUnitArray = function(unitIDs, orders, _)
            table.insert(calls, { unitIDs = unitIDs, orders = orders })
        end
        return calls
    end

    function mock.captureUnitOrders()
        local calls = {}
        env.Spring.GiveOrderToUnit = function(unitID, cmdID, _, _)
            table.insert(calls, { unitID = unitID, cmdID = cmdID })
        end
        return calls
    end

    return mock
end

return SUB
