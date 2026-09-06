--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "No Land Damage",
		desc = "Stops torpedo bombers from damaging units when they're on land.",
		author = "TheFatController",
		date = "Aug 31, 2009",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false --  silent removal
end

local GetUnitBasePosition = Spring.GetUnitBasePosition

-- weapondef customparams.land_damage_mult scales damage against targets above water
local LAND_DAMAGE_MULT = {}
for weaponDefID, wd in pairs(WeaponDefs) do
	local mult = wd.customParams and tonumber(wd.customParams.land_damage_mult)
	if mult then
		LAND_DAMAGE_MULT[weaponDefID] = mult
	end
end

function gadget:UnitPreDamaged(
	unitID,
	unitDefID,
	unitTeam,
	damage,
	paralyzer,
	weaponID,
	projectileID,
	attackerID,
	attackerDefID,
	attackerTeam
)
	local mult = LAND_DAMAGE_MULT[weaponID]
	if mult and select(2, GetUnitBasePosition(unitID)) > 0 then
		return (damage * mult), 1
	end
	return damage, 1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
