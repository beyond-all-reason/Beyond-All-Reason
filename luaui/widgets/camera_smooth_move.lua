--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  file:    camera_smooth_scroll.lua
--  brief:   Alternate camera scrolling for the middle mouse button
--  author:  Dave Rodgers
--
--  Copyright (C) 2007.
--  Licensed under the terms of the GNU GPL, v2 or later.
--
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "SmoothScroll",
    desc      = "Alternate view movement for the middle mouse button",
    author    = "trepan",
    date      = "Feb 27, 2007",
    license   = "GNU GPL, v2 or later",
    layer     = 1,     --  after the normal widgets
    enabled   = true  --  loaded by default?
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- Automatically generated local definitions

local GL_LINES    = GL.LINES
local GL_POINTS   = GL.POINTS

local glBeginEnd  = gl.BeginEnd
local glColor     = gl.Color
local glLineWidth = gl.LineWidth
local glPointSize = gl.PointSize
local glVertex    = gl.Vertex

local spGetCameraState   = Spring.GetCameraState
local spGetCameraVectors = Spring.GetCameraVectors
local spGetModKeyState   = Spring.GetModKeyState
local spGetMouseState    = Spring.GetMouseState
local spIsAboveMiniMap   = Spring.IsAboveMiniMap
local spSendCommands     = Spring.SendCommands
local spSetCameraState   = Spring.SetCameraState
local spSetMouseCursor   = Spring.SetMouseCursor
local spTraceScreenRay   = Spring.TraceScreenRay
local spWarpMouse        = Spring.WarpMouse


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--
--  NOTES:
--
--  1. The GetCameraState() table is supposed to be opaque.
--

local blockModeSwitching = true


local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end


local decayFactor = 1
local speedFactor = 25

local mx, my
local active = false


--------------------------------------------------------------------------------

function widget:Update(dt)
  if (active) then
    local x, y, lmb, mmb, rmb = spGetMouseState()
    local cs = spGetCameraState()
    local speed = dt * speedFactor

    if (cs.name == 'free') then
      local a,c,m,s = spGetModKeyState()
      if (c) then
        return
      end
      -- clear the velocities
      cs.vx  = 0; cs.vy  = 0; cs.vz  = 0
      cs.avx = 0; cs.avy = 0; cs.avz = 0
    end
    if (cs.name == 'ta') then
      local flip = -cs.flipped
      -- simple, forward and right are locked
      cs.px = cs.px + (speed * flip * (x - mx))
      if (false) then
        cs.py = cs.py + (speed * flip * (my - y))
      else
        cs.pz = cs.pz + (speed * flip * (my - y))
      end
    else
      -- forward, up, right, top, bottom, left, right
      local camVecs = spGetCameraVectors()
      local cf = camVecs.forward
      local len = math.sqrt((cf[1] * cf[1]) + (cf[3] * cf[3]))
      local dfx = cf[1] / len
      local dfz = cf[3] / len
      local cr = camVecs.right
      local len = math.sqrt((cr[1] * cr[1]) + (cr[3] * cr[3]))
      local drx = cr[1] / len
      local drz = cr[3] / len
      local mxm = (speed * (x - mx))
      local mym = (speed * (y - my))
      cs.px = cs.px + (mxm * drx) + (mym * dfx)
      cs.pz = cs.pz + (mxm * drz) + (mym * dfz)
    end

    spSetCameraState(cs, 0)

    if (mmb) then
      spSetMouseCursor('none')
    end
  end
end


function widget:MousePress(x, y, button)
  if (button ~= 2) then
    return false
  end
  if (spIsAboveMiniMap(x, y)) then
    return false
  end
  local cs = spGetCameraState()
  if (blockModeSwitching and (cs.name ~= 'ta') and (cs.name ~= 'free')) then
    local a,c,m,s = spGetModKeyState()
    return (c or s)  --  block the mode toggling
  end
  if (cs.name == 'free') then
    local a,c,m,s = spGetModKeyState()
    if (m and (not (c or s))) then
      return false
    end
  end
  active = not active
  if (active) then
    mx = vsx * 0.5
    my = vsy * 0.5
    spWarpMouse(mx, my)
    spSendCommands({'trackoff'})
  end
  return true
end


function widget:MouseRelease(x, y, button)
  active = false
  return -1
end


-- FIXME -- this algo could still use some lovin'
function widget:MouseWheel(up, value)
  local cs = spGetCameraState()
  local a,c,m,s = spGetModKeyState()
  if (m) then
    local py = math.abs(cs.py)
    local dy = (1 + math.pow(py * 100, 0.25)) * (up and -1 or 1)
    local dy = (py / 10) * (up and -1 or 1)
    print(dy)
    spSetCameraState({
      py = py + dy,
    }, 0)
    return true
  end
  if (cs.name ~= 'free') then
    return false
  end
  local scale = value * 10
  local mx, my = spGetMouseState()
  local _, gpos = spTraceScreenRay(mx, my, true)
  if (not gpos) then
    spSetCameraState({ vy = cs.vy + scale}, 0)
  else
    local dx = gpos[1] - cs.px
    local dy = gpos[2] - cs.py
    local dz = gpos[3] - cs.pz
    local d = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
    local s = (up and 1 or -1) * (1 / 8)
    
    dx = dx * s
    dy = dy * s
    dz = dz * s
    local newCS = {
      px = cs.px + dx,
      py = cs.py + dy,
      pz = cs.pz + dz,
      vx = 0,
      vy = 0,
      vz = 0,
    }
    spSetCameraState(newCS, 0)
  end
  return true
end


local function DrawPoint(x, y, c, s)
  glPointSize(s)
  glColor(c)
  glBeginEnd(GL_POINTS, glVertex, x, y)
end


local function DrawLine(x0, y0, c0, x1, y1, c1)
  glColor(c0); glVertex(x0, y0)
  glColor(c1); glVertex(x1, y1)
end


local red   = { 1, 0, 0 }
local green = { 0, 1, 0 }
local black = { 0, 0, 0 }
local white = { 1, 1, 1 }


function widget:DrawScreen()
  if (active) then
    local x, y = spGetMouseState()

    DrawPoint(mx, my, black, 14)
    DrawPoint(mx, my, white, 11)
    DrawPoint(mx, my, black,  8)
    DrawPoint(mx, my, red,    5)

    glLineWidth(2)
    glBeginEnd(GL_LINES, DrawLine, x, y, green, mx, my, red)
    glLineWidth(1)

    DrawPoint(x, y, { 0, 1, 0 },  5)

    glPointSize(1)
  end
end


--------------------------------------------------------------------------------

