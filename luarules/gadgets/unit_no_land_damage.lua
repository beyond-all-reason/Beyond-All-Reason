--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "No Land Damage",
    desc      = "Stops torpedo bombers from damaging units when they're on land.",
    author    = "TheFatController",
    date      = "Aug 31, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false  --  silent removal
end

local GetUnitBasePosition = Spring.GetUnitBasePosition

local NO_LAND_DAMAGE = {
  [WeaponDefNames['armlance_armair_torpedo'].id] = true,
  [WeaponDefNames['cortitan_armair_torpedo'].id] = true,
  [WeaponDefNames['armseap_armseap_weapon1'].id] = true,
  [WeaponDefNames['corseap_armseap_weapon1'].id] = true,
}

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, 
                            weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  if NO_LAND_DAMAGE[weaponID] then
    if select(2,GetUnitBasePosition(unitID)) > 0 then 
      return (damage * 0.2),1
    else 
      return damage,1
    end
  else
    return damage,1
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------