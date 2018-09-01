
function Spring.Utilities.getMovetype(ud)
	if ud.canFly or ud.isAirUnit then
		if ud.isHoveringAirUnit then
			return 1 -- gunship
		else
			return 0 -- fixedwing
		end
	elseif not (ud.isBuilding or ud.isFactory or ud.speed == 0) then
		return 2 -- ground/sea
	end
	return false -- For structures or any other invalid movetype
end

function Spring.Utilities.getMovetypeByID(unitDefID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if ud then
		Spring.Utilities.getMovetype(ud)
	end
	return false
end

function Spring.Utilities.BlueprintFloat(ud)
	return ud.floatOnWater
end
