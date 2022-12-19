--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
    return {
      name      = "Dev Commands",
      desc      = "v0.011 Dev Commands",
      author    = "CarRepairer",
      date      = "2011-11-17",
      license   = "GPLv2",
      layer     = 5,
      enabled   = false,  --  loaded by default?
    }
  end
  
  VFS.Include("LuaRules/Configs/customcmds.h.lua")
  
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  -- Mission Creation
  
  local recentlyExported = false
  local BUILD_RESOLUTION = 16
  
  local function SanitizeBuildPositon(x, z, ud, facing)
      local oddX = (ud.xsize % 4 == 2)
      local oddZ = (ud.zsize % 4 == 2)
      
      if facing % 2 == 1 then
          oddX, oddZ = oddZ, oddX
      end
      
      if oddX then
          x = math.floor((x + 8)/BUILD_RESOLUTION)*BUILD_RESOLUTION - 8
      else
          x = math.floor(x/BUILD_RESOLUTION)*BUILD_RESOLUTION
      end
      if oddZ then
          z = math.floor((z + 8)/BUILD_RESOLUTION)*BUILD_RESOLUTION - 8
      else
          z = math.floor(z/BUILD_RESOLUTION)*BUILD_RESOLUTION
      end
      return x, z
  end
  
  local function GetUnitFacing(unitID)
      return math.floor(((Spring.GetUnitHeading(unitID) or 0)/16384 + 0.5)%4)
  end
  
  local function GetFeatureFacing(unitID)
      return math.floor(((Spring.GetFeatureHeading(unitID) or 0)/16384 + 0.5)%4)
  end
  
  local commandNameMap = {
      [CMD.PATROL] = "PATROL",
      [CMD_RAW_MOVE] = "RAW_MOVE",
      [CMD_JUMP] = "JUMP",
      [CMD.ATTACK] = "ATTACK",
      [CMD.MOVE] = "MOVE",
      [CMD.GUARD] = "GUARD",
      [CMD.FIGHT] = "FIGHT",
  }
  
  local function GetCommandString(index, command)
      local cmdID = command.id
      if not commandNameMap[cmdID] then
          return
      end
      if not (command.params[1] and command.params[3]) then
          return
      end
      local commandString = [[{cmdID = planetUtilities.COMMAND.]] .. commandNameMap[cmdID]
      commandString = commandString .. [[, pos = {]] .. math.floor(command.params[1]) .. ", " .. math.floor(command.params[3]) .. [[}]]
      
      if index > 1 then
          commandString = commandString .. [[, options = {"shift"}]]
      end
      return commandString .. [[},]]
  end
  
  local function ProcessUnitCommands(inTabs, commands, unitID, mobileUnit)
      if mobileUnit and commands[1] then
          if (commands[1].id == CMD.PATROL) or (commands[2] and commands[2].id == CMD.PATROL) then
              local fullCommandString
              for i = 1, #commands do
                  local command = commands[i]
                  if command.id == CMD.PATROL and command.params[1] and command.params[3] then
                      fullCommandString = (fullCommandString or "") .. inTabs .. "\t" .. [[{]] .. math.floor(command.params[1]) .. ", " .. math.floor(command.params[3]) .. [[},]] .. "\n"
                  end
              end
              
              if fullCommandString then
                  return inTabs  .. [[patrolRoute = {]] .. "\n" .. fullCommandString .. inTabs .. "},\n"
              end
          end
      end
  
      local fullCommandString
      for i = 1, #commands do
          local commandString = GetCommandString(i, commands[i])
          if commandString then
              fullCommandString = (fullCommandString or "") .. inTabs .. "\t" .. commandString .. "\n"
          end
      end
      if fullCommandString then
          return inTabs  .. [[commands = {]] .. "\n" .. fullCommandString .. inTabs .. "},\n"
      end
  end
  
  local function GetUnitString(unitID, tabs, sendCommands)
      local ud = UnitDefs[Spring.GetUnitDefID(unitID)]
      local x, y, z = Spring.GetUnitPosition(unitID)
      
      local facing = 0
      
      if ud.isImmobile then
          facing = Spring.GetUnitBuildFacing(unitID)
          x, z = SanitizeBuildPositon(x, z, ud, facing)
      else
          facing = GetUnitFacing(unitID)
      end
      
      local build = select(5, Spring.GetUnitHealth(unitID))
      
      local inTabs = tabs .. "\t\t"
      local unitString = tabs .. "\t{\n"
      
      unitString = unitString .. inTabs .. [[name = "]] .. ud.name .. [[",]] .. "\n"
      unitString = unitString .. inTabs .. [[unitID = "]] .. unitID .. [[",]] .. "\n"
      unitString = unitString .. inTabs .. [[x = ]] .. math.floor(x) .. [[,]] .. "\n"
      unitString = unitString .. inTabs .. [[y = ]] .. math.floor(y) .. [[,]] .. "\n" --missing hight of the ground so added it for dump
      unitString = unitString .. inTabs .. [[z = ]] .. math.floor(z) .. [[,]] .. "\n"
      unitString = unitString .. inTabs .. [[facing = ]] .. facing .. [[,]] .. "\n"
      
      if build and build < 1 then
          unitString = unitString .. inTabs .. [[buildProgress = ]] .. math.floor(build*10000)/10000 .. [[,]] .. "\n"
      end
      
      if ud.isImmobile then
          local origHeight = Spring.GetGroundOrigHeight(x, z)
          if ud.floatOnWater and (origHeight < 0) then
              origHeight = 0
          end
          if math.abs(origHeight - y) > 5 then
              unitString = unitString .. inTabs .. [[terraformHeight = ]] .. math.floor(y) .. [[,]] .. "\n"
          end
      end
      
      if sendCommands then
          local commands = Spring.GetCommandQueue(unitID, -1)
          if commands and #commands > 0 then
              local commandString = ProcessUnitCommands(inTabs, commands, unitID, not ud.isImmobile)
              if commandString then
                  unitString = unitString .. commandString
              end
          end
      end
      return unitString .. tabs .. "\t},"
  end
  
  local function GetFeatureString(fID)
      local fx, fy, fz = Spring.GetFeaturePosition(fID)
      local fd = FeatureDefs[Spring.GetFeatureDefID(fID)]
      local tabs = "\t\t\t\t"
      local inTabs = tabs .. "\t"
      local unitString = tabs .. "{\n"
      
      unitString = unitString .. inTabs .. [[name = "]] .. fd.name .. [[",]] .. "\n"
      unitString = unitString .. inTabs .. [[x = ]] .. math.floor(fx) .. [[,]] .. "\n"
      unitString = unitString .. inTabs .. [[y = ]] .. math.floor(fy) .. [[,]] .. "\n" --missing feature ground hight
      unitString = unitString .. inTabs .. [[z = ]] .. math.floor(fz) .. [[,]] .. "\n"
      unitString = unitString .. inTabs .. [[facing = ]] .. GetFeatureFacing(fID) .. [[,]] .. "\n"
      
      return unitString .. tabs.. "},"
  end
  
  local function ExportTeamUnitsForMission(teamID, sendCommands, selectedOnly)
      local units = Spring.GetTeamUnits(teamID)
      if not (units and #units > 0) then
          return
      end
      local tabs = (teamID == 0 and "\t\t\t\t") or "\t\t\t\t\t"
      Spring.Echo("====== Unit export team " .. (teamID or "??") .. " ======")
      for i = 1, 20 do
          Spring.Echo("= - = - = - = - = - = - = - = - = - = - = - = - = - = - = - = - =")
      end
      local unitsString = tabs .. "startUnits = {\n"
      for i = 1, #units do
          if (not selectedOnly) or Spring.IsUnitSelected(units[i]) then
              Spring.Echo(GetUnitString(units[i], tabs, sendCommands))
          end
      end
      --unitsString = unitsString .. tabs .. "}"
      --Spring.Echo(unitsString)
  end
  
  local function ExportUnitsForMission(sendCommands, selectedOnly)
      if recentlyExported then
          return
      end
      local teamList = Spring.GetTeamList()
      Spring.Echo("================== ExportUnitsForMission ==================")
      for i = 1, #teamList do
          ExportTeamUnitsForMission(teamList[i], sendCommands, selectedOnly)
      end
      recentlyExported = 1
  end
  
  local function ExportUnitsAndCommandsForMission()
      ExportUnitsForMission(true)
  end
  
  local function ExportSelectedUnitsAndCommandsForMission()
      ExportUnitsForMission(true, true)
  end
  
  local function ExportFeaturesForMission()
      Spring.Echo("================== ExportFeaturesForMission ==================")
      local features = Spring.GetAllFeatures()
      for i = 1, #features do
          Spring.Echo(GetFeatureString(features[i]))
      end
  end
  
  local unitToMove = 0
  local recentlyMovedUnit = false
  local function MoveUnitRaw(snap)
      local units = Spring.GetSelectedUnits()
      if not (units and units[1]) then
          return
      end
      
      if not recentlyMovedUnit then
          unitToMove = unitToMove + 1
          if unitToMove > #units then
              unitToMove = 1
          end
          recentlyMovedUnit = options.moveUnitDelay.value
      end
      local unitID = units[unitToMove]
      
      local unitDefID = Spring.GetUnitDefID(unitID)
      local ud = unitDefID and UnitDefs[unitDefID]
      if not ud then
          return
      end
      
      local mx, my = Spring.GetMouseState()
      local trace, pos = Spring.TraceScreenRay(mx, my, true, false, false, true)
      if not (trace == "ground" and pos) then
          return
      end
      
      local x, z = math.floor(pos[1]), math.floor(pos[3])
      if snap or ud.isImmobile then
          local facing = Spring.GetUnitBuildFacing(unitID)
          x, z = SanitizeBuildPositon(x, z, ud, facing)
      end
      
      Spring.SendCommands("luarules moveunit " .. unitID .. " " .. x .. " " .. z)
  end
  
  local function MoveUnit()
      MoveUnitRaw(false)
  end
  
  local function MoveUnitSnap()
      MoveUnitRaw(true)
  end
  
  local function DestroyUnit()
      local units = Spring.GetSelectedUnits()
      if not units then
          return
      end
      
      for i = 1, #units do
          Spring.SendCommands("luarules destroyunit " .. units[i])
      end
  end
  
  local function RotateUnit(add)
      local units = Spring.GetSelectedUnits()
      if not units then
          return
      end
      
      for i = 1, #units do
          local unitDefID = Spring.GetUnitDefID(units[i])
          local ud = unitDefID and UnitDefs[unitDefID]
          if ud then
              local facing
              if ud.isImmobile then
                  facing = Spring.GetUnitBuildFacing(units[i])
              else
                  facing = GetUnitFacing(units[i])
              end
              facing = (facing + add)%4
              Spring.SendCommands("luarules rotateunit " .. units[i] .. " " .. facing)
          end
      end
  end
  
  local function RotateUnitLeft()
      RotateUnit(1)
  end
  
  local function RotateUnitRight()
      RotateUnit(-1)
  end
  
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  
  function widget:Update(dt)
      if recentlyExported then
          recentlyExported = recentlyExported - dt
          if recentlyExported < 0 then
              recentlyExported = false
          end
      end
      if recentlyMovedUnit then
          recentlyMovedUnit = recentlyMovedUnit - dt
          if recentlyMovedUnit < 0 then
              recentlyMovedUnit = false
          end
      end
  end
  
  local doCommandEcho = false
  function widget:CommandNotify(cmdID, params, options)
      if doCommandEcho then
          Spring.Echo("cmdID", cmdID)
          Spring.Utilities.TableEcho(params, "params")
          Spring.Utilities.TableEcho(options, "options")
      end
  end
  
  --------------------------------------------------------------------------------
  --------------------------------------------------------------------------------
  options_path = 'Settings/Dev'
  options = {
      cheat = {
          name = "Cheat",
          type = 'button',
          action = 'cheat',
      },
      nocost = {
          name = "No Cost",
          type = 'button',
          action = 'nocost',
      },
      
      spectator = {
          name = "Spectator",
          type = 'button',
          action = 'spectator',
      },
      
      godmode = {
          name = "Godmode",
          type = 'button',
          action = 'godmode',
      },
      
      testunit = {
          name = "Spawn Testunit",
          type = 'button',
          action = 'give testunit',
      },
      
      luauireload = {
          name = "Reload LuaUI",
          type = 'button',
          action = 'luaui reload',
      },
      
      luarulesreload = {
          name = "Reload LuaRules",
          type = 'button',
          action = 'luarules reload',
      },
      
      debug = {
          name = "Debug",
          type = 'button',
          action = 'debug',
      },
      debugcolvol = {
          name = "Debug Colvol",
          type = 'button',
          action = 'debugcolvol',
      },
      debugpath = {
          name = "Debug Path",
          type = 'button',
          action = 'debugpath',
      },
      singlestep = {
          name = "Single Step",
          type = 'button',
          action = 'singlestep',
      },
      
      
      printunits = {
          name = "Print Units",
          type = 'button',
          OnChange = function(self)
              for i=1,#UnitDefs do
                  local ud = UnitDefs[i]
                  local name = ud.name
                  Spring.Echo("'" .. name .. "',")
              end
          end,
      },
      printunitnames = {
          name = "Print Unit Names",
          type = 'button',
          OnChange = function(self)
              for i=1,#UnitDefs do
                  local ud = UnitDefs[i]
                  local name = ud.humanName
                  Spring.Echo("'" .. name .. "',")
              end
          end,
      },
      echoCommand = {
          name = 'Echo Given Commands',
          type = 'bool',
          value = false,
          OnChange = function(self)
              doCommandEcho = self.value
          end,
      },
      missionexport = {
          name = "Mission Units Export",
          type = 'button',
          action = 'mission_units_export',
          OnChange = ExportUnitsForMission,
      },
      missionexportcommands = {
          name = "Mission Unit Export (Commands)",
          type = 'button',
          action = 'mission_unit_commands_export',
          OnChange = ExportUnitsAndCommandsForMission,
      },
      missionexportselectedcommands = {
          name = "Mission Unit Export (Selected and Commands)",
          type = 'button',
          action = 'mission_unit_commands_export',
          OnChange = ExportSelectedUnitsAndCommandsForMission,
      },
      missionexportfeatures = {
          name = "Mission Feature Export",
          type = 'button',
          action = 'mission_features_export',
          OnChange = ExportFeaturesForMission,
      },
      moveUnit = {
          name = "Move Unit",
          desc = "Move selected unit to the mouse cursor.",
          type = 'button',
          action = 'debug_move_unit',
          OnChange = MoveUnit,
      },
      moveUnitSnap = {
          name = "Move Unit Snap",
          desc = "Move selected unit to the mouse cursor. Snaps to grid.",
          type = 'button',
          action = 'debug_move_unit_snap',
          OnChange = MoveUnitSnap,
      },
      moveUnitDelay = {
          name = "Move Unit Repeat Time",
          type = "number",
          value = 0.1, min = 0.01, max = 0.4, step = 0.01,
      },
      destroyUnit = {
          name = "Destroy Units",
          desc = "Destroy selected units (gentle).",
          type = 'button',
          action = 'debug_destroy_unit',
          OnChange = DestroyUnit,
      },
      RotateUnitLeft = {
          name = "Rotate Unit Anticlockwise",
          type = 'button',
          action = 'debug_rotate_unit_anticlockwise',
          OnChange = RotateUnitLeft,
      },
      RotateUnitRight = {
          name = "Rotate Unit Clockwise",
          type = 'button',
          action = 'debug_rotate_unit_clockwise',
          OnChange = RotateUnitRight,
      },
  }

  function widget:Initialize()
    widgetHandler:AddAction("ExportUnitsForMission", ExportUnitsForMission, nil, 'p')
  end

  function widget:TextCommand(command) -- this one registers the TextCommand callin, all widgets get this called on any /luaui command, so choose your string name wisely
    if string.find(command, "ExportUnitsForMission", nil, true) or string.find(command, "ExportFeaturesForMission", nil, true)== 1 then -- look for whatever you want in the command string
        ExportUnitsForMission(true, true) -- execute what you want // true true give ud, team, pos, facing, commandname and cmd pos if apply//
        ExportFeaturesForMission() -- get feature name, pos, facing
    end
end