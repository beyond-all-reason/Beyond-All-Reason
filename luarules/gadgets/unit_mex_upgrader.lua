function gadget:GetInfo() 
  return { 
    name      = "Mex Upgrader Gadget", 
    desc      = "Upgrades mexes.", 
    author    = "author: BigHead, modified by DeadnightWarrior",
    date      = "September 13, 2007", 
    license   = "GNU GPL, v2 or later", 
    layer     = 100, 
    enabled   = true -- loaded by default? 
  } 
end 

local ignoreWeapons = false --if the only weapon is a shield it is ignored
local ignoreStealth = false 

local insert = table.insert 
local remove = table.remove 

local GetTeamUnits = Spring.GetTeamUnits 
local GetUnitDefID = Spring.GetUnitDefID 
local GiveOrderToUnit = Spring.GiveOrderToUnit 
local GetUnitPosition = Spring.GetUnitPosition 
local GetUnitHealth = Spring.GetUnitHealth 
local GetGroundHeight = Spring.GetGroundHeight 
local GetUnitTeam = Spring.GetUnitTeam 
local GetCommandQueue = Spring.GetCommandQueue 
local Echo = Spring.Echo 
local FindUnitCmdDesc = Spring.FindUnitCmdDesc 
local InsertUnitCmdDesc = Spring.InsertUnitCmdDesc 
local EditUnitCmdDesc = Spring.EditUnitCmdDesc
local SendMessageToTeam = Spring.SendMessageToTeam

local builderDefs = {} 
local mexDefs = {} 

local mexes = {} 
local builders = {} 

local IDLE = 0 
local FOLOWING_ORDERS = 1 
local RECLAIMING = 2 
local BUILDING = 3 

local scheduledBuilders = {} 
local addFakeReclaim = {} 
local addCommands = {} 

local CMD_RECLAIM = CMD.RECLAIM 
local CMD_STOP = CMD.STOP 
local CMD_INSERT = CMD.INSERT 
local CMD_OPT_INTERNAL = CMD.OPT_INTERNAL 

local CMD_AUTOMEX = 31143 

local CMD_UPGRADEMEX = 31244 

local ONTooltip = "Metal makers are upgraded automatically\nby this builder." 
local OFFTooltip = "Metal makers are NOT upgraded automatically\nby this builder." 

local autoMexCmdDesc = { 
  id      = CMD_AUTOMEX, 
  type    = CMDTYPE.ICON_MODE, 
  name    = 'Automatic Mex Upgrade', 
  cursor  = 'AutoMex', 
  action  = 'automex', 
  tooltip = ONTooltip, 
  params  = { '0', 'UpgMex OFF', 'UpgMex ON'} 
} 

local upgradeMexCmdDesc = { 
  id      = CMD_UPGRADEMEX, 
  type    = CMDTYPE.ICON_UNIT_OR_AREA, 
  name    = 'Upgrade Mex', 
  cursor  = 'Attack', 
  action  = 'upgrademex', 
  tooltip = 'Upgrade Mex', 
  hidden  = false, 
  params  = {} 
} 


if (gadgetHandler:IsSyncedCode()) then 

-- This part of the code determines who should upgrade what 
--------------------------------------------------------------------------------------------------------------------------- 
function gadget:Initialize()  
  determine() 
  registerUnits()  
end 

function determine() 
  local tmpbuilders = {} 
  for unitDefID, unitDef in pairs(UnitDefs) do 
    if isBuilder(unitDef) then 
      insert(tmpbuilders, unitDefID) 
    else 
      local extractsMetal = unitDef.extractsMetal 
      if (extractsMetal > 0) then 
        local mexDef = {} 
        mexDef.extractsMetal = extractsMetal 
        if #unitDef.weapons <= 1 then
          if (#unitDef.weapons == 1 and WeaponDefs[unitDef.weapons[1].weaponDef].isShield) then
	    mexDef.armed = #unitDef.weapons < 0
          else
            mexDef.armed = #unitDef.weapons > 0      
          end
        else	
          mexDef.armed = #unitDef.weapons > 0
	end	
        mexDef.stealth = unitDef.stealth 
        mexDef.water = unitDef.minWaterDepth >= 0        
        mexDefs[unitDefID] = mexDef 
      end 
    end 
  end 
      
  for _, unitDefID in ipairs(tmpbuilders) do 
    local upgradePairs = nil 
    for _, optionID in ipairs(UnitDefs[unitDefID].buildOptions) do 
      local mexDef = mexDefs[optionID] 
      if mexDef then 
        upgradePairs = processMexData(optionID, mexDef, upgradePairs)        
      end 
    end 
    if upgradePairs then 
    
      builderDefs[unitDefID] = upgradePairs 
    end 
  end 
  
  _G.builderDefs = builderDefs 
end 

function processMexData(mexDefID, mexDef, upgradePairs)  
  for defID, def in pairs(mexDefs) do 
    if (mexDef.water == def.water) and (ignoreStealth or mexDef.stealth == def.stealth) and (ignoreWeapons or mexDef.armed == def.armed) then      
    
      if mexDef.extractsMetal > def.extractsMetal then 
        if not upgradePairs then 
          upgradePairs = {} 
        end 
        local upgrader = upgradePairs[defID] 
        if not upgrader or mexDef.extractsMetal > mexDefs[upgrader].extractsMetal then                
          upgradePairs[defID] = mexDefID 
        end 
      end      
    end        
  end 
  
  return upgradePairs 
end 

function isBuilder(unitDef) 
  return (unitDef.isBuilder and unitDef.canAssist) 
end 

function registerUnits() 
  local teams = Spring.GetTeamList() 
  for _, teamID in ipairs(teams) do 
    builders[teamID] = {} 
    mexes[teamID] = {} 
    for _, unitID in ipairs(GetTeamUnits(teamID)) do 
      local unitDefID = GetUnitDefID(unitID) 
      registerUnit(unitID, unitDefID, teamID)    
    end 
  end 
end 

-- This part of the code actually does somethings (upgrades mexes) 
--------------------------------------------------------------------------------------------------------------------------- 
function gadget:GameFrame(n)  

  for unitID, data in pairs(addCommands) do 
    GiveOrderToUnit(unitID, data.cmd, data.params, data.options) 
  end 
  addCommands = {} 

  for unitID, data in pairs(scheduledBuilders) do 
    local teamID = GetUnitTeam(unitID) 
    if builders[teamID] then
      local builder = builders[teamID][unitID] 
      local y = GetGroundHeight(builder.targetX, builder.targetZ) 

      GiveOrderToUnit(unitID, CMD_INSERT, {0, CMD_RECLAIM, CMD_OPT_INTERNAL, data}, {"alt"});    
      GiveOrderToUnit(unitID, CMD_INSERT, {1,-builder.targetUpgrade,CMD_OPT_INTERNAL,builder.targetX, y, builder.targetZ, 0}, {"alt"});    
    
    
      builder.orderTaken = true 
    end
  end 
  scheduledBuilders = {} 

  for unitID, _ in pairs(addFakeReclaim) do 
    local commands = GetCommandQueue(unitID) 
    for i, cmd in ipairs(commands) do 
      if cmd.id == CMD_UPGRADEMEX and not (commands[i+1] and commands[i+1].id == CMD_RECLAIM) then 
        GiveOrderToUnit(unitID, CMD_INSERT, {i, CMD_RECLAIM, CMD_OPT_INTERNAL+1, cmd.params[1]}, {"alt"}) 
      end 
    end 

  end 
  addFakeReclaim = {} 
  
  gadgetHandler:RemoveCallIn("GameFrame") 
end 


function autoUpgradeDisabled(unitID, teamID) 
  local builder = builders[teamID][unitID] 
  builder.autoUpgrade = false 
  if getUnitPhase(unitID, teamID) == RECLAIMING then 
    mexes[teamID][builder.targetMex].assignedBuilder = nil 
    GiveOrderToUnit(unitID, CMD_STOP, {}, {""}) 
  end 
end 

function autoUpgradeEnabled(unitID, teamID) 
  local builder = builders[teamID][unitID] 
  builder.autoUpgrade = true 
  local phase = getUnitPhase(unitID, teamID) 
  if phase ~= BUILDING then      
    local upgradePairs = builderDefs[builder.unitDefID] 
    if getClosestMex(unitID, upgradePairs, teamID) then 
      upgradeClosestMex(unitID, teamID) 
    end 
  end 
end 

function upgradeClosestMex(unitID, teamID, mexesInRange) 
  local builder = builders[teamID][unitID] 
  local upgradePairs = builderDefs[builder.unitDefID] 
  
  local mexID = getClosestMex(unitID, upgradePairs, teamID, mexesInRange) 

  if not mexID then 
    SendMessageToTeam(teamID, builder.humanName .. ": No mexes to upgrade")
    return false 
  end 
    
  orderBuilder(unitID, mexID) 
  return true 
end 

function orderBuilder(unitID, mexID) 
  --GiveOrderToUnit(unitID, CMD_UPGRADEMEX, {mexID}, {""}); 
  --addCommands[unitID] = {cmd = CMD_UPGRADEMEX, params = {mexID}, options = {""}} 
  addCommands[unitID] = {cmd = CMD_INSERT, params = {1, CMD_UPGRADEMEX, CMD_OPT_INTERNAL, mexID}, options = {"alt"}}      
  
  gadgetHandler:UpdateCallIn("GameFrame") 
end 

function upgradeMex(unitID, mexID, teamID) 
  local builder = builders[teamID][unitID] 
  local mex = mexes[teamID][mexID] 
  if not mex then 
    return 
  end 
  local upgradePairs = builderDefs[builder.unitDefID] 
  
  builder.targetMex = mexID 
  builder.targetUpgrade = upgradePairs[mex.unitDefID] 
  builder.targetX = mex.x 
  builder.targetY = mex.y 
  builder.targetZ = mex.z 
  
  mex.assignedBuilder = unitID 
  
  gadgetHandler:UpdateCallIn("GameFrame") 
  scheduledBuilders[unitID] = mexID 
end 

function getClosestMex(unitID, upgradePairs, teamID, mexesInRange) 
  local bestDistance = nil 
  local bestMexID, bestMexDefID = nil, nil 
  
  if not mexesInRange then 
    mexesInRange = mexes[teamID] 
  end 
  
  for mexID, mex in pairs(mexesInRange) do 
    if not mex.assignedBuilder then 
      local mexDefID = mex.unitDefID 
      local upgradeTo = upgradePairs[mexDefID] 
      if upgradeTo then 
        local dist = getDistance(unitID, mexID, teamID) 
        if not bestDistance or dist < bestDistance then 
          bestDistance = dist 
          bestMexID, bestMexDefID = mexID, mexDefID 
        end 
      end 
    end 
  end 
  
  return bestMexID, bestMexDefID 
end 

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam) 
  unregisterUnit(unitID, unitDefID, unitTeam, true) 
end 

function gadget:UnitIdle(unitID, unitDefID, unitTeam) 
  local builder = builders[unitTeam][unitID] 
  if builder then 
  
    if builder.autoUpgrade then    
      upgradeClosestMex(unitID, unitTeam) 
    end 
  end 
end 

function gadget:UnitTaken(unitID, unitDefID, unitTeam, newTeam) 
  unregisterUnit(unitID, unitDefID, unitTeam, false) 
end 

function unregisterUnit(unitID, unitDefID, unitTeam, destroyed) 
  local mex = mexes[unitTeam][unitID] 
  local builder = builders[unitTeam][unitID] 
  
  if mex then 
    local builderID = mex.assignedBuilder 
    if builderID then 
      builder = builders[unitTeam][builderID] 
      if not (destroyed and getDistance(builderID, unitID, unitTeam) < builder.buildDistance * 2) then        
        upgradeClosestMex(builderID, unitTeam) 
      end 
    end 
    
    mexes[unitTeam][unitID] = nil 
  elseif builder then 
    if getUnitPhase(unitID, unitTeam) == RECLAIMING then 
      local mex = mexes[unitTeam][builder.targetMex] 
      if mexes[unitTeam][builder.targetMex] then
        mexes[unitTeam][builder.targetMex].assignedBuilder = nil
      end
      if mex then
		assignClosestBuilder(builder.targetMex, mex, unitTeam) 
	  end
    end 
    
    builders[unitTeam][unitID] = nil 
  end 
end 

function registerUnit(unitID, unitDefID, unitTeam) 
  if builderDefs[unitDefID] then 
    local builder = {} 
    local unitDef = UnitDefs[unitDefID] 
  
    builder.unitDefID = unitDefID    
    builder.autoUpgrade = false 
    builder.buildDistance = unitDef.buildDistance 
    builder.humanName = unitDef.humanName 
    builder.teamID = unitTeam 
    builders[unitTeam][unitID] = builder 
    
    addLayoutCommands(unitID) 
    
  elseif mexDefs[unitDefID] then 
    local mex = {} 
    mex.unitDefID = unitDefID 
    mex.teamID = unitTeam 
    mex.x, mex.y, mex.z = GetUnitPosition(unitID) 
    mexes[unitTeam][unitID] = mex 
    assignClosestBuilder(unitID, mex, unitTeam) 
  end 
end 

function assignClosestBuilder(mexID, mex, teamID) 
  local bestDistance = nil 
  local bestBuilder, bestBuilderID = nil 
  local mexDefID = mex.unitDefID 
  
  for unitID, builder in pairs(builders[teamID]) do 
    if builder.autoUpgrade and getUnitPhase(unitID, teamID) == IDLE then 
      local upgradePairs = builderDefs[builder.unitDefID] 
      local upgradeTo = upgradePairs[mexDefID] 
      if upgradeTo then 
        local dist = getDistance(unitID, mexID, teamID) 
        if not bestDistance or dist < bestDistance then 
          bestDistance = dist 
          bestBuilder = builder 
          bestBuilderID = unitID 
        end 
      end 
    end 
  end 
  
  if bestBuilder then 
    orderBuilder(bestBuilderID, mexID) 
  end 
end 

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) 
  registerUnit(unitID, unitDefID, unitTeam) 
end 

function gadget:UnitGiven(unitID, unitDefID, unitTeam, oldTeam) 
  registerUnit(unitID, unitDefID, unitTeam) 
end 

function getDistance(unitID, mexID, teamID) 
  local x1, _, y1 = GetUnitPosition(unitID) 
  local mex = mexes[teamID][mexID] 
  local x2, y2 = mex.x, mex.z 
  return math.sqrt((x1-x2)^2 + (y1-y2)^2) 
end 

function getDistanceFromPosition(x1, y1, mexID, teamID) 
  local mex = mexes[teamID][mexID] 
  local x2, y2 = mex.x, mex.z 
  return math.sqrt((x1-x2)^2 + (y1-y2)^2) 
end 


function getUnitPhase(unitID, teamID) 

  local commands = GetCommandQueue(unitID, 1) 
  if #commands == 0 then 
    return IDLE 
  end 
  local cmd = commands[1] 
  local builder = builders[teamID][unitID] 
  
  if cmd.id == CMD_RECLAIM and cmd.params[1] == builder.targetMex then 
    return RECLAIMING 
    
  elseif builder.targetUpgrade and cmd.id == builder.targetUpgrade then 
    return BUILDING 
  else 
    return FOLLOWING_ORDERS 
  end 
end 

-- Gadget Button 
--------------------------------------------------------------------------------------------------------------------------- 
local ON, OFF = 1, 0 

function addLayoutCommands(unitID) 
  local insertID = 
    FindUnitCmdDesc(unitID, CMD.CLOAK)      or 
    FindUnitCmdDesc(unitID, CMD.ONOFF)      or 
    FindUnitCmdDesc(unitID, CMD.TRAJECTORY) or 
    FindUnitCmdDesc(unitID, CMD.REPEAT)     or 
    FindUnitCmdDesc(unitID, CMD.MOVE_STATE) or 
    FindUnitCmdDesc(unitID, CMD.FIRE_STATE) or 
    123456 -- back of the pack 
    
  autoMexCmdDesc.params[1] = '0' 
  updateCommand(unitID, insertID + 1, autoMexCmdDesc) 
  updateCommand(unitID, insertID + 2, upgradeMexCmdDesc)  
end 

function updateCommand(unitID, insertID, cmd) 
  local cmdDescId = FindUnitCmdDesc(unitID, cmd.id) 
  if not cmdDescId then 
    InsertUnitCmdDesc(unitID, insertID, cmd) 
  else 
    EditUnitCmdDesc(unitID, cmdDescId, cmd) 
  end 
end 

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, _) 
  --Echo("AC " .. cmdID) 
  local builder = builders[teamID][unitID] 
  if cmdID == CMD_UPGRADEMEX then 
  
    if not cmdParams[2] then -- Unit 
      local mex = mexes[teamID][cmdParams[1]]    
      if mex and builder then 
        local upgradePairs = builderDefs[builder.unitDefID] 
        local upgradeTo = upgradePairs[mex.unitDefID] 
        if upgradeTo then      
          addFakeReclaim[unitID] = true; 
          gadgetHandler:UpdateCallIn("GameFrame") 
          return true 
        end 
      end 
    
    -- Circle 
    else 
      return true          
    end 
    
    return false 
  elseif cmdID ~= CMD_AUTOMEX then 
    if builder and getUnitPhase(unitID, teamID) == RECLAIMING then 
      mexes[teamID][builder.targetMex].assignedBuilder = nil 
    end 
    return true 
  end 
  local cmdDescID = FindUnitCmdDesc(unitID, CMD_AUTOMEX) 
  if (cmdDescID == nil) then 
    return 
  end 
  
  local status = cmdParams[1] 
  local tooltip 
  if status == OFF then 
    autoUpgradeDisabled(unitID, teamID) 
    tooltip = OFFTooltip 
    status = OFF 
  else 
    autoUpgradeEnabled(unitID, teamID) 
    tooltip = ONTooltip 
    status = ON 
  end 
  autoMexCmdDesc.params[1] = status 
  EditUnitCmdDesc(unitID, cmdDescID, { 
    params  = autoMexCmdDesc.params, 
    tooltip = tooltip 
  }) 
  
  return false 
end 

function gadget:CommandFallback(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions) 
  --Echo("CF " .. cmdID)  

  if cmdID ~= CMD_UPGRADEMEX then 
    return false 
  end 
  
  local builder = builders[teamID][unitID] 
  if not cmdParams[2] then 
    -- Unit 
    if not builder.orderTaken then 
      local mexID = cmdParams[1] 
      
      upgradeMex(unitID, mexID, teamID) 
      return true, false 
    else 
      builder.orderTaken = false 
      return true, true 
    end 
  
  else 
    --Circle 
    local x, y, z, radius = cmdParams[1], cmdParams[2], cmdParams[3], cmdParams[4] 
    
    local mexesInRange = {} 
    local canUpgrade = false 
    for mexID, mex in pairs(mexes[teamID]) do 
    
      if not mex.assignedBuilder and getDistanceFromPosition(x, z, mexID, teamID) < radius then 
        mexesInRange[mexID] = mexes[teamID][mexID] 
        canUpgrade = true 
      end 
    end 
    if canUpgrade then        
    
      local upgradePairs = builderDefs[builder.unitDefID]  
      local mexID = getClosestMex(unitID, upgradePairs, teamID, mexesInRange) 
      
      if mexID then 
        addCommands[unitID] = {cmd = CMD_INSERT, params = {0, CMD_UPGRADEMEX, CMD_OPT_INTERNAL, mexID}, options = {"alt"}}      
        gadgetHandler:UpdateCallIn("GameFrame") 

        return true, false 
      end    
    end 
    return true, true 
    
  end 
end 

else 

function gadget:Update() 
  if SYNCED.builderDefs and Script.LuaUI.registerUpgradePairs then 
  
    local builderDefs = {} 
    for k,v in spairs(SYNCED.builderDefs) do 
      local upgradePairs = {} 
      for k2,v2 in spairs(v) do 
        upgradePairs[k2] = v2 
      end 
      builderDefs[k] = upgradePairs 
    end 

    if Script.LuaUI.registerUpgradePairs(builderDefs) then 
      gadgetHandler:RemoveCallIn("Update") 
    end 
  end 
end 

end
