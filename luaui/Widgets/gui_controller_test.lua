local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Controller Test",
		desc      = "Tests Controller Stuff",
		author    = "badosu",
		date      = "Oct 2022",
		license   = "GNU GPL, v2 or later",
		layer     = 0
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo

local connectedController
local reportState = false

function widget:Initialize()
	if not Spring.GetAvailableControllers then
		spEcho("ControllerTest: Spring.GetAvailableControllers not available")
		return
	end
	local availableControllers = Spring.GetAvailableControllers()

	if next(availableControllers) == nil then
		spEcho("ControllerTest: No available controllers")
		return
	end

	spEcho("ControllerTest: Found controllers")
	spEcho(availableControllers)

	-- Find already connected controllers and disconnect if more than 1 already connected
	for _, controller in pairs(availableControllers) do
		if controller.instanceId then
			if connectedController then
				spEcho("ControllerTest: Already connected to " .. connectedController .. ". Disconnecting " .. controller.instanceId .. ": " .. controller.name)
				Spring.DisconnectController(controller.instanceId)
			else
				spEcho("ControllerTest: Using already connected " .. controller.instanceId .. ": " .. controller.name)
				connectedController = controller.instanceId
			end
		end
	end

	if not connectedController then
		-- get any controller to connect to
		local deviceId, controller = next(availableControllers)
		spEcho("ControllerTest: No controllers connected, connecting to " .. deviceId .. ": " .. controller.name)
		Spring.ConnectController(deviceId)
	end
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 1 and connectedController and reportState then
		uiSec = 0

		spEcho("ControllerTest: Controller State")
		spEcho(Spring.GetControllerState(connectedController))
	end
end

function widget:ControllerAdded(deviceId)
	spEcho("ControllerTest: Added", deviceId)

	if not connectedController then
		spEcho("ControllerTest: Connecting to ", deviceId)
		Spring.ConnectController(deviceId)
	end
end

function widget:ControllerConnected(instanceId)
	spEcho("ControllerTest: Connected", instanceId)

	if not connectedController then
		spEcho("ControllerTest: Connection to " .. instanceId .. " established")
		connectedController = instanceId
	end
end

function widget:ControllerRemoved(instanceId)
	spEcho("ControllerTest: Removed", instanceId)

	if connectedController == instanceId then
		spEcho("ControllerTest: Disconnecting", instanceId)
		Spring.DisconnectController(instanceId)
	end
end

function widget:ControllerRemapped(instanceId)
	spEcho("ControllerTest: Remapped", instanceId)
end

function widget:ControllerDisconnected(instanceId)
	spEcho("ControllerTest: Disconnected", instanceId)

	if connectedController == instanceId then
		spEcho("ControllerTest: Removed Connection")
		connectedController = nil
	end
end

function widget:ControllerButtonUp(instanceId, buttonId, state, name)
	if instanceId ~= connectedController then
		spEcho("ControllerTest: ButtonUp -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	spEcho("ControllerTest: ButtonUp", instanceId, buttonId, state, name)
end

function widget:ControllerButtonDown(instanceId, buttonId, state, name)
	if instanceId ~= connectedController then
		spEcho("ControllerTest: ButtonDown -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	spEcho("ControllerTest: ButtonDown", instanceId, buttonId, state, name)
end

function widget:ControllerAxisMotion(instanceId, axisId, value, name)
	if instanceId ~= connectedController then
		spEcho("ControllerTest: AxisMotion -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	spEcho("ControllerTest: AxisMotion", instanceId, axisId, value, name)
end
