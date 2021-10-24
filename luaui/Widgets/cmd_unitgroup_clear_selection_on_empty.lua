--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    cmd_units_holdposition.lua
--  brief:   Sets units to hold position
--  author:  verybadsoldier
--
--  Copyright (C) 2021.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
    return {
      name      = "Unit Groups - Clear selection on empty",
      desc      = "Clears selection when selecting an empty unit group",
      author    = "verybadsoldier",
      date      = "2021-10-10",
      license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true  --  loaded by default
    }
end
  
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spGetGroupUnitsCount = Spring.GetGroupUnitsCount
local spSelectUnitMap      = Spring.SelectUnitMap
----------------------------------------------
------------------------------------------

function widget:Initialize()
  ManageAction(true)
end

function widget:Shutdown()
  ManageAction(false)
end

function ManageAction(doAdd)
  for i=0, 9 do
    actionName = "group" .. i
    if doAdd then
      widgetHandler:AddAction(actionName, OnGroupSelected)
    else
      widgetHandler:RemoveAction(actionName, OnGroupSelected)
    end
  end
end

function OnGroupSelected(cmd)
  group = string.sub(cmd, 6, 6)
  count = spGetGroupUnitsCount(group)
  if count == 0 then
    spSelectUnitMap({}, false)
  end
end