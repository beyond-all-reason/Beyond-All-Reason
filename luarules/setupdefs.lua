--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    setupdefs.lua
--  brief:   setup some custom UnitDefs parameters,
--           and UnitDefNames, FeatureDefNames, WeaponDefNames
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

for _,ud in pairs(UnitDefs) do

  -- set the cost value  (same as shown in the tooltip)
  ud.cost = ud.metalCost + (ud.energyCost / 60.0)

  -- add the custom weapons based parameters
  ud.hasShield      = false
  ud.canParalyze    = false
  ud.canStockpile   = false
  ud.canAttackWater = false
  for _,wt in ipairs(ud.weapons) do
    local wd = WeaponDefs[wt.weaponDef]
    if (wd) then
      if wd.weapontype == "Shield" then ud.hasShield = true end
      if (wd.paralyzer)   then ud.canParalyze    = true end
      if (wd.stockpile)   then ud.canStockpile   = true end
      if (wd.waterWeapon) then ud.canAttackWater = true end
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- setup the UnitDefNames{} table
do
  local tbl = {}
  for _,def in pairs(UnitDefs) do
    tbl[def.name] = def
  end
  UnitDefNames = tbl
end


-- setup the FeatureDefNames{} table
do
  local tbl = {}
  for _,def in pairs(FeatureDefs) do
    tbl[def.name] = def
  end
  FeatureDefNames = tbl
end


-- setup the WeaponDefNames{} table
do
  local tbl = {}
  for _,def in pairs(WeaponDefs) do
    tbl[def.name] = def
  end
  WeaponDefNames = tbl
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
