-- A minimal widget for exercising SpringUnsyncedBuilder. It records what the
-- sandbox exposed to it, then reads and writes through the standard widget
-- surface so the builder's capture hooks have something to catch.

---@diagnostic disable: undefined-global

local function GetInfo()
	return { name = "tmp_unsynced" }
end

local seen = {
	unitDefs = UnitDefs,
	platformGl = Platform and Platform.gl,
	isHeadless = Platform and (Platform.isHeadless or not Platform.gl),
}

function widget:Initialize()
	WG["tmp_unsynced"] = {
		seen = seen,
		callGiveOrder = function(unitID, cmdID)
			Spring.GiveOrderToUnit(unitID, cmdID, {}, {})
		end,
		callGiveOrderArray = function(unitIDs, orders)
			Spring.GiveOrderArrayToUnitArray(unitIDs, orders, false)
		end,
		getUnitDefID = function(id)
			return Spring.GetUnitDefID(id)
		end,
	}
end

return GetInfo
