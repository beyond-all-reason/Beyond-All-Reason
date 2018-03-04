
local AC0 = 1/140
local AC1 = 1/128
local AC2 = 1/116

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

return convertCapacities

