function gadget:GetInfo()
	return {
		name      = "Death Animations",
		desc      = "Prevent moving of Dying units",
		author    = "Beherith",
		date      = "2020",
		license   = "CC BY NC ND",
		layer     = 1000,
		enabled   = true,
	}
end

if (not gadgetHandler:IsSyncedCode()) then
	return
end

local hasDeathAnim = {
  [UnitDefNames.corkarg.id] = true,
  [UnitDefNames.corthud.id] = true,
  [UnitDefNames.corstorm.id] = true,
  [UnitDefNames.corsumo.id] = true,
}

for udid, ud in pairs(UnitDefs) do
	if ud.customParams and ud.customParams.subfolder and ud.customParams.subfolder == "other/chickens" then
    
		hasDeathAnim[udid] = true
	end
end

local SetUnitNoSelect	= Spring.SetUnitNoSelect
local GiveOrderToUnit	= Spring.GiveOrderToUnit
local CMD_STOP = CMD.STOP

function gadget:UnitDestroyed(unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
	if hasDeathAnim[unitDefID] then
		--Spring.Echo("gadget:UnitDestroyed",unitID, unitDefID, teamID, attackerID, attackerDefID, attackerTeamID)
		SetUnitNoSelect(unitID,true)
		GiveOrderToUnit(unitID, CMD_STOP, {}, 0)
	end
end
