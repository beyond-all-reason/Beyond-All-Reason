function widget:GetInfo()
  return {
    name      = "Camera Move Middle Mouse (MMB) Hold",
    desc      = "Alternate view movement for the middle mouse button & overhead camera",
    author    = "qknight <js@lastlog.de>",
    date      = "July 2024",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false
  }
end

local mouse_previous_x = 0.0
local mouse_previous_y = 0.0
local view_width, view_height = Spring.GetScreenGeometry()
local view_center_x = view_width/2.0
local view_center_y = view_height/2.0
local map_width  = Game.mapSizeX
local map_height = Game.mapSizeZ
local active = false

-- create none-linear scrolling speeds
local movement_multiplier = 1.5

local x_ratio = map_width/view_width * movement_multiplier
local y_ratio = map_height/view_height * movement_multiplier
--local x_ratio = 3.2 * movement_multiplier
--local y_ratio = 3.2 * movement_multiplier

-- mouse position memory for reset
local mouse_before_x = 0.0
local mouse_before_y = 0.0

function widget:MouseMove(x, y)
  if (active) then
    --Spring.Echo("DEBUG", x_ratio, y_ratio)
    --Spring.Echo("DEBUG", view_width, view_height, map_width, map_height, x_ratio, y_ratio)

	dx = mouse_previous_x - x
	dy = mouse_previous_y - y
		
	local cameraState = Spring.GetCameraState()

	local newCameraState = {
		px = cameraState.px - (dx * x_ratio),
		pz = cameraState.pz + (dy * y_ratio),
	}
	Spring.SetCameraState(newCameraState, 0)	
	Spring.WarpMouse(view_center_x, view_center_y)
	
	mouse_previous_x = view_center_x
	mouse_previous_y = view_center_y
  end	
end

function widget:Update(dt)
  if (active) then
    Spring.SetMouseCursor('none')
  end
end  

function widget:MousePress(x, y, button)
  if (button ~= 2) then
	return false
  end
  if (Spring.IsAboveMiniMap(x, y)) then
	return false
  end
  local cs = Spring.GetCameraState()
  if (cs.name == 'rot' or cs.name == 'free') then
	return false
  end
  
  if (active == false) then
	local lastMouseX, lastMouseY = Spring.GetMouseState()
  
    mouse_previous_x = lastMouseX
    mouse_previous_y = lastMouseY
	mouse_before_x, mouse_before_y = Spring.GetMouseState()
	  
	active = true
	--Spring.Echo("active")

	return true
  end
end


function widget:MouseRelease(x, y, button)
  active = false
  --Spring.Echo("!active")
  Spring.WarpMouse(mouse_before_x, mouse_before_y)
end



