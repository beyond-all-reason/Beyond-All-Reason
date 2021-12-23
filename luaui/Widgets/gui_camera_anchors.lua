-- Add to your uikeys.txt:
-- bind m,1   set_camera_anchor 1
-- bind n,1 focus_camera_anchor 1
-- quickly tap m followed by 1 to set anchor 1
-- quickly tap n followed by 1 to focus on anchor 1
-- etc etc
function widget:GetInfo()
    return {
      name      = "Camera Anchors",
      desc      = "Adds keybindings for Camera Anchors",
      author    = "badosu",
      date      = "Oct 06, 2021",
      license   = "GNU GPL, v2 or later",
      layer     = 0,
      enabled   = true
    }
end

local GetCameraState      = Spring.GetCameraState
local SetCameraTarget     = Spring.SetCameraTarget

function widget:Initialize()
  widgetHandler:AddAction("set_camera_anchor", SetCameraAnchor, nil, "t")
  widgetHandler:AddAction("focus_camera_anchor", FocusCameraAnchor, nil, "t")
end

local cameraAnchors = {}

function SetCameraAnchor(_, _, args)
  local anchorId = args[1]
  local cameraState = GetCameraState()

  cameraAnchors[anchorId] = {cameraState.px, cameraState.py, cameraState.pz}

  Spring.Echo("Camera anchor set: " .. anchorId)
  -- Spring.Echo("set: " .. cameraState.px .. "x " .. cameraState.pz .. "z " .. cameraState.py .. "y")

  return true
end

function FocusCameraAnchor(_, _, args)
  local anchorId = args[1]
  local cameraAnchor = cameraAnchors[anchorId]

  if cameraAnchor then
    SetCameraTarget(cameraAnchor[1], 0, cameraAnchor[3])

    -- Spring.Echo("Camera focus: " .. anchorId)
    -- Spring.Echo("focus: " .. cameraAnchor[1] .. "x " .. cameraAnchor[3] .. "z " .. cameraAnchor[2] .. "y")

    return true
  else
    return false
  end
end
