--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
    return {
        name      = "No Self Pwn",
        desc      = "Prevents Some units from damaging themselves.",
        author    = "quantum/TheFatController",
        date      = "Feb 1, 2008",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true  --  loaded by default?
    }
end

if not gadgetHandler:IsSyncedCode() then
  return false  --  silent removal
end

local GetUnitHealth = Spring.GetUnitHealth
local SetUnitHealth = Spring.SetUnitHealth

local PWN_UNITS = {
  [UnitDefNames.corpyro.id] = true,
  [UnitDefNames.cormaw.id] = true,
  [UnitDefNames.corthud.id] = true,
  [UnitDefNames.armham.id] = true,
  [UnitDefNames.armfav.id] = true,
  [UnitDefNames.corfav.id] = true,
  [UnitDefNames.corak.id] = true,
  [UnitDefNames.corpt.id] = true,
  [UnitDefNames.armpt.id] = true,
  [UnitDefNames.armdecade.id] = true,
  [UnitDefNames.coresupp.id] = true,
}
for udid, ud in pairs(UnitDefs) do
  for id, v in pairs(PWN_UNITS) do
    if string.find(ud.name, UnitDefs[id].name) then
      PWN_UNITS[id] = v
    end
  end
end

function gadget:UnitPreDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, projectileID, attackerID, attackerDefID, attackerTeam)
  if unitID == attackerID and PWN_UNITS[unitDefID] then
    return 0, 0
  else
    return damage,1
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------