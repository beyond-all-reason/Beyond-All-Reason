--============================================================--

-- Parameter Types

--============================================================--

-- unit = {
--      type = number (unitType),
--      unit = string/number,
--      team = number
--}

local unitType = {
	name = 0,
	unitID = 1,
	unitDefID = 2,
	unitDefName = 3,
}

----------------------------------------------------------------

-- unitDef = {
--      type = number (unitDefType),
--      unitDef = string/number/table,
--      team = number
--}

local unitDefType = {
    name = 0,
    ID = 1,
}

--============================================================--

return {
    unitType = unitType,
    unitDefType = unitDefType,
}

--============================================================--