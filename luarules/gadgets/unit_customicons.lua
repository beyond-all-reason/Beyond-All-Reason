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


--------------------------------------------------------------------------------

if (gadgetHandler:IsSyncedCode()) then
  return false
end

--------------------------------------------------------------------------------

local iconScale = Spring.GetConfigFloat("UnitIconScale", 1)

local icons = {
    -- ID,   icon png file,   scale
    {"armcom.user", "armcom",1.75},
    {"corcom.user", "corcom",1.75},
  
    {"mine1.user", "mine",0.36},
    {"mine2.user", "mine",0.44},
    {"mine3.user", "mine",0.53},
  
    {"sub_t1.user", "sub",1.33},
    {"sub_t2.user", "sub",1.7},
    {"sub_t1_worker.user", "sub_worker",1.33},
    {"sub_t2_worker.user", "sub_worker",1.66},
  
  
    {"wind.user", "wind",1.1},
    {"energy1.user", "solar",1.75},   
    {"energy2.user", "energy",1.75},
    {"energy3.user", "fusion",1.4},
    {"energy4.user", "hazardous",2.5},
    {"energy5.user", "fusion",1.8},
    {"energy6.user", "energy",2.2},
  
    {"eye.user", "eye",0.85},
    {"spy.user", "eye",1.25},
  
    {"hover_t1.user", "hover",0.9},
    {"hover_t1_worker.user", "hover_worker",0.9},
    {"hover_t1_aa.user", "hover_aa",0.9},
    {"hover_t2.user", "hover",1.3},
    {"hover_t3.user", "hover",1.6},
  
    {"ship_tiny.user", "ship",0.8},
    {"ship.user", "ship",1.2},
    {"ship_destroyer.user", "ship",1.44},
    {"ship_t1_worker.user", "ship_worker",1.33},
    {"ship_aa1.user", "ship_aa",1.2},
    {"ship_t2.user", "ship",1.65},
    {"ship_t2_worker.user", "ship_worker",1.65},
    {"ship_t2_aa1.user", "ship_aa",1.65},
    {"ship_t2_big.user", "ship",2},
    {"ship_t2_battleship.user", "ship",2.5},
    {"ship_t2_battleship.user", "ship",2.5},
    {"ship_t2_flagship.user", "ship",3.3},
  
    {"amphib_t1.user", "amphib",1.2},
    {"amphib_t1_aa.user", "amphib_aa",1.2},
    {"amphib_t1_worker.user", "amphib_worker",1.3},
    {"amphib_t2.user", "amphib",1.6},
    {"amphib_t2_aa.user", "amphib_aa",1.6},
    {"amphib_t3.user", "amphib",2.05},
  
    {"shield.user", "shield", 2.05},
  
    {"radar_t1.user", "radar", 0.9},
    {"jammer_t1.user", "jammer", 0.9},
    {"radar_t2.user", "radar", 1.2},
    {"jammer_t2.user", "jammer", 1.2},
  
    {"krogoth.user", "mech",3.2},
    {"bantha.user", "bantha",2.6},
    {"juggernaut.user", "kbot",2.75},
    {"commando.user", "mech",1.3},
  
    {"mex_t1.user", "mex",0.85},
    {"mex_t2.user", "mex",1.15},
  
    {"metalmaker_t1.user", "metalmaker",0.75},
    {"metalmaker_t2.user", "metalmaker",1.15},
  
    {"nuke.user", "nuke",1.8},
          {"nuke_big.user", "nuke",2.5},
          {"antinuke.user", "antinuke",1.6},
          {"antinuke_mobile.user", "antinuke",1.3},
  
    {"aa1.user", "aa", 0.85},
    {"aa2.user", "aa", 1.1},
    {"aa_flak.user", "aa", 1.4},
    {"aa_longrangenergy1.user", "aa", 1.8},
  
    {"worker.user", "worker", 0.85},
  
    {"allterrain_t1.user", "allterrain",1},
    {"allterrain_t2.user", "allterrain",1.33},
    {"allterrain_t3.user", "allterrain",1.95},
    {"allterrain_vanguard.user", "allterrain",2.3},
  
    {"kbot_t1_flea.user", "kbot",0.51},
    {"kbot_t1_tinyworker.user", "worker",0.8},
    {"engineer.user", "wrench",1.4},
    {"ship_engineer.user", "shipengineer",1.5},
    {"kbot_t1_raid.user", "kbot",0.7},
    {"kbot_t1.user", "kbot",0.95},
    {"kbot_t1_big.user", "kbot",1.1},
    {"kbot_t1_worker.user", "kbot_worker",0.95},
    {"kbot_t1_aa1.user", "kbot_aa",0.95},
    {"kbot_t2.user", "kbot",1.28},
    {"kbot_t2_big.user", "kbot",1.47},
    {"kbot_t2_worker.user", "kbot_worker", 1.33},
    {"kbot_t2_aa1.user", "kbot_aa",1.28},
    {"kbot_t3.user", "kbot",1.9},
  
    {"tank_t1_flea.user", "vehicle",0.55},
    {"tank_t1_raid.user", "vehicle",0.75},
    {"tank_t1.user", "vehicle",1},
    {"tank_t1_big.user", "vehicle",1.15},
    {"tank_t1_aa1.user", "vehicle_aa",1},
    {"tank_t2.user", "vehicle",1.3},
    {"tank_t2_aa1.user", "vehicle_aa",1.3},
    {"tank_t2_big.user", "vehicle",1.5},
    {"tank_t1_worker.user", "vehicle_worker",0.95},
    {"tank_t2_worker.user", "vehicle_worker", 1.3},
  
    {"building_t1.user", "building", 1},
    {"building_t2.user", "building", 1.3},
  
    {"factory_t1", "factory",1.45},
    {"factory_t2", "factory",1.85},
    {"factory_t3", "factory",2.4},
  
    {"lrpc.user", "lrpc", 2.35},
    {"lrpc_lolcannon.user", "lrpc", 3.5},

    {"chicken1.user", "chicken", 0.9},
    {"chicken2.user", "chicken", 1.2},
    {"chicken3.user", "chicken", 1.5},
    {"chicken4.user", "chicken", 2.6},
    {"chicken_air.user", "chicken_air", 1.3},
    {"chicken_air2.user", "chicken_air", 1.7},
    {"chicken_roost.user", "chicken_roost", 1.5},
    {"chicken_queen.user", "chicken_queen", 4},

    {"meteor.user", "blank", 1},
  
    {"wall.user", "building",0.55},
  
    {"air_t1.user", "air",0.85},
    {"air_t1_worker.user", "air_worker",1.2},
    {"air_t1_hover_t1.user", "air_hover",1.25},
    {"air_t1_bomber.user", "air_bomber",1.35},
    {"air_t1_transport.user", "transport",1.3},
    {"air_t1_scout.user", "air_los",0.6},
    {"air_t2.user", "air",1.05},
    {"air_t2_worker.user", "air_worker",1.6},
    {"air_t2_hover_t1.user", "air_hover",1.55},
    {"air_t2_bomber.user", "air_bomber",1.66},
    {"air_t2_transport.user", "transport",1.6},
    {"veh_transport.user", "vehtrans",1.7},
    {"hover_transport.user", "hovertrans",1.5},
    {"ship_transport.user", "shiptrans",2},
    {"air_t2_radar_t1.user", "air_los",1.33},
    {"air_bladew.user", "air_hover_bw",0.75},
    {"air_krow.user", "air_hover",2},
    {"air_liche.user", "air_bomber",2},
  
    {"defence_0", "defence", 0.8},
    {"defence_1", "defence", 1.05},
    {"defence_2", "defence", 1.4},
    {"defence_3", "defence", 1.95},
  
    {"blank.user", "blank", 1},
    {"unknown.user", "unknown", 2},
}


function changeUnitIcons(folder)

    -- load icons
  if folder then
      for i, icon in ipairs(icons) do
        Spring.FreeUnitIcon(icon[1])
        if VFS.FileExists('icons/'..folder..'/'..icon[2]..icon[3]..'.png') then    -- check if specific custom sized icon is availible
            Spring.AddUnitIcon(icon[1], 'icons/'..folder..'/'..icon[2]..icon[3]..'.png', icon[3]*iconScale)
        else
            Spring.AddUnitIcon(icon[1], 'icons/'..folder..'/'..icon[2]..'.png', icon[3]*iconScale)
        end
      end
  end

    -- load custom unit icons when availible
    local files = VFS.DirList('icons/'..folder, "*.png")
    for k, file in ipairs(files) do
        local name = string.gsub(file, 'icons\\'..folder..'\\', '')   -- when located in spring folder
        name = string.gsub(name, 'icons/'..folder..'/', '')   -- when located in game archive
        local iconname = string.gsub(name, '.png', '')
        if iconname then
            local iconname = string.match(iconname, '([a-z0-9-_]*)')
            iconname = string.sub(iconname, 1, #iconname-2)
            local scale = string.match(name, '_[0-9.]*\.png')
            if scale ~= nil then
                scale = string.gsub(scale, '_', '')
                scale = string.gsub(scale, '.png', '')
            end
            if scale == '' then
                scale = icon[3]
            end
            for i, icon in ipairs(icons) do
                if string.gsub(icon[1], '.user', '') == iconname then
                    Spring.AddUnitIcon(icon[1], 'icons/'..folder..'/'..iconname..'_'..scale..'.png', tonumber(scale)*iconScale)
                end
            end
            if unitname and UnitDefNames[unitname] then
                local scale = string.gsub(name, unitname, '')
                scale = string.gsub(scale, '_', '')
                if scale ~= '' then
                    Spring.AddUnitIcon(unitname..".user", file, tonumber(scale)*iconScale)
                end
            end
        end
    end

  -- assign (standard) icons
  for udid,ud in pairs(UnitDefs) do

    if (ud == nil) then break end
    local name = string.gsub(ud.name, '_bar', '')

    if name=="meteor" then
        Spring.SetUnitDefIcon(udid, "blank.user")
    elseif string.sub(name, 0, 7) == "critter" then
      Spring.SetUnitDefIcon(udid, "blank.user")
    elseif name=="chip" or name=="dice" or name=="xmasball" or name=="corstone" or name=="armstone" then
      Spring.SetUnitDefIcon(udid, "blank.user")
    elseif (name=="corkrog") then
      Spring.SetUnitDefIcon(udid, "krogoth.user")
    elseif (name=="armbanth") then
      Spring.SetUnitDefIcon(udid, "bantha.user")
    elseif (name=="corjugg") then
      Spring.SetUnitDefIcon(udid, "juggernaut.user")
    elseif (name=="cormando") then
      Spring.SetUnitDefIcon(udid, "commando.user")

    -- chickens
    elseif (name=="chickenr3") then
        Spring.SetUnitDefIcon(udid, "chicken4.user")
    elseif (ud.moveDef ~= nil and ud.moveDef.name=="chickqueen") then
        Spring.SetUnitDefIcon(udid, "chicken_queen.user")
    elseif name=="roost" or name=="chickend1" then
        Spring.SetUnitDefIcon(udid, "chicken_roost.user")
    elseif  ud.modCategories["chicken"] and ud.canFly and ud.xsize >= 3 then
        Spring.SetUnitDefIcon(udid, "chicken_air2.user")
    elseif  ud.modCategories["chicken"] and ud.canFly then
        Spring.SetUnitDefIcon(udid, "chicken_air.user")
    elseif  ud.modCategories["chicken"] and ud.xsize >= 5 then
        Spring.SetUnitDefIcon(udid, "chicken3.user")
    elseif  ud.modCategories["chicken"] and ud.xsize >= 3 then
        Spring.SetUnitDefIcon(udid, "chicken2.user")
    elseif  ud.modCategories["chicken"] then
        Spring.SetUnitDefIcon(udid, "chicken1.user")

      -- mine
    elseif ud.modCategories["mine"] ~= nil or ud.modCategories["kamikaze"] ~= nil then
      if (name=="cormine3" or name=="armmine3" or name=="corfmine3" or name=="armfmine3" or name=="corsktl") then
        Spring.SetUnitDefIcon(udid, "mine3.user")
      elseif (name=="cormine2" or name=="armmine2" or name=="cormine4" or name=="armmine4" or name=="corroach" or name=="armvader") then
        Spring.SetUnitDefIcon(udid, "mine2.user")
      else
        Spring.SetUnitDefIcon(udid, "mine1.user")
      end

      -- cloak
    elseif (name=="armeyes" or name=="coreyes") then
      Spring.SetUnitDefIcon(udid, "eye.user")
    elseif (name=="armspy" or name=="corspy" or name=="armst") then
      Spring.SetUnitDefIcon(udid, "spy.user")
    elseif (name=="armpeep" or name=="corfink") then
      Spring.SetUnitDefIcon(udid, "air_t1_scout.user")

      -- energy
    elseif (name=="armwin") or (name=="corwin") then
      Spring.SetUnitDefIcon(udid, "wind.user")
    elseif (name=="corafus" or name=="armafus") then
      Spring.SetUnitDefIcon(udid, "energy5.user")
    elseif (name=="armageo" or name=="corageo") then
      Spring.SetUnitDefIcon(udid, "energy4.user")
    elseif (name=="armgmm") or  (name=="armfus") or (name=="corfus") or (name=="armckfus") or (name=="armdf") or (name=="armuwfus") or (name=="coruwfus") then
      Spring.SetUnitDefIcon(udid, "energy3.user")
    elseif name=="armgeo" or name=="corgeo" or name=="corbhmth" then
      Spring.SetUnitDefIcon(udid, "energy6.user")
    elseif name=="armadvsol" or name=="coradvsol" then
      Spring.SetUnitDefIcon(udid, "energy2.user")
    elseif name=="armsolar" or name=="corsolar" or name=="armtide" or name=="cortide" then
        Spring.SetUnitDefIcon(udid, "energy1.user")

      -- lrpc
    elseif (name=="armvulc") or (name=="corbuzz") then
      Spring.SetUnitDefIcon(udid, "lrpc_lolcannon.user")
    elseif (name=="armbrtha") or (name=="corint") then
      Spring.SetUnitDefIcon(udid, "lrpc.user")

      -- commander
    elseif (name=="armcom") or (name=="armdecom") then
      Spring.SetUnitDefIcon(udid, "armcom.user")
    elseif (name=="corcom") or (name=="cordecom") then
      Spring.SetUnitDefIcon(udid, "corcom.user")

    elseif (name=="armclaw") or (name=="cormaw") then
      Spring.SetUnitDefIcon(udid, "defence_0")

      -- factories
    elseif (ud.isFactory) then
      if (name=="armshltx" or name=="armshltxuw" or name=="corgant" or name=="corgantuw") then
        Spring.SetUnitDefIcon(udid, "factory_t3")
      elseif (name=="armaap" or name=="armavp" or name=="armalab" or name=="armasy" or name=="coraap" or name=="coravp" or name=="coralab" or name=="corasy") then
        Spring.SetUnitDefIcon(udid, "factory_t2")
      else
        Spring.SetUnitDefIcon(udid, "factory_t1")
      end

     -- anti nuke
        elseif (name=="corfmd" or name=="armamd") then
            Spring.SetUnitDefIcon(udid,"antinuke.user")
        elseif (name=="cormabm" or name=="armscab" or name=="armcarry" or name=="corcarry") then
            Spring.SetUnitDefIcon(udid,"antinuke_mobile.user")
        elseif (ud.stockpileWeaponDef ~= nil) and not (name=="armmercury" or name=="corscreamer" or name=="corfmd" or name=="armamd" or name=="cormabm" or name=="armscab") then
            -- nuke( stockpile weapon, but not mercury/screamer or anti nukes)
            if name=="armsilo" or name=="corsilo" then
                Spring.SetUnitDefIcon(udid, "nuke_big.user")
            elseif name=="armjuno" or name=="corjuno" then Spring.SetUnitDefIcon(udid, "jammer_t2.user")else
                Spring.SetUnitDefIcon(udid, "nuke.user")
            end

      -- shield
    elseif (ud.shieldWeaponDef) then
      Spring.SetUnitDefIcon(udid, "shield.user")

      -- metal
    elseif ((ud.extractsMetal > 0) or (ud.makesMetal > 0)) or
            (name=="armmakr") or (name=="armfmkr") or (name=="armmmkr") or (name=="armuwmmm") or
            (name=="cormakr") or (name=="corfmkr") or (name=="cormmkr") or (name=="coruwmmm") then
      -- metal extractors and makers
      if ud.extractsMetal > 0.001 then
        Spring.SetUnitDefIcon(udid, "mex_t2.user")
      elseif ud.extractsMetal > 0 and ud.extractsMetal <= 0.001 then
        Spring.SetUnitDefIcon(udid, "mex_t1.user")
      elseif name=="armmmkr" or name=="cormmkr" then
        Spring.SetUnitDefIcon(udid, "metalmaker_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "metalmaker_t1.user")
      end

    elseif (ud.isTransport) then
      -- transports
      if (name=="armdfly" or name=="corseah") then
        Spring.SetUnitDefIcon(udid, "air_t2_transport.user")
      elseif (name=="armthovr" or name=="corthovr") then
        Spring.SetUnitDefIcon(udid, "hover_transport.user")
      elseif name=="corintr" then
        Spring.SetUnitDefIcon(udid, "veh_transport.user")
      elseif (name=="armtship" or name=="cortship") then
        Spring.SetUnitDefIcon(udid, "ship_transport.user")
      else
        Spring.SetUnitDefIcon(udid, "air_t1_transport.user")
      end

      -- nanos
    elseif (ud.deathExplosion =="nanoboom") then
      Spring.SetUnitDefIcon(udid, "worker.user")

      -- amphib & t2 subs 
    elseif ud.modCategories["phib"] ~= nil or (ud.modCategories["canbeuw"] ~= nil and ud.modCategories["underwater"] == nil) then
if (name=="armserp" or name=="armsubk" or name=="corshark" or name=="corssub") then
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
      if (name=="armacsub" or name=="coracsub" or name=="armrecl" or name=="correcl" ) then
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
      elseif name=="corhal" then
        Spring.SetUnitDefIcon(udid, "hover_t2.user")
      elseif name=="armlun" or name=="corsok" then
        Spring.SetUnitDefIcon(udid, "hover_t3.user")
      else
        Spring.SetUnitDefIcon(udid, "hover_t1.user")
      end

      -- aircraft
    elseif (ud.canFly) then

      if (name=="armliche") then
        Spring.SetUnitDefIcon(udid, "air_liche.user")
      elseif (name=="corcrw") then
        Spring.SetUnitDefIcon(udid, "air_krow.user")
      elseif (name=="armawac" or name=="corawac" or name=="armsehak" or name=="corhunt") then
        Spring.SetUnitDefIcon(udid, "air_t2_radar_t1.user")
      elseif ud.isBuilder then
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "air_t2_worker.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_worker.user")
        end
      elseif (ud.hoverAttack) then
        if (name=="corbw") then
          Spring.SetUnitDefIcon(udid, "air_bladew.user")
        elseif (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') then
          Spring.SetUnitDefIcon(udid, "air_t2_hover_t1.user")
        else
          Spring.SetUnitDefIcon(udid, "air_t1_hover_t1.user")
        end
      elseif #ud.weapons > 0 and WeaponDefs[ud.weapons[1].weaponDef].type == "AircraftBomb" then
        if (name=="armpnix" or name=="corhurc") then
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
      if (name=="armroy" or name=="corroy") then
        Spring.SetUnitDefIcon(udid, "ship_destroyer.user")
      elseif (name=="armmship" or name=="cormship" or name=="armcrus" or name=="corcrus") then
        Spring.SetUnitDefIcon(udid, "ship_t2_big.user")
      elseif (name=="armbats" or name=="corbats") then
        Spring.SetUnitDefIcon(udid, "ship_t2_battleship.user")
      elseif (name=="armepoch" or name=="corblackhy") then
        Spring.SetUnitDefIcon(udid, "ship_t2_flagship.user")
      elseif (name=="armpt" or name=="corpt") then
        Spring.SetUnitDefIcon(udid, "ship_tiny.user")
      elseif ud.isBuilder then
	if (name=="armmls" or name=="cormls") then
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
      if (name=="corsd" or name=="armarad" or name=="armason" or name=="corarad" or name=="corason") then
        Spring.SetUnitDefIcon(udid, "radar_t2.user")
      else
        Spring.SetUnitDefIcon(udid, "radar_t1.user")
      end

      -- jammers
    elseif (((ud.jammerRadius > 1) or (ud.sonarJamRadius > 1)) and (ud.speed <= 0)) then
      if (name=="corshroud" or name=="armveil") then
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
          if (name=="armmercury" or name=="corscreamer") then
            Spring.SetUnitDefIcon(udid, "aa_longrangenergy1.user")
          elseif WeaponDefs[ud.weapons[1].weaponDef].cegTag == '' then
            Spring.SetUnitDefIcon(udid, "aa_flak.user")
          elseif name=="corerad" or name=="armcir" or name=="armpacko" or name=="cormadsam" then
            Spring.SetUnitDefIcon(udid, "aa2.user")
          else
            Spring.SetUnitDefIcon(udid, "aa1.user")
          end
        else
          if (name=="armanni" or name=="cordoom") then
            Spring.SetUnitDefIcon(udid, "defence_3")
          elseif ((ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '2') or name=="armguard" or name=="corpun") then
            Spring.SetUnitDefIcon(udid, "defence_2")
          elseif (name=="armhlt" or name=="corhlt" or name=="armfhlt" or name=="corfhlt") then
            Spring.SetUnitDefIcon(udid, "defence_1")
          else
            Spring.SetUnitDefIcon(udid, "defence_0")
          end
        end
      end

      -- vehicles
    elseif ud.modCategories["tank"] ~= nil then

      if (name=="armmanni" or name=="corgol") then
        Spring.SetUnitDefIcon(udid, "tank_t2_big.user")
      elseif name=="corfav" or name=="armfav" then
        Spring.SetUnitDefIcon(udid, "tank_t1_flea.user")
      elseif name=="armflash" or name=="corgator" then
        Spring.SetUnitDefIcon(udid, "tank_t1_raid.user")
      elseif name=="armjanus" or name=="corlevlr" then
        Spring.SetUnitDefIcon(udid, "tank_t1_big.user")
      elseif ud.isBuilder then
      if name=="armconsul" then
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

      if name=="armvang" then
        Spring.SetUnitDefIcon(udid, "allterrain_vanguard.user")
      elseif name=="armspid" then
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

      if (name=="corsumo" or name=="corgol") then
        Spring.SetUnitDefIcon(udid, "kbot_t2_big.user")
      elseif name=="armflea" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_flea.user")
      elseif name=="corak" or name=="armpw" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_raid.user")
      elseif name=="armham" or name=="armwar" or name=="corthud" then
        Spring.SetUnitDefIcon(udid, "kbot_t1_big.user")
      elseif ud.isBuilder then
        if (name=="cornecro" or name=="armrectr") then
          Spring.SetUnitDefIcon(udid, "kbot_t1_tinyworker.user")
        elseif (name=="armfark" or name=="armconsul" or name=="corfast") then
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
        if (ud.customParams.techlevel ~= nil and ud.customParams.techlevel == '3') then
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


    -- load and assign custom unit icons when availible
    local customUnitIcons = {}
    local files = VFS.DirList('icons/'..folder, "*.png")
    for k, file in ipairs(files) do
        local name = string.gsub(file, 'icons\\'..folder..'\\', '')   -- when located in spring folder
        name = string.gsub(name, 'icons/'..folder..'/', '')   -- when located in game archive
        name = string.gsub(name, '.png', '')
        if name then
            local unitname = string.match(name, '([a-z0-9]*)')
            if unitname and UnitDefNames[unitname] then
                local scale = string.gsub(name, unitname, '')
                scale = string.gsub(scale, '_', '')
                if scale ~= '' then
                    Spring.AddUnitIcon(unitname..".user", file, tonumber(scale)*iconScale)
                    Spring.SetUnitDefIcon(UnitDefNames[unitname].id, unitname..".user")
                end
            end
        end
    end
end


local myPlayerID = Spring.GetMyPlayerID()

local function isFolderValid(folder)
    local found = false
    for k, subdir in pairs(VFS.SubDirs('icons')) do
        if folder == string.gsub(string.sub(subdir, 1, #subdir-1), 'icons/', '')  or  folder == string.gsub(string.sub(subdir, 1, #subdir-1), 'icons\\', '') then
            found = true
            break
        end
    end
    return found
end

function gadget:GotChatMsg(msg, playerID)
  if playerID == myPlayerID then
      if string.sub(msg,1,12) == "uniticonset " then
          local folder = string.sub(msg,13)
          if not isFolderValid(folder) then
              Spring.Echo('Icons folder \''..folder..'\' isnt valid')
          else
              Spring.Echo('Unit icon set loaded: '..folder)
              changeUnitIcons(folder)
              Spring.SetConfigString("UnitIconFolder", folder)
          end
      end
      if string.sub(msg,1,14) == "uniticonscale " then
          iconScale = tonumber(string.sub(msg,15))
          Spring.SetConfigFloat("UnitIconScale", iconScale)
          changeUnitIcons(Spring.GetConfigString("UnitIconFolder", 'old'))
          Spring.SendCommands("minimap unitsize "..Spring.GetConfigFloat("MinimapIconScale", 2.5))
      end
  end
end


function gadget:Initialize()
    local folder = Spring.GetConfigString("UnitIconFolder", 'modern')
    if not isFolderValid(folder) then
        folder = 'modern'
    end
    changeUnitIcons(folder)
end


--------------------------------------------------------------------------------

