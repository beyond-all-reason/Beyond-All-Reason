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

local halfpi = math.pi / 2

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

	--[[ Adding pi when positive and subtracting pi when negative allows the camera flip
	to work regardless of the state of cardinal lock. This is because the cardinal lock
	formula in the Recoil engine is not actually symmetrical around the cardinal directions.
	
	For example, when the user experiences cardinal locking to halfpi radians, their
	actual camera ry is required to be between (1.1) * halfpi and (1.3) * halfpi.
	
	Conversely, in order to cardinal lock to -3 * halfpi radians (which is functionally
	equivalent to halfpi radians), the user's actual camera ry is required to be between
	(-3.1) * halfpi radians and (-3.3) * halfpi radians.
	
	In other words, the cardinal lock behavior is asymmetrical with regards to the cardinal
	directions, and the asymmetry is mirrored around 0.0f.

	Notably, behavior around 0.0f is also unusual. All values between (-0.3) * halfpi and
	(0.3) * halfpi will cardinally lock to 0. This requires special handling when ry is
	between -0.1 and 0.1 * halfpi.

	Feel free to investigate and/or fix `static float GetRotationWithCardinalLock(float rot)` in
	`SpringController.cpp`.
	]]

	local cardinalLock = Spring.GetConfigInt("CamSpringLockCardinalDirections")
	local lockCorrection = 0
	if cardinalLock == 1 and math.abs(camState.ry) < 0.1 * halfpi then
		-- Edge case around 0.0f: values with absolute value less than 0.1 * halfpi
		-- should be corrected so that they have absolute value between 0.1 and 0.3 * halfpi.
		lockCorrection = 0.1 * halfpi
	end
	if camState.ry > 0 then
		camState.ry = camState.ry + math.pi + lockCorrection
	else
		camState.ry = camState.ry - math.pi - lockCorrection
	end

	Spring.SetCameraState(camState, 0)

	return true
end

function widget:Initialize()
	widgetHandler:AddAction("cameraflip", cameraFlipHandler, nil, "p")
end
