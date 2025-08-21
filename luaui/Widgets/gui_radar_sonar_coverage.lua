function widget:GetInfo()
  return {
    name    = "Radar & Sonar Coverage",
    desc    = "Draws team/allied radar, sonar and jammer coverage with subtle rings",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 0,
    enabled = true,
  }
end

--------------------------------------------------------------------------------
-- Spring API
--------------------------------------------------------------------------------
local spGetAllyTeamList     = Spring.GetAllyTeamList
local spGetTeamList         = Spring.GetTeamList
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetTeamUnits        = Spring.GetTeamUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsSphereInView      = Spring.IsSphereInView
local spGetTeamColor        = Spring.GetTeamColor
local spGetSpectatingState  = Spring.GetSpectatingState
local spIsGUIHidden         = Spring.IsGUIHidden

local glColor               = gl.Color
local glDrawGroundCircle    = gl.DrawGroundCircle

--------------------------------------------------------------------------------
-- State
--------------------------------------------------------------------------------
local myTeam = spGetMyTeamID()
local coverage = {}   -- { {x,y,z, rr, sr, jr, r,g,b}, ... }
local lastRefresh = 0
local REFRESH_FRAMES = 15
local MAX_DRAW = 300

local function gatherAlliedTeams()
  local teams = {}
  for _,teamID in ipairs(spGetTeamList()) do
    if spAreTeamsAllied(teamID, myTeam) then
      teams[#teams+1] = teamID
    end
  end
  return teams
end

local function clamp01(x) return (x < 0 and 0) or (x > 1 and 1) or x end

local function refreshCoverage()
  coverage = {}
  local teams = gatherAlliedTeams()
  for i=1,#teams do
    local t = teams[i]
    local r,g,b = spGetTeamColor(t)
    r,g,b = r or 0.2, g or 0.8, b or 0.8
    for _,u in ipairs(spGetTeamUnits(t)) do
      local ud = UnitDefs[spGetUnitDefID(u)]
      if ud then
        local rr = ud.radarRadius or 0
        local sr = ud.sonarRadius or 0
        local jr = ud.jammerRadius or 0
        if rr>0 or sr>0 or jr>0 then
          local x,y,z = spGetUnitPosition(u)
          if x then
            coverage[#coverage+1] = {x,y,z, rr, sr, jr, r,g,b}
          end
        end
      end
    end
  end
end

function widget:Initialize()
  refreshCoverage()
end

function widget:Update()
  local f = Spring.GetGameFrame()
  if f - lastRefresh >= REFRESH_FRAMES then
    refreshCoverage()
    lastRefresh = f
  end
end

function widget:UnitCreated(uID, team)
  if not spAreTeamsAllied(team, myTeam) then return end
  lastRefresh = -1 -- force refresh next update
end
function widget:UnitDestroyed(uID, team)
  if not spAreTeamsAllied(team, myTeam) then return end
  lastRefresh = -1
end

function widget:DrawWorld()
  if spIsGUIHidden() then return end
  if not coverage or #coverage==0 then return end

  local drawn = 0
  for i=1,#coverage do
    if drawn >= MAX_DRAW then break end
    local e = coverage[i]
    local x,y,z, rr,sr,jr, r,g,b = e[1],e[2],e[3], e[4],e[5],e[6], e[7],e[8],e[9]
    if spIsSphereInView(x,y,z, math.max(rr,sr,jr)) then
      if rr>0 then
        glColor(r, g, b, 0.14); glDrawGroundCircle(x,y,z, rr, 28)
      end
      if sr>0 then
        glColor(0.35, 0.55, 1.0, 0.16); glDrawGroundCircle(x,y,z, sr, 28)
      end
      if jr>0 then
        glColor(0.75, 0.35, 0.9, 0.10); glDrawGroundCircle(x,y,z, jr, 28)
      end
      drawn = drawn + 1
    end
  end
  glColor(1,1,1,1)
end
