-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------
-- Author: Rafal

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

local spGetUnitStates   = Spring.GetUnitStates
local spGiveOrderToUnit = Spring.GiveOrderToUnit


local cmdToStateName = {
  [CMD.FIRE_STATE]      = "firestate",
  [CMD.MOVE_STATE]      = "movestate",
  [CMD.REPEAT]          = "repeat",
  [CMD.CLOAK]           = "cloak",
  [CMD.ONOFF]           = "active",
  [CMD.TRAJECTORY]      = "trajectory",
  [CMD.IDLEMODE]        = "autoland",
  [CMD.AUTOREPAIRLEVEL] = "autorepairlevel",
  [CMD.LOOPBACKATTACK]  = "loopbackattack",
}

local stateToParam = {
  [0]     = 0,
  [1]     = 1,
  [2]     = 2,
  [false] = 0,
  [true]  = 1,
  [0.3]   = 1,  --for CMD.AUTOREPAIRLEVEL
  [0.5]   = 2,
  [0.8]   = 3,
}

local paramTable = { 0 }

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

-- Spring.GiveOrderToUnit is VERY EXPENSIVE!
-- approximately 30-50 times more expensive than Spring.GetUnitStates()
-- so better not call it when not necessary

function Spring.Utilities.GiveStateOrderToUnit (unitID, cmdID, param1, options)
  local stateName = cmdToStateName[cmdID]
  if (stateName) then
    local states    = spGetUnitStates(unitID)
    local state     = states and states[stateName]
    local prevParam = stateToParam[state]
    if (prevParam and prevParam == param1) then
      return
    end
  end

  paramTable[1] = param1
  spGiveOrderToUnit(unitID, cmdID, paramTable, options)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------