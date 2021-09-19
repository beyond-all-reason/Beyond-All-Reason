--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    debug.lua
--  brief:   printing routines to debug Spring call-out results
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function PrintInCommand()
  local cmdIndex, cmdId, cmdType, name = Spring.GetActiveCommand()
  print("InCommand: ", cmdIndex, cmdId, cmdType, name)
end


function PrintBuildQueue(unitID)
  local queue, count = Spring.GetRealBuildQueue(unitID)
  print("BuildQueue(" .. unitID .."): " .. count)
  for i,v in pairs(queue) do
    for i2,v2 in pairs(v) do
      print('  ' .. i .. ': ' .. i2 .. '  x' .. v2)
    end
  end
end


function PrintSelection()
  local udTable       = Spring.GetSelectedUnitsSorted()
  local selectedGroup = Spring.GetSelectedGroup()
  print("Selected Group = " .. selectedGroup)
  print("Selected: " .. udTable.n .. " types")
  udTable.n = nil
  for udid,uTable in pairs(udTable) do
     print('  ' .. udid .. '=' .. UnitDefs[udid].name .. ' count ' .. uTable.n)
    uTable.n = nil
    for _,uid in ipairs(uTable) do
      local health, maxHealth, paralyze, capture, build = Spring.GetUnitHealth(uid)
      print('  ', uid, health, maxHealth, paralyze, capture, build)
      PrintCommandQueue(uid)
    end
  end
  for udid,uTable in pairs(udTable) do
    uTable.n = nil
    for uid,udid2 in pairs(uTable) do
      PrintBuildQueue(uid)
    end
  end
end


function PrintCommandQueue(uid)
  local queue = Spring.GetCommandQueue(uid, -1)
  if (queue ~= nil) then
    local msg = ''
    local count = 0
    for i,cmd in pairs(queue) do
      local name = CommandNames[cmd]
      if (name ~= nil) then
        count = count + 1
        msg = msg .. '  ' .. CommandNames[cmd] .. ','
        if (count >= 8) then
          break
        end
      end
    end
    print('', 'commands: ' .. msg)
  end
end


function PrintGroups()
  local groupList, count = Spring.GetGroupList()
  print("GetGroupList: " .. tostring(count))
  for i, v in pairs(groupList) do
    local groupName = Spring.GetGroupAIName(i)
    if (groupName == nil) then groupName = "" end
    print('  ' .. i .. '\t' .. v .. '\t' .. groupName)
  end

  for g, c in pairs(groupList) do
    print("Units in Group " .. g)
    local udTable = Spring.GetGroupUnitsSorted(g)
    print("  MyTeamUnits: " .. udTable.n .. " types")
    udTable.n = nil
    for udid,uTable in pairs(udTable) do
       print('    ' .. udid .. '=' .. UnitDefs[udid].name .. ' count ' .. uTable.n)
      uTable.n = nil
      for _,uid in ipairs(uTable) do
        print('    ', uid)
      end
    end
  end
end


function PrintTeamUnits(team)
  udTable = Spring.GetTeamUnitsSorted(team)
--  print("TeamUnits(" .. team .. "): " .. udTable.n .. " types")
--  udTable.n = nil
  if (udTable == nil) then
    return
  end
  udTable.n = nil
  for udid,uTable in pairs(udTable) do
    print('  ' .. udid .. '=' .. UnitDefs[udid].name .. ' count ' .. uTable.n)
    uTable.n = nil
    for _,uid in ipairs(uTable) do
      print('  ', uid)
    end
  end
end


function PrintTeamUnitsCounts(team)
  print("Team Units Count:" .. team)
  local countTable = Spring.GetTeamUnitsCounts(team)
  if (countTable == nil) then
    return
  end
  countTable.n = nil
  for udid,count in pairs(countTable) do
    print('  ' .. udid .. '=' .. UnitDefs[udid].name .. ': ' .. count)
  end
end


function PrintAlliedUnits()
  local teamTable = Spring.GetTeamList(Spring.GetMyAllyTeamID())
--  print("AlliedUnits: " .. teamTable.n .. " teams")
  teamTable.n = nil
  for n,tid in pairs(teamTable) do
    PrintTeamUnits(tid);
  end
end


function PrintAllyTeamList()
  local allyTeamTable = Spring.GetAllyTeamList()
  local msg = "AllyTeams(" .. allyTeamTable.n .. ")"
  allyTeamTable.n = nil
  for n,atid in pairs(allyTeamTable) do
    msg = msg .. " " .. atid
  end
  print(msg)
end


function PrintTeamList(allyTeam)
  local teamTable
  if (allyTeam == nil) then
    teamTable = Spring.GetTeamList()
  else
    teamTable = Spring.GetTeamList(allyTeam)
  end
  if (teamTable == nil) then
    return
  end

  local msg = "Teams(" .. teamTable.n .. ")"
  teamTable.n = nil
  for n,tid in pairs(teamTable) do
    msg = msg .. " " .. tid
  end
  print(msg)
end


function PrintPlayerList(team)
  local playerTable
  if (team == nil) then
    playerTable = Spring.GetTeamList()
  else
    playerTable = Spring.GetTeamList(team)
  end
  if (playerTable == nil) then
    return
  end

  local msg = "Players(" .. playerTable.n .. ")"
  playerTable.n = nil
  for n,pid in pairs(playerTable) do
    msg = msg .. " " .. pid
  end
  print(msg)
end


function PrintPlayerTree()
  local atTable = Spring.GetAllyTeamList()
  for atn,atid in ipairs(atTable) do
    print('Ally team: ' .. atid)
    local tTable = Spring.GetTeamList(atid)
    for tn,tid in ipairs(tTable) do
      print('  Team: ' .. tid)
      local pTable = Spring.GetPlayerList(tid)
      for pn,pid in ipairs(pTable) do
        local pname, active = Spring.GetPlayerInfo(pid)
        if (active) then
          print('    Player: ' .. pid .. " " .. pname)
        end
      end
    end
  end
end


function PrintTeamInfo(teamID)
  local num, leader, dead, isAI, side, allyTeam = Spring.GetTeamInfo(teamID)
  print('Team number: ' .. num)
  print('     leader: ' .. leader)
  print('       dead: ' .. tostring(dead))
  print('       isAI: ' .. tostring(isAI))
  print('       side: ' .. side)
  print('   allyTeam: ' .. allyTeam)
end


function PrintTeamResources(teamID, type)
  local current, storage, pull, income, expense,
    share, sent, received = Spring.GetTeamResources(teamID, type)
  if (current ~= nil) then
    print('Team number: ' .. teamID)
    print('  ' .. type .. ':           ' .. current)
    print('  ' .. type .. ' storage:   ' .. storage)
    print('  ' .. type .. ' pull:      ' .. pull)
    print('  ' .. type .. ' income:    ' .. income)
    print('  ' .. type .. ' expense:   ' .. expense)
    print('  ' .. type .. ' share:     ' .. share)
    print('  ' .. type .. ' sent:      ' .. sent)
    print('  ' .. type .. ' received:  ' .. received)
  end
end


function PrintTeamUnitStats(teamID)
  local kills, deaths, caps, losses, recv, sent = Spring.GetTeamUnitStats(teamID)
  if (kills ~= nil) then
    print('Team number: ' .. teamID)
    print('  kills:  ' .. kills)
    print('  deaths: ' .. deaths)
    print('  caps:   ' .. caps)
    print('  losses: ' .. losses)
    print('  recv:   ' .. recv)
    print('  sent:   ' .. sent)
  end
end


function PrintPlayerInfo(playerID)
  local name, active, spectator, team, allyteam, ping, cpuUsage = 
    Spring.GetPlayerInfo(playerID)
  print('   name:     '..name)
  print('   id:       '..playerID)
  print('   active:   '..tostring(active))
  print('   spectator '..tostring(spectator))
  print('   team:     '..team)
  print('   allyteam: '..allyteam)
  print('   ping:     '..ping)
  print('   cpu:      '..(100*cpuUsage)..'%')
end


function PrintCommands(commands)
  for i, v in pairs(commands) do
    if (type(v) == "table") then
      local txt = ""
      for i2, v2 in pairs(v) do
        txt = txt .. '"' .. i2 .. '"' .. ' = '
        if (type(v2) ~= "table") then
          txt = txt .. tostring(v2) .. ', '
        else
          txt = txt .. '{ '
          for i3,v3 in pairs(v2) do
            txt = txt .. '"' .. v3 .. '", '
          end
          txt = txt .. '}, '
        end
      end
      print(txt)
    else
      print(i, v)
    end
  end
end


function Debug()
  for i,v in pairs(UnitDefs) do
    if (v ~= nil) then
      print(i ..' '.. v.name)
    end
  end
  for i,v in pairs(WeaponDefs) do
    if (v ~= nil) then
      print(i ..' '.. v.name)
    end
  end

  print("Game.version               = " .. Engine.version)
  print("Game.commEnds              = " .. tostring(Game.commEnds))
  print("Game.gravity               = " .. Game.gravity)
  print("Game.tidal                 = " .. Game.tidal)
  print("Game.windMin               = " .. Game.windMin)
  print("Game.windMax               = " .. Game.windMax)
  print("Game.mapX                  = " .. Game.mapX)
  print("Game.mapY                  = " .. Game.mapY)
  print("Game.mapSizeX              = " .. Game.mapSizeX)
  print("Game.mapSizeZ              = " .. Game.mapSizeZ)
  print("Game.mapName               = " .. Game.mapName)
  print("Game.modName               = " .. Game.modName)
  print("Game.limitDGun             = " .. tostring(Game.limitDGun))
  print("Game.Game.diminishingMetal = " .. tostring(Game.diminishingMetal))

  PrintAllyTeamList()
  PrintTeamList()
  PrintPlayerList()

  PrintPlayerTree()

  PrintAlliedUnits()
  
  PrintSelection()
  PrintGroups()
  PrintInCommand()
  print("UserName = "        .. Spring.GetConfigString("name", ""))
  print("Shadows = "         .. Spring.GetConfigString("Shadows", 0))
  print("ReflectiveWater = " .. Spring.GetConfigString("ReflectiveWater", 1))

  PrintTeamUnits(Spring.GetMyTeamID())

  print("My Player Info:")
  local myPlayerID = Spring.GetMyPlayerID()
  PrintPlayerInfo(myPlayerID)
  
  PrintTeamUnitsCounts(Spring.GetMyTeamID())
end


