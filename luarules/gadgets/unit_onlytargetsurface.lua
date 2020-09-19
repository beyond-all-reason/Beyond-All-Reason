function gadget:GetInfo()
	return {
		name	= "Only Target Surface",
		desc	= "Prevents attacking anything other than the only target category",
		author	= "Floris",
		date	= "January 2018",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local category = 'surface'

local onlyTargetsCategory = {}
local unitMayBeTargeted = {}
for udid, unitDef in pairs(UnitDefs) do
	local skip = false
	local add = false
	for wid, weapon in ipairs(unitDef.weapons) do
		if weapon.onlyTargets[category] then
			local i = 0
			for category, _ in pairs(weapon.onlyTargets) do
				i = i + 1
			end
			if i == 1 then
				add = true
			end
		else
			skip = true
		end
		-- add crawling bombs
		local length = string.len(WeaponDefs[weapon.weaponDef].name)
		if length > 14 then
			if string.sub(WeaponDefs[weapon.weaponDef].name, length-14, length) == 'crawl_detonator' then
				skip = false
				add = true
			end
		end
	end
	if not skip and add then
		onlyTargetsCategory[udid] = true
	end
	if unitDef.modCategories[category] then
		unitMayBeTargeted[udid] = true
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cmdID == CMD.ATTACK
	and cmdParams[2] == nil
	and onlyTargetsCategory[unitDefID]
	and type(cmdParams[1]) == 'number'
	and not unitMayBeTargeted[Spring.GetUnitDefID(cmdParams[1])] then
		return false
	else
		return true
	end
end
