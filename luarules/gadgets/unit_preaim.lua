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

--use weaponDef.customparams.exclude_preaim = true to exclude units from being able to pre-aim at targets almost within firing range.
--this is a good idea for pop-up turrets so they don't prematurely reveal themselves.
--also when proximityPriority is heavily biased toward far targets

local rangeBoost = {}
local isPreaimUnit = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if not unitDef.canFly then
		local weapons = unitDef.weapons
		if #weapons > 0 then
			for i=1, #weapons do
				if not WeaponDefs[weapons[i].weaponDef].customParams.exclude_preaim then
					isPreaimUnit[unitDefID] = isPreaimUnit[unitDefID] or {}

					local weaponDefID = weapons[i].weaponDef
					isPreaimUnit[unitDefID][i] = weaponDefID
					rangeBoost[weaponDefID] = math.max(0.1 * WeaponDefs[weaponDefID].range, 20)
				end
			end
		end
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	if isPreaimUnit[unitDefID] then
		for id, wdefID in pairs(isPreaimUnit[unitDefID]) do
			Spring.SetUnitWeaponState(unitID, id, "autoTargetRangeBoost", rangeBoost[wdefID])
		end
	end
end
