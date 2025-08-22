local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Transport To (Gadget)", -- gadget copy from: Decloak when damaged
        desc      = "Adds a map-click Transport To command and auto-assigns transports",
        author    = "Silla Noble",
        date      = "uhhhhh.....", -- Major rework 12 Feb 2014
        license   = "A what now?",
        layer     = 1,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
    return false
end

-- ========= debug toggles =========
local LOG_VERBOSE = false
local LOG_DETAIL = false

-- ========= locals / engine aliases =========
local Echo = Spring.Echo
local GameFrame = Spring.GetGameFrame
local GetUnitDefID = Spring.GetUnitDefID

local CMDTYPE_ICON_MAP = CMDTYPE.ICON_MAP
local CMD_LOAD_UNITS   = CMD.LOAD_UNITS
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local CMD_STOP         = CMD.STOP
local CMD_WAIT         = CMD.WAIT
local CMD_INSERT       = CMD.INSERT

-- ========= helpers =========
local function unameByDef(defID)
    local ud = defID and UnitDefs[defID]
    return (ud and ud.name) or ("def:" .. tostring(defID))
end

local function uname(unitID)
    local defID = GetUnitDefID(unitID)
    return string.format("%s#%d", unameByDef(defID), unitID or -1)
end

local function gf()
    return string.format("gf=%d", GameFrame())
end

local function E(fmt, ...)
    if LOG_VERBOSE then
        Echo(string.format(fmt, ...))
    end
end

local function Ed(fmt, ...)
    if LOG_DETAIL then
        Echo(string.format(fmt, ...))
    end
end

-- Pretty, cycle-safe table -> string for debugging.
local function debug_tostring(value, opts, _depth, _seen)
    opts = opts or {}
    local indentStr = opts.indent or "  "
    local maxDepth = opts.maxDepth or 3
    local sortKeys = (opts.sortKeys ~= false)
    local maxItems = opts.maxItems or 200
    local showMeta = opts.showMetatable or false
    local compact = opts.compact or false
    local showFuncs = (opts.showFunctions ~= false)

    _depth = _depth or 0
    _seen = _seen or {}

    local t = type(value)
    if t == "nil" or t == "number" or t == "boolean" then
        return tostring(value)
    elseif t == "string" then
        return string.format("%q", value)
    elseif t ~= "table" then
        if showFuncs or t ~= "function" then
            return string.format("<%s:%s>", t, tostring(value))
        else
            return "<function>"
        end
    end

    if _seen[value] then
        return string.format("<ref#%d>", _seen[value].id)
    end
    if _depth >= maxDepth then
        return "<table ...>"
    end

    local id = 1 + (function()
        local c = 0
        for _ in pairs(_seen) do c = c + 1 end
        return c
    end)()
    _seen[value] = { id = id }

    local function indent(n)
        return compact and "" or string.rep(indentStr, n)
    end

    -- detect array
    local arrMax, count = 0, 0
    for k, _ in pairs(value) do
        count = count + 1
        if type(k) == "number" and k > 0 and math.floor(k) == k then
            if k > arrMax then arrMax = k end
        end
    end
    local isArray = true
    local seenCount = 0
    for i = 1, arrMax do
        if value[i] == nil then isArray = false break end
        seenCount = seenCount + 1
    end
    if seenCount ~= count then isArray = false end

    if isArray then
        local items = {}
        for i = 1, arrMax do
            if #items >= maxItems then
                items[#items + 1] = "...(truncated)"
                break
            end
            items[#items + 1] = debug_tostring(value[i], opts, _depth + 1, _seen)
        end
        if compact then
            return "{" .. table.concat(items, ",") .. "}"
        else
            local pad = indent(_depth + 1)
            return "{"
                .. (#items > 0 and ("\n" .. pad .. table.concat(items, ",\n" .. pad) .. "\n" .. indent(_depth)) or "")
                .. "}"
        end
    else
        local keys = {}
        for k in pairs(value) do keys[#keys + 1] = k end
        if sortKeys then
            table.sort(keys, function(a, b)
                local ta, tb = type(a), type(b)
                if ta == tb then
                    if ta == "string" or ta == "number" then
                        return a < b
                    end
                    return tostring(a) < tostring(b)
                end
                return ta < tb
            end)
        end
        local pieces, emitted = {}, 0
        for _, k in ipairs(keys) do
            emitted = emitted + 1
            if emitted > maxItems then
                pieces[#pieces + 1] = compact and "...(truncated)" or (indent(_depth + 1) .. "...(truncated)")
                break
            end
            local v = value[k]
            local kv
            if type(k) == "string" and k:match("^[_%a][_%w]*$") then
                kv = string.format("%s = %s", k, debug_tostring(v, opts, _depth + 1, _seen))
            else
                kv = string.format("[%s] = %s", debug_tostring(k, opts, _depth + 1, _seen), debug_tostring(v, opts, _depth + 1, _seen))
            end
            if compact then pieces[#pieces + 1] = kv else pieces[#pieces + 1] = indent(_depth + 1) .. kv end
        end
        if showMeta then
            local mt = getmetatable(value)
            if mt then
                local mtStr = debug_tostring(mt, opts, _depth + 1, _seen)
                local line = compact and ("<metatable>=" .. mtStr) or (indent(_depth + 1) .. "<metatable> = " .. mtStr)
                pieces[#pieces + 1] = line
            end
        end
        if compact then
            return "{" .. table.concat(pieces, ",") .. "}"
        else
            local inner = table.concat(pieces, ",\n")
            return inner == "" and "{}" or ("{\n" .. inner .. "\n" .. indent(_depth) .. "}")
        end
    end
end

-- ========= command id & description =========
local CMD_TRANSPORT_TO = GameCMD.TRANSPORT_TO
local CMD_TRANSPORT_TO_DESC = {
    id = CMD_TRANSPORT_TO,
    type = CMDTYPE_ICON_MAP,
    name = "Transport To",
    cursor = nil,
    action = "transport_to",
}

-- ========= classification thresholds =========
local HEAVY_TRANSPORT_MASS_THRESHOLD = 3000
local LIGHT_UNIT_SIZE_THRESHOLD = 6
local UNLOAD_RADIUS = 10

-- ========= def caches =========
local isFactoryDef = {}
local isNanoDef = {}
local isTransportDef = {}
local transportClass = {} -- "light" | "heavy"
local transportCapacityMass = {}
local transportSizeLimit = {}
local transportCapSlots = {}

local isTransportableDef = {}
local unitMass = {}
local unitXsize = {}

-- ========= UnitDef scanning =========
local function buildDefCaches()
    for defID, ud in pairs(UnitDefs) do
        -- transports
        if ud.isTransport and ud.canFly and (ud.transportCapacity or 0) > 0 then
            isTransportDef[defID] = true
            transportCapacityMass[defID] = ud.transportMass or 0
            transportSizeLimit[defID] = ud.transportSize or 0
            transportCapSlots[defID] = ud.transportCapacity or 0
            transportClass[defID] = (transportCapacityMass[defID] >= HEAVY_TRANSPORT_MASS_THRESHOLD) and "heavy" or "light"
        end

        -- transportability (grounded, movable non-building, not explicitly excluded)
        local movable = (ud.speed or 0) > 0
        local grounded = not ud.canFly
        local notBuilding = not ud.isBuilding
        local notCantBeTransported = (ud.cantBeTransported == nil) or (ud.cantBeTransported == false)

        local isNano = ud.isBuilder and not ud.canMove and not ud.isFactory
        local isFactory = ud.isFactory

        if (movable and grounded and notBuilding and notCantBeTransported) then
            isTransportableDef[defID] = true
        end
        if isNano then
            isNanoDef[defID] = true
            isTransportableDef[defID] = true
        end
        if isFactory then
            isFactoryDef[defID] = true
            isTransportableDef[defID] = true
        end

        unitMass[defID] = ud.mass or 0
        unitXsize[defID] = ud.xsize or 0
    end
end

-- ========= gadget lifecycle =========
local function tcount(t)
    local c = 0
    for _ in pairs(t) do c = c + 1 end
    return c
end

function gadget:Initialize()
    buildDefCaches()
    E(
        "[TransportTo:Gadget] %s def caches built: transports=%d transportable=%d factories=%d nanos=%d",
        gf(),
        tcount(isTransportDef),
        tcount(isTransportableDef),
        tcount(isFactoryDef),
        tcount(isNanoDef)
    )
end

function gadget:Shutdown()
    E("[TransportTo:Gadget] %s shutdown", gf())
end

local loadedUnits = {} --[unitID=boolean]

function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag)
    if cmdID == CMD_TRANSPORT_TO then
        if loadedUnits[unitID] then
            loadedUnits[unitID] = nil
            E("[TransportTo:Gadget] %s unit %s got loaded, setting the command a completed", gf(), uname(unitID))
            return true, true
        else
            return true, false
        end
    end
end

function gadget:UnitLoaded(unitID, unitDefID, teamID, transportID)
    loadedUnits[unitID] = true
end

function gadget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
    loadedUnits[unitID] = nil
end