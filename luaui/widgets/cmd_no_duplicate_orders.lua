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

function widget:GetInfo()
  return {
    name      = "NoDuplicateOrders",
    desc      = "Blocks duplicate Attack and Repair/Build orders 1.1b",
    author    = "TheFatController",
    date      = "16 April, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local GetSelectedUnits = Spring.GetSelectedUnits
local GetCommandQueue  = Spring.GetCommandQueue
local GetUnitPosition  = Spring.GetUnitPosition
local GiveOrderToUnit  = Spring.GiveOrderToUnit
local GetUnitHealth    = Spring.GetUnitHealth

local buildList = {}

function widget:Initialize()
  if Spring.GetSpectatingState() or Spring.IsReplay() then widgetHandler:RemoveWidget() end
  for _,unitID in ipairs(Spring.GetTeamUnits(Spring.GetMyTeamID())) do
    local _, _, _, _, buildProgress = GetUnitHealth(unitID)
    if (buildProgress < 1) then widget:UnitCreated(unitID) end    
  end
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

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  local locString = toLocString(GetUnitPosition(unitID))
  buildList[locString] = nil
end

function widget:CommandNotify(id, params, options)
  if (options.coded == 16) then
    if (id == CMD.REPAIR) then
      local selUnits = GetSelectedUnits()
      local blockUnits = {}
      for _,unitID in ipairs(selUnits) do
        local cQueue = GetCommandQueue(unitID, 1)
        if (#cQueue > 0) then
          if (cQueue[1].id < 0) and (params[1] == buildList[toLocString(cQueue[1].params[1], 0, cQueue[1].params[3])]) then
            blockUnits[unitID] = true
          elseif (cQueue[1].id == CMD.REPAIR) and (params[1] == cQueue[1].params[1]) then
            blockUnits[unitID] = true
          end
        end
      end
      if next(blockUnits) then
        for _,unitID in ipairs(selUnits) do
          if not blockUnits[unitID] then
            GiveOrderToUnit(unitID, id, params, options)
          else
            local cQueue = GetCommandQueue(unitID)
            for _,v in ipairs(cQueue) do
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
      for _,unitID in ipairs(selUnits) do
        local cQueue = GetCommandQueue(unitID)
        if (#cQueue > 0) and (params[1] == cQueue[1].params[1]) then
          blockUnits[unitID] = true
        end
      end
      if next(blockUnits) then
        for _,unitID in ipairs(selUnits) do
          if not blockUnits[unitID] then
            GiveOrderToUnit(unitID, id, params, options)
          else
            local cQueue = GetCommandQueue(unitID)
            for _,v in ipairs(cQueue) do
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
