function widget:GetInfo()
  return {
    name    = "Econ Projection",
    desc    = "Tiny banner with 15s ahead projection for Energy/Metal stores; shows time-to-empty/overflow",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 2,
    enabled = true,
  }
end

local spGetTeamResources = Spring.GetTeamResources
local spGetMyTeamID      = Spring.GetMyTeamID
local spIsGUIHidden      = Spring.IsGUIHidden
local glColor, glRect, glText = gl.Color, gl.Rect, gl.Text

local horizon = 15.0 -- seconds
local pad = 8
local font = 14

local function econ(kind)
  -- cur, storage, pull, income, expense
  local c,s,p,i,e = spGetTeamResources(Spring.GetMyTeamID(), kind)
  c,s,p,i,e = c or 0, s or 0, p or 0, i or 0, e or 0
  local net = i - e
  return c,s,net,i,e
end

local function project(cur, storage, net, t)
  local future = cur + net * t
  if future < 0 then
    local t_empty = (net < 0) and (cur / -net) or math.huge
    return 0, t_empty, "empty"
  elseif future > storage then
    local t_full = (net > 0) and ((storage - cur) / net) or math.huge
    return storage, t_full, "full"
  end
  return future, math.huge, "ok"
end

function widget:DrawScreen()
  if spIsGUIHidden() then return end

  local ex, es, en = econ("energy")
  local mx, ms, mn = econ("metal")

  local ef, tE, eState = project(ex, es, en, horizon)
  local mf, tM, mState = project(mx, ms, mn, horizon)

  local w, h = 280, 64
  local x, y = 8, 40
  glColor(0,0,0,0.55); glRect(x,y,x+w,y+h)

  local function col(state)
    if state == "empty" then glColor(1.0,0.5,0.5,1)
    elseif state == "full" then glColor(1.0,0.9,0.5,1)
    else glColor(1,1,1,1) end
  end

  -- Energy line
  col(eState)
  glText(string.format("E: %.0f / %.0f  (net %+d)", ex, es, en), x+pad, y+h-20, font, "n")
  local eMsg = (tE ~= math.huge) and string.format("E %s in %.1fs", eState, tE) or "E stable"
  glText(eMsg, x+pad, y+h-36, font-2, "n")

  -- Metal line
  col(mState)
  glText(string.format("M: %.1f / %.0f  (net %+0.1f)", mx, ms, mn), x+pad, y+h-52, font, "n")
  local mMsg = (tM ~= math.huge) and string.format("M %s in %.1fs", mState, tM) or "M stable"
  glText(mMsg, x+pad+140, y+h-36, font-2, "n")

  glColor(1,1,1,1)
end
