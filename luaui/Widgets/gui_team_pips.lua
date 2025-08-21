function widget:GetInfo()
  return {
    name    = "Team Pips (Colorblind Aid)",
    desc    = "Adds a tiny, shape-coded pip next to unit icons to improve team recognition without altering team colors",
    author  = "bar-helper",
    date    = "2025-08-21",
    license = "GPLv2 or later",
    layer   = 5,
    enabled = false, -- opt-in; toggle in widget list
  }
end

local spGetVisibleUnits = Spring.GetVisibleUnits
local spGetUnitTeam     = Spring.GetUnitTeam
local spGetUnitViewPosition = Spring.GetUnitViewPosition
local spWorldToScreen   = Spring.WorldToScreenCoords
local glColor, glRect   = gl.Color, gl.Rect

-- Simple, shape-coded sequence; we keep a stable mapping by teamID modulo table length
local pipStyles = {
  { w = 7, h = 7,  shape = "square",   col = {1,1,1,0.9} },
  { w = 9, h = 3,  shape = "bar",      col = {1,0.9,0.3,0.9} },
  { w = 7, h = 7,  shape = "diamond",  col = {0.6,1,0.6,0.9} },
  { w = 9, h = 9,  shape = "corner",   col = {0.9,0.6,1,0.9} },
}

local function drawDiamond(cx, cy, s)
  gl.Rect(cx - s, cy,     cx,     cy + s) -- bottom-left
  gl.Rect(cx,     cy,     cx + s, cy + s) -- bottom-right
  gl.Rect(cx - s, cy - s, cx,     cy)     -- top-left
  gl.Rect(cx,     cy - s, cx + s, cy)     -- top-right
end

function widget:DrawScreen()
  -- Skip when GUI hidden
  if Spring.IsGUIHidden() then return end

  local units = spGetVisibleUnits(-1, 30, false) -- icon or near-icon LOD
  if not units or #units > 5000 then return end   -- be defensive

  for i = 1, #units do
    local u = units[i]
    local team = spGetUnitTeam(u)
    if team then
      local x, y, z = spGetUnitViewPosition(u)
      if x then
        local sx, sy = spWorldToScreen(x, y, z)
        if sx then
          local style = pipStyles[(team % #pipStyles) + 1]
          local w, h = style.w, style.h
          local col  = style.col
          glColor(col[1], col[2], col[3], col[4])
          if style.shape == "square" then
            glRect(sx + 10, sy + 8, sx + 10 + w, sy + 8 + h)
          elseif style.shape == "bar" then
            glRect(sx + 10, sy + 8, sx + 10 + w, sy + 8 + h)
          elseif style.shape == "corner" then
            glRect(sx + 10, sy + 8, sx + 10 + w, sy + 8 + h)
            glRect(sx + 10, sy + 8, sx + 10 + 3, sy + 8 + h + 3)
          elseif style.shape == "diamond" then
            drawDiamond(sx + 13, sy + 10, 3)
          end
        end
      end
    end
  end

  glColor(1,1,1,1)
end
