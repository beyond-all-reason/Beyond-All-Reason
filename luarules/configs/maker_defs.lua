
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
if Spring.GetModOptions and (tonumber(Spring.GetModOptions().scavengers) or 0) ~= 0 then
    local convertCapacitiesScavs = {}
    for k,v in pairs(convertCapacities) do
        convertCapacitiesScavs[k..'_scav'] = v
    end
    for k,v in pairs(convertCapacitiesScavs) do
        convertCapacities[k] = v
    end
    convertCapacitiesScavs = nil
end

local convertCapacitiesProcessed = {}
for k,v in pairs(convertCapacities) do
    convertCapacitiesProcessed[UnitDefNames[k].id] = v
end
convertCapacities = nil

return convertCapacitiesProcessed

