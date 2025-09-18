--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gadget = gadget ---@type Gadget

function gadget:GetInfo()
    return {
        name      = "Prevent Load Hax",
        desc      = "Prevent instantly loading units by adding buffer commands",
        author    = "TheFatController",
        date      = "Jul 20, 2009",
        license   = "GNU GPL, v2 or later",
        layer     = 0,
        enabled   = true
    }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (not gadgetHandler:IsSyncedCode()) then
  return false
end

local GetUnitPosition = Spring.GetUnitPosition
local GetUnitSeparation = Spring.GetUnitSeparation
local GetGameFrame = Spring.GetGameFrame
local GetUnitCommands = Spring.GetUnitCommands
local GetUnitTeam = Spring.GetUnitTeam
local GiveOrInsertOrder = Game.CustomCommands.ReissueOrder
local CMD_LOAD_UNITS = CMD.LOAD_UNITS
local CMD_MOVE = CMD.MOVE
local CMD_REMOVE = CMD.REMOVE

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local watchList = {}

function gadget:Initialize()
	gadgetHandler:RegisterAllowCommand(CMD_REMOVE)
	gadgetHandler:RegisterAllowCommand(CMD_LOAD_UNITS)
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
  if fromSynced then
     return true
  end

  if (cmdID == CMD_REMOVE) then
     if watchList[unitID] then
       return false
     end
     local cQueue = GetUnitCommands(unitID,20)
     if (#cQueue > 0) then
       for i=1,#cQueue do
         local command = cQueue[i]
         if (command.id == CMD_LOAD_UNITS) and (#command.params == 1) then
           watchList[unitID] = GetGameFrame() + 30
           return false
         end
       end
     end
  elseif (cmdID == CMD_LOAD_UNITS) then
     if cmdParams[4] then
       local tx,ty,tz = GetUnitPosition(unitID)
       if (math.diag(cmdParams[1]-tx, cmdParams[3]-tz) < math.max(100, cmdParams[4])) then
         local angle = math.random() * math.tau
         local movePosition = { cmdParams[1] + (math.sin(angle) * 120), ty, cmdParams[3] + (math.cos(angle) * 120) }
         GiveOrInsertOrder(unitID, CMD_MOVE, movePosition, cmdOptions, cmdTag, fromInsert)
         if not fromInsert then
            cmdOptions.shift = true
         end
         GiveOrInsertOrder(unitID, CMD_LOAD_UNITS, cmdParams, cmdOptions, cmdTag, fromInsert)
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
         local movePosition = { ux + (math.sin(angle) * 100), ty, uz + (math.cos(angle) * 100) }
         GiveOrInsertOrder(unitID, CMD_MOVE, movePosition, cmdOptions, cmdTag, fromInsert)
         if not fromInsert then
            cmdOptions.shift = true
         end
         GiveOrInsertOrder(unitID, CMD_LOAD_UNITS, cmdParams, cmdOptions, cmdTag, fromInsert)
         watchList[unitID] = GetGameFrame() + 45
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
