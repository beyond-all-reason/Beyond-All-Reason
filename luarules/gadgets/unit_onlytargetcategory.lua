local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Only Target onlytargetcategory",
		desc	= "Prevents attacking anything other than the only target category",
		author	= "Floris",
		date	= "September 2020",
		license	= "GNU GPL, v2 or later",
		layer	= 0,
		enabled	= true,
	}
end

local unitCategories = {}
local unitOnlyTargetsCategory = {}
local unitDontAttackGround = {}
for udid, unitDef in pairs(UnitDefs) do
	if unitDef.modCategories then
		unitCategories[udid] = unitDef.modCategories
	end

	local skip = false
	local add = false
	for wid, weapon in ipairs(unitDef.weapons) do
		if weapon.onlyTargets then
			local i = 0
			for category, _ in pairs(weapon.onlyTargets) do
				i = i + 1
				if not unitOnlyTargetsCategory[udid] then
					unitOnlyTargetsCategory[udid] = category
					if category == 'vtol' then
						unitDontAttackGround[udid] = true
					end
				elseif unitOnlyTargetsCategory[udid] ~= category then	-- multiple different onlytargetcategory used: disregard
					unitOnlyTargetsCategory[udid] = nil
					unitDontAttackGround[udid] = nil -- If there are multiple categories, then it can shoot ground, and should be allowed to do so
					break
				end
			end
		end
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	-- accepts: CMD.ATTACK
	if cmdParams[2] == nil
	and unitOnlyTargetsCategory[unitDefID]
	and type(cmdParams[1]) == 'number'
	and not (unitCategories[Spring.GetUnitDefID(cmdParams[1])] and unitCategories[Spring.GetUnitDefID(cmdParams[1])][unitOnlyTargetsCategory[unitDefID]]) then
		return false
	else
		if cmdParams[2] and unitDontAttackGround[unitDefID] then
			return false
		else
			return true
		end
	end
end
