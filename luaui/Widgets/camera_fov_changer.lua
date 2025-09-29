local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name      = "FOV changer",
	desc      = "shortcuts: keypad 1/7 or CTRL+O/P",
	author    = "",
	date      = "",
	license   = "GNU GPL, v2 or later",
	layer     = 999999,
	enabled   = false
	}
end

local fovStep = 5
local FOVminus = 111 -- CTRL+O
local FOVplus = 112 -- CTRL+P
local FOVminus2 = 257 --KP1
local FOVplus2 = 263 --KP7

function widget:KeyRelease(key, modifier)
	--Spring.Echo(key)
	if ((key == FOVplus and modifier.ctrl) or key == FOVplus2 or (key == FOVminus and modifier.ctrl) or key == FOVminus2) then
		local current_cam_state = Spring.GetCameraState()
		if key == FOVplus or key == FOVplus2 then
			current_cam_state.fov = math.floor(current_cam_state.fov + fovStep)
			if current_cam_state.fov > 100 then	-- glitches beyond 100
				current_cam_state.fov = 100
			end
		else
			current_cam_state.fov = math.floor(current_cam_state.fov - fovStep)
			if current_cam_state.fov < 0 then
				current_cam_state.fov = 0
			end
		end
		Spring.Echo('target FOV: '..current_cam_state.fov)
		Spring.SetCameraState(current_cam_state, WG['options'] and WG['options'].getCameraSmoothness() or 2)
	end
end
