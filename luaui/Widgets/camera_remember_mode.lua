local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Camera Remember",
		desc = "Remembers the camera mode",
		author = "Otto Von Lichtenstein",
		date = "April 1st",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local spEcho = Spring.Echo
local spGetCameraState = Spring.GetCameraState
local spSetCameraState = Spring.SetCameraState

local CameraMath = VFS.Include("common/camera_math.lua")

local savedCamState
local defaultCamState = { mode = 2, rx = 2.677, ry = 0.0, rz = 0.0 } --spring

local function avoidOverviewCam()
	local camState = spGetCameraState()
	if camState.mode == 5 then -- dirty workaround for https://springrts.com/mantis/view.php?id=5028
		spEcho("Warning: you have Overview camera as default. Switching to Spring camera.")
		spSetCameraState(defaultCamState, 0)
	end
end

function widget:SetConfigData(data)
	savedCamState = data or defaultCamState
end

function widget:Initialize()
	avoidOverviewCam() -- bug is when you switch from overview to spring
	if savedCamState then
		spSetCameraState(savedCamState, 0)
	end
	avoidOverviewCam() -- and we don't want to switch to overview at game start anyway
end

function widget:GetConfigData()
	-- While a scripted camera sequence plays, the live state is the sequence's: remember the player's own.
	local playerCamState = WG.cinematicCamera and WG.cinematicCamera.GetPlayerCameraState()
	local camState = table.copy(playerCamState or spGetCameraState())
	if camState.ry and Spring.GetConfigInt("CamSpringLockCardinalDirections") == 1 and camState.mode == 2 then
		camState.ry = CameraMath.GetCardinalLockSafeYaw(camState.ry)
	elseif camState.ry then
		camState.ry = math.clampRadians(camState.ry)
	end
	return camState
end
