--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    cmd_fac_holdposition.lua
--  brief:   Sets new factories to hold position
--  author:  Masta Ali
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Factory hold position",
    desc      = "Sets new factories, and all units they build, to hold position automatically (except aircraft)",
    author    = "Masta Ali",
    date      = "Mar 20, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitSet = {}

local unitArray_ = {
  "armlab",
  "armalab",
  "armvp",
  "armavp",
  "armsy",
  "armasy",
  "armhp",
  "armfhp",
  "armshltx",
  "armshltxuw",
  "armcom",
  "armamsub",
  "corlab",
  "coralab",
  "corvp",
  "coravp",
  "corsy",
  "corasy",
  "corhp",
  "corfhp",
  "corgant",
  "corgantuw",
  "coramsub",
  "corcom",
  "leglab",
  "legvp",
  "legalab",
}
local unitArray = {}
for _, name in pairs(unitArray_) do
  unitArray[UnitDefNames[name].id] = true
  unitArray[UnitDefNames[name.."_scav"].id] = true
end
unitArray_ = nil

local myTeamID = Spring.GetMyTeamID()

----------------------------------------------
------------------------------------------

function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() then
    widgetHandler:RemoveWidget()
  end
  myTeamID = Spring.GetMyTeamID()
end

function widget:Initialize()
  if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
    widget:PlayerChanged()
  end
end

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
  if unitTeam == myTeamID then
    if unitArray[unitDefID] then--or (builderID and unitArray[Spring.GetUnitDefID(builderID)]) then
      Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, 0)
    end
  end
end
