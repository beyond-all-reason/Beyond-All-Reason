local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name		= "Unit Range XP Update",
		desc		= "Applies weapon range bonus when unit earns XP",
		author		= "BrainDamage, lonewolfdesign",
		date		= "",
		license		= "WTFPL",
		layer		= 0,
		enabled		= true
	}
end


if not gadgetHandler:IsSyncedCode() then
	return false
end


local spSetUnitWeaponState = Spring.SetUnitWeaponState
local spSetUnitMaxRange = Spring.SetUnitMaxRange
local gainsRangeFromXp = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.customParams.rangexpscale ~= nil then
		gainsRangeFromXp[unitDefID] = { unitDef.customParams.rangexpscale, WeaponDefs[unitDef.weapons[1].weaponDef].range }
	end
end

function gadget:Initialize()
	Spring.SetExperienceGrade(0.01) --without this, gadget:UnitExperience doesn't work at all.
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, xp, oldxp)
	if gainsRangeFromXp[unitDefID] then
		local rangeXPScale, originalRange = unpack(gainsRangeFromXp[unitDefID])
		local limitXP = ((3 * xp) / (1 + 3 * xp)) * rangeXPScale
		local newRange = originalRange * (1 + limitXP)

		spSetUnitWeaponState(unitID, 1, "range", newRange)
		spSetUnitMaxRange(unitID, newRange)
	end
end
