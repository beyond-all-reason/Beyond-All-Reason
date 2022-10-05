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

function widget:Initialize()
	-- availableControllers = Spring.GetAvailableControllers()

	-- if #availableControllers > 0 then
	-- 	Spring.Echo("ControllerTest: Found controllers")
	-- 	Spring.Debug.TableEcho(availableControllers)
	-- else
	-- 	Spring.Echo("ControllerTest: No available controllers")
	-- end
	connectedController = Spring.ConnectController(0)
end

local uiSec = 0
function widget:Update(dt)
	uiSec = uiSec + dt
	if uiSec > 1 and connectedController then
		uiSec = 0

		-- Spring.Echo("ControllerTest: Controller State")
		-- Spring.Debug.TableEcho(Spring.GetControllerState(connectedController))
	end
end

function widget:ControllerAdded(deviceId)
	Spring.Echo("ControllerTest: Added", deviceId)

	if not connectedController then
		Spring.Echo("ControllerTest: Connecting", deviceId)
		connectedController = Spring.ConnectController(deviceId)

		if not connectedController then
			Spring.Echo("ControllerTest: Connecting failed")
		end
	end
end

function widget:ControllerConnected(instanceId)
	Spring.Echo("ControllerTest: Connected", instanceId)
end

function widget:ControllerRemoved(instanceId)
	Spring.Echo("ControllerTest: Removed", instanceId)

	Spring.DisconnectController(instanceId)
end

function widget:ControllerDisconnected(instanceId)
	Spring.Echo("ControllerTest: Disconnected", instanceId)

	if connectedController == instanceId then
		Spring.Echo("ControllerTest: Removed Connection")
		connectedController = nil
	end
end

function widget:ControllerButtonUp(instanceId, buttonId, state, name)
	Spring.Echo("ControllerTest: ButtonUp", name)
end

function widget:ControllerButtonDown(instanceId, buttonId, state, name)
	Spring.Echo("ControllerTest: ButtonDown", name)
end

function widget:ControllerAxisMotion(instanceId, axisId, value, name)
	Spring.Echo("ControllerTest: AxisMotion", name, value)
end
