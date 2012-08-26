--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    unit_immobile_buider.lua
--  brief:   sets immobile builders to MANEUVERING, and gives them a FIGHT order
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "ImmobileBuilder",
    desc      = "Sets immobile builders to MANEUVER, with a FIGHT command",
    author    = "trepan",
    date      = "Jan 8, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions
local CMD_PASSIVE = 34571
local CMD_MOVE_STATE    = CMD.MOVE_STATE
local CMD_REPEAT        = CMD.REPEAT
local CMD_PATROL        = CMD.PATROL
local CMD_FIGHT         = CMD.FIGHT
local CMD_STOP          = CMD.STOP
local spGetGameFrame    = Spring.GetGameFrame
local spGetMyTeamID     = Spring.GetMyTeamID
local spGetTeamUnits    = Spring.GetTeamUnits
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitDefID    = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit

local hmsx = Game.mapSizeX/2
local hmsz = Game.mapSizeZ/2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- if this is >0, then commands are re-issued for immobile
-- builders that have been idling for the number of game frames
-- (in case a player accidentally STOPs them)

local idleFrames = 60


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function IsImmobileBuilder(ud)
  return(ud and ud.builder and not ud.canMove
         and not ud.isFactory)
end


local function SetupUnit(unitID)
  -- set immobile builders (nanotowers?) to the MANEUVER movestate,
  -- and give them a FIGHT order (does not matter where, afaict)
  local ret = false
  local x, y, z = spGetUnitPosition(unitID)
  if (x) then
    ret = spGiveOrderToUnit(unitID, CMD_MOVE_STATE, { 1 }, {})
    if (x > hmsx) then -- avoid to issue commands outside map
      x = x - 50
    else
      x = x + 50
    end
    if (z > hmsz) then
      z = z - 50
    else
      z = z + 50
    end
    ret = spGiveOrderToUnit(unitID, CMD_FIGHT, { x, y, z }, {"meta"}) and ret -- meta enables reclaim enemy units, alt autoresurrect ( if available )
  end
  return ret
end


function widget:Initialize()
  for _,unitID in ipairs(spGetTeamUnits(spGetMyTeamID())) do
    local unitDefID = spGetUnitDefID(unitID)
    if (IsImmobileBuilder(UnitDefs[unitDefID])) then
      SetupUnit(unitID)
    end
  end
end


function widget:UnitCreated(unitID, unitDefID, unitTeam)
  if (unitTeam ~= spGetMyTeamID()) then
    return
  end
  if (IsImmobileBuilder(UnitDefs[unitDefID])) then
    SetupUnit(unitID)
    spGiveOrderToUnit(unitID, CMD_PASSIVE, { 1 }, {}) 
  end
end


function widget:UnitGiven(unitID, unitDefID, unitTeam)
  widget:UnitCreated(unitID, unitDefID, unitTeam)
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (idleFrames > 0) then

  local idlers = {}


  function widget:GameFrame(frame)
    for unitID, f in pairs(idlers) do
      local idler = idlers[k]
      if ((frame - f) > idleFrames) then
        local cmds = spGetUnitCommands(unitID)
        if (cmds and (#cmds <= 0)) then
          if SetupUnit(unitID) then
            idlers[unitID] = frame -- safeguard against command spam
          else
            idlers[unitID] = nil -- the unit could not be set up, don't retry
          end
        else
          idlers[unitID] = nil
        end
      end
    end
  end


  function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
    idlers[unitID] = nil
  end


  function widget:UnitIdle(unitID, unitDefID, unitTeam)
    if (unitTeam ~= spGetMyTeamID()) then
      return
    end
    if (IsImmobileBuilder(UnitDefs[unitDefID])) then
      idlers[unitID] = spGetGameFrame()
    end
  end


end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
