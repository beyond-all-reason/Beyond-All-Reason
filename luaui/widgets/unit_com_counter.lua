--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "ComCounter",
    desc      = "Nofifies how many Commanders are remaining in Kill All Commanders mode.",
    author    = "TheFatController",
    date      = "Apr 28, 2008",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

if (Spring.GetModOptions().deathmode~="com") then
  return false
end

local comNotify = -1
local GetUnitDefID = Spring.GetUnitDefID
local lastCounts = {}

function widget:UnitFinished(unitID, unitDefID, unitTeam)
  if UnitDefs[unitDefID].customParams.iscommander then
    comNotify = (Spring.GetGameFrame() + 15)
  end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
  if UnitDefs[unitDefID].customParams.iscommander then
    comNotify = (Spring.GetGameFrame() + 15)
  end
end

function widget:TeamDied(teamID)
  if (teamID == Spring.GetMyTeamID()) then
    comNotify = -1
  end
end

function widget:UnitGiven(unitID, unitDefID, unitTeam, newTeam)
  if UnitDefs[unitDefID].customParams.iscommander then
    comNotify = (Spring.GetGameFrame() + 15)
  end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam, newTeam)
  if UnitDefs[unitDefID].customParams.iscommander then
    comNotify = (Spring.GetGameFrame() + 15)
  end
end

function widget:GameFrame(n)
  if (n == comNotify) and (n > 300) then
    local comCount = 0
    local allyID = Spring.GetMyAllyTeamID()
    for _, teamID in ipairs(Spring.GetTeamList(allyID)) do
      for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
        if (UnitDefs[GetUnitDefID(unitID)].customParams.iscommander) then
          comCount = (comCount + 1)
        end
      end
    end
    if (lastCounts[allyID] ~= comCount) then
      lastCounts[allyID] = comCount
      Spring.Echo("Commanders Remaining: " .. comCount)
    end
  end
end
