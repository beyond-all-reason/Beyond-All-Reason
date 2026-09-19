-- A minimal widget for spring_unsynced_builder_spec. Records the globals the env gave
-- it, and calls the Spring functions the builder's capture hooks replace.

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
