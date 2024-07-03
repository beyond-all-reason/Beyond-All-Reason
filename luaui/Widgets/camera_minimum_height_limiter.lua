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
local vsx,vsy = Spring.GetViewGeometry()

function widget:ViewResize()
	vsx,vsy = Spring.GetViewGeometry()
end

local sec = 0
function widget:Update(dt)
	sec = sec + dt
	if sec > (fastUpdateRate and 0.001 or 0.15) then
		sec = 0
		if WG['advplayerlist_api'] and WG['advplayerlist_api'].GetLockPlayerID() ~= nil then
			return
		end
		local x,y,z = Spring.GetCameraPosition()
		local desc, params = Spring.TraceScreenRay(vsx/2, vsy/2, true)
		if params and params[3] then
			local dist = math.distance3d(x, y, z, params[1], params[2], params[3])
			fastUpdateRate = dist < (desiredLevel + 200)
			if dist < desiredLevel then
				local camstate = Spring.GetCameraState()
				if camstate.name == "ta" then
					if camstate.height < desiredLevel then
						camstate.height = desiredLevel
						Spring.SetCameraState(camstate, Spring.GetConfigFloat("CameraTransitionTime", 0))
					end
				elseif camstate.name == "spring"  then
					if camstate.dist < desiredLevel then
						camstate.dist = desiredLevel
						Spring.SetCameraState(camstate, Spring.GetConfigFloat("CameraTransitionTime", 0))
					end
				end
			end

			optionRefresh = optionRefresh + 1
			if optionRefresh > 20 then
				optionRefresh = 0
				desiredLevel = Spring.GetConfigInt("MinimumCameraHeight", defaultDesiredLevel)
			end
		end
	end
end