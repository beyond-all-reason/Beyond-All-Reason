function widget:GetInfo()
  return {
    name    = "Composition Summary",
    desc    = "Counts roles for allies vs visible enemies (raid/skirm/arty/assault/AA/air/builders)",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 2,
    enabled = true,
  }
end

local spGetTeamList         = Spring.GetTeamList
local spAreTeamsAllied      = Spring.AreTeamsAllied
local spGetMyTeamID         = Spring.GetMyTeamID
local spGetTeamUnits        = Spring.GetTeamUnits
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitAllyTeam     = Spring.GetUnitAllyTeam
local spIsUnitInLos         = Spring.IsUnitInLos
local spIsGUIHidden         = Spring.IsGUIHidden

local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local myTeam = spGetMyTeamID()
local myAlly = Spring.GetMyAllyTeamID()

local roles = {"raid","skirm","arty","assault","aa","air","builder","factory"}
local allyCount = {}
local enemyCount = {}

local function zeroCounts(t)
  for _,k in ipairs(roles) do t[k] = 0 end
end

local function maxRange(ud)
  local best = 0
  if ud.weapons then
    for i=1,#ud.weapons do
      local wd = WeaponDefs[ud.weapons[i].weaponDef]
      if wd and wd.range and wd.range>best then best = wd.range end
    end
  end
  return best
end

local function hasAA(ud)
  if not ud.weapons then return false end
  for i=1,#ud.weapons do
    local wd = WeaponDefs[ud.weapons[i].weaponDef]
    if wd and wd.onlyTargets and (wd.onlyTargets.vtol or wd.onlyTargets["vtol"]) then
      return true
    end
  end
  return false
end

local function classify(ud)
  if not ud then return "assault" end
  if ud.isFactory then return "factory" end
  if ud.isBuilder then return "builder" end
  if ud.canFly then return "air" end
  if hasAA(ud) then return "aa" end
  local r = maxRange(ud)
  local spd = ud.speed or 0
  if r >= 850 then return "arty"
  elseif r >= 500 then return "skirm"
  elseif spd >= 75 then return "raid"
  else return "assault" end
end

local function countAllies()
  zeroCounts(allyCount)
  for _,team in ipairs(spGetTeamList()) do
    if spAreTeamsAllied(team, myTeam) then
      for _,u in ipairs(spGetTeamUnits(team)) do
        local ud = UnitDefs[spGetUnitDefID(u)]
        allyCount[classify(ud)] = (allyCount[classify(ud)] or 0) + 1
      end
    end
  end
end

local function countEnemiesVisible()
  zeroCounts(enemyCount)
  for _,team in ipairs(spGetTeamList()) do
    if not spAreTeamsAllied(team, myTeam) then
      for _,u in ipairs(spGetTeamUnits(team)) do
        if spIsUnitInLos(u, myAlly) then
          local ud = UnitDefs[spGetUnitDefID(u)]
          enemyCount[classify(ud)] = (enemyCount[classify(ud)] or 0) + 1
        end
      end
    end
  end
end

local lastUpdate = 0
function widget:Update(dt)
  local f = Spring.GetGameFrame()
  if f - lastUpdate >= 30 then  -- ~1/sec
    countAllies()
    countEnemiesVisible()
    lastUpdate = f
  end
end

local function row(t)
  return ("Raid:%d  Skirm:%d  Arty:%d  Assault:%d  AA:%d  Air:%d  Bld:%d  Fac:%d")
    :format(t.raid, t.skirm, t.arty, t.assault, t.aa, t.air, t.builder, t.factory)
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end
  local x,y,w,h = Spring.GetViewGeometry()
  x = x + w - 560; y = y + 8; w = 552; h = 58
  glColor(0,0,0,0.55); glRect(x,y,x+w,y+h)
  glColor(1,1,1,1)
  glText("Composition (Allies vs Visible Enemy)", x+8, y+h-18, 13, "n")
  glColor(0.8,0.95,0.8,1); glText("Allies:  "..row(allyCount), x+8, y+h-36, 12, "n")
  glColor(0.95,0.8,0.8,1); glText("Enemy:  "..row(enemyCount), x+8, y+h-52, 12, "n")
  glColor(1,1,1,1)
end
