--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_stockpile.lua
--  brief:   adds 100 builds to all new units that can stockpile
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Stockpiler",
    desc      = "Automatically adds 100 stockpile builds to new units",
    author    = "trepan",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
  if ((ud ~= nil) and (unitTeam == Spring.GetMyTeamID())) then
    if (ud.canStockpile) then
      -- give stockpilers 100 units to build
      Spring.GiveOrderToUnit(unitID, CMD.STOCKPILE, {}, { "ctrl", "shift" })
    end
  end
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
