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

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Factory Auto-Repeat",
    desc      = "Sets new factories to Repeat on automatically",
    author    = "TheFatController",
    date      = "Mar 20, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false
  }
end


-- Localized functions for performance

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gameStarted

local isFactory = {}
for udid, ud in pairs(UnitDefs) do
    if ud.isFactory then
        isFactory[udid] = true
    end
end

function maybeRemoveSelf()
    if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
        widgetHandler:RemoveWidget()
    end
end

function widget:GameStart()
    gameStarted = true
    maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
    maybeRemoveSelf()
end

function widget:Initialize()
    if Spring.IsReplay() or spGetGameFrame() > 0 then
        maybeRemoveSelf()
    end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
    if isFactory[unitDefID] then
        Spring.GiveOrderToUnit(unitID, CMD.REPEAT, { 1 }, 0)
    end
end

--------------------------------------------------------------------------------
