function widget:GetInfo()
  return {
    name    = "Combat Hotspots",
    desc    = "Shows short-lived damage heat spots; great for minimap scanning and spectating",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 1,
    enabled = true,
  }
end

local spGetUnitPosition   = Spring.GetUnitPosition
local spWorldToScreen     = Spring.WorldToScreenCoords
local spIsGUIHidden       = Spring.IsGUIHidden
local spGetSpectatingState= Spring.GetSpectatingState
local glColor, glDrawGroundCircle, glRect, glText = gl.Color, gl.DrawGroundCircle, gl.Rect, gl.Text

-- grid accumulation (coarse -> fast)
local cell = 256          -- map units per cell
local tau  = 6.0          -- seconds to decay to ~37%; 2*tau ~ 12s memory
local maxCellsDraw = 40

local DAMAGE = {}
local lastUpdate = Spring.GetGameFrame()

local function cellKey(x,z)
  return string.format("%d:%d", math.floor(x/cell), math.floor(z/cell))
end

function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
  local x, y, z = spGetUnitPosition(unitID)
  if not x then return end
  local k = cellKey(x,z)
  local e = DAMAGE[k]
  if not e then
    e = {x=x,y=y,z=z, val=0}
    DAMAGE[k] = e
  end
  e.x, e.y, e.z = x, y, z
  e.val = e.val + math.max(0, damage or 0)
end

function widget:Update(dt)
  local gf = Spring.GetGameFrame()
  if gf == lastUpdate then return end
  lastUpdate = gf
  -- simple exponential decay
  local decay = math.exp(-(1/30)/tau)
  for k,e in pairs(DAMAGE) do
    e.val = e.val * decay
    if e.val < 1 then DAMAGE[k] = nil end
  end
end

function widget:DrawWorld()
  if next(DAMAGE) == nil then return end
  gl.DepthTest(true)

  -- collect & sort top cells
  local tmp = {}
  for _,e in pairs(DAMAGE) do tmp[#tmp+1] = e end
  table.sort(tmp, function(a,b) return a.val > b.val end)

  local n = math.min(#tmp, maxCellsDraw)
  for i=1,n do
    local e = tmp[i]
    local intensity = math.min(1.0, (e.val / 800)) -- tune to taste
    glColor(1.0, 0.25, 0.25, 0.18 + 0.22*intensity)
    local r = 70 + 120 * math.sqrt(intensity)
    glDrawGroundCircle(e.x, e.y, e.z, r, 24)
  end

  gl.DepthTest(false); glColor(1,1,1,1)
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end
  -- small legend (optional)
  glColor(0,0,0,0.35); glRect(8,8,160,32)
  glColor(1,1,1,1); glText("Combat hotspots enabled", 12, 14, 12, "n")
end
