local widget = widget ---@type Widget

function widget:GetInfo()
	return {
	name      = "FOV changer",
	desc      = "Changes the camera's field of view, either by a relative amount or to a specific value",
	author    = "Floris, Chronographer",
	date      = "April 10, 2019",
	license   = "GNU GPL, v2 or later",
	layer     = 999999,
	enabled   = false
	}
end

-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spEcho = Spring.Echo

--------------------------------------------------------------------------------
-- Bindable actions:	fov [number] - Set Field of View to [number] or 45 degrees
-- 						fov_inc [number] - Increase Field of View [number] or 5 degrees
-- 						fov_dec [number] - Decrease Field of View [number] or 5 degrees	
--------------------------------------------------------------------------------
local FOV_DEFAULT = 40
local STEP_DEFAULT = 5

local fovTarget
local direction

local function limitFieldOfView(fov)
	if fov < 0 then
		return 0
	elseif fov > 100 then -- glitches beyond 100
		return 100 
	else
		return fov
	end
end

local function updateFieldOfView(fovTarget, direction)
	local current_cam_state = Spring.GetCameraState()
	if direction == 1 or direction == -1 then
		current_cam_state.fov = mathFloor(current_cam_state.fov + direction * fovTarget)
		current_cam_state.fov = limitFieldOfView(current_cam_state.fov)
	elseif direction == 0 then
		current_cam_state.fov = limitFieldOfView(fovTarget)
	end

	spEcho('FOV: '..current_cam_state.fov)
	Spring.SetCameraState(current_cam_state, WG['options'] and WG['options'].getCameraSmoothness() or 2)
end

local function fieldOfViewHandler(_, _, args, data, isRepeat, isRelease)
	local data = data or {}
	direction = data["direction"]
	local args = args or {}
	fovTarget = (args[1] and tonumber(args[1])) or (direction == 0 and FOV_DEFAULT or STEP_DEFAULT)
	updateFieldOfView(fovTarget, direction)
	return true
end

function widget:Initialize()
    widgetHandler:AddAction("fov_inc", fieldOfViewHandler, {direction = 1}, "pt")
    widgetHandler:AddAction("fov_dec", fieldOfViewHandler, {direction = -1}, "pt")
	widgetHandler:AddAction("fov", fieldOfViewHandler, {direction = 0}, "pt")
end

function widget:Shutdown()
	widgetHandler:RemoveAction("fov_inc", "pt")
	widgetHandler:RemoveAction("fov_dec", "pt")
	widgetHandler:RemoveAction("fov", "pt")
end
