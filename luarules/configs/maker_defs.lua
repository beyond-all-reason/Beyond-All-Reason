
local AC0 = 1/70
local AC1 = 1/64
local AC2 = 1/58

local convertCapacities = {
	[UnitDefNames.armmakr.id]  = { c = (70), e = (AC0) }, 
    [UnitDefNames.cormakr.id]  = { c = (70), e = (AC0) },
    [UnitDefNames.armfmkr.id]  = { c = (70), e = (AC1) },
    [UnitDefNames.corfmkr.id]  = { c = (70), e = (AC1) },
    [UnitDefNames.armmmkr.id]  = { c = (600), e = (AC2) }, 
    [UnitDefNames.cormmkr.id]  = { c = (600), e = (AC2) },
    [UnitDefNames.armuwmmm.id] = { c = (650), e = (AC2) }, 
    [UnitDefNames.coruwmmm.id] = { c = (650), e = (AC2) },
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

return convertCapacities

