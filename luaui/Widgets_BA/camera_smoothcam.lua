local versionNumber = "0.5"

function widget:GetInfo()
  return {
    name      = "SmoothCam",
    desc      = "[v" .. string.format("%s", versionNumber ) .. "] Moves camera smoothly",
    author    = "very_bad_soldier",
    date      = "August, 8, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = -100,
	handler   = true,
    enabled   = true
  }
end


function widget:Update(dt)
    Spring.SetCameraState(Spring.GetCameraState(), 0.3)
end

