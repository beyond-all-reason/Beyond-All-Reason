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
	local previousLock = Spring.GetConfigInt("CamSpringLockCardinalDirections")

	if previousLock == 1 then
		Spring.SetConfigInt("CamSpringLockCardinalDirections", 0)
	end

	camState.ry = camState.ry + math.pi
	Spring.SetCameraState(camState, 0)

	if previousLock == 1 then
		Spring.SetConfigInt("CamSpringLockCardinalDirections", previousLock)
	end

	return true
end

function widget:Initialize()
	widgetHandler:AddAction("cameraflip", cameraFlipHandler, nil, "p")
end
