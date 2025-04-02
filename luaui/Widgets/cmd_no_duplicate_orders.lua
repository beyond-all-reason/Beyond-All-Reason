--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    cmd_no_duplicate_orders.lua
--  brief:   Blocks duplicate Attack and Repair/Build orders
--  author:  Owen Martindell
--
--  Copyright (C) 2008.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "NoDuplicateOrders",
    desc      = "Blocks duplicate Attack and Repair/Build orders 1.1b",
    author    = "TheFatController",
    date      = "16 April, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetSelectedUnits        = Spring.GetSelectedUnits
local GetUnitCommands         = Spring.GetUnitCommands
local GetUnitCurrentCommand   = Spring.GetUnitCurrentCommand
local GetUnitPosition         = Spring.GetUnitPosition
local GiveOrderToUnit         = Spring.GiveOrderToUnit
local GetUnitIsBeingBuilt     = Spring.GetUnitIsBeingBuilt

local buildList = {}

function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() then
    widgetHandler:RemoveWidget()
  end
end

function widget:Initialize()
  if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
    widget:PlayerChanged()
  end
  for _,unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
    if GetUnitIsBeingBuilt(unitID) then widget:UnitCreated(unitID) end
  end
end

function widget:GameStart()
    widget:PlayerChanged()
end

local function toLocString(posX,posY,posZ)
  return (math.ceil(posX - 0.5) .. "_" .. math.ceil(posZ - 0.5))
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local locString = toLocString(GetUnitPosition(unitID))
  buildList[locString] = unitID
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  local locString = toLocString(GetUnitPosition(unitID))
  buildList[locString] = nil
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
  local locString = toLocString(GetUnitPosition(unitID))
  buildList[locString] = nil
end

function widget:CommandNotify(id, params, options)
  if (options.coded == 16) then
    if (id == CMD.REPAIR) then
      local selUnits = GetSelectedUnits()
      local blockUnits = {}
      for i=1,#selUnits do
        local unitID = selUnits[i]
        local cmdID, _, _, cmdParam1, _, cmdParam3 = GetUnitCurrentCommand(unitID)
        if cmdID then
          if cmdID < 0 and (params[1] == buildList[toLocString(cmdParam1, 0, cmdParam3)]) then
            blockUnits[unitID] = true
          elseif (cmdID == CMD.REPAIR) and (params[1] == cmdParam1) then
            blockUnits[unitID] = true
          end
        end
      end
      if next(blockUnits) then
        for i=1,#selUnits do
          local unitID = selUnits[i]
          if not blockUnits[unitID] then
            GiveOrderToUnit(unitID, id, params, options)
          else
            local cQueue = GetUnitCommands(unitID,50) or {}
            for i=1,#cQueue do
              local v = cQueue[i]
              if (v.tag ~= cQueue[1].tag) then
                GiveOrderToUnit(unitID,v.id,v.params,{"shift"})
              end
            end
          end
        end
        return true
      else
        return false
      end
    elseif (id == CMD.ATTACK) then
      local selUnits = GetSelectedUnits()
      local blockUnits = {}
      for i=1,#selUnits do
        local unitID = selUnits[i]
        local cQueue = GetUnitCommands(unitID,50) or {}
        if (#cQueue > 0) and (params[1] == cQueue[1].params[1]) then
          blockUnits[unitID] = true
        end
      end
      if next(blockUnits) then
        for i=1,#selUnits do
          local unitID = selUnits[i]
          if not blockUnits[unitID] then
            GiveOrderToUnit(unitID, id, params, options)
          else
            local cQueue = GetUnitCommands(unitID,50) or {}
            for i=1,#cQueue do
              local v = cQueue[i]
              if (v.tag ~= cQueue[1].tag) then
                GiveOrderToUnit(unitID,v.id,v.params,{"shift"})
              end
            end
          end
        end
        return true
      else
        return false
      end  
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
