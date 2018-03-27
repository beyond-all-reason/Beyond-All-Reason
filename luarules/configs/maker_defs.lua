
local AC0 = 1/140
local AC2 = 1/120

local convertCapacities = {
	[UnitDefNames.armmakr.id]  = { c = (70), e = (AC0) }, 
    [UnitDefNames.cormakr.id]  = { c = (70), e = (AC0) },
    [UnitDefNames.armfmkr.id]  = { c = (77), e = (AC0) },
    [UnitDefNames.corfmkr.id]  = { c = (77), e = (AC0) },
    [UnitDefNames.armmmkr.id]  = { c = (600), e = (AC2) }, 
    [UnitDefNames.cormmkr.id]  = { c = (600), e = (AC2) },
    [UnitDefNames.armuwmmm.id] = { c = (660), e = (AC2) }, 
    [UnitDefNames.coruwmmm.id] = { c = (660), e = (AC2) },
}

return convertCapacities

