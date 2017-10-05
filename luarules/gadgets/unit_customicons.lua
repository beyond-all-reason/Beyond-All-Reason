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

  Spring.AddUnitIcon("armcom.user", "LuaUI/Icons/armcom.png",1.75)
  Spring.AddUnitIcon("corcom.user", "LuaUI/Icons/corcom.png",1.75)

  Spring.AddUnitIcon("mine1.user", "LuaUI/Icons/mine.png",0.4)
  Spring.AddUnitIcon("mine2.user", "LuaUI/Icons/mine.png",0.5)
  Spring.AddUnitIcon("mine3.user", "LuaUI/Icons/mine.png",0.62)

  Spring.AddUnitIcon("sub.user", "LuaUI/Icons/sub.png",1.33)
  Spring.AddUnitIcon("sub_t2.user", "LuaUI/Icons/sub.png",1.7)
  Spring.AddUnitIcon("sub_t1_worker.user", "LuaUI/Icons/sub_worker.png",1.33)
  Spring.AddUnitIcon("sub_t2_worker.user", "LuaUI/Icons/sub_worker.png",1.66)

  Spring.AddUnitIcon("energy1.user", "LuaUI/Icons/energy.png",1.4)
  Spring.AddUnitIcon("energy2.user", "LuaUI/Icons/energy.png",1.85)
  Spring.AddUnitIcon("energy3.user", "LuaUI/Icons/energy.png",2.6)
  Spring.AddUnitIcon("energy4.user", "LuaUI/Icons/energy.png",3.1)
  Spring.AddUnitIcon("energy5.user", "LuaUI/Icons/energy.png",3.7)

  Spring.AddUnitIcon("eyenergy1.user", "LuaUI/Icons/eye.png",0.85)
  Spring.AddUnitIcon("spy.user", "LuaUI/Icons/eye.png",1.25)

  Spring.AddUnitIcon("hover.user", "LuaUI/Icons/hover.png",1)
  Spring.AddUnitIcon("hover_t1_worker.user", "LuaUI/Icons/hover_worker.png",1)
  Spring.AddUnitIcon("hover_aa.user", "LuaUI/Icons/hover_aa.png",1)
  Spring.AddUnitIcon("hover2.user", "LuaUI/Icons/hover.png",1.35)

  Spring.AddUnitIcon("ship.user", "LuaUI/Icons/ship.png",1.2)
  Spring.AddUnitIcon("ship_t1_worker.user", "LuaUI/Icons/ship_worker.png",1.3)
  Spring.AddUnitIcon("ship_aa.user", "LuaUI/Icons/ship_aa.png",1.2)
  Spring.AddUnitIcon("ship_t2.user", "LuaUI/Icons/ship.png",1.6)
  Spring.AddUnitIcon("ship_t2_worker.user", "LuaUI/Icons/ship_worker.png",1.6)
  Spring.AddUnitIcon("ship_t2_aa.user", "LuaUI/Icons/ship_aa.png",1.6)
  Spring.AddUnitIcon("ship_t2_missileship.user", "LuaUI/Icons/ship.png",2)
  Spring.AddUnitIcon("ship_t2_battleship.user", "LuaUI/Icons/ship.png",2.5)
  Spring.AddUnitIcon("ship_t2_flagship.user", "LuaUI/Icons/ship.png",3.3)

  Spring.AddUnitIcon("amphib.user", "LuaUI/Icons/amphib.png",1.2)
  Spring.AddUnitIcon("amphib_aa.user", "LuaUI/Icons/amphib_aa.png",1.2)
  Spring.AddUnitIcon("amphib_t1_worker.user", "LuaUI/Icons/amphib_worker.png",1.3)
  Spring.AddUnitIcon("amphib_t2.user", "LuaUI/Icons/amphib.png",1.6)
  Spring.AddUnitIcon("amphib_t2_aa.user", "LuaUI/Icons/amphib_aa.png",1.6)
  Spring.AddUnitIcon("amphib_t3.user", "LuaUI/Icons/amphib.png",2.05)

  Spring.AddUnitIcon("shield.user", "LuaUI/Icons/shield.png", 2.05)

  Spring.AddUnitIcon("radar.user", "LuaUI/Icons/radar.png", 0.9)
  Spring.AddUnitIcon("jammer.user", "LuaUI/Icons/jammer.png", 0.9)
  Spring.AddUnitIcon("radar_t2.user", "LuaUI/Icons/radar.png", 1.2)
  Spring.AddUnitIcon("jammer_t2.user", "LuaUI/Icons/jammer.png", 1.2)

  Spring.AddUnitIcon("krogoth.user", "LuaUI/Icons/mech.png",3.2)
  Spring.AddUnitIcon("bantha.user", "LuaUI/Icons/mech.png",2.66)
  Spring.AddUnitIcon("juggernaut.user", "LuaUI/Icons/kbot.png",2.75)
  Spring.AddUnitIcon("commando.user", "LuaUI/Icons/mech.png",1.35)

  Spring.AddUnitIcon("mex.user", "LuaUI/Icons/mex.png",0.85)
  Spring.AddUnitIcon("mex_t2.user", "LuaUI/Icons/mex.png",1.15)

  Spring.AddUnitIcon("metalmaker.user", "LuaUI/Icons/metalmaker.png",0.85)
  Spring.AddUnitIcon("metalmaker_t2.user", "LuaUI/Icons/metalmaker.png",1.15)

  Spring.AddUnitIcon("nukenergy1.user", "LuaUI/Icons/nuke.png",1.35)
  Spring.AddUnitIcon("nuke_big.user", "LuaUI/Icons/nuke.png",2)
  Spring.AddUnitIcon("antinukenergy1.user", "LuaUI/Icons/antinuke.png",1.15)

  Spring.AddUnitIcon("aa.user", "LuaUI/Icons/aa.png", 0.85)
  Spring.AddUnitIcon("aa2.user", "LuaUI/Icons/aa.png", 1.1)
  Spring.AddUnitIcon("aa_flak.user", "LuaUI/Icons/aa.png", 1.4)
  Spring.AddUnitIcon("aa_longrangenergy1.user", "LuaUI/Icons/aa.png", 1.8)

  Spring.AddUnitIcon("worker.user", "LuaUI/Icons/worker.png",1) -- fallback unit icon

  Spring.AddUnitIcon("allterrain_t1.user", "LuaUI/Icons/allterrain.png",1)
  Spring.AddUnitIcon("allterrain_t2.user", "LuaUI/Icons/allterrain.png",1.33)
  Spring.AddUnitIcon("allterrain_t3.user", "LuaUI/Icons/allterrain.png",1.95)
  Spring.AddUnitIcon("allterrain_vanguard.user", "LuaUI/Icons/allterrain.png",2.25)

  Spring.AddUnitIcon("kbot_flea.user", "LuaUI/Icons/kbot.png",0.51)
  Spring.AddUnitIcon("kbot_tinyworker.user", "LuaUI/Icons/kbot_worker.png",0.75)
  Spring.AddUnitIcon("kbot_t1_raid.user", "LuaUI/Icons/kbot.png",0.7)
  Spring.AddUnitIcon("kbot_t1.user", "LuaUI/Icons/kbot.png",0.95)
  Spring.AddUnitIcon("kbot_t1_aa.user", "LuaUI/Icons/kbot_aa.png",0.95)
  Spring.AddUnitIcon("kbot_t2.user", "LuaUI/Icons/kbot.png",1.28)
  Spring.AddUnitIcon("kbot_t2_aa.user", "LuaUI/Icons/kbot_aa.png",1.28)
  Spring.AddUnitIcon("kbot_t2_big.user", "LuaUI/Icons/kbot.png",1.47)
  Spring.AddUnitIcon("kbot_t1_worker.user", "LuaUI/Icons/kbot.png",0.95)
  Spring.AddUnitIcon("kbot_t2_worker.user", "LuaUI/Icons/kbot.png", 1.33)
  Spring.AddUnitIcon("kbot_t3.user", "LuaUI/Icons/kbot.png",1.9)

  Spring.AddUnitIcon("tank_flea.user", "LuaUI/Icons/vehicle.png",0.55)
  Spring.AddUnitIcon("tank_t1_raid.user", "LuaUI/Icons/vehicle.png",0.75)
  Spring.AddUnitIcon("tank_t1.user", "LuaUI/Icons/vehicle.png",1)
  Spring.AddUnitIcon("tank_t1_aa.user", "LuaUI/Icons/vehicle_aa.png",1)
  Spring.AddUnitIcon("tank_t2.user", "LuaUI/Icons/vehicle.png",1.3)
  Spring.AddUnitIcon("tank_t2_aa.user", "LuaUI/Icons/vehicle_aa.png",1.3)
  Spring.AddUnitIcon("tank_t2_big.user", "LuaUI/Icons/vehicle.png",1.5)
  Spring.AddUnitIcon("tank_t1_worker.user", "LuaUI/Icons/vehicle_worker.png",0.95)
  Spring.AddUnitIcon("tank_t2_worker.user", "LuaUI/Icons/vehicle_worker.png", 1.3)

  Spring.AddUnitIcon("building_t1.user", "LuaUI/Icons/building.png", 1)
  Spring.AddUnitIcon("building_t2.user", "LuaUI/Icons/building.png", 1.3)

  Spring.AddUnitIcon("nano.user", "LuaUI/Icons/worker.png", 0.9)

  Spring.AddUnitIcon("factory_t1", "LuaUI/Icons/factory.png",1.45)
  Spring.AddUnitIcon("factory_t2", "LuaUI/Icons/factory.png",1.85)
  Spring.AddUnitIcon("factory_t3", "LuaUI/Icons/factory.png",2.4)

  Spring.AddUnitIcon("lrpc.user", "LuaUI/Icons/lrpc.png", 2.35)
  Spring.AddUnitIcon("lrpc_lolcannon.user", "LuaUI/Icons/lrpc.png", 3.5)

  Spring.AddUnitIcon("meteor.user", "LuaUI/Icons/meteor.png")

  Spring.AddUnitIcon("wall.user", "LuaUI/Icons/building.png",0.55)

  Spring.AddUnitIcon("air_transport.user", "LuaUI/Icons/transport.png",1.3)
  Spring.AddUnitIcon("air_transport_t2.user", "LuaUI/Icons/transport.png",1.6)
  Spring.AddUnitIcon("air_bomber.user", "LuaUI/Icons/air_bomber.png",1.35)
  Spring.AddUnitIcon("air_bomber_t2.user", "LuaUI/Icons/air_bomber.png",1.66)
  Spring.AddUnitIcon("air_bladew.user", "LuaUI/Icons/air_hover.png",0.75)
  Spring.AddUnitIcon("air_hover.user", "LuaUI/Icons/air_hover.png",1.25)
  Spring.AddUnitIcon("air_hover_t2.user", "LuaUI/Icons/air_hover.png",1.55)
  Spring.AddUnitIcon("air_t1_worker.user", "LuaUI/Icons/air_worker.png",1.2)
  Spring.AddUnitIcon("air_t2_worker.user", "LuaUI/Icons/air_worker.png",1.6)
  Spring.AddUnitIcon("air.user", "LuaUI/Icons/air.png",0.85)
  Spring.AddUnitIcon("air_t2.user", "LuaUI/Icons/air.png",1.05)
  Spring.AddUnitIcon("air_scout.user", "LuaUI/Icons/air_los.png",0.6)
  Spring.AddUnitIcon("air_radar.user", "LuaUI/Icons/air_los.png",1.33)
  Spring.AddUnitIcon("air_krow.user", "LuaUI/Icons/air_hover.png",2)
  Spring.AddUnitIcon("air_liche.user", "LuaUI/Icons/air_bomber.png",2)

  Spring.AddUnitIcon("defence_0", "LuaUI/Icons/defence.png", 0.8)
  Spring.AddUnitIcon("defence_1", "LuaUI/Icons/defence.png", 1.05)
  Spring.AddUnitIcon("defence_2", "LuaUI/Icons/defence.png", 1.4)
  Spring.AddUnitIcon("defence_3", "LuaUI/Icons/defence.png", 1.95)

  Spring.AddUnitIcon("blank.user", "LuaUI/Icons/blank.png")
  Spring.AddUnitIcon("unknown.user", "LuaUI/Icons/unknown.png", 2)

  -- Setup the unitdef icons
  for udid,ud in pairs(UnitDefs) do

    if (ud == nil) then break end

    if (ud.name=="roost") or (ud.name=="meteor") then
      Spring.SetUnitDefIcon(udid, "meteor.user")
    elseif string.sub(ud.name, 0, 7) == "critter" then
      Spring.SetUnitDefIcon(udid, "blank.user")

    -- mine
    elseif ud.modCategories["mine"] ~= nil then
      if (ud.name=="cormine3" or ud.name=="armmine3" or ud.name=="corfmine3" or ud.name=="armfmine3" or ud.name=="corsktl") then
        Spring.SetUnitDefIcon(udid, "mine3.user")
      elseif (ud.name=="cormine2" or ud.name=="armmine2" or ud.name=="cormine4" or ud.name=="armmine4" or ud.name=="corroach" or ud.name=="armvader") then
        Spring.SetUnitDefIcon(udid, "mine2.user")
      else
        Spring.SetUnitDefIcon(udid, "mine1.user")
      end

    -- cloak
    elseif (ud.name=="armeyes" or ud.name=="coreyes") then
      Spring.SetUnitDefIcon(udid, "eyenergy1.user")
    elseif (ud.name=="armspy" or ud.name=="corspy" or ud.name=="armst") then
      Spring.SetUnitDefIcon(udid, "spy.user")
    elseif (ud.name=="armpeep" or ud.name=="corfink") then
      Spring.SetUnitDefIcon(udid, "air_scout.user")

    -- energy
    elseif (ud.name=="armwin") or (ud.name=="corwin") then
      Spring.SetUnitDefIcon(udid, "energy1.user")
    elseif (ud.name=="corafus" or ud.name=="armafus") then
      Spring.SetUnitDefIcon(udid, "energy5.user")
    elseif (ud.name=="armageo" or ud.name=="corageo") then
      Spring.SetUnitDefIcon(udid, "energy4.user")
    elseif (ud.name=="armgmm") or  (ud.name=="armfus") or (ud.name=="corfus") or (ud.name=="armckfus") or (ud.name=="armdf") or (ud.name=="armuwfus") or (ud.name=="coruwfus") then
      Spring.SetUnitDefIcon(udid, "energy3.user")
    elseif (ud.name=="armadvsol" or ud.name=="coradvsol" or ud.name=="armgeo" or ud.name=="corgeo" or ud.name=="corbhmth") then
      Spring.SetUnitDefIcon(udid, "energy2.user")

    -- lrpc
    elseif (ud.name=="armvulc") or (ud.name=="corbuzz") then
      Spring.SetUnitDefIcon(udid, "lrpc_lolcannon.user")
    elseif (ud.name=="armbrtha") or (ud.name=="corint") then
      Spring.SetUnitDefIcon(udid, "lrpc.user")

    -- commander
    elseif (ud.name=="armcom") or (ud.name=="armdecom") then
      Spring.SetUnitDefIcon(udid, "armcom.user")
    elseif (ud.name=="corcom") or (ud.name=="cordecom") then
      Spring.SetUnitDefIcon(udid, "corcom.user")

    elseif (ud.name=="armclaw") or (ud.name=="cormaw") then
      Spring.SetUnitDefIcon(udid, "defence_0")

    -- factories
    elseif (ud.isFactory) then
      if (ud.name=="armshltx" or ud.name=="armshltxuw" or ud.name=="corgant" or ud.name=="corgantuw") then
        Spring.SetUnitDefIcon(udid, "factory_t3")
      elseif (ud.name=="armaap" or ud.name=="armavp" or ud.name=="armalab" or ud.name=="armasy" or ud.name=="coraap" or ud.name=="coravp" or ud.name=="coralab" or ud.name=="corasy") then
        Spring.SetUnitDefIcon(udid, "factory_t2")
      else
        Spring.SetUnitDefIcon(udid, "factory_t1")
      end

    -- anti nuke
    elseif (ud.name=="corfmd" or ud.name=="armamd" or ud.name=="cormabm" or ud.name=="armscab" or ud.name=="armcarry" or ud.name=="corcarry") then
      Spring.SetUnitDefIcon(udid,"antinukenergy1.user")
    elseif (ud.stockpileWeaponDef ~= nil) and not (ud.name=="armmercury" or ud.name=="corscreamer" or ud.name=="corfmd" or ud.name=="armamd" or ud.name=="cormabm" or ud.name=="armscab") then
      -- nuke( stockpile weapon, but not mercury/screamer or anti nukes)
      if ud.name=="armsilo" or ud.name=="corsilo" then
        Spring.SetUnitDefIcon(udid, "nuke_big.user")
      else
        Spring.SetUnitDefIcon(udid, "nukenergy1.user")
      end

    -- shield
    elseif (ud.shieldWeaponDef) then
      Spring.SetUnitDefIcon(udid, "shield.user")

    -- metal
    elseif ((ud.extractsMetal > 0) or (ud.makesMetal > 0)) or
      (ud.name=="armmakr") or (ud.name=="armfmkr") or (ud.name=="armmmkr") or (ud.name=="armuwmmm") or
      (ud.name=="cormakr") or (ud.name=="corfmkr") or (ud.name=="cormmkr") or (ud.name=="coruwmmm") then
      -- metal extractors and makers
      if ud.extractsMetal > 0.001 then
        Spring.SetUnitDefIcon(udid, "mex_t2.user")
      elseif ud.extractsMetal > 0 and ud.extractsMetal <= 0.001 then
        Spring.SetUnitDefIcon(udid, "mex.user")
      elseif ud.name=="armmmkr" or ud.name=="cormmkr" then
        Spring.SetUnitDefIcon(udid, "metalmaker_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "metalmaker.user")
      end

    -- energy generators
    elseif ((ud.totalEnergyOut > 10) and (ud.speed <= 0)) then
      Spring.SetUnitDefIcon(udid, "energy1.user")
    elseif (ud.isTransport) then
      -- transports
      if (ud.name=="armdfly" or ud.name=="corseah") then
        Spring.SetUnitDefIcon(udid, "air_transport_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "air_transport.user")
      end

    -- amphib
    elseif ud.modCategories["phib"] ~= nil or (ud.modCategories["canbeuw"] ~= nil and ud.modCategories["underwater"] == nil) then
      if (ud.techLevel >= 6) then
        Spring.SetUnitDefIcon(udid, "amphib_t3.user")
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if (ud.techLevel >= 4) then
          Spring.SetUnitDefIcon(udid, "amphib_t2_aa.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib_aa.user")
        end
      elseif (ud.techLevel >= 4) then
        if (ud.isBuilder) then
          Spring.SetUnitDefIcon(udid, "amphib_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib_t2.user")
        end
      else
        if (ud.isBuilder) then
          Spring.SetUnitDefIcon(udid, "amphib_t1_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib.user")
        end
      end

    -- submarines
    elseif ((ud.modCategories["underwater"] ~= nil or ud.name=="armsubsurface") and ud.speed > 0) then
      if (ud.name=="armserp" or ud.name=="armsubk" or ud.name=="corshark" or ud.name=="corssub") then
        Spring.SetUnitDefIcon(udid, "sub_t2.user")
      elseif (ud.name=="armacsub" or ud.name=="coracsub") then
        Spring.SetUnitDefIcon(udid, "sub_t2_worker.user")
      else
        Spring.SetUnitDefIcon(udid, "sub.user")
      end

    -- hovers
    elseif ud.modCategories["hover"] ~= nil then
      if ud.isBuilder then
        Spring.SetUnitDefIcon(udid, "hover_t1_worker.user")
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        Spring.SetUnitDefIcon(udid, "hover_aa.user")
      elseif ud.name=="corhal" or ud.name=="corsok" then
        Spring.SetUnitDefIcon(udid, "hover2.user")
      else
        Spring.SetUnitDefIcon(udid, "hover.user")
      end

    -- aircraft
    elseif (ud.canFly) then

      if (ud.name=="armliche") then
        Spring.SetUnitDefIcon(udid, "air_liche.user")
      elseif (ud.name=="corcrw") then
        Spring.SetUnitDefIcon(udid, "air_krow.user")
      elseif (ud.name=="armawac" or ud.name=="corawac" or ud.name=="armsehak" or ud.name=="corhunt") then
        Spring.SetUnitDefIcon(udid, "air_radar.user")
      elseif ud.isBuilder then
        if (ud.techLevel == 4) then
          Spring.SetUnitDefIcon(udid, "air_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_worker.user")
        end
      elseif (ud.hoverAttack) then
        if (ud.name=="corbw") then
          Spring.SetUnitDefIcon(udid, "air_bladew.user")
        elseif (ud.techLevel >= 4) then
          Spring.SetUnitDefIcon(udid, "air_hover_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "air_hover.user")
        end
      elseif #ud.weapons > 0 and WeaponDefs[ud.weapons[1].weaponDef].type == "AircraftBomb" then
        if (ud.name=="armpnix" or ud.name=="corhurc") then
          Spring.SetUnitDefIcon(udid, "air_bomber_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "air_bomber.user")
        end
      else
        if (ud.techLevel >= 4) then
          Spring.SetUnitDefIcon(udid, "air_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "air.user")
        end
      end

    -- ships
    elseif ud.modCategories["ship"] ~= nil then
      if (ud.name=="armmship" or ud.name=="cormship") then
        Spring.SetUnitDefIcon(udid, "ship_t2_missileship.user")
      elseif (ud.name=="armbats" or ud.name=="corbats") then
        Spring.SetUnitDefIcon(udid, "ship_t2_battleship.user")
      elseif (ud.name=="armepoch" or ud.name=="corblackhy") then
        Spring.SetUnitDefIcon(udid, "ship_t2_flagship.user")
      elseif ud.isBuilder then
        if ud.techLevel == 4 then
          Spring.SetUnitDefIcon(udid, "ship_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "ship_t1_worker.user")
        end
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if ud.techLevel == 4 then
          Spring.SetUnitDefIcon(udid, "ship_t2_aa.user")
        else
          Spring.SetUnitDefIcon(udid, "ship_aa.user")
        end
      else
        if (ud.techLevel == 4) then
          Spring.SetUnitDefIcon(udid, "ship_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "ship.user")
        end
      end

    -- sensors
    elseif (((ud.radarRadius > 1) or (ud.sonarRadius > 1) or (ud.seismicRadius > 1)) and (ud.speed <= 0) and (#ud.weapons <= 0)) then
      if (ud.name=="corsd" or ud.name=="armarad" or ud.name=="armason" or ud.name=="corarad" or ud.name=="corason") then
        Spring.SetUnitDefIcon(udid, "radar_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "radar.user")
      end

    -- jammers
    elseif (((ud.jammerRadius > 1) or (ud.sonarJamRadius > 1)) and (ud.speed <= 0)) then
      if (ud.name=="corshroud" or ud.name=="armveil") then
        Spring.SetUnitDefIcon(udid, "jammer_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "jammer.user")
      end

    -- defenders and other buildings
    elseif (ud.isBuilding or (ud.speed <= 0)) then
      if (#ud.weapons <= 0) then
        if (ud.techLevel >= 4) then
          Spring.SetUnitDefIcon(udid, "building_t2.user")
      else
          Spring.SetUnitDefIcon(udid, "building_t1.user")
      end
      else
        if ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
          if (ud.name=="armmercury" or ud.name=="corscreamer") then
            Spring.SetUnitDefIcon(udid, "aa_longrangenergy1.user")
          elseif WeaponDefs[ud.weapons[1].weaponDef].cegTag == '' then
            Spring.SetUnitDefIcon(udid, "aa_flak.user")
          elseif ud.name=="corerad" or ud.name=="armcir" or ud.name=="armpacko" or ud.name=="cormadsam" then
            Spring.SetUnitDefIcon(udid, "aa2.user")
          else
            Spring.SetUnitDefIcon(udid, "aa.user")
          end
        else
          if (ud.name=="armanni" or ud.name=="cordoom") then
            Spring.SetUnitDefIcon(udid, "defence_3")
          elseif (ud.techLevel >= 4 or ud.name=="armguard" or ud.name=="corpun") then
            Spring.SetUnitDefIcon(udid, "defence_2")
          elseif (ud.name=="armhlt" or ud.name=="corhlt" or ud.name=="armfhlt" or ud.name=="corfhlt") then
            Spring.SetUnitDefIcon(udid, "defence_1")
          else
            Spring.SetUnitDefIcon(udid, "defence_0")
          end
        end
      end

    -- vehicles
    elseif ud.modCategories["tank"] ~= nil then

        if (ud.name=="armmanni" or ud.name=="corgol") then
          Spring.SetUnitDefIcon(udid, "tank_t2_big.user")
        elseif ud.name=="corfav" or ud.name=="armfav" then
          Spring.SetUnitDefIcon(udid, "tank_flea.user")
        elseif ud.name=="armflash" or ud.name=="corgator" then
          Spring.SetUnitDefIcon(udid, "tank_t1_raid.user")
        elseif ud.isBuilder then
          if ud.techLevel == 4 then
            Spring.SetUnitDefIcon(udid, "tank_t2_worker.user")
          else
            Spring.SetUnitDefIcon(udid, "tank_t1_worker.user")
          end
        elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
          if ud.techLevel == 4 then
            Spring.SetUnitDefIcon(udid, "tank_t2_aa.user")
          else
            Spring.SetUnitDefIcon(udid, "tank_aa.user")
          end
        else
          if (ud.techLevel == 4) then
            Spring.SetUnitDefIcon(udid, "tank_t2.user")
          else
            Spring.SetUnitDefIcon(udid, "tank_t1.user")
          end
        end

    -- all terrain
    elseif ud.moveDef.name == "tkbot2" or ud.moveDef.name == "tkbot3" or ud.moveDef.name == "htkbot4" then

      if ud.name=="armvang" then
        Spring.SetUnitDefIcon(udid, "allterrain_vanguard.user")
      elseif ud.name=="armspid" then
        Spring.SetUnitDefIcon(udid, "allterrain_t1.user")
      elseif (ud.techLevel == 6) then
          Spring.SetUnitDefIcon(udid, "allterrain_t3.user")
      elseif (ud.techLevel == 4) then
        Spring.SetUnitDefIcon(udid, "allterrain_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "allterrain_t1.user")
      end

      -- kbots
    elseif ud.modCategories["kbot"] ~= nil then

      if (ud.name=="corkrog") then
        Spring.SetUnitDefIcon(udid, "krogoth.user")
      elseif (ud.name=="armbanth") then
        Spring.SetUnitDefIcon(udid, "bantha.user")
      elseif (ud.name=="corjugg") then
        Spring.SetUnitDefIcon(udid, "juggernaut.user")
      elseif (ud.name=="cormando") then
        Spring.SetUnitDefIcon(udid, "commando.user")
      elseif (ud.name=="corsumo" or ud.name=="corgol") then
        Spring.SetUnitDefIcon(udid, "kbot_t2_big.user")
      elseif ud.name=="armflea" then
        Spring.SetUnitDefIcon(udid, "kbot_flea.user")
      elseif ud.name=="corak" or ud.name=="armpw" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_raid.user")
      elseif ud.isBuilder then
        if (ud.name=="cornecro" or ud.name=="armrectr") then
          Spring.SetUnitDefIcon(udid, "kbot_tinyworker.user")
        elseif ud.techLevel == 4 then
          Spring.SetUnitDefIcon(udid, "kbot_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "kbot_t1_worker.user")
        end
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if ud.techLevel == 4 then
          Spring.SetUnitDefIcon(udid, "kbot_t2_aa.user")
        else
          Spring.SetUnitDefIcon(udid, "kbot_aa.user")
        end
      else
        if (ud.techLevel == 6 or ud.name=="orcone" or ud.name=="krogtaar") then
          Spring.SetUnitDefIcon(udid, "kbot_t3.user")
        elseif (ud.techLevel == 4) then
          Spring.SetUnitDefIcon(udid, "kbot_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "ship.user")
        end
      end

    -- unknown
    else
      Spring.SetUnitDefIcon(udid, "unknown.user")

    end

  end

  -- Walls
  Spring.SetUnitDefIcon(UnitDefNames["cordrag"].id, "wall.user")
  Spring.SetUnitDefIcon(UnitDefNames["armdrag"].id, "wall.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfort"].id, "wall.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfort"].id, "wall.user")
  Spring.SetUnitDefIcon(UnitDefNames["corfdrag"].id, "wall.user")
  Spring.SetUnitDefIcon(UnitDefNames["armfdrag"].id, "wall.user")

end

--------------------------------------------------------------------------------

