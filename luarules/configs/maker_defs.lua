
local AC0 = 140
local AC2 = 120

local convertCapacities = {
	[UnitDefNames.armmakr.id]  = { c = (70), e = (AC0) }, 
    [UnitDefNames.cormakr.id]  = { c = (70), e = (AC0) },
    [UnitDefNames.armfmkr.id]  = { c = (70), e = (AC0) },
    [UnitDefNames.corfmkr.id]  = { c = (70), e = (AC0) },
    [UnitDefNames.armmmkr.id]  = { c = (600), e = (AC2) }, 
    [UnitDefNames.cormmkr.id]  = { c = (600), e = (AC2) },
    [UnitDefNames.armuwmmm.id] = { c = (600), e = (AC2) }, 
    [UnitDefNames.coruwmmm.id] = { c = (600), e = (AC2) },
}
local convertRates = {
	["flat"] = 1.0, --(1.0/AC)
	["scale"] = 0.6, --(0.6%/AC)
	}

return convertCapacities, convertRates

