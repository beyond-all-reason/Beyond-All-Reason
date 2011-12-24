function gadget:GetInfo()
  return {
    name      = "prevent_flying_com_wrecks",
    desc      = "prevent_flying_com_wrecks",
    author    = "TheFatController",
    date      = "17 Aug 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return
end

local GetUnitHealth = Spring.GetUnitHealth
--local LICHE_BOMB = WeaponDefNames['arm_pidr'].id

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	--if (UnitDefs[unitDefID].isCommander) and ((damage > GetUnitHealth(unitID)) or (weaponID==LICHE_BOMB)) then
	if UnitDefs[unitDefID].customParams.iscommander and damage > GetUnitHealth(unitID) then
		return damage, 0
	end
	return damage, 1
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------