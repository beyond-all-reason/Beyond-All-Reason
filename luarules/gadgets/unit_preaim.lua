local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Pre-aim",
		desc = "Makes units preaim their weapons before its actually in range'",
		author = "Doo, Floris",
		date = "April 2018",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local spSetUnitWeaponState = Spring.SetUnitWeaponState

--use weaponDef.customparams.exclude_preaim = true to exclude units from being able to pre-aim at targets almost within firing range.
--this is a good idea for pop-up turrets so they don't prematurely reveal themselves.
--also when proximityPriority is heavily biased toward far targets

local autoTargetRangeBoost = {}

for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.canFly then
		local weaponBoost = {}

		local weapons = unitDef.weapons
		for i = 1, #weapons do
			local weaponDefID = weapons[i].weaponDef
			local weaponDef = WeaponDefs[weaponDefID]

			if not weaponDef.customParams.exclude_preaim then
				local range = weaponDef.range
				local param = tonumber(weaponDef.customParams.preaim_range)
				local boost = math.max(20, range * 0.10, (param or 0) - range)
				weaponBoost[i] = boost
			end
		end

		if next(weaponBoost) then
			autoTargetRangeBoost[unitDefID] = weaponBoost
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	local unitData = autoTargetRangeBoost[unitDefID]
	if unitData then
		for weaponNum, rangeBoost in pairs(unitData) do
			spSetUnitWeaponState(unitID, weaponNum, "autoTargetRangeBoost", rangeBoost)
		end
	end
end
