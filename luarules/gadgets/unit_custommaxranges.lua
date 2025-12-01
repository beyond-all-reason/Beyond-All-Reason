--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Controls Unit's maxrange",
        desc      = "Fixes some aa/ground units not closing in on target when given attack order",
        author    = "Doo",
        date      = "06 dec 2017",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spSetUnitMaxRange = Spring.SetUnitMaxRange

local unitMaxRange = {}
for unitDefID, unitDef in pairs(UnitDefs) do
    if unitDef.customParams.maxrange then
        unitMaxRange[unitDefID] = tonumber(unitDef.customParams.maxrange)
    end
end

function gadget:Initialize()
	local allUnits = spGetAllUnits()
	for i = 1, #allUnits do
		local unitID = allUnits[i]
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID))
	end
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if unitMaxRange[unitDefID] then
		spSetUnitMaxRange(unitID, unitMaxRange[unitDefID])
	end
end