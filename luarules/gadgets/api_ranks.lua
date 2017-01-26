-- $Id: api_ranks.lua 3171 2008-11-06 09:06:29Z det $
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "ranks api",
    desc      = "a shared interface to recieve unit ranks",
    author    = "jK",
    date      = "Dec 19, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = -math.huge,
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------






if (gadgetHandler:IsSyncedCode()) then
-----------------------------------------------------------------------------------
--  SYNCED
-----------------------------------------------------------------------------------

--// speed-ups

local Script = Script
local SendToUnsynced = SendToUnsynced

local GetUnitDefID         = Spring.GetUnitDefID
local GetUnitExperience    = Spring.GetUnitExperience
local GetUnitTeam          = Spring.GetUnitTeam
local GetAllUnits          = Spring.GetAllUnits

local floor = math.floor
local type  = type

-- controls how often Spring.UnitExperience is called
-- it is based on the following equation:
-- (int) [exp/(exp+1)] / expGrade
--  If this integer differs from the one before the experience change
--  it will call UnitExperience().
local EXP_GRADE = 0.0005	

------------------------------------------------------------------------------------
------------------------------------------------------------------------------------

local unitRanks  = {}

function GetUnitRank(unitID)
  return unitRanks[unitID] or 0
end

function RankToXp(unitDefID,rank)
  return ((UnitDefs[unitDefID] or {}).power_xp_coeffient or 0) * (rank or 0)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:Initialize()
  for udid, ud in pairs(UnitDefs) do
    ud.power_xp_coeffient  = ((ud.power / 1000) ^ -0.2) / 6  -- dark magic
  end

  GG['rankHandler'] = {}
  GG['rankHandler'].RankToXp    = RankToXp
  GG['rankHandler'].GetUnitRank = GetUnitRank
  if (type(GG.UnitRanked)~="table") then GG.UnitRanked = {} end

  Spring.SetExperienceGrade(EXP_GRADE)

  RecreateList()
end

function gadget:Shutdown()
  GG['rankHandler'] = nil
  Spring.SetExperienceGrade(0)
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function gadget:UnitExperience(unitID, unitDefID, unitTeam, xp, oldxp)
  local ud = UnitDefs[unitDefID]
  if (not ud or not ud.power_xp_coeffient) then
    return
  end
  local oldRank = unitRanks[unitID] or floor(oldxp / ud.power_xp_coeffient)
  if oldRank>4 then return end

  local newRank = floor(xp / ud.power_xp_coeffient)
  if (newRank~=oldRank) then
    unitRanks[unitID] = newRank
    if (type(GG.UnitRanked)=="table") then
      for _,f in pairs(GG.UnitRanked) do
        if (type(f)=="function") then
          f(unitID,unitDefID,unitTeam,newRank,oldRank)
        end
      end
    end
  end
end


local function SetUnitRank(unitID)
  local unitDefID = GetUnitDefID(unitID)
  local ud = UnitDefs[unitDefID]
  local xp = GetUnitExperience(unitID)
  if (xp == nil)or(ud == nil) then
    unitRanks[unitID] = 0
    return
  end

  local newRank = floor(xp / ud.power_xp_coeffient)
  local oldRank = unitRanks[unitID] or 0
  if (newRank~=oldRank) then
    unitRanks[unitID] = newRank
    local unitTeam = GetUnitTeam(unitID)
    if (type(GG.UnitRanked)=="table") then
      for _,f in pairs(GG.UnitRanked) do
        if (type(f)=="function") then
          f(unitID,unitDefID,unitTeam,newRank,oldRank)
        end
      end
    end
  end
end


-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------

function RecreateList()
  unitRanks = {}
  local allUnits = GetAllUnits()
  for i=1,#allUnits do
    SetUnitRank(allUnits[i])
  end
end

-------------------------------------------------------------------------------------
-------------------------------------------------------------------------------------


function gadget:UnitCreated(unitID)
  unitRanks[unitID] = 0
end


function gadget:UnitDestroyed(unitID)
  unitRanks[unitID] = nil
end

-----------------------------------------------------------------------------------
--  END SYNCED
-----------------------------------------------------------------------------------
end