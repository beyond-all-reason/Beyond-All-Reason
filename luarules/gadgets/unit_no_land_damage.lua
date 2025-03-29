--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "No Land Damage",
        desc      = "Stops torpedo bombers from damaging units when they're on land.",
        author    = "TheFatController",
        date      = "Aug 31, 2009",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

if not gadgetHandler:IsSyncedCode() then
  return false  --  silent removal
end

local GetUnitBasePosition = Spring.GetUnitBasePosition

local weapons = {'armair_torpedo', 'armseap_weapon'}
local NO_LAND_DAMAGE = {}
for wdid, wd in pairs(WeaponDefNames) do
  for _, wname in pairs(weapons) do
    if string.find(wd.name, wname) then
      NO_LAND_DAMAGE[wdid] = true
    end
  end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
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