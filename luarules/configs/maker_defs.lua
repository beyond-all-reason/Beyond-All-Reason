
local AC0 = 1/70
local AC1 = 1/64
local AC2 = 1/58

local convertCapacities = {
	['armmakr']  = { c = (70), e = (AC0) },
    ['cormakr']  = { c = (70), e = (AC0) },
    ['armfmkr']  = { c = (70), e = (AC1) },
    ['corfmkr']  = { c = (70), e = (AC1) },
    ['armmmkr']  = { c = (600), e = (AC2) }, 
    ['cormmkr']  = { c = (600), e = (AC2) },
    ['armuwmmm'] = { c = (650), e = (AC2) }, 
    ['coruwmmm'] = { c = (650), e = (AC2) },
}
for name, v in pairs(convertCapacities) do
    for udid, ud in pairs(UnitDefs) do
        if string.find(ud.name, name) then
            convertCapacities[ud.name] = v
        end
    end
end

local convertCapacitiesProcessed = {}
for k,v in pairs(convertCapacities) do
    convertCapacitiesProcessed[UnitDefNames[k].id] = v
end
convertCapacities = nil

return convertCapacitiesProcessed

