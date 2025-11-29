function widget:GetInfo()
	return {
		name = "Minimap Rotation Manager",
		desc = "Manages rotation states of the minimap.",
		author = "TheFutureKnight",
		date = "2025-24-4",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


-- Localized functions for performance
local mathFloor = math.floor

-- Localized Spring API for performance
local spEcho = Spring.Echo

--[[
	Minimap Rotation Manager
	-----------------------------------------------
	Manages and handles the rotation of the minimap based on camera rotation (Automatic rotation) or Manual Commands (Keybinds).
	Via Engine calls, it can automatically adjust the minimap rotation to match the camera's orientation (90 or 180 degree increments).

	Supports three modes:
	1. none - No automatic rotation, manual control only.
	2. autoFlip - Automatically flips the minimap to match the camera's orientation (180 degrees).
	3. autoRotate - Automatically rotates the minimap in 90-degree increments to match the camera's orientation.

	Modes can be set via the settings menu or utilising the keybinds that come with this manager.

	Keybinds:
		Modules:
			- mode [none|autoFlip/180|autoRotate/90] - Sets the rotation mode. Shortcut instead of settings menu.

			- set [degrees] [absolute] - Sets the minimap rotation to a specific degree, either absolute or relative to current rotation.
				- degrees - Must be a multiple of 90 (e.g., 0, 90, 180, 270).
				- absolute - If specified, sets the rotation to the exact degree; otherwise, it rotates relative to the current rotation.
				- if auto-tracking is enabled (via autoFlip or autoRotate modes), it will lock the auto-tracking during manual rotation until toggled off.

			- toggleTracking - Toggles the auto-tracking lock, preventing automatic updates while manual rotation is in progress.
				- This is useful when you want to manually adjust the minimap without it snapping back to the camera's rotation.
				- Then toggle it back to enable auto-tracking again.
		Examples usage:
			- minimap_rotate mode autoRotate
			- minimap_rotate set 90 absolute
			- minimap_rotate toggleTracking
]]--

local CameraRotationModes = {
	none = 1,
	autoFlip = 2,
	autoRotate = 3,
}

local mode
local prevSnap
local trackingLock = false


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spSetMiniRot		= 	Spring.SetMiniMapRotation
local spGetMiniRot		= 	Spring.GetMiniMapRotation
local PI = math.pi
local HALFPI = PI / 2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function minimapRotateHandler(_, _, args)
	args = args or {}
	local module = args[1]
	if module == "mode" then
		if not args[2] then
			spEcho("[MinimapManager] No mode specified. Available modes: none, autoFlip|180, autoRotate|90")
			return
		end

		local modeMap = {
			["none"] = CameraRotationModes.none,
			["autoFlip"] = CameraRotationModes.autoFlip,
			["180"] = CameraRotationModes.autoFlip,
			["autoRotate"] = CameraRotationModes.autoRotate,
			["90"] = CameraRotationModes.autoRotate
		}

		local newMode = modeMap[args[2]]
		if not newMode then
			spEcho("[MinimapManager] Invalid mode specified: " .. args[2] .. ". Available modes: none, autoFlip|180, autoRotate|90")
			return
		end

		WG['options'].applyOptionValue("minimaprotation", newMode)
		spEcho("[MinimapManager] Mode set to " .. args[2])
		return true

	elseif module == "set" then

		local rotationArg = tonumber(args[2]) or nil
		local absoluteArg = args[3] == "absolute"

		if not rotationArg or rotationArg % 90 ~= 0 then
			spEcho("[MinimapManager] Rotation must be a multiple of 90. Received: " .. rotationArg)
			return
		end

		local rotationIndex = ((rotationArg / 90) + 4) % 4 -- Normalize to 0-3 range and Negative values

		local newRotation
		if absoluteArg then
			newRotation = rotationIndex * HALFPI
		else
			local currentRotation = spGetMiniRot()
			local currentIndex = mathFloor((currentRotation / HALFPI + 0.5) % 4)
			newRotation = ((currentIndex + rotationIndex) % 4) * HALFPI
		end

		if not trackingLock then
			trackingLock = true
			spEcho("[MinimapManager] Auto-tracking locked during manual rotation")
		end

		spSetMiniRot(newRotation)
		return true

	elseif module == "toggleTracking" then
		trackingLock = not trackingLock
		spEcho("[MinimapManager] Tracking lock is now " .. (trackingLock and "enabled" or "disabled"))
		return true
	else
		spEcho("[MinimapManager] Invalid module. Usage: mode [none|autoFlip/180|autoRotate/90], set [degrees] [absolute], toggleLock")
	end
end

local function isValidOption(num)
	if num == nil then return false end
	if num < CameraRotationModes.none or num > CameraRotationModes.autoRotate then return false end
	return true
end

function widget:Initialize()
	WG['minimaprotationmanager'] = {}
	WG['minimaprotationmanager'].setMode = function(newMode)
		if isValidOption(newMode) then
			mode = newMode
			prevSnap = nil
			trackingLock = false
			widget:CameraRotationChanged(Spring.GetCameraRotation()) -- Force update on mode change
		end
	end

	WG['minimaprotationmanager'].getMode = function()
		return mode
	end

	local temp = WG['options'].getOptionValue("minimaprotation")
	if isValidOption(temp) then -- Sync up when the widget was unloaded
		mode = temp
	end

	Spring.SetConfigInt("MiniMapCanFlip", 0)

	widgetHandler:AddAction("minimap_rotate", minimapRotateHandler, nil, "p")
end

function widget:Shutdown()
	WG['minimaprotationmanager'] = nil
end

function widget:CameraRotationChanged(_, roty)
	if mode == CameraRotationModes.none or trackingLock then return end
	local newRot
	if mode == CameraRotationModes.autoFlip then
		newRot = PI * mathFloor((roty/PI) + 0.5)
	elseif mode == CameraRotationModes.autoRotate then
		newRot = HALFPI * (mathFloor((roty/HALFPI) + 0.5) % 4)
	end
	if newRot ~= prevSnap then
		prevSnap = newRot
		spSetMiniRot(newRot)
	end
end

-- remove this after engine update
function widget:Update(dt)
	widget:CameraRotationChanged(Spring.GetCameraRotation())
end


function widget:GetConfigData()
	return {
		mode = mode
	}
end


function widget:SetConfigData(data)
	if data.mode ~= nil then
		mode = data.mode
	end
end
