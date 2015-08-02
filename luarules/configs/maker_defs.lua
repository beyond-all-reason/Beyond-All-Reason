
local AC0 = 1/60
local AC1 = 1/55
local AC2 = 1/50
local AC3 = 1/46



local convertCapacities = {

	[UnitDefNames.armmakr.id]  = { c = (60), e = (AC0) }, 
        [UnitDefNames.cormakr.id]  = { c = (60), e = (AC0) },
        [UnitDefNames.armfmkr.id]  = { c = (60), e = (AC1) },
        [UnitDefNames.corfmkr.id]  = { c = (60), e = (AC1) },
        [UnitDefNames.armmmkr.id]  = { c = (600), e = (AC2) }, 
        [UnitDefNames.cormmkr.id]  = { c = (600), e = (AC2) },
        [UnitDefNames.armuwmmm.id] = { c = (600), e = (AC3) }, 
        [UnitDefNames.coruwmmm.id] = { c = (600), e = (AC3) },
    }


return convertCapacities

