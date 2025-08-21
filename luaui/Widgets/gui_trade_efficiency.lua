function widget:GetInfo()
  return {
    name    = "Trade Efficiency",
    desc    = "Shows metal destroyed vs. metal lost over a rolling window",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 2,
    enabled = true,
  }
end

local spGetMyTeamID = Spring.GetMyTeamID
local spIsGUIHidden = Spring.IsGUIHidden
local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local myTeam = spGetMyTeamID()
local horizonList = {60, 120, 300}
local horizonIdx = 2
local events = {} -- {t=gameSec, val=+metal/-metal}

local function now()
  return Spring.GetGameSeconds()
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam)
  local ud = UnitDefs[unitDefID]
  if not ud then return end
  local cost = ud.metalCost or 0
  if unitTeam == myTeam then
    events[#events+1] = {t=now(), val = -cost}
  elseif attackerTeam == myTeam and unitTeam ~= myTeam then
    events[#events+1] = {t=now(), val = +cost}
  end
end

local function prune()
  local T = now()
  local H = horizonList[horizonIdx]
  local j = 1
  for i=1,#events do
    if T - events[i].t <= H then
      events[j] = events[i]; j = j + 1
    end
  end
  for k=j,#events do events[k] = nil end
end

function widget:Update(dt)
  prune()
end

function widget:KeyPress(key, mods, isRepeat)
  if mods.ctrl and (key == string.byte('K')) then
    horizonIdx = horizonIdx % #horizonList + 1
    return true
  end
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end
  local sum = 0
  local killed, lost = 0, 0
  for i=1,#events do
    sum = sum + events[i].val
    if events[i].val > 0 then killed = killed + events[i].val else lost = lost - events[i].val end
  end

  local x, y, w, h = 8, 8, 300, 64
  glColor(0,0,0,0.55); glRect(x,y,x+w,y+h)
  local H = horizonList[horizonIdx]
  local ratio = (lost > 0) and (killed/lost) or (killed>0 and math.huge or 1)

  glColor(1,1,1,1)
  glText(("Trade (%ds)"):format(H), x+8, y+h-18, 13, "n")

  local r,g,b = 0.8,0.95,0.8
  if ratio < 0.9 then r,g,b = 0.95,0.7,0.7 elseif ratio < 1.1 then r,g,b = 0.95,0.95,0.75 end
  glColor(r,g,b,1)
  glText(("Killed: %d  Lost: %d"):format(math.floor(killed+0.5), math.floor(lost+0.5)), x+8, y+h-36, 12, "n")
  glText(("Ratio: %0.2f"):format(ratio), x+8, y+h-54, 12, "n")

  glColor(1,1,1,1)
end
