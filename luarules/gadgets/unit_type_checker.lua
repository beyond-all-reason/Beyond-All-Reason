
UTC = {}




local moveType = {}
for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	if ud.canFly or ud.isAirUnit then
		if ud.isHoveringAirUnit then
			moveType[i] = 1 -- gunship
		else
			moveType[i] = 2 -- fixedwing
		end
	elseif not ud.isImmobile then
		moveType[i] = 2 -- ground/sea
	else
		moveType[i] = false -- For structures or any other invalid movetype
	end
end

function UTC.getMovetype(ud)
	if ud.canFly or ud.isAirUnit then
		if ud.isHoveringAirUnit then
			return 1 -- gunship
		else
			return 0 -- fixedwing
		end
	elseif not ud.isImmobile then
		return 2 -- ground/sea
	end
	return false -- For structures or any other invalid movetype
end

function UTC.GetMovetypeUnitDefID(unitDefID)
	return unitDefID and moveType[unitDefID]
end

function UTC.getMovetypeByID(unitDefID)
	local ud = unitDefID and UnitDefs[unitDefID]
	if ud then
		return UTC.getMovetype(ud)
	end
	return false
end
--when is a factory not a factory...
function UTC.isGroundFactory(ud)
	if ud.isFactory and (not ud.customParams.notreallyafactory) and ud.buildOptions then
		local buildOptions = ud.buildOptions

		for i = 1, #buildOptions do
			local boDefID = buildOptions[i]

			if (UTC.getMovetypeByID(boDefID) == 2) then
				return true
			end
		end
	end

	return false
end
