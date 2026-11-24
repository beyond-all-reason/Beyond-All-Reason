local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Only Target onlytargetcategory",
		desc = "Prevents attacking anything other than the only target category",
		author = "Floris",
		date = "September 2020",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local unitCategories = {}
local unitOnlyTargetsCategory = {}
local unitDontAttackGround = {}
for udid, unitDef in pairs(UnitDefs) do
	if unitDef.modCategories then
		unitCategories[udid] = unitDef.modCategories
	end

	for wid, weapon in ipairs(unitDef.weapons) do
		if weapon.onlyTargets then
			local disregard = false
			for category, _ in pairs(weapon.onlyTargets) do
				if unitOnlyTargetsCategory[udid] == nil then
					unitOnlyTargetsCategory[udid] = category
					if category == "vtol" then
						unitDontAttackGround[udid] = true
					end
				elseif unitOnlyTargetsCategory[udid] ~= category then -- multiple different onlytargetcategory used: disregard
					unitOnlyTargetsCategory[udid] = nil
					unitDontAttackGround[udid] = nil -- If there are multiple categories, then it can shoot ground, and should be allowed to do so
					disregard = true
					break
				end
			end
			if disregard then
				break
			end
		end
	end
end

local function matchesCategory(targetID, category)
	local categories = unitCategories[Spring.GetUnitDefID(targetID)]
	return categories and categories[category]
end

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD.ATTACK)
	GG.AttackListMatchesTargetCategory = function(unitDefID, targetIDs)
		local category = unitOnlyTargetsCategory[unitDefID]
		if category then
			for _, targetID in ipairs(targetIDs) do
				if not matchesCategory(targetID, category) then
					return false
				end
			end
		end
		return true
	end
end

function gadget:Shutdown()
	GG.AttackListMatchesTargetCategory = nil
end

function gadget:AllowCommand(
	unitID,
	unitDefID,
	teamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	-- accepts: CMD.ATTACK
	if
		cmdParams[2] == nil
		and unitOnlyTargetsCategory[unitDefID]
		and type(cmdParams[1]) == "number"
		and not matchesCategory(cmdParams[1], unitOnlyTargetsCategory[unitDefID])
	then
		return false
	else
		if cmdParams[2] and unitDontAttackGround[unitDefID] then
			return false
		else
			return true
		end
	end
end
