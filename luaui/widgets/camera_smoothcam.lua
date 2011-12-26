local versionNumber = "0.5"

function widget:GetInfo()
  return {
    name      = "SmoothCam",
    desc      = "[v" .. string.format("%s", versionNumber ) .. "] Moves camera smoothly",
    author    = "very_bad_soldier",
    date      = "August, 8, 2010",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
	handler   = true,
    enabled   = true
  }
end


--------------------------------------------------------------------------------
----------------------------Configuration---------------------------------------
local camSpeed   = 0.35
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
local spGetCameraState   	= Spring.GetCameraState
local spSetCameraState   	= Spring.SetCameraState
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
function widget:Update(dt)
  local cs = spGetCameraState()
  spSetCameraState(cs, camSpeed)
end

