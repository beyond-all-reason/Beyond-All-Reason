---
--- Created by Hobo Joe.
--- DateTime: 4/26/2023 8:48 PM
---


local unitEnergyCost = {} ---@type table<number, number>
local unitMetalCost = {} ---@type table<number, number>
local unitGroup = {} ---@type table<number, number>
local unitRestricted = {} ---@type table<number, true>
local unitHidden = {} ---@type table<number, true>
local isBuilder = {} ---@type table<number, true>
local isFactory = {} ---@type table<number, true>
local unitIconType = {} ---@type table<number, number>
local isMex = {} ---@type table<number, true>
local unitMaxWeaponRange = {} ---@type table<number, number>

for unitDefID, unitDef in pairs(UnitDefs) do

	unitGroup[unitDefID] = unitDef.customParams.unitgroup

	if unitDef.maxWeaponRange > 16 then
		unitMaxWeaponRange[unitDefID] = unitDef.maxWeaponRange
	end

	unitIconType[unitDefID] = unitDef.iconType
	unitEnergyCost[unitDefID] = unitDef.energyCost
	unitMetalCost[unitDefID] = unitDef.metalCost

	if unitDef.buildSpeed > 0 and unitDef.buildOptions[1] then
		isBuilder[unitDefID] = unitDef.buildOptions
	end

	if unitDef.isFactory and #unitDef.buildOptions > 0 then
		isFactory[unitDefID] = true
	end

	if unitDef.extractsMetal > 0 then
		isMex[unitDefID] = true
	end
end



------------------------------------
-- UNIT ORDER ----------------------
------------------------------------

---At the end of this 'UNIT ORDER' section, unitOrder is an array with unitIDs
---sorted by their value specified in unitOrderManualOverrideTable. If no
---value is specified, the unit will be placed at the end of the array.
---@type number[]
local unitOrder = {}

local unitOrderManualOverrideTable = VFS.Include("luaui/configs/buildmenu_sorting.lua")

-- Populate unitOrder with unit IDs.
local count = 1
for id, _ in pairs(UnitDefs) do
	unitOrder[count] = id
	count = count + 1
end

-- maxOrder is the largest order value found in unitOrderManualOverrideTable.
-- Units with no value in unitOrderManualOverrideTable will implicitly take the
-- maxOrder value when sorting unitOrder below.
local maxOrder = 0
for _, order in pairs(unitOrderManualOverrideTable) do
	if order > maxOrder then
		maxOrder = order
	end
end
maxOrder = maxOrder + 1

-- Sorts unitIDs by their order value (if one exists) specified in
-- unitOrderManualOverrideTable. All units who do not have an order value
-- specified in unitOrderManualOverrideTable are considered to have an order
-- value of maxOrder.
-- For units who have the same order value we compare the unit's IDs.
-- This sort is always stable, as no two units should have the same ID.
table.sort(unitOrder, function(aID, bID)
	local aOrder = unitOrderManualOverrideTable[aID] or maxOrder
	local bOrder = unitOrderManualOverrideTable[bID] or maxOrder

	if (aOrder == bOrder) then
		return aID < bID
	end
	return aOrder < bOrder
end)


local units = {
	unitEnergyCost = unitEnergyCost,
	unitMetalCost = unitMetalCost,
	unitGroup = unitGroup,
	unitRestricted = unitRestricted,
	unitHidden = unitHidden,
	unitIconType = unitIconType,
	unitMaxWeaponRange = unitMaxWeaponRange,
	---Set of unit IDs that are factories.
	isFactory = isFactory,
	---Set of unit IDs that have build options.
	isBuilder = isBuilder,
	---Set of unit IDs that require metal.
	isMex = isMex,
	---An array with unitIDs sorted by their value specified in
	---`unitOrderManualOverrideTable`. If no value is specified, the unit will be
	---placed at the end of the array.
	unitOrder = unitOrder,
}

return units
