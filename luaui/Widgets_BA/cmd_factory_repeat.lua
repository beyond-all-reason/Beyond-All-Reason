--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    cmd_factory_repeat.lua
--  brief:   Sets new factories to Repeat on automatically
--  author:  Owen Martindell
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Factory Auto-Repeat",
    desc      = "Sets new factories to Repeat on automatically",
    author    = "TheFatController",
    date      = "Mar 20, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:PlayerChanged(playerID)
  if Spring.GetGameFrame() > 0 and Spring.GetSpectatingState() then
    widgetHandler:RemoveWidget()
  end
end

function widget:Initialize()
  widget:PlayerChanged()
end

function widget:UnitFinished(unitID, unitDefID, unitTeam)
 local ud = UnitDefs[unitDefID]
 if (ud and ud.isFactory) then
   Spring.GiveOrderToUnit(unitID, CMD.REPEAT, { 1 }, {})
 end
end

--------------------------------------------------------------------------------
