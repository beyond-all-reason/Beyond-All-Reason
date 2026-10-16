local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Mission Camera",
		desc = "Runs the Mission API's camera actions through the Cinematic Camera API",
		date = "October 2026",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

-- Sent from luarules/mission_api/actions/camera/ through luarules/gadgets/api_mission_camera.lua.
local handlers = {
	MissionCameraPlay = function(camera, params)
		camera.Play(params)
	end,
	MissionCameraFollow = function(camera, params)
		camera.Follow(params)
	end,
	MissionCameraOrbit = function(camera, params)
		camera.Orbit(params)
	end,
	MissionCameraShake = function(camera, params)
		camera.Shake(params)
	end,
	MissionCameraSave = function(camera, params)
		camera.Save(params.slot)
	end,
	MissionCameraRestore = function(camera, params)
		camera.Restore(params.slot, params.duration, params.easing)
	end,
	MissionCameraStop = function(camera)
		camera.Stop()
	end,
}

function widget:Initialize()
	for name, handler in pairs(handlers) do
		widgetHandler:RegisterGlobal(name, function(params)
			if WG.cinematicCamera then
				handler(WG.cinematicCamera, params)
			end
		end)
	end
end

function widget:Shutdown()
	for name in pairs(handlers) do
		widgetHandler:DeregisterGlobal(name)
	end
end
