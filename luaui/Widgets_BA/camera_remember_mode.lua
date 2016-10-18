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

local camName
local defaultCamName = 'ta'

function GetModeFromName(name)
    local camNames = Spring.GetCameraNames()
    return camNames[name]
end

function widget:SetConfigData(data)
    camName = data and data.name or defaultCamName
end

function widget:Initialize()
    avoidOverviewCam(); -- bug is when you switch from overview to spring

    --Spring.Echo("wanted", camName)
    if camName then
        local camState = Spring.GetCameraState()
        camState.name = camName
        camState.mode = GetModeFromName(camName)
        --Spring.Echo("set", camName, camState.mode)
        Spring.SetCameraState(camState, 0)
    end

    avoidOverviewCam() -- and we don't want to switch to overview at game start anyway
end

function avoidOverviewCam()
    local camState = Spring.GetCameraState()
    if camState.name == 'ov' then -- dirty workaround for https://springrts.com/mantis/view.php?id=5028
        Spring.Echo("Warning: you have Overview camera as default. This camera is not intended to start game with. Switching to TA camera.");
        camState.name = defaultCamName
        camState.mode = GetModeFromName(defaultCamName)
        Spring.SetCameraState(camState, 0)
    end
end

function widget:GetConfigData()
    local camState = Spring.GetCameraState()
    local data = {}
    data.name = camState.name
    --Spring.Echo("saved", data.name, camState.mode)
    return data
end

