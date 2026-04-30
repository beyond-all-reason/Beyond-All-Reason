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

local savedCamState
local defaultCamState = { mode = 2, rx = 2.677, ry = 0.0, rz = 0.0 } --spring

local function avoidOverviewCam()
	local camState = spGetCameraState()
	if camState.mode == 5 then -- dirty workaround for https://springrts.com/mantis/view.php?id=5028
		spEcho("Warning: you have Overview camera as default. Switching to Spring camera.")
		spSetCameraState(defaultCamState, 0)
	end
end

local HALFPI = math.pi * 0.5
local LOCK_WIDTH = 0.2
local B = 1.0 / (1.0 - LOCK_WIDTH)
local C = 1.0 - B

local function GetRotationWithCardinalLock(rot)
	local q = rot / HALFPI
	local x = math.abs(q) - LOCK_WIDTH * 0.5
	local n = math.modf(x)
	local f = x - n
	local y = n + ((f > LOCK_WIDTH) and (f * B + C) or 0.0)
	return ((q < 0) and -y or y) * HALFPI
end

local function GetCardinalLockSafeYaw(rawYaw)
	local locked = math.clampRadians(GetRotationWithCardinalLock(rawYaw))
	local q = math.abs(locked) / HALFPI
	local n = math.floor(q)
	local f = q - n

	q = n + LOCK_WIDTH * 0.5 + (f - C) / B
	return ((locked < 0) and -q or q) * HALFPI
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
	local camState = table.copy(spGetCameraState())
	if camState.ry and Spring.GetConfigInt("CamSpringLockCardinalDirections") == 1 and camState.mode == 2 then
		camState.ry = GetCardinalLockSafeYaw(camState.ry)
	elseif camState.ry then
		camState.ry = math.clampRadians(camState.ry)
	end
	return camState
end
