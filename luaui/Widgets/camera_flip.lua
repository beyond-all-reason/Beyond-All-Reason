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

	--[[
	When cardinal locking is disabled, the camera's ry (y rotation in radians) is treated literally.
	In this case, simply adding (or subtracting) pi from the ry correctly flips the camera by 180 degrees.

	When cardinal locking is enabled, the camera's ry is interpolated to keep a small part of the
	range near each of the four cardinal directions "sticky" to the cardinal direction.

	However, the interpolation formula has problematic behavior when ry is near zero.
	This requires two adjustments:

	1. Adding pi always works when the initial ry is positive, and subtracting pi
	always works when the initial ry is negative. This avoids crossing 0, which
	would cause issues.
	2. When the initial ry is between (-0.1)halfpi and (0.1)halfpi, adding
	or subtracting pi does not generate a full 180 degree rotation. A small
	correction is necessary to increase the rotation to 180 degrees.

	The interpolation formula is at `static float GetRotationWithCardinalLock(float rot)`
	in `SpringController.cpp`
	]]
	local cardinalLock = Spring.GetConfigInt("CamSpringLockCardinalDirections")
	local lockCorrection = 0
	if cardinalLock == 1 and math.abs(camState.ry) < 0.1 * halfpi then
		-- Edge case around 0.0f: cameare ry's with absolute value less than 0.1 * halfpi
		-- require a small increase in rotation magnitude so that they work with the cardinal locking formula.
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
