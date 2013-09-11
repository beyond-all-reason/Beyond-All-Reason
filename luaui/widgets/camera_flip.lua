function widget:GetInfo()
	return {
		name = "CameraFlip",
		desc = "Press ctrl+f to flip the camera \n(with overhead or smooth cam)",
		author = "Bluestone",
		date = "11/09/2013",
		license = "WTFPL",
		layer = 0,
		enabled = true
	}
end

local f = 102

function widget:KeyPress(key,mods,isRepeat)
	if key ~= f then return end
	if isRepeat then return end
	if mods.ctrl ~= true then return end

	local camState = Spring.GetCameraState()
	--Spring.Echo(camState.mode)
	if camState.mode ~= 1 and camState.mode ~= 5 then return end --do nothing unless overhead cam or smooth cam
	--Spring.Echo(camState.flipped)
	if camState.flipped == 1 then 
		camState.flipped = -1
		Spring.SetCameraState(camState,0)
	elseif camState.flipped == -1 then
		camState.flipped = 1
		Spring.SetCameraState(camState,0)
	end
end