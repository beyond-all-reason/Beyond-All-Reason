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
    author    = "trepan,BD,TheFatController,Floris",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -100,
    enabled   = true  --  loaded by default?
  }
end


-- do note BA now includes a widget "Icon adjuster" that does this aswell (can change icon size)
-- so any changes made here will/could be be overwritten by the widget


--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then
  return false
end

--------------------------------------------------------------------------------

local iconScale = 1
local icons = {
  {"armcom.user", "icons/armcom.png",1.75*iconScale},
  {"corcom.user", "icons/corcom.png",1.75*iconScale},

  {"mine1.user", "icons/mine.png",0.36*iconScale},
  {"mine2.user", "icons/mine.png",0.44*iconScale},
  {"mine3.user", "icons/mine.png",0.53*iconScale},

  {"sub_t1.user", "icons/sub.png",1.33*iconScale},
  {"sub_t2.user", "icons/sub.png",1.7*iconScale},
  {"sub_t1_worker.user", "icons/sub_worker.png",1.33*iconScale},
  {"sub_t2_worker.user", "icons/sub_worker.png",1.66*iconScale},


  {"wind.user", "icons/wind.png",1.1*iconScale},
  {"energy1.user", "icons/solar.png",1.75*iconScale},   
  {"energy2.user", "icons/energy.png",1.75*iconScale},
  {"energy3.user", "icons/fusion.png",1.4*iconScale},
  {"energy4.user", "icons/hazardous.png",2.5*iconScale},
  {"energy5.user", "icons/fusion.png",1.8*iconScale},
  {"energy6.user", "icons/energy.png",2.2*iconScale},

  {"eye.user", "icons/eye.png",0.85*iconScale},
  {"spy.user", "icons/eye.png",1.25*iconScale},

  {"hover_t1.user", "icons/hover.png",0.9*iconScale},
  {"hover_t1_worker.user", "icons/hover_worker.png",0.9*iconScale},
  {"hover_t1_aa.user", "icons/hover_aa.png",0.9*iconScale},
  {"hover_t2.user", "icons/hover.png",1.3*iconScale},
  {"hover_t3.user", "icons/hover.png",1.6*iconScale},

  {"ship_tiny.user", "icons/ship.png",0.8*iconScale},
  {"ship.user", "icons/ship.png",1.2*iconScale},
  {"ship_destroyer.user", "icons/ship.png",1.44*iconScale},
  {"ship_t1_worker.user", "icons/ship_worker.png",1.33*iconScale},
  {"ship_aa1.user", "icons/ship_aa.png",1.2*iconScale},
  {"ship_t2.user", "icons/ship.png",1.65*iconScale},
  {"ship_t2_worker.user", "icons/ship_worker.png",1.65*iconScale},
  {"ship_t2_aa1.user", "icons/ship_aa.png",1.65*iconScale},
  {"ship_t2_big.user", "icons/ship.png",2*iconScale},
  {"ship_t2_battleship.user", "icons/ship.png",2.5*iconScale},
  {"ship_t2_battleship.user", "icons/ship.png",2.5*iconScale},
  {"ship_t2_flagship.user", "icons/ship.png",3.3*iconScale},

  {"amphib_t1.user", "icons/amphib.png",1.2*iconScale},
  {"amphib_t1_aa.user", "icons/amphib_aa.png",1.2*iconScale},
  {"amphib_t1_worker.user", "icons/amphib_worker.png",1.3*iconScale},
  {"amphib_t2.user", "icons/amphib.png",1.6*iconScale},
  {"amphib_t2_aa.user", "icons/amphib_aa.png",1.6*iconScale},
  {"amphib_t3.user", "icons/amphib.png",2.05*iconScale},

  {"shield.user", "icons/shield.png", 2.05*iconScale},

  {"radar_t1.user", "icons/radar.png", 0.9*iconScale},
  {"jammer_t1.user", "icons/jammer.png", 0.9*iconScale},
  {"radar_t2.user", "icons/radar.png", 1.2*iconScale},
  {"jammer_t2.user", "icons/jammer.png", 1.2*iconScale},

  {"krogoth.user", "icons/mech.png",3.2*iconScale},
  {"bantha.user", "icons/bantha.png",2.6*iconScale},
  {"juggernaut.user", "icons/kbot.png",2.75*iconScale},
  {"commando.user", "icons/mech.png",1.3*iconScale},

  {"mex_t1.user", "icons/mex.png",0.85*iconScale},
  {"mex_t2.user", "icons/mex.png",1.15*iconScale},

  {"metalmaker_t1.user", "icons/metalmaker.png",0.75*iconScale},
  {"metalmaker_t2.user", "icons/metalmaker.png",1.15*iconScale},

  {"nuke.user", "icons/nuke.png",1.8*iconScale},
        {"nuke_big.user", "icons/nuke.png",2.5*iconScale},
        {"antinuke.user", "icons/antinuke.png",1.6*iconScale},
        {"antinuke_mobile.user", "icons/antinuke.png",1.3*iconScale},

  {"aa1.user", "icons/aa.png", 0.85*iconScale},
  {"aa2.user", "icons/aa.png", 1.1*iconScale},
  {"aa_flak.user", "icons/aa.png", 1.4*iconScale},
  {"aa_longrangenergy1.user", "icons/aa.png", 1.8*iconScale},

  {"worker.user", "icons/worker.png", 0.85*iconScale},

  {"allterrain_t1.user", "icons/allterrain.png",1*iconScale},
  {"allterrain_t2.user", "icons/allterrain.png",1.33*iconScale},
  {"allterrain_t3.user", "icons/allterrain.png",1.95*iconScale},
  {"allterrain_vanguard.user", "icons/allterrain.png",2.3*iconScale},

  {"kbot_t1_flea.user", "icons/kbot.png",0.51*iconScale},
  {"kbot_t1_tinyworker.user", "icons/worker.png",0.8*iconScale},
  {"engineer.user", "icons/wrench.png",1.4*iconScale},
  {"ship_engineer.user", "icons/shipengineer.png",1.5*iconScale},
  {"kbot_t1_raid.user", "icons/kbot.png",0.7*iconScale},
  {"kbot_t1.user", "icons/kbot.png",0.95*iconScale},
  {"kbot_t1_big.user", "icons/kbot.png",1.1*iconScale},
  {"kbot_t1_worker.user", "icons/kbot_worker.png",0.95*iconScale},
  {"kbot_t1_aa1.user", "icons/kbot_aa.png",0.95*iconScale},
  {"kbot_t2.user", "icons/kbot.png",1.28*iconScale},
  {"kbot_t2_big.user", "icons/kbot.png",1.47*iconScale},
  {"kbot_t2_worker.user", "icons/kbot_worker.png", 1.33*iconScale},
  {"kbot_t2_aa1.user", "icons/kbot_aa.png",1.28*iconScale},
  {"kbot_t3.user", "icons/kbot.png",1.9*iconScale},

  {"tank_t1_flea.user", "icons/vehicle.png",0.55*iconScale},
  {"tank_t1_raid.user", "icons/vehicle.png",0.75*iconScale},
  {"tank_t1.user", "icons/vehicle.png",1*iconScale},
  {"tank_t1_big.user", "icons/vehicle.png",1.15*iconScale},
  {"tank_t1_aa1.user", "icons/vehicle_aa.png",1*iconScale},
  {"tank_t2.user", "icons/vehicle.png",1.3*iconScale},
  {"tank_t2_aa1.user", "icons/vehicle_aa.png",1.3*iconScale},
  {"tank_t2_big.user", "icons/vehicle.png",1.5*iconScale},
  {"tank_t1_worker.user", "icons/vehicle_worker.png",0.95*iconScale},
  {"tank_t2_worker.user", "icons/vehicle_worker.png", 1.3*iconScale},

  {"building_t1.user", "icons/building.png", 1*iconScale},
  {"building_t2.user", "icons/building.png", 1.3*iconScale},

  {"factory_t1", "icons/factory.png",1.45*iconScale},
  {"factory_t2", "icons/factory.png",1.85*iconScale},
  {"factory_t3", "icons/factory.png",2.4*iconScale},

  {"lrpc.user", "icons/lrpc.png", 2.35*iconScale},
  {"lrpc_lolcannon.user", "icons/lrpc.png", 3.5*iconScale},

  {"chicken_queen.user", "icons/queen.png", 4*iconScale},

  {"meteor.user", "icons/meteor.png", 1*iconScale},

  {"wall.user", "icons/building.png",0.55*iconScale},

  {"air_t1.user", "icons/air.png",0.85*iconScale},
  {"air_t1_worker.user", "icons/air_worker.png",1.2*iconScale},
  {"air_t1_hover_t1.user", "icons/air_hover.png",1.25*iconScale},
  {"air_t1_bomber.user", "icons/air_bomber.png",1.35*iconScale},
  {"air_t1_transport.user", "icons/transport.png",1.3*iconScale},
  {"air_t1_scout.user", "icons/air_los.png",0.6*iconScale},
  {"air_t2.user", "icons/air.png",1.05*iconScale},
  {"air_t2_worker.user", "icons/air_worker.png",1.6*iconScale},
  {"air_t2_hover_t1.user", "icons/air_hover.png",1.55*iconScale},
  {"air_t2_bomber.user", "icons/air_bomber.png",1.66*iconScale},
  {"air_t2_transport.user", "icons/transport.png",1.6*iconScale},
  {"veh_transport.user", "icons/vehtrans.png",1.7*iconScale},
  {"hover_transport.user", "icons/hovertrans.png",1.5*iconScale},
  {"ship_transport.user", "icons/shiptrans.png",2*iconScale},
  {"air_t2_radar_t1.user", "icons/air_los.png",1.33*iconScale},
  {"air_bladew.user", "icons/air_hover_bw.png",0.75*iconScale},
  {"air_krow.user", "icons/air_hover.png",2*iconScale},
  {"air_liche.user", "icons/air_bomber.png",2*iconScale},

  {"defence_0", "icons/defence.png", 0.8*iconScale},
  {"defence_1", "icons/defence.png", 1.05*iconScale},
  {"defence_2", "icons/defence.png", 1.4*iconScale},
  {"defence_3", "icons/defence.png", 1.95*iconScale},

  {"blank.user", "icons/blank.png", 1*iconScale},
  {"unknown.user", "icons/unknown.png", 2*iconScale},
}

function changeUnitIcons()
  for i, icon in ipairs(icons) do
    Spring.FreeUnitIcon(icon[1])
    Spring.AddUnitIcon(icon[1], icon[2], icon[3])
  end

  -- Setup the unitdef icons
  for udid,ud in pairs(UnitDefs) do

    if (ud == nil) then break end

    if (ud.name=="roost") or (ud.name=="meteor") then
      Spring.SetUnitDefIcon(udid, "meteor.user")
    elseif string.sub(ud.name, 0, 7) == "critter" then
      Spring.SetUnitDefIcon(udid, "blank.user")
    elseif ud.name=="chip" or ud.name=="dice" or ud.name=="xmasball" or ud.name=="corstone" or ud.name=="armstone" then
      Spring.SetUnitDefIcon(udid, "blank.user")
    elseif (ud.moveDef ~= nil and ud.moveDef.name=="chickqueen") then
      Spring.SetUnitDefIcon(udid, "chicken_queen.user")
    elseif (ud.name=="corkrog") then
      Spring.SetUnitDefIcon(udid, "krogoth.user")
    elseif (ud.name=="armbanth") then
      Spring.SetUnitDefIcon(udid, "bantha.user")
    elseif (ud.name=="corjugg") then
      Spring.SetUnitDefIcon(udid, "juggernaut.user")
    elseif (ud.name=="cormando") then
      Spring.SetUnitDefIcon(udid, "commando.user")

      -- mine
    elseif ud.modCategories["mine"] ~= nil or ud.modCategories["kamikaze"] ~= nil then
      if (ud.name=="cormine3" or ud.name=="armmine3" or ud.name=="corfmine3" or ud.name=="armfmine3" or ud.name=="corsktl") then
        Spring.SetUnitDefIcon(udid, "mine3.user")
      elseif (ud.name=="cormine2" or ud.name=="armmine2" or ud.name=="cormine4" or ud.name=="armmine4" or ud.name=="corroach" or ud.name=="armvader") then
        Spring.SetUnitDefIcon(udid, "mine2.user")
      else
        Spring.SetUnitDefIcon(udid, "mine1.user")
      end

      -- cloak
    elseif (ud.name=="armeyes" or ud.name=="coreyes") then
      Spring.SetUnitDefIcon(udid, "eye.user")
    elseif (ud.name=="armspy" or ud.name=="corspy" or ud.name=="armst") then
      Spring.SetUnitDefIcon(udid, "spy.user")
    elseif (ud.name=="armpeep" or ud.name=="corfink") then
      Spring.SetUnitDefIcon(udid, "air_t1_scout.user")

      -- energy
    elseif (ud.name=="armwin") or (ud.name=="corwin") then
      Spring.SetUnitDefIcon(udid, "wind.user")
    elseif (ud.name=="corafus" or ud.name=="armafus") then
      Spring.SetUnitDefIcon(udid, "energy5.user")
    elseif (ud.name=="armageo" or ud.name=="corageo") then
      Spring.SetUnitDefIcon(udid, "energy4.user")
    elseif (ud.name=="armgmm") or  (ud.name=="armfus") or (ud.name=="corfus") or (ud.name=="armckfus") or (ud.name=="armdf") or (ud.name=="armuwfus") or (ud.name=="coruwfus") then
      Spring.SetUnitDefIcon(udid, "energy3.user")
    elseif ud.name=="armgeo" or ud.name=="corgeo" or ud.name=="corbhmth" then
      Spring.SetUnitDefIcon(udid, "energy6.user")
elseif ud.name=="armadvsol" or ud.name=="coradvsol" then
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
        elseif (ud.name=="corfmd" or ud.name=="armamd") then
            Spring.SetUnitDefIcon(udid,"antinuke.user")
        elseif (ud.name=="cormabm" or ud.name=="armscab" or ud.name=="armcarry" or ud.name=="corcarry") then
            Spring.SetUnitDefIcon(udid,"antinuke_mobile.user")
        elseif (ud.stockpileWeaponDef ~= nil) and not (ud.name=="armmercury" or ud.name=="corscreamer" or ud.name=="corfmd" or ud.name=="armamd" or ud.name=="cormabm" or ud.name=="armscab") then
            -- nuke( stockpile weapon, but not mercury/screamer or anti nukes)
            if ud.name=="armsilo" or ud.name=="corsilo" then
                Spring.SetUnitDefIcon(udid, "nuke_big.user")
            elseif ud.name=="armjuno" or ud.name=="corjuno" then Spring.SetUnitDefIcon(udid, "jammer_t2.user")else
                Spring.SetUnitDefIcon(udid, "nuke.user")
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
        Spring.SetUnitDefIcon(udid, "mex_t1.user")
      elseif ud.name=="armmmkr" or ud.name=="cormmkr" then
        Spring.SetUnitDefIcon(udid, "metalmaker_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "metalmaker_t1.user")
      end

      -- energy generators
    elseif ((ud.totalEnergyOut > 10) and (ud.speed <= 0)) then
      Spring.SetUnitDefIcon(udid, "energy1.user")
    elseif (ud.isTransport) then
      -- transports
      if (ud.name=="armdfly" or ud.name=="corseah") then
        Spring.SetUnitDefIcon(udid, "air_t2_transport.user")
      elseif (ud.name=="armthovr" or ud.name=="corthovr") then
        Spring.SetUnitDefIcon(udid, "hover_transport.user")
      elseif ud.name=="corintr" then
        Spring.SetUnitDefIcon(udid, "veh_transport.user")
      elseif (ud.name=="armtship" or ud.name=="cortship") then
        Spring.SetUnitDefIcon(udid, "ship_transport.user")
      else
        Spring.SetUnitDefIcon(udid, "air_t1_transport.user")
      end

      -- nanos
    elseif (ud.deathExplosion =="nanoboom") then
      Spring.SetUnitDefIcon(udid, "worker.user")

      -- amphib & t2 subs 
    elseif ud.modCategories["phib"] ~= nil or (ud.modCategories["canbeuw"] ~= nil and ud.modCategories["underwater"] == nil) then
if (ud.name=="armserp" or ud.name=="armsubk" or ud.name=="corshark" or ud.name=="corssub") then
        Spring.SetUnitDefIcon(udid, "sub_t2.user")
      elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3') then
        Spring.SetUnitDefIcon(udid, "amphib_t3.user")
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "amphib_t2_aa.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib_t1_aa.user")
        end
      elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
        if (ud.isBuilder) then
          Spring.SetUnitDefIcon(udid, "amphib_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib_t2.user")
        end
      else
        if (ud.isBuilder) then
          Spring.SetUnitDefIcon(udid, "amphib_t1_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "amphib_t1.user")
        end
      end

      -- submarines
    elseif ((ud.modCategories["underwater"] ~= nil) and ud.speed > 0) then
      if (ud.name=="armacsub" or ud.name=="coracsub" or ud.name=="armrecl" or ud.name=="correcl" ) then
        Spring.SetUnitDefIcon(udid, "sub_t2_worker.user")
      else
        Spring.SetUnitDefIcon(udid, "sub_t1.user")
      end

      -- hovers
    elseif ud.modCategories["hover"] ~= nil then
      if ud.isBuilder then
        Spring.SetUnitDefIcon(udid, "hover_t1_worker.user")
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        Spring.SetUnitDefIcon(udid, "hover_t1_aa.user")
      elseif ud.name=="corhal" then
        Spring.SetUnitDefIcon(udid, "hover_t2.user")
      elseif ud.name=="armlun" or ud.name=="corsok" then
        Spring.SetUnitDefIcon(udid, "hover_t3.user")
      else
        Spring.SetUnitDefIcon(udid, "hover_t1.user")
      end

      -- aircraft
    elseif (ud.canFly) then

      if (ud.name=="armliche") then
        Spring.SetUnitDefIcon(udid, "air_liche.user")
      elseif (ud.name=="corcrw") then
        Spring.SetUnitDefIcon(udid, "air_krow.user")
      elseif (ud.name=="armawac" or ud.name=="corawac" or ud.name=="armsehak" or ud.name=="corhunt") then
        Spring.SetUnitDefIcon(udid, "air_t2_radar_t1.user")
      elseif ud.isBuilder then
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "air_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_worker.user")
        end
      elseif (ud.hoverAttack) then
        if (ud.name=="corbw") then
          Spring.SetUnitDefIcon(udid, "air_bladew.user")
        elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "air_t2_hover_t1.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_hover_t1.user")
        end
      elseif #ud.weapons > 0 and WeaponDefs[ud.weapons[1].weaponDef].type == "AircraftBomb" then
        if (ud.name=="armpnix" or ud.name=="corhurc") then
          Spring.SetUnitDefIcon(udid, "air_t2_bomber.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_bomber.user")
        end
      else
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "air_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1.user")
        end
      end

      -- ships
    elseif ud.modCategories["ship"] ~= nil then
      if (ud.name=="armroy" or ud.name=="corroy") then
        Spring.SetUnitDefIcon(udid, "ship_destroyer.user")
      elseif (ud.name=="armmship" or ud.name=="cormship" or ud.name=="armcrus" or ud.name=="corcrus") then
        Spring.SetUnitDefIcon(udid, "ship_t2_big.user")
      elseif (ud.name=="armbats" or ud.name=="corbats") then
        Spring.SetUnitDefIcon(udid, "ship_t2_battleship.user")
      elseif (ud.name=="armepoch" or ud.name=="corblackhy") then
        Spring.SetUnitDefIcon(udid, "ship_t2_flagship.user")
      elseif (ud.name=="armpt" or ud.name=="corpt") then
        Spring.SetUnitDefIcon(udid, "ship_tiny.user")
      elseif ud.isBuilder then
	if (ud.name=="armmls" or ud.name=="cormls") then
        Spring.SetUnitDefIcon(udid, "ship_engineer.user")
      elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "ship_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "ship_t1_worker.user")
        end
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "ship_t2_aa1.user")
        else
          Spring.SetUnitDefIcon(udid, "ship_aa1.user")
        end
      else
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
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
        Spring.SetUnitDefIcon(udid, "radar_t1.user")
      end

      -- jammers
    elseif (((ud.jammerRadius > 1) or (ud.sonarJamRadius > 1)) and (ud.speed <= 0)) then
      if (ud.name=="corshroud" or ud.name=="armveil") then
        Spring.SetUnitDefIcon(udid, "jammer_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "jammer_t1.user")
      end

      -- defenders and other buildings
    elseif (ud.isBuilding or (ud.speed <= 0)) then
      if (#ud.weapons <= 0) then
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
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
            Spring.SetUnitDefIcon(udid, "aa1.user")
          end
        else
          if (ud.name=="armanni" or ud.name=="cordoom") then
            Spring.SetUnitDefIcon(udid, "defence_3")
          elseif ((ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') or ud.name=="armguard" or ud.name=="corpun") then
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
        Spring.SetUnitDefIcon(udid, "tank_t1_flea.user")
      elseif ud.name=="armflash" or ud.name=="corgator" then
        Spring.SetUnitDefIcon(udid, "tank_t1_raid.user")
      elseif ud.name=="armjanus" or ud.name=="corlevlr" then
        Spring.SetUnitDefIcon(udid, "tank_t1_big.user")
      elseif ud.isBuilder then
      if ud.name=="armconsul" then
        Spring.SetUnitDefIcon(udid, "engineer.user")
        elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "tank_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "tank_t1_worker.user")
        end
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "tank_t2_aa1.user")
        else
          Spring.SetUnitDefIcon(udid, "tank_aa1.user")
        end
      else
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
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
      elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3') then
        Spring.SetUnitDefIcon(udid, "allterrain_t3.user")
      elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
        Spring.SetUnitDefIcon(udid, "allterrain_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "allterrain_t1.user")
      end

      -- kbots
    elseif ud.modCategories["kbot"] ~= nil then

      if (ud.name=="corsumo" or ud.name=="corgol") then
        Spring.SetUnitDefIcon(udid, "kbot_t2_big.user")
      elseif ud.name=="armflea" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_flea.user")
      elseif ud.name=="corak" or ud.name=="armpw" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_raid.user")
      elseif ud.name=="armham" or ud.name=="armwar" or ud.name=="corthud" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_big.user")
      elseif ud.isBuilder then
        if (ud.name=="cornecro" or ud.name=="armrectr") then
          Spring.SetUnitDefIcon(udid, "kbot_t1_tinyworker.user")
        elseif (ud.name=="armfark" or ud.name=="armconsul" or ud.name=="corfast") then
        Spring.SetUnitDefIcon(udid, "engineer.user")
        elseif ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "kbot_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "kbot_t1_worker.user")
        end
      elseif ud.weapons[1] ~= nil and ud.weapons[1].onlyTargets["vtol"] then
        if ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2' then
          Spring.SetUnitDefIcon(udid, "kbot_t2_aa1.user")
        else
          Spring.SetUnitDefIcon(udid, "kbot_aa1.user")
        end
      else
        if ((ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3') or ud.name=="orcone" or ud.name=="krogtaar") then
          Spring.SetUnitDefIcon(udid, "kbot_t3.user")
        elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "kbot_t2.user")
        else
          Spring.SetUnitDefIcon(udid, "kbot_t1.user")
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


function gadget:Initialize()
  changeUnitIcons()
end


--------------------------------------------------------------------------------

