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

local connectedController
local reportState = false

function widget:Initialize()
	if not Spring.GetAvailableControllers then
		Spring.Echo("ControllerTest: Spring.GetAvailableControllers not available")
		return
	end
	local availableControllers = Spring.GetAvailableControllers()

	if next(availableControllers) == nil then
		Spring.Echo("ControllerTest: No available controllers")
		return
	end

	Spring.Echo("ControllerTest: Found controllers")
	Spring.Echo(availableControllers)

	-- Find already connected controllers and disconnect if more than 1 already connected
	for _, controller in pairs(availableControllers) do
		if controller.instanceId then
			if connectedController then
				Spring.Echo("ControllerTest: Already connected to " .. connectedController .. ". Disconnecting " .. controller.instanceId .. ": " .. controller.name)
				Spring.DisconnectController(controller.instanceId)
			else
				Spring.Echo("ControllerTest: Using already connected " .. controller.instanceId .. ": " .. controller.name)
				connectedController = controller.instanceId
			end
		end
	end

	if not connectedController then
		-- get any controller to connect to
		local deviceId, controller = next(availableControllers)
		Spring.Echo("ControllerTest: No controllers connected, connecting to " .. deviceId .. ": " .. controller.name)
		Spring.ConnectController(deviceId)
	end
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 1 and connectedController and reportState then
		uiSec = 0

		Spring.Echo("ControllerTest: Controller State")
		Spring.Echo(Spring.GetControllerState(connectedController))
	end
end

function widget:ControllerAdded(deviceId)
	Spring.Echo("ControllerTest: Added", deviceId)

	if not connectedController then
		Spring.Echo("ControllerTest: Connecting to ", deviceId)
		Spring.ConnectController(deviceId)
	end
end

function widget:ControllerConnected(instanceId)
	Spring.Echo("ControllerTest: Connected", instanceId)

	if not connectedController then
		Spring.Echo("ControllerTest: Connection to " .. instanceId .. " established")
		connectedController = instanceId
	end
end

function widget:ControllerRemoved(instanceId)
	Spring.Echo("ControllerTest: Removed", instanceId)

	if connectedController == instanceId then
		Spring.Echo("ControllerTest: Disconnecting", instanceId)
		Spring.DisconnectController(instanceId)
	end
end

function widget:ControllerRemapped(instanceId)
	Spring.Echo("ControllerTest: Remapped", instanceId)
end

function widget:ControllerDisconnected(instanceId)
	Spring.Echo("ControllerTest: Disconnected", instanceId)

	if connectedController == instanceId then
		Spring.Echo("ControllerTest: Removed Connection")
		connectedController = nil
	end
end

function widget:ControllerButtonUp(instanceId, buttonId, state, name)
	if instanceId ~= connectedController then
		Spring.Echo("ControllerTest: ButtonUp -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	Spring.Echo("ControllerTest: ButtonUp", instanceId, buttonId, state, name)
end

function widget:ControllerButtonDown(instanceId, buttonId, state, name)
	if instanceId ~= connectedController then
		Spring.Echo("ControllerTest: ButtonDown -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	Spring.Echo("ControllerTest: ButtonDown", instanceId, buttonId, state, name)
end

function widget:ControllerAxisMotion(instanceId, axisId, value, name)
	if instanceId ~= connectedController then
		Spring.Echo("ControllerTest: AxisMotion -> Received event from controller not connected by this widget", instanceId, name)
		return
	end

	Spring.Echo("ControllerTest: AxisMotion", instanceId, axisId, value, name)
end
