
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

	if camState.mode == 2 then
		camState.ry = camState.ry + math.pi

		Spring.SetCameraState(camState, 0)

		return
	end

	if camState.mode ~= 1 and camState.mode ~= 5 then
		return
	end --do nothing unless overhead cam or smooth cam
	
	--Spring.Echo(camState.flipped)
	if camState.flipped then
		camState.flipped = camState.flipped * -1
		Spring.SetCameraState(camState, 0)
	end
end

function widget:Initialize()
	widgetHandler:AddAction("cameraflip", cameraFlipHandler, nil, "p")
end
