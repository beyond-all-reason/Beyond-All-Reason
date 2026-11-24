local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Unit Range XP Update",
		desc = "Applies weapon range bonus when unit earns XP",
		author = "BrainDamage, lonewolfdesign",
		date = "",
		license = "WTFPL",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local ATTRIBUTE_SOURCE = "xp_range_bonus"
local setUnitWeaponModifier -- see api_unit_attributes
local rangeXPScaleByDef = {} ---@type table<UnitDefID, number?>

for unitDefID, unitDef in pairs(UnitDefs) do
	rangeXPScaleByDef[unitDefID] = tonumber(unitDef.customParams.rangexpscale)
end

function gadget:Initialize()
	Spring.SetExperienceGrade(0.01) -- provides step size to gadget:UnitExperience, required
	setUnitWeaponModifier = GG.UnitAttributes.SetUnitWeaponModifier
end

function gadget:UnitExperience(unitID, unitDefID, unitTeam, experience, oldExperience)
	local rangeXPScale = rangeXPScaleByDef[unitDefID]
	if rangeXPScale then
		local limitXP = ((3 * experience) / (1 + 3 * experience)) * rangeXPScale
		setUnitWeaponModifier(unitID, 1, "maxWeaponRange", 1 + limitXP, ATTRIBUTE_SOURCE)
	end
end
