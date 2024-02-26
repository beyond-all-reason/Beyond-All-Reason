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

local weaponRange = {}
local isPreaimUnit = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.canFly then
		local weapons = unitDef.weapons
		if #weapons > 0 then
			for i=1, #weapons do
				if not isPreaimUnit[unitDefID] then
					isPreaimUnit[unitDefID] = {}
				end
				local weaponDefID = weapons[i].weaponDef
				isPreaimUnit[unitDefID][i] = weaponDefID
				weaponRange[weaponDefID] = WeaponDefs[weaponDefID].range
			end
		end
	end
end

local exludedUnits = {    -- exclude auto target range boost for popup units
	[UnitDefNames.armada_dragonsclaw.id] = true,
	[UnitDefNames.armada_pitbull.id] = true,
	[UnitDefNames.armada_rattlesnake.id] = true,
	[UnitDefNames.cortex_dragonsmaw.id] = true,
	[UnitDefNames.cortex_scorpion.id] = true,
	[UnitDefNames.cortex_agitator.id] = true,
	[UnitDefNames.cortex_exploiter.id] = true,

	[UnitDefNames.cortex_guard.id] = true,
	[UnitDefNames.cortex_twinguard.id] = true,
	[UnitDefNames.armada_sentry.id] = true,
	[UnitDefNames.leginc.id] = true,
}
local scavengerPopups = {}
for k, v in pairs(exludedUnits) do
	scavengerPopups[k .. '_scav'] = v
end
for k, v in pairs(scavengerPopups) do
	exludedUnits[k] = v
end
scavengerPopups = nil
for k, v in pairs(exludedUnits) do
	isPreaimUnit[k] = nil
end

function gadget:UnitCreated(unitID, unitDefID)
	if isPreaimUnit[unitDefID] then
		for id, wdefID in pairs(isPreaimUnit[unitDefID]) do
			Spring.SetUnitWeaponState(unitID, id, "autoTargetRangeBoost", (0.1 * weaponRange[wdefID]) or 20)
		end
	end
end
