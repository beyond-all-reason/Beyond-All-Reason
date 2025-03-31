local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "CameraFlip",
		desc = "Press ctrl+shift+o to flip the camera \n(with overhead or smooth cam)",
		author = "Bluestone",
		date = "11/09/2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

local function cameraFlipHandler()
	local camState = Spring.GetCameraState()

	if camState.mode ~= 1 and camState.mode ~= 2 then
		return false
	end --do nothing unless overhead or spring cam

	if camState.flipped then -- camera is overhead cam
		camState.flipped = camState.flipped * -1

		Spring.SetCameraState(camState, 0)

		return true
	end

	-- camera is spring cam
	-- CardinalLock messes up rotation
	local cardinalLock = Spring.GetConfigInt("CamSpringLockCardinalDirections")
	local lockCorrection = 0
	if cardinalLock == 1 then
		-- This value must be larger than the cardinal lock width of 0.2
		lockCorrection = 1/3
	end

	if camState.ry > 0 then
		camState.ry = camState.ry - math.pi - lockCorrection
	else
		camState.ry = camState.ry + math.pi + lockCorrection
	end

	Spring.SetCameraState(camState, 0)

	return true
end

function widget:Initialize()
	widgetHandler:AddAction("cameraflip", cameraFlipHandler, nil, "p")
end
