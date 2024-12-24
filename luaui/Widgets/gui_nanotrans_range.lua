function widget:GetInfo()
    return {
       name         = "Nano range on transport",
       desc         = "Draw a circle around a transport carrying a nano when its about to unload",
       author       = "Cheva",
       date         = "December 2024",
       license      = "GNU GPL, v2 or later",
       layer        = 0,
       enabled      = true
    }
end

--------------------------------------------------------------------------------
--vars
--------------------------------------------------------------------------------
local circleDivs = 96
local range
local isNanoTC = {}
local turretRange = {}
local transportWithNano = {}

--------------------------------------------------------------------------------
--speedups
--------------------------------------------------------------------------------
local CMD_UNLOAD_UNITS = CMD.UNLOAD_UNITS
local spGetActiveCmd = Spring.GetActiveCommand
local GetSelectedUnitsSorted = Spring.GetSelectedUnitsSorted
local glColor = gl.Color
local glLineWidth = gl.LineWidth
local glDrawGroundCircle = gl.DrawGroundCircle

for udid, ud in pairs(UnitDefs) do
    if ud.isStaticBuilder and not ud.isFactory then
        isNanoTC[udid] = true
        turretRange[udid] = ud.buildDistance
    end
end

--------------------------------------------------------------------------------
-- utility functions
--------------------------------------------------------------------------------
function MinValue(table)
    local min = table[1]
    for i = 2, #table do
        if table[i] < min then
            min = table[i]
        end
    end
    return min
end

--------------------------------------------------------------------------------
--Transported Nano Range
--------------------------------------------------------------------------------
local function DrawNanoRange(x, y, z, range)
    glLineWidth(1)
    glColor(0.24, 1.0, 0.2, 0.40)
    glDrawGroundCircle(x, y, z, range, circleDivs)
    glColor(1,1,1,1)
    glLineWidth(1)
end

function widget:UnitLoaded(unitID, unitDefID, teamID, transportID)
    if isNanoTC[unitDefID] then
        range = turretRange[unitDefID]
        transportWithNano[transportID] = unitDefID
    end
end

function widget:UnitUnloaded(unitID, unitDefID, teamID, transportID)
    if transportWithNano[transportID] then
        transportWithNano[transportID] = nil
    end
end

function widget:DrawWorldPreUnit()
    local _, cmdId, _, _ = spGetActiveCmd()
    if cmdId ~= CMD_UNLOAD_UNITS then
        return
    end
    local sel = GetSelectedUnitsSorted()
    local ranges = {}
    for _, unitIds in pairs(sel) do
        for _, unitId in pairs(unitIds) do
            if transportWithNano[unitId] then
                table.insert(ranges, turretRange[transportWithNano[unitId]])
            end
        end
    end
    range = MinValue(ranges)
    if range == nil then return end
    local mouseX, mouseY = Spring.GetMouseState()
    local desc, args = Spring.TraceScreenRay(mouseX, mouseY, true)
    if desc == nil then return end
    local x, y, z = args[1], args[2], args[3]
    DrawNanoRange(x, y, z, range)
end
