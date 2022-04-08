function widget:GetInfo()
	return {
		name = "CameraFlip",
		desc = "Press ctrl+shift+o to flip the camera \n(with overhead or smooth cam)",
		author = "Bluestone",
		date = "11/09/2013",
		license = "WTFPL",
		layer = 0,
		enabled = true
	}
end

local function cameraFlipHandler()
	local camState = Spring.GetCameraState()
	--Spring.Echo(camState.mode)
	if camState.mode ~= 1 and camState.mode ~= 5 then return end --do nothing unless overhead cam or smooth cam
	--Spring.Echo(camState.flipped)
	camState.flipped = camState.flipped * -1
	Spring.SetCameraState(camState, 0)
end

function widget:Initialize()
	widgetHandler:AddAction("cameraflip", cameraFlipHandler, nil, "p")
end
