local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Middle Mouse SmoothScroll",
    desc      = "Alternate view movement for the middle mouse button & overhead camera",
    author    = "[DE]LSR, original implementation by trepan",
    date      = "March 2023",
    license   = "GNU GPL, v2 or later",
    layer     = 1,     --  after the normal widgets
    enabled   = false
  }
end

local spGetCameraState   = Spring.GetCameraState
local spGetCameraVectors = Spring.GetCameraVectors
local spGetModKeyState   = Spring.GetModKeyState
local spGetMouseState    = Spring.GetMouseState
local spIsAboveMiniMap   = Spring.IsAboveMiniMap
local spSendCommands     = Spring.SendCommands
local spSetCameraState   = Spring.SetCameraState
local spSetMouseCursor   = Spring.SetMouseCursor
local spWarpMouse        = Spring.WarpMouse

local blockModeSwitching = true


local vsx, vsy = widgetHandler:GetViewSizes()
function widget:ViewResize(viewSizeX, viewSizeY)
  vsx = viewSizeX
  vsy = viewSizeY
end

local mx, my
local active = false
local drawing = false

function widget:Update(dt)
  if (active) then

    local speedFactor = Spring.GetConfigInt('OverheadScrollSpeed', 10)
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

-- Adjust the camera position when the user scrolls the mouse wheel
function widget:MouseWheel(up, value)
    -- Get the current camera state and mod key state
    local cameraState = Spring.GetCameraState()
    local altDown, ctrlDown, metaDown, shiftDown = Spring.GetModKeyState()

    -- If the Alt key is down, adjust the camera height
    if altDown then
        local absCameraY = math.abs(cameraState.py)
        local cameraYDelta = (absCameraY / 10) * (up and -1 or 1)

		local newCameraState = {
			py = absCameraY + cameraYDelta
		}

        Spring.SetCameraState(newCameraState, 0)		
        return true
    end

    -- If the camera mode is not "free", do nothing
    if cameraState.name ~= 'free' then
        return false
    end

    -- Get the mouse position and position on ground
    local mouseX, mouseY = Spring.GetMouseState()
    local _, groundPos = Spring.TraceScreenRay(mouseX, mouseY, true)

    -- If there is no ground position, adjust the camera vertically
    if not groundPos then
        local cameraYDelta = value * 10
        Spring.SetCameraState({
            vy = cameraState.vy + cameraYDelta
        }, 0)
    else
        -- Otherwise, adjust the camera position based on the ground position
        local dx = groundPos[1] - cameraState.px
        local dy = groundPos[2] - cameraState.py
        local dz = groundPos[3] - cameraState.pz
        -- local distance = math.sqrt((dx * dx) + (dy * dy) + (dz * dz))
        local speed = (up and 1 or -1) * (1 / 8)

        dx = dx * speed
        dy = dy * speed
        dz = dz * speed

        local newCameraState = {
            px = cameraState.px + dx,
            py = cameraState.py + dy,
            pz = cameraState.pz + dz,
            vx = 0,
            vy = 0,
            vz = 0
        }

        Spring.SetCameraState(newCameraState, 0)
    end

    return true
end

