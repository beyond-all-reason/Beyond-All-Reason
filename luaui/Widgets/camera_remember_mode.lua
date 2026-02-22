local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Camera Remember",
    desc      = "Remembers the camera mode",
    author    = "Otto Von Lichtenstein",
    date      = "April 1st",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true,
    reason_for_existence = "laughable"
  }
end


-- Localized Spring API for performance
local spEcho = Spring.Echo

local savedCamState
local defaultCamState = {mode = 2, rx = 2.677, ry = 0.0, rz = 0.0} --spring

function widget:SetConfigData(data)
    savedCamState = data or defaultCamState
end

function widget:Initialize()
	--spEcho("Hello!!!")
    avoidOverviewCam() -- bug is when you switch from overview to spring

    --spEcho("wanted", camName)
    if savedCamState then
        Spring.SetCameraState(savedCamState, 0)
    end

    avoidOverviewCam() -- and we don't want to switch to overview at game start anyway
end

function avoidOverviewCam()
    local camState = Spring.GetCameraState()
    if camState.mode == 5 then -- dirty workaround for https://springrts.com/mantis/view.php?id=5028
        spEcho("Warning: you have Overview camera as default. This camera is not intended to start game with. Switching to Spring camera.");
        Spring.SetCameraState(defaultCamState, 0)
    end
end

function widget:GetConfigData()
    local camState = Spring.GetCameraState()
    local data = {}
    data = table.copy(camState)
    return data
end

