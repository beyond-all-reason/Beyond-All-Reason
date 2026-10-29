---
--- No Radar: every unit loses its radar. The area and strength are ignored.
---

local setUnitDefAttribute = GG.UnitAttributes.SetUnitDefAttribute

local ATTRIBUTE = "radarRadius"
local SOURCE_PREFIX = "effect:NoRadar:"

local radarUnitDefIDs = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.radarRadius > 0 then
		radarUnitDefIDs[#radarUnitDefIDs + 1] = unitDefID
	end
end

local generation = 0 -- effects can reapply so must be identified uniquely

local function removeRadar()
	generation = generation + 1
	local source = SOURCE_PREFIX .. generation
	for i = 1, #radarUnitDefIDs do
		setUnitDefAttribute(radarUnitDefIDs[i], ATTRIBUTE, 0, source)
	end
	return source
end

local function restoreRadar(source)
	for i = 1, #radarUnitDefIDs do
		setUnitDefAttribute(radarUnitDefIDs[i], ATTRIBUTE, nil, source)
	end
end

return {
	type = "NoRadar",
	Create = removeRadar,
	Remove = restoreRadar,
}
