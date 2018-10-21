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
    enabled   = false  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local unitSet = {}

local unitArray = {
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
}

if UnitDefNames.armcom_bar then
  function tableMerge(t1, t2)
    for k,v in pairs(t2) do if type(v) == "table" then if type(t1[k] or false) == "table" then tableMerge(t1[k] or {}, t2[k] or {}) else t1[k] = v end else t1[k] = v end end
    return t1
  end
  local unitArrayBAR = {}
  for _,name in pairs(unitArray) do
    unitArrayBAR[#unitArrayBAR+1] = name
  end
  unitArray = tableMerge(unitArray, unitArrayBAR)
end
----------------------------------------------
------------------------------------------

function widget:PlayerChanged(playerID)
  if Spring.GetSpectatingState() then
    widgetHandler:RemoveWidget(self)
  end
end

function widget:Initialize()
  if Spring.IsReplay() or Spring.GetGameFrame() > 0 then
    widget:PlayerChanged()
  end
  for i, v in pairs(unitArray) do
    unitSet[v] = true
  end
end

function widget:GameStart()
  widget:PlayerChanged()
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
  local ud = UnitDefs[unitDefID]
   if ((ud ~= nil) and (unitTeam == Spring.GetMyTeamID())) then
    for i, v in pairs(unitSet) do
      if (unitSet[ud.name]) then
        Spring.GiveOrderToUnit(unitID, CMD.MOVE_STATE, { 0 }, {})
      end
    end
  end
end

--------------------------------------------------------------------------------
