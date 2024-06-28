function widget:GetInfo()
	return {
		name	= "Camera Minimum Height",
		desc	= "Prevents you from zooming all the way to the ground, all the way to desired level - configurable in settings",
		author	= "Damgam",
		date	= "2022",
		license = "GNU GPL, v2 or later",
		layer	= -3,
		enabled	= true,
	}
end

local defaultDesiredLevel = 300
local desiredLevel = Spring.GetConfigInt("MinimumCameraHeight", defaultDesiredLevel)
local optionRefresh = 0
local fastUpdateRate = false

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > (fastUpdateRate and 0.03 or 0.4) then
		sec = 0
		if WG['advplayerlist_api'] and WG['advplayerlist_api'].GetLockPlayerID() ~= nil then
			return
		end

		local camstate = Spring.GetCameraState()
		if camstate.name == "ta" then
			fastUpdateRate = camstate.height < (desiredLevel + 250)
			if camstate.height < desiredLevel then
				camstate.height = desiredLevel
				Spring.SetCameraState(camstate, Spring.GetConfigFloat("CameraTransitionTime", 0))
			end
		elseif camstate.name == "spring"  then
			fastUpdateRate = camstate.dist < (desiredLevel + 250)
			if camstate.dist < desiredLevel then
				camstate.dist = desiredLevel
				Spring.SetCameraState(camstate, Spring.GetConfigFloat("CameraTransitionTime", 0))
			end
		end

		optionRefresh = optionRefresh+1
		if optionRefresh > 30 then
			optionRefresh = 0
			desiredLevel = Spring.GetConfigInt("MinimumCameraHeight", defaultDesiredLevel)
		end
	end
end
