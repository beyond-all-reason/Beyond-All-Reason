function gadget:GetInfo()
	return {
		name	= "Only Target Category (surface only)",
		desc	= "Prevents attacking anything other than the only target category",
		author	= "Floris",
		date	= "January 2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local onlyTargetsSurface = {}
for udid, unitDef in pairs(UnitDefs) do
	for wid, weapon in ipairs(unitDef.weapons) do
		if weapon.onlyTargets['surface'] then
			local i = 0
			for category, _ in pairs(weapon.onlyTargets) do
				i = i + 1
			end
			if i == 1 then
				onlyTargetsSurface[udid] = true
			end
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, synced)
	if cmdID == CMD.ATTACK and cmdParams[2] == nil and onlyTargetsSurface[unitDefID] and not UnitDefs[Spring.GetUnitDefID(cmdParams[1])].modCategories['surface'] then
		return false
	else
		return true
	end
end