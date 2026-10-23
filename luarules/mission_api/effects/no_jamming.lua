---
--- No Jamming: every unit loses its radar jamming. The area and strength are ignored.
---

local setUnitDefAttribute = GG.UnitAttributes.SetUnitDefAttribute

local SOURCE_PREFIX = "effect:no_jamming:"
local ATTRIBUTE = "jammerRadius"

local jammerUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.jammerRadius > 0 then
		jammerUnitDefIDs[#jammerUnitDefIDs + 1] = unitDefID
	end
end

local generation = 0 -- effects can reapply so must be identified uniquely

local function removeJamming()
	generation = generation + 1
	local source = SOURCE_PREFIX .. generation
	for i = 1, #jammerUnitDefIDs do
		setUnitDefAttribute(jammerUnitDefIDs[i], ATTRIBUTE, 0, source)
	end
	return source
end

local function restoreJamming(source)
	for i = 1, #jammerUnitDefIDs do
		setUnitDefAttribute(jammerUnitDefIDs[i], ATTRIBUTE, nil, source)
	end
end

return {
	type = "NoJamming",
	Create = removeJamming,
	Remove = restoreJamming,
}
