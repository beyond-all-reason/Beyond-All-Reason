local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitDefID = Spring.GetUnitDefID
VFS.Include("LuaRules/Utilities/isTargetReachable.lua")

function IsTargetReallyReachable(unitID, x,y,z,ux, uy, uz)
	Spring.Echo("IsTargetReallyReachable ran")
	local udid = spGetUnitDefID(unitID)
	local moveID = UnitDefs[udid].moveDef.id
	local reach = true --Note: first assume unit is flying and/or target always reachable
	if moveID then --Note: crane/air-constructor do not have moveID!
		if not ux then
			ux, uy, uz = spGetUnitPosition(unitID)	-- unit location
		end
		local result,finCoord = Spring.Utilities.IsTargetReachable(moveID, ux,uy,uz,x,y,z,128)
		if result == "outofreach" then --if result not reachable (and we'll have the closest coordinate), then:
			reach = false --target is unreachable
		end
		--Technical note: Spring.PathRequest() will return NIL(noreturn) if either origin is too close to target or when pathing is not functional (this is valid for Spring91, may change in different version)
	end
	Spring.Echo("IsTargetReallyReachable result:", reach)
	return reach
end