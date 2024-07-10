function widget:GetInfo()
  return {
    name      = "Camera Move Middle Mouse (MMB) Click",
    desc      = "Alternate view movement for the middle mouse button & overhead camera",
    author    = "qknight <js@lastlog.de>",
    date      = "July 2024",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = false
  }
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
  -- Trace the screen coordinates to the world coordinates
  local traceType, worldPos = Spring.TraceScreenRay(x, y, true)

  if traceType == "ground" then
	local cameraState = Spring.GetCameraState()

	local newCameraState = {
		px = worldPos[1],
		pz = worldPos[3]
	}
	Spring.SetCameraState(newCameraState, 0)		
	return true
  end
  
  return true
end
