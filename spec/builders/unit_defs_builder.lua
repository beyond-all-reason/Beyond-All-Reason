-- Unit Defs Builder
-- Shared registry of unit definitions and live unit instances, used by both
-- SpringSyncedBuilder and SpringUnsyncedBuilder so they don't each carry
-- their own copy of WithUnitDef / WithUnit / WithRealUnitDefs.
--
-- Two views of the registered defs are exposed:
--   GetUnitDefsByID()   numeric defID -> def     (engine-runtime shape, used by widgets)
--   GetUnitDefsByName() string name   -> def     (gamedata pre-load shape, used by synced specs)
-- Both views observe the same underlying defs.

---@class UnitDefsBuilder
---@field _byID table<number, table>
---@field _byName table<string, table>
---@field _names table<string, { id: number }>
---@field _instances table<number, number>
---@field _realLoaded boolean
local UDFB = {}
UDFB.__index = UDFB

function UDFB.new()
    return setmetatable({
        _byID = {},
        _byName = {},
        _names = {},
        _instances = {},
        _realLoaded = false,
    }, UDFB)
end

---Register a unit definition. Accepts either a UnitDefBuilder or a (defID, defTable) pair.
---@overload fun(self: UnitDefsBuilder, udb: UnitDefBuilder): UnitDefsBuilder
---@param defID number
---@param def table
---@return UnitDefsBuilder
function UDFB:WithUnitDef(defID, def)
    local resolvedID, resolvedDef
    if type(defID) == "table" and defID.GetDefID then
        ---@type UnitDefBuilder
        local udb = defID
        resolvedID = udb:GetDefID()
        resolvedDef = udb:GetDef()
    else
        ---@cast defID number
        resolvedID = defID
        resolvedDef = def
    end
    self._byID[resolvedID] = resolvedDef
    if resolvedDef.name then
        self._byName[resolvedDef.name] = resolvedDef
        self._names[resolvedDef.name] = { id = resolvedID }
    end
    return self
end

---Register a live unit instance. defIDOrName accepts either a numeric defID
---or the name of a previously-registered def. Errors loudly if the def has
---not been registered (via WithUnitDef or WithRealUnitDefs).
---@param unitID number
---@param defIDOrName number|string
---@return UnitDefsBuilder
function UDFB:WithUnit(unitID, defIDOrName)
    local defID
    if type(defIDOrName) == "string" then
        local entry = self._names[defIDOrName]
        if not entry then
            error(("UnitDefsBuilder:WithUnit unknown unit name '%s' — register via :WithUnitDef or :WithRealUnitDefs first"):format(defIDOrName))
        end
        defID = entry.id
    elseif type(defIDOrName) == "number" then
        if not self._byID[defIDOrName] then
            error(("UnitDefsBuilder:WithUnit unknown defID %d — register via :WithUnitDef or :WithRealUnitDefs first"):format(defIDOrName))
        end
        defID = defIDOrName
    else
        error("UnitDefsBuilder:WithUnit expected unit name or numeric defID, got " .. type(defIDOrName))
    end
    self._instances[unitID] = defID
    return self
end

---Load real BAR UnitDefs from gamedata into the registry.
---
---loadHarness is an optional callable: harness(fn) invokes fn() with whatever
---globals the loader needs (e.g. _G.Spring.GetModOptions, _G.VFS overrides).
---The synced builder passes its WithGlobalsDefined harness so modoptions are
---honored; callers who already have spec_helper's globals can pass nil.
---@param loadHarness? fun(loadFn: fun())
---@return UnitDefsBuilder
function UDFB:WithRealUnitDefs(loadHarness)
    if self._realLoaded then return self end

    local function load()
        local prevDefs = _G.UnitDefs
        local prevNames = _G.UnitDefNames

        local success, defs = pcall(require, "gamedata.unitdefs")
        if not success or type(defs) ~= "table" then
            _G.UnitDefs = prevDefs
            _G.UnitDefNames = prevNames
            return
        end
        ---@diagnostic disable-next-line: global-in-non-module
        _G.UnitDefs = defs
        pcall(require, "gamedata.alldefs_post")
        pcall(require, "gamedata.unitdefs_post")

        local loaded = _G.UnitDefs
        local names  = _G.UnitDefNames
        if type(loaded) == "table" then
            for _, def in pairs(loaded) do
                if def.builder ~= nil and def.isBuilder == nil then
                    def.isBuilder = def.builder
                end
            end
            -- Post-load shape is name-keyed (BAR's gamedata flow);
            -- UnitDefNames carries the numeric id mapping.
            for name, def in pairs(loaded) do
                if type(def) == "table" then
                    self._byName[name] = def
                    local info = names and names[name]
                    local id = info and info.id
                    if id then
                        self._byID[id] = def
                        self._names[name] = { id = id }
                    end
                end
            end
        end
        ---@diagnostic disable-next-line: global-in-non-module
        _G.UnitDefs = prevDefs
        ---@diagnostic disable-next-line: global-in-non-module
        _G.UnitDefNames = prevNames
    end

    local harness = loadHarness or function(fn) fn() end
    harness(load)
    self._realLoaded = true
    return self
end

---@return table<number, table>
function UDFB:GetUnitDefsByID() return self._byID end

---@return table<string, table>
function UDFB:GetUnitDefsByName() return self._byName end

---@return table<string, { id: number }>
function UDFB:GetUnitDefNames() return self._names end

---@param unitID number
---@return number|nil
function UDFB:GetUnitDefID(unitID) return self._instances[unitID] end

---@return boolean
function UDFB:HasRealDefs() return self._realLoaded end

return UDFB
