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
  local vehUnits = {
    -- t1
    armbeaver='', armcv='', armfav='', armflash='', armjanus='', armmlv='', armpincer='', armsam='', armstump='', armart='',
    -- t2
    armacv='', armbull='', armcroc='', armjam='', armlatnk='', armmanni='', armmart='', armmerl='', armseer='', armst='', armyork='', armconsul='',
    -- t1
    corcv='', corfav='', corgarp='', corgator='', corlevlr='', cormist='', cormlv='', cormuskrat='', corraid='', corwolv='',
    -- t2
    coracv='', coreter='', corgol='', cormabm='', cormart='', corparrow='', correap='', corseal='', corsent='', corvrad='', corvroc='', corintr='', corban='', cortrem='',
  }

  Spring.AddUnitIcon("armcom.user", "LuaUI/Icons/armcom.png",2)
  Spring.AddUnitIcon("corcom.user", "LuaUI/Icons/corcom.png",2)
  --Spring.AddUnitIcon("cross.user", "LuaUI/Icons/cross1.png",0.95)
  --Spring.AddUnitIcon("cross_t2.user", "LuaUI/Icons/cross1.png", 1.3)
  Spring.AddUnitIcon("cross.user", "LuaUI/Icons/ba_sphere1.png",1)
  Spring.AddUnitIcon("cross_tiny.user", "LuaUI/Icons/ba_sphere1_cross.png",0.75)
  Spring.AddUnitIcon("cross_t2.user", "LuaUI/Icons/ba_sphere1.png", 1.33)
  Spring.AddUnitIcon("vehcross.user", "LuaUI/Icons/vehicle_cross.png",0.95)
  Spring.AddUnitIcon("vehcross_t2.user", "LuaUI/Icons/vehicle_cross.png", 1.3)
  Spring.AddUnitIcon("sub.user", "LuaUI/Icons/sub.png",1.2)
  Spring.AddUnitIcon("sub_t2.user", "LuaUI/Icons/sub.png",1.55)
  Spring.AddUnitIcon("sub_worker.user", "LuaUI/Icons/sub-worker.png",1.33)
  Spring.AddUnitIcon("sub_t2worker.user", "LuaUI/Icons/sub-worker.png",1.66)
  Spring.AddUnitIcon("e.user", "LuaUI/Icons/bolt.png",1.4)
  Spring.AddUnitIcon("e1.user", "LuaUI/Icons/bolt.png",1.85)
  Spring.AddUnitIcon("e2.user", "LuaUI/Icons/bolt.png",2.6)
  Spring.AddUnitIcon("e3.user", "LuaUI/Icons/bolt.png",3.1)
  Spring.AddUnitIcon("e4.user", "LuaUI/Icons/bolt.png",3.7)
  Spring.AddUnitIcon("hemi-down_flagship.user", "LuaUI/Icons/hemi-down1.png",3)
  Spring.AddUnitIcon("hemi-down_battleship.user", "LuaUI/Icons/hemi-down1.png",2.3)
  Spring.AddUnitIcon("hemi-down.user", "LuaUI/Icons/hemi-down1.png",1.3)
  Spring.AddUnitIcon("hemi-down_worker.user", "LuaUI/Icons/hemi-down_worker.png",1.3)
  Spring.AddUnitIcon("shield.user", "LuaUI/Icons/shield.png", 1.85)
  Spring.AddUnitIcon("hemi.user", "LuaUI/Icons/hemi1.png")
  Spring.AddUnitIcon("hourglass-side.user", "LuaUI/Icons/hourglass2-side.png", 0.9)
  Spring.AddUnitIcon("hourglass.user", "LuaUI/Icons/hourglass2.png", 0.9)
  Spring.AddUnitIcon("hourglasst2-side.user", "LuaUI/Icons/hourglass2-side.png", 1.2)
  Spring.AddUnitIcon("hourglasst2.user", "LuaUI/Icons/hourglass2.png", 1.2)
  Spring.AddUnitIcon("krogoth.user", "LuaUI/Icons/krogoth.png",3)
  Spring.AddUnitIcon("m-down.user", "LuaUI/Icons/m-down.png")
  Spring.AddUnitIcon("m-up.user", "LuaUI/Icons/m-up.png")
  Spring.AddUnitIcon("m.user", "LuaUI/Icons/m.png",0.85)
  Spring.AddUnitIcon("m_t2.user", "LuaUI/Icons/m.png",1.15)
  Spring.AddUnitIcon("mm.user", "LuaUI/Icons/m-down1.png",0.85)
  Spring.AddUnitIcon("mm_t2.user", "LuaUI/Icons/m-down1.png",1.15)
  Spring.AddUnitIcon("nuke.user", "LuaUI/Icons/nuke.png",1.3)
  Spring.AddUnitIcon("nuke_big.user", "LuaUI/Icons/nuke.png",1.9)
  Spring.AddUnitIcon("anti-nuke.user", "LuaUI/Icons/anti-nuke.png",1.15)
  Spring.AddUnitIcon("slash.user", "LuaUI/Icons/slash.png")
  Spring.AddUnitIcon("tiny-sphere_flea.user", "LuaUI/Icons/ba_sphere1.png",0.51)
  Spring.AddUnitIcon("tiny-sphere.user", "LuaUI/Icons/ba_sphere1.png",0.66)
  Spring.AddUnitIcon("sphere.user", "LuaUI/Icons/ba_sphere1.png",0.95)
  Spring.AddUnitIcon("sphere2.user", "LuaUI/Icons/ba_sphere1.png",1.28)
  Spring.AddUnitIcon("sphere3.user", "LuaUI/Icons/ba_sphere1.png",1.8)
  Spring.AddUnitIcon("tiny-vehicle_flea.user", "LuaUI/Icons/vehicle.png",0.55)
  Spring.AddUnitIcon("tiny-vehicle.user", "LuaUI/Icons/vehicle.png",0.7)
  Spring.AddUnitIcon("vehicle.user", "LuaUI/Icons/vehicle.png",1)
  Spring.AddUnitIcon("vehicle2.user", "LuaUI/Icons/vehicle.png",1.3)
  Spring.AddUnitIcon("vehicle3.user", "LuaUI/Icons/vehicle.png",1.85)
  Spring.AddUnitIcon("square.user", "LuaUI/Icons/square1.png")
  Spring.AddUnitIcon("square_+.user", "LuaUI/Icons/square_+.png")
  Spring.AddUnitIcon("square_x.user", "LuaUI/Icons/square_x1.png")
  Spring.AddUnitIcon("factory.user", "LuaUI/Icons/square_x1.png",1.45)
  Spring.AddUnitIcon("factoryt2.user", "LuaUI/Icons/square_x1.png",1.85)
  Spring.AddUnitIcon("factoryt3.user", "LuaUI/Icons/square_x1.png",2.4)
  Spring.AddUnitIcon("star-dark.user", "LuaUI/Icons/star-dark.png")
  Spring.AddUnitIcon("star.user", "LuaUI/Icons/star.png")
  Spring.AddUnitIcon("lrpc.user", "LuaUI/Icons/star.png", 2.3)
  Spring.AddUnitIcon("lrpc_lolcannon.user", "LuaUI/Icons/star.png", 3.3)
  Spring.AddUnitIcon("tiny-square.user", "LuaUI/Icons/square1.png",0.55)
  Spring.AddUnitIcon("tri-down.user", "LuaUI/Icons/tri-down1.png",1.3)
  Spring.AddUnitIcon("tri-t2down.user", "LuaUI/Icons/tri-down1.png",1.6)
  Spring.AddUnitIcon("tri-up.user", "LuaUI/Icons/tri-up1.png",1.3)
  Spring.AddUnitIcon("tri-up_bomber.user", "LuaUI/Icons/tri-bomber.png",1.35)
  Spring.AddUnitIcon("tri-up_t2bomber.user", "LuaUI/Icons/tri-bomber.png",1.66)
  Spring.AddUnitIcon("tri-up_liche.user", "LuaUI/Icons/tri-bomber.png",2)
  Spring.AddUnitIcon("tri-up_hover.user", "LuaUI/Icons/tri-up_hover.png",1.25)
  Spring.AddUnitIcon("tri-up_hover_huge.user", "LuaUI/Icons/tri-up_hover.png",2)
  Spring.AddUnitIcon("tri-up_hover_bladew.user", "LuaUI/Icons/tri-up_hover.png",0.75)
  Spring.AddUnitIcon("tri-up_t2hover.user", "LuaUI/Icons/tri-up_hover.png",1.55)
  Spring.AddUnitIcon("tri-up_worker.user", "LuaUI/Icons/tri-up_worker.png",1.2)
  Spring.AddUnitIcon("tri-up_t2worker.user", "LuaUI/Icons/tri-up_worker.png",1.6)
  Spring.AddUnitIcon("tri-up_fighter.user", "LuaUI/Icons/tri-up1.png",0.85)
  Spring.AddUnitIcon("tri-up_t2fighter.user", "LuaUI/Icons/tri-up1.png",1.05)
  Spring.AddUnitIcon("tri-up_scout.user", "LuaUI/Icons/tri.png",0.6)
  Spring.AddUnitIcon("tri-up_radar.user", "LuaUI/Icons/tri.png",1.33)
  Spring.AddUnitIcon("triangle-down.user", "LuaUI/Icons/triangle-down1.png")
  Spring.AddUnitIcon("triangle-up.user", "LuaUI/Icons/triangle-up1.png")
  Spring.AddUnitIcon("x.user", "LuaUI/Icons/warning.png")
  Spring.AddUnitIcon("x-t2.user", "LuaUI/Icons/warning.png")
  Spring.AddUnitIcon("blank.user", "LuaUI/Icons/blank.png")
   
  -- Setup the unitdef icons
  for udid,ud in pairs(UnitDefs) do
  
    if (ud ~= nil) then

      if (ud.name=="roost") or (ud.name=="meteor") then
          Spring.SetUnitDefIcon(udid, "star.user")
      elseif string.sub(ud.name, 0, 7) == "critter" then
        Spring.SetUnitDefIcon(udid, "blank.user")
      elseif (ud.name=="corfav" or ud.name=="armfav" or ud.name=="armflea") then
        if vehUnits[ud.name] ~= nil then
          Spring.SetUnitDefIcon(udid, "tiny-vehicle_flea.user")
        else
          Spring.SetUnitDefIcon(udid, "tiny-sphere_flea.user")
        end
      elseif (ud.name=="corak" or ud.name=="armpw" or ud.name=="armflash" or ud.name=="corgator") then
        if vehUnits[ud.name] ~= nil then
          Spring.SetUnitDefIcon(udid, "tiny-vehicle.user")
        else
          Spring.SetUnitDefIcon(udid, "tiny-sphere.user")
        end
      elseif (ud.name=="armpeep" or ud.name=="corfink") then
        Spring.SetUnitDefIcon(udid, "tri-up_scout.user")
      elseif (ud.name=="armawac" or ud.name=="corawac") then
        Spring.SetUnitDefIcon(udid, "tri-up_radar.user")
      elseif (ud.name=="armwin") or (ud.name=="corwin") then
        Spring.SetUnitDefIcon(udid, "e.user")
      elseif (ud.name=="armfig") or (ud.name=="corveng") or (ud.name=="armhawk") or (ud.name=="corvamp") then
        if (ud.name=="armhawk") or (ud.name=="corvamp") then
          Spring.SetUnitDefIcon(udid, "tri-up_t2fighter.user")
        else
          Spring.SetUnitDefIcon(udid, "tri-up_fighter.user")
        end
      elseif (ud.name=="corafus" or ud.name=="armafus") then
        Spring.SetUnitDefIcon(udid, "e4.user")
      elseif (ud.name=="armageo" or ud.name=="corageo") then
        Spring.SetUnitDefIcon(udid, "e3.user")
      elseif (ud.name=="armgmm") or  (ud.name=="armfus") or (ud.name=="corfus") or (ud.name=="armckfus") or (ud.name=="armdf") or (ud.name=="armuwfus") or (ud.name=="coruwfus") then
        Spring.SetUnitDefIcon(udid, "e2.user")
      elseif (ud.name=="armadvsol" or ud.name=="coradvsol" or ud.name=="armgeo" or ud.name=="corgeo" or ud.name=="corbhmth") then
        Spring.SetUnitDefIcon(udid, "e1.user")
      elseif (ud.name=="armvulc") or (ud.name=="corbuzz") then
        Spring.SetUnitDefIcon(udid, "lrpc_lolcannon.user")
      elseif (ud.name=="armbrtha") or (ud.name=="corint") then
        Spring.SetUnitDefIcon(udid, "lrpc.user")
      elseif (ud.name=="armcom") or (ud.name=="armdecom") then
        Spring.SetUnitDefIcon(udid, "armcom.user")
      elseif (ud.name=="corcom") or (ud.name=="cordecom") then
        Spring.SetUnitDefIcon(udid, "corcom.user")
      elseif (ud.name=="armclaw") or (ud.name=="cormaw") then
        Spring.SetUnitDefIcon(udid, "x.user")
      elseif (ud.name=="corkrog") then
        Spring.SetUnitDefIcon(udid, "krogoth.user")
      elseif (ud.name=="armbats" or ud.name=="corbats") then
        Spring.SetUnitDefIcon(udid, "hemi-down_battleship.user")
      elseif (ud.name=="armepoch" or ud.name=="corblackhy") then
        Spring.SetUnitDefIcon(udid, "hemi-down_flagship.user")
      elseif (ud.isFactory) then
        -- factories
        if (ud.name=="armshltx" or ud.name=="armshltxuw" or ud.name=="corgant" or ud.name=="corgantuw") then
          Spring.SetUnitDefIcon(udid, "factoryt3.user")
        elseif (ud.name=="armaap" or ud.name=="armavp" or ud.name=="armalab" or ud.name=="armasy" or ud.name=="coraap" or ud.name=="coravp" or ud.name=="coralab" or ud.name=="corasy") then
          Spring.SetUnitDefIcon(udid, "factoryt2.user")
        else
          Spring.SetUnitDefIcon(udid, "factory.user")
        end
      elseif (ud.name=="corfmd" or ud.name=="armamd" or ud.name=="cormabm" or ud.name=="armscab" or ud.name=="armcarry" or ud.name=="corcarry") then
        -- anti nukes
        Spring.SetUnitDefIcon(udid,"anti-nuke.user")
      elseif (ud.stockpileWeaponDef ~= nil) and not (ud.name=="armmercury" or ud.name=="corscreamer" or ud.name=="corfmd" or ud.name=="armamd" or ud.name=="cormabm" or ud.name=="armscab") then
      	-- nuke( stockpile weapon, but not mercury/screamer or anti nukes)
        if ud.name=="armsilo" or ud.name=="corsilo" then
          Spring.SetUnitDefIcon(udid, "nuke_big.user")
        else
          Spring.SetUnitDefIcon(udid, "nuke.user")
        end
      elseif ((ud.speed <= 0) and ud.shieldWeaponDef) then
        -- immobile shields
        Spring.SetUnitDefIcon(udid, "shield.user")
      elseif ((ud.extractsMetal > 0) or (ud.makesMetal > 0)) or
	(ud.name=="armmakr") or (ud.name=="armfmkr") or (ud.name=="armmmkr") or (ud.name=="armuwmmm") or
	(ud.name=="cormakr") or (ud.name=="corfmkr") or (ud.name=="cormmkr") or (ud.name=="coruwmmm") then
        -- metal extractors and makers
        if ud.extractsMetal > 0.001 then
          Spring.SetUnitDefIcon(udid, "m_t2.user")
        elseif ud.extractsMetal > 0 and ud.extractsMetal <= 0.001 then
          Spring.SetUnitDefIcon(udid, "m.user")
        elseif ud.name=="armmmkr" or ud.name=="cormmkr" then
          Spring.SetUnitDefIcon(udid, "mm_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "mm.user")
        end
      elseif ((ud.totalEnergyOut > 10) and (ud.speed <= 0)) then
        -- energy generators
        Spring.SetUnitDefIcon(udid, "e.user")
      elseif (ud.isTransport) then
        -- transports
        if (ud.name=="armdfly" or ud.name=="corseah") then
          Spring.SetUnitDefIcon(udid, "tri-t2down.user")
        else
          Spring.SetUnitDefIcon(udid, "tri-down.user")
        end
      -- submarines
      elseif (ud.name=="armserp" or ud.name=="armsubk" or ud.name=="corshark" or ud.name=="corssub") then
        Spring.SetUnitDefIcon(udid, "sub_t2.user")
      elseif (ud.name=="armacsub" or ud.name=="coracsub") then
        Spring.SetUnitDefIcon(udid, "sub_t2worker.user")
      elseif ((ud.minWaterDepth > 0) and (ud.speed > 0) and (ud.waterline > 12)) then
        Spring.SetUnitDefIcon(udid, "sub.user")
      elseif (ud.isBuilder) then
          -- builders
          if (ud.name=="armack" or ud.name=="corack" or ud.name=="corfast") then
            Spring.SetUnitDefIcon(udid, "cross_t2.user")
          elseif (ud.name=="armacv" or ud.name=="coracv" or ud.name=="armconsul") then
            Spring.SetUnitDefIcon(udid, "vehcross_t2.user")
          elseif (ud.name=="armcv" or ud.name=="armbeaver" or ud.name=="corcv" or ud.name=="cormuskrat") then
            Spring.SetUnitDefIcon(udid, "vehcross.user")
          elseif (ud.name=="cornecro" or ud.name=="armrectr") then
            Spring.SetUnitDefIcon(udid, "cross_tiny.user")
          elseif (ud.canFly) then
            if (ud.name=="armaca" or ud.name=="coraca") then
              Spring.SetUnitDefIcon(udid, "tri-up_t2worker.user")
            else
              Spring.SetUnitDefIcon(udid, "tri-up_worker.user")
            end
          elseif ((ud.minWaterDepth > 0) and (ud.speed > 0)) then -- ships
            Spring.SetUnitDefIcon(udid, "hemi-down_worker.user")
          elseif (ud.name=="armrecl" or ud.name=="correcl") then  -- subs
            Spring.SetUnitDefIcon(udid, "sub_worker.user")
          else
            if ((ud.speed > 0) and ud.canMove) then
              Spring.SetUnitDefIcon(udid, "cross.user")     -- mobile
            else
              Spring.SetUnitDefIcon(udid, "square_+.user")  -- immobile
            end
          end
      elseif (ud.canFly) then
        -- aircraft
        if (ud.hoverAttack) then
          if (ud.name=="corbw") then
            Spring.SetUnitDefIcon(udid, "tri-up_hover_bladew.user")
          elseif (ud.name=="armbrawl" or ud.name=="corblade") then
            Spring.SetUnitDefIcon(udid, "tri-up_t2hover.user")
          elseif (ud.name=="corcrw") then
            Spring.SetUnitDefIcon(udid, "tri-up_hover_huge.user")
          else
            Spring.SetUnitDefIcon(udid, "tri-up_hover.user")
          end
        else
          if (ud.name=="armliche") then
            Spring.SetUnitDefIcon(udid, "tri-up_liche.user")
          else
            if #ud.weapons > 0 and WeaponDefs[ud.weapons[1].weaponDef].type == "AircraftBomb" then
              if (ud.name=="armpnix" or ud.name=="corhurc") then
                Spring.SetUnitDefIcon(udid, "tri-up_t2bomber.user")
              else
                Spring.SetUnitDefIcon(udid, "tri-up_bomber.user")
              end
            else
              Spring.SetUnitDefIcon(udid, "tri-up.user")
            end
          end
        end
      elseif ((ud.minWaterDepth > 0) and (ud.speed > 0)) then
        -- ships
        Spring.SetUnitDefIcon(udid, "hemi-down.user")
      elseif (((ud.radarRadius > 1) or
               (ud.sonarRadius > 1) or
               (ud.seismicRadius > 1)) and (ud.speed <= 0) and (#ud.weapons <= 0)) then
        -- sensors
        if (ud.name=="corsd" or ud.name=="armarad" or ud.name=="armason" or ud.name=="corarad" or ud.name=="corason") then
          Spring.SetUnitDefIcon(udid, "hourglasst2-side.user")
        else
          Spring.SetUnitDefIcon(udid, "hourglass-side.user")
        end
      elseif (((ud.jammerRadius > 1) or
               (ud.sonarJamRadius > 1)) and (ud.speed <= 0)) then
        -- jammers
        if (ud.name=="corshroud" or ud.name=="armveil") then
          Spring.SetUnitDefIcon(udid, "hourglasst2.user")
        else
          Spring.SetUnitDefIcon(udid, "hourglass.user")
        end
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
          if vehUnits[ud.name] ~= nil then
            Spring.SetUnitDefIcon(udid, "vehicle2.user")
          else
            Spring.SetUnitDefIcon(udid, "sphere2.user")
          end
        elseif (ud.techLevel == 6) then
          if vehUnits[ud.name] ~= nil then
            Spring.SetUnitDefIcon(udid, "vehicle3.user")
          else
            Spring.SetUnitDefIcon(udid, "sphere3.user")
          end
        else
          if vehUnits[ud.name] ~= nil then
            Spring.SetUnitDefIcon(udid, "vehicle.user")
          else
            Spring.SetUnitDefIcon(udid, "sphere.user")
          end
        end
      end
    end
  end

  -- Walls
  Spring.SetUnitDefIcon(UnitDefNames["cordrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armdrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfort"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfort"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfdrag"].id, "tiny-square.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfdrag"].id, "tiny-square.user")

end

--------------------------------------------------------------------------------

