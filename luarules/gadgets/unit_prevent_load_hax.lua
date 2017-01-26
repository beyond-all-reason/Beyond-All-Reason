--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Prevent Load Hax",
    desc      = "Prevent Load Hax",
    author    = "TheFatController",
    date      = "Jul 20, 2009",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local GiveOrderToUnit = Spring.GiveOrderToUnit
local GetUnitPosition = Spring.GetUnitPosition
local GetUnitSeparation = Spring.GetUnitSeparation
local GetGameFrame = Spring.GetGameFrame
local GetCommandQueue = Spring.GetCommandQueue
local GetUnitTeam = Spring.GetUnitTeam
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_INSERT = CMD.INSERT
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local watchList = {}

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, synced)
  if synced then return true end
  if (cmdID == CMD_INSERT) then
     if watchList[unitID] then
       return false
     end
     if (CMD_LOAD_UNITS == cmdParams[2]) then
       return gadget:AllowCommand(unitID, unitDefID, teamID, CMD_LOAD_UNITS, {cmdParams[4], cmdParams[5], cmdParams[6], cmdParams[7]}, cmdOptions, "nr", false)
     end
     local cQueue = GetCommandQueue(unitID,20)
     if (#cQueue > 0) then
       for _,command in ipairs(cQueue) do
         if (command.id == CMD_LOAD_UNITS) and (#command.params == 1) then
           watchList[unitID] = GetGameFrame() + 30
           return false
         end
       end
     end
  elseif (cmdID == CMD_REMOVE) then
     if watchList[unitID] then
       return false
     end
     local cQueue = GetCommandQueue(unitID,20)
     if (#cQueue > 0) then
       for _,command in ipairs(cQueue) do
         if (command.id == CMD_LOAD_UNITS) and (#command.params == 1) then
           watchList[unitID] = GetGameFrame() + 30
           return false
         end
       end
     end    
  elseif (cmdID == CMD_LOAD_UNITS) then
     if cmdParams[4] then
       local tx,ty,tz = GetUnitPosition(unitID)
       local dist = math.sqrt(((cmdParams[1]-tx)*(cmdParams[1]-tx))+((cmdParams[3]-tz)*(cmdParams[3]-tz)))
       if (dist < math.max(100,cmdParams[4])) then
         local angle = (math.random()*6.28)-3.14
         GiveOrderToUnit(unitID, CMD_MOVE, {cmdParams[1] + (math.sin(angle) * 120),ty, cmdParams[3] + (math.cos(angle) * 120)}, cmdOptions.coded)
         GiveOrderToUnit(unitID, CMD_LOAD_UNITS, cmdParams, {"shift"})
         watchList[unitID] = GetGameFrame() + 45
         return false
       else
         return true
       end
     else
       local dist = GetUnitSeparation(unitID, cmdParams[1])
       if (not dist) then return false end
       if ((dist < 80) and (GetUnitTeam(unitID) ~= GetUnitTeam(cmdParams[1]))) then	
         local tx,ty,tz = GetUnitPosition(unitID)
         local ux,_,uz = GetUnitPosition(cmdParams[1])
         local angle = math.atan2((tx-ux),(tz-uz))
         if (cmdTag ~= "nr") then
           GiveOrderToUnit(unitID, CMD_MOVE, {ux + (math.sin(angle) * 100),ty, uz + (math.cos(angle) * 100)}, cmdOptions.coded)
           GiveOrderToUnit(unitID, CMD_LOAD_UNITS, cmdParams, {"shift"})
           watchList[unitID] = GetGameFrame() + 45
         end
         return false
       else
         return true
       end
     end    
  end
  return true
end

function gadget:GameFrame(n)
  for unitID,t in pairs(watchList) do
    if (n > t) then
      watchList[unitID] = nil
    end
  end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------