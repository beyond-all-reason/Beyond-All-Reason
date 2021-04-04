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

local savedCamState
local defaultCamState = {mode = 2} --spring

local function deepcopy(orig)
	local orig_type = type(orig)
	local copy
	if orig_type == 'table' then
		copy = {}
		for orig_key, orig_value in next, orig, nil do
			copy[deepcopy(orig_key)] = deepcopy(orig_value)
		end
		setmetatable(copy, deepcopy(getmetatable(orig)))
	else
		-- number, string, boolean, etc
		copy = orig
	end
	return copy
end

function widget:SetConfigData(data)
    savedCamState = data or defaultCamMode
end

function widget:Initialize()
	Spring.Echo("Hello!!!")
    avoidOverviewCam() -- bug is when you switch from overview to spring

    --Spring.Echo("wanted", camName)
    if savedCamState then
        Spring.SetCameraState(savedCamState, 0)
    end

    avoidOverviewCam() -- and we don't want to switch to overview at game start anyway
end

function avoidOverviewCam()
    local camState = Spring.GetCameraState()
    if camState.mode == 5 then -- dirty workaround for https://springrts.com/mantis/view.php?id=5028
        Spring.Echo("Warning: you have Overview camera as default. This camera is not intended to start game with. Switching to Spring camera.");
        Spring.SetCameraState(defaultCamState, 0)
    end
end

function widget:GetConfigData()
    local camState = Spring.GetCameraState()
    local data = {}
    data = deepcopy(camState)
    return data
end

