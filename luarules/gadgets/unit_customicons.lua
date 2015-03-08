--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    ico_customicons.lua
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
-- This gadget checks through the attributes of each unitdef and assigns an appropriate icon for use in the minimap & zoomed out mode.
--
-- The reason that this is a gadget (it could also be a widget) and not part of weapondefs_post.lua/iconTypes.lua is the following:  
-- the default valuesfor UnitDefs attributes that are not specified in our unitdefs lua files are only loaded into UnitDefs AFTER  
-- unitdefs_post.lua and iconTypes.lua have been processed. For example, at the time of unitdefs_post, for most units ud.speed is  
-- nil and not a number, so we can't e.g. compare it to zero. Also, it's more modularized as a widget/gadget. 
-- [We could set the default values up in unitdefs_post to match engine defaults but thats just too hacky.]
--
-- Bluestone 27/04/2013
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "CustomIcons",
    desc      = "Sets custom unit icons for BA",
    author    = "trepan,BD,TheFatController",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -100,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then
  return false
end

--------------------------------------------------------------------------------

local wasLuaModUIEnabled = 0

--------------------------------------------------------------------------------

function gadget:Initialize()

  Spring.AddUnitIcon("armcom.user", "LuaUI/Icons/armcom.png",2)
  Spring.AddUnitIcon("corcom.user", "LuaUI/Icons/corcom.png",2)
  Spring.AddUnitIcon("cross.user", "LuaUI/Icons/cross.png")
  Spring.AddUnitIcon("diamond.user", "LuaUI/Icons/diamond.png",1.1)
  Spring.AddUnitIcon("e.user", "LuaUI/Icons/e.png")
  Spring.AddUnitIcon("e2.user", "LuaUI/Icons/e.png",1.4)
  Spring.AddUnitIcon("e3.user", "LuaUI/Icons/e.png",1.8)
  Spring.AddUnitIcon("hemi-down.user", "LuaUI/Icons/hemi-down.png",1.3)
  Spring.AddUnitIcon("hemi-up.user", "LuaUI/Icons/hemi-up.png")
  Spring.AddUnitIcon("hemi.user", "LuaUI/Icons/hemi.png")
  Spring.AddUnitIcon("hourglass-side.user", "LuaUI/Icons/hourglass-side.png")
  Spring.AddUnitIcon("hourglass.user", "LuaUI/Icons/hourglass.png")
  Spring.AddUnitIcon("krogoth.user", "LuaUI/Icons/krogoth.png",3)
  Spring.AddUnitIcon("m-down.user", "LuaUI/Icons/m-down.png")
  Spring.AddUnitIcon("m-up.user", "LuaUI/Icons/m-up.png")
  Spring.AddUnitIcon("m.user", "LuaUI/Icons/m.png")
  Spring.AddUnitIcon("nuke.user", "LuaUI/Icons/nuke.png",1.25)
  Spring.AddUnitIcon("slash.user", "LuaUI/Icons/slash.png") 
  Spring.AddUnitIcon("sphere.user", "LuaUI/Icons/ba_sphere.png",1.1)
  Spring.AddUnitIcon("sphere2.user", "LuaUI/Icons/ba_sphere.png",1.35)
  Spring.AddUnitIcon("sphere3.user", "LuaUI/Icons/ba_sphere.png",1.7)
  Spring.AddUnitIcon("square.user", "LuaUI/Icons/square.png")
  Spring.AddUnitIcon("square_+.user", "LuaUI/Icons/square_+.png")
  Spring.AddUnitIcon("square_x.user", "LuaUI/Icons/square_x.png")
  Spring.AddUnitIcon("square_x_factory.user", "LuaUI/Icons/square_x.png",1.5)
  Spring.AddUnitIcon("star-dark.user", "LuaUI/Icons/star-dark.png")
  Spring.AddUnitIcon("star.user", "LuaUI/Icons/star.png")
  Spring.AddUnitIcon("tiny-sphere.user", "LuaUI/Icons/ba_sphere.png",0.55)
  Spring.AddUnitIcon("tiny-square.user", "LuaUI/Icons/square.png",0.55)
  Spring.AddUnitIcon("tri-down.user", "LuaUI/Icons/tri-down.png",1.3)
  Spring.AddUnitIcon("tri-up.user", "LuaUI/Icons/tri-up.png",1.4)
  Spring.AddUnitIcon("tri-up_fighter.user", "LuaUI/Icons/tri-up.png",0.9)
  Spring.AddUnitIcon("triangle-down.user", "LuaUI/Icons/triangle-down.png")
  Spring.AddUnitIcon("triangle-up.user", "LuaUI/Icons/triangle-up.png")
  Spring.AddUnitIcon("x.user", "LuaUI/Icons/x.png")
   
  -- Setup the unitdef icons
  for udid,ud in pairs(UnitDefs) do
  
    if (ud ~= nil) then
      
      if (ud.name=="roost") or (ud.name=="meteor") then
        Spring.SetUnitDefIcon(udid, "star.user")
      elseif (ud.name=="armwin") or (ud.name=="corwin") then
        Spring.SetUnitDefIcon(udid, "e.user")
      elseif (ud.name=="armfig") or (ud.name=="corveng") or (ud.name=="armhawk") or (ud.name=="corvamp") then
        Spring.SetUnitDefIcon(udid, "tri-up_fighter.user") 
      elseif (ud.name=="cafus") or (ud.name=="aafus") then
        Spring.SetUnitDefIcon(udid, "e3.user")
      elseif (ud.name=="armfus") or (ud.name=="corfus") or (ud.name=="armckfus") or (ud.name=="armdf") or (ud.name=="armuwfus") or (ud.name=="coruwfus") then
        Spring.SetUnitDefIcon(udid, "e2.user")
      elseif (ud.name=="armcom") or (ud.name=="armdecom") then
        Spring.SetUnitDefIcon(udid, "armcom.user")
      elseif (ud.name=="corcom") or (ud.name=="cordecom") then
        Spring.SetUnitDefIcon(udid, "corcom.user")
      elseif (ud.name=="corkrog") then
        Spring.SetUnitDefIcon(udid, "krogoth.user")
      elseif (ud.isFactory) then
        -- factories
        Spring.SetUnitDefIcon(udid, "square_x_factory.user")
      elseif (ud.isBuilder) then
        -- builders
        if ((ud.speed > 0) and ud.canMove) then
          Spring.SetUnitDefIcon(udid, "cross.user")     -- mobile
        else
          Spring.SetUnitDefIcon(udid, "square_+.user")  -- immobile
        end
      elseif (ud.stockpileWeaponDef ~= nil) and not (ud.name=="mercury" or ud.name=="screamer") then
      	-- nuke / antinuke ( stockpile weapon, but not mercury/screamer )
      	Spring.SetUnitDefIcon(udid, "nuke.user")
      elseif (ud.canFly) then
        -- aircraft
        Spring.SetUnitDefIcon(udid, "tri-up.user")
      elseif ((ud.speed <= 0) and ud.shieldWeaponDef) then
        -- immobile shields
        Spring.SetUnitDefIcon(udid, "hemi-up.user")
      elseif ((ud.extractsMetal > 0) or (ud.makesMetal > 0)) or
	(ud.name=="armmakr") or (ud.name=="armfmkr") or (ud.name=="armmmkr") or (ud.name=="armuwmmm") or
	(ud.name=="cormakr") or (ud.name=="corfmkr") or (ud.name=="cormmkr") or (ud.name=="coruwmmm") then
        -- metal extractors and makers
        Spring.SetUnitDefIcon(udid, "m.user")
      elseif ((ud.totalEnergyOut > 10) and (ud.speed <= 0)) then
        -- energy generators
        Spring.SetUnitDefIcon(udid, "e.user")
      elseif (ud.isTransport) then
        -- transports
        Spring.SetUnitDefIcon(udid, "diamond.user")
      elseif ((ud.minWaterDepth > 0) and (ud.speed > 0) and (ud.waterline > 12)) then
        -- submarines
        Spring.SetUnitDefIcon(udid, "tri-down.user")
      elseif ((ud.minWaterDepth > 0) and (ud.speed > 0)) then
        -- ships
        Spring.SetUnitDefIcon(udid, "hemi-down.user")
      elseif (((ud.radarRadius > 1) or
               (ud.sonarRadius > 1) or
               (ud.seismicRadius > 1)) and (ud.speed <= 0) and (#ud.weapons <= 0)) then
        -- sensors
        Spring.SetUnitDefIcon(udid, "hourglass-side.user")
      elseif (((ud.jammerRadius > 1) or
               (ud.sonarJamRadius > 1)) and (ud.speed <= 0)) then
        -- jammers
        Spring.SetUnitDefIcon(udid, "hourglass.user")
      elseif (ud.isBuilding or (ud.speed <= 0)) then
         -- defenders and other buildings
        if (#ud.weapons <= 0) then
          Spring.SetUnitDefIcon(udid, "square.user")
        else
		  if ud.weapons[1].onlyTargets["vtol"] then
			Spring.SetUnitDefIcon(udid, "slash.user")		  
		  else
			Spring.SetUnitDefIcon(udid, "x.user")
		  end
        end
      else
        if (ud.techLevel == 4) then
          Spring.SetUnitDefIcon(udid, "sphere2.user")
        elseif (ud.techLevel == 6) then
          Spring.SetUnitDefIcon(udid, "sphere3.user")
        else
          Spring.SetUnitDefIcon(udid, "sphere.user")
        end
      end
    end
  end
  
  -- Shrink scouts
  Spring.SetUnitDefIcon(UnitDefNames["corfav"].id, "tiny-sphere.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfav"].id, "tiny-sphere.user")
  Spring.SetUnitDefIcon(UnitDefNames["corak"].id, "tiny-sphere.user")
  Spring.SetUnitDefIcon(UnitDefNames["armpw"].id, "tiny-sphere.user")
  Spring.SetUnitDefIcon(UnitDefNames["armflea"].id, "tiny-sphere.user")
  
  -- Walls
  Spring.SetUnitDefIcon(UnitDefNames["cordrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armdrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfort"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfort"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfdrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfdrag"].id, "tiny-square.user")

end

--------------------------------------------------------------------------------

