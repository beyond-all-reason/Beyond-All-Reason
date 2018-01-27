function gadget:GetInfo()
	return {
		name	= "Bladewings",
		desc	= "Prevents attacking anything other than surface category units",
		author	= "Floris",
		date	= "January 2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local bladewingUnitDefID
for udid, unitDef in pairs(UnitDefs) do
	if unitDef.name == 'corbw' then
		bladewingUnitDefID = udid
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)

	if unitDefID == bladewingUnitDefID and cmdID == CMD.ATTACK and cmdParams[2] == nil and not UnitDefs[Spring.GetUnitDefID(cmdParams[1])].modCategories['surface'] then
		return false
	else
		return true
	end
end