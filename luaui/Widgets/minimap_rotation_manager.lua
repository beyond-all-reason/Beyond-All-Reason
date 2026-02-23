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

	Supports four modes:
	1. none - No automatic rotation, manual control only.
	2. autoFlip - Automatically flips the minimap to match the camera's orientation (180 degrees).
	3. autoRotate - Automatically rotates the minimap in 90-degree increments to match the camera's orientation.
	4. autoLandscape - Automatically rotates portrait maps by 90° at game start so they display in landscape, then only allows flipping between the two landscape orientations.

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
	autoLandscape = 4,
}

local mode
local prevSnap
local trackingLock = false
local autoFitApplied = false
local autoFitPending = false
local autoFitTargetRot = nil
local autoFitCameraApplied = false
local lastGameID = nil


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spSetMiniRot		= 	Spring.SetMiniMapRotation
local spGetMiniRot		= 	Spring.GetMiniMapRotation
local PI = math.pi
local HALFPI = PI / 2
local TWOPI = PI * 2
local AUTOFIT_HYSTERESIS = PI / 6  -- ~30°: camera must move this far past the midpoint before the minimap flips

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
			["90"] = CameraRotationModes.autoRotate,
			["autoLandscape"] = CameraRotationModes.autoLandscape,
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
	if num < CameraRotationModes.none or num > CameraRotationModes.autoLandscape then return false end
	return true
end

local function applyAutoFitRotation()
	if mode ~= CameraRotationModes.autoLandscape then return end
	local mapSizeX = Game.mapSizeX
	local mapSizeZ = Game.mapSizeZ
	if mapSizeZ > mapSizeX then
		-- Map is portrait-oriented: rotate 90 degrees so it fills the wider minimap GUI area
		if not autoFitTargetRot then
			local camState = Spring.GetCameraState()
			local ry = (camState and camState.ry) or 0
			local sunX, _, sunZ = gl.GetSun("pos")
			-- Compute forward dot sun for both candidate rotations
			local ryPlus = ry + HALFPI
			local ryMinus = ry - HALFPI
			local dotPlus = math.sin(ryPlus) * sunX + math.cos(ryPlus) * sunZ
			local dotMinus = math.sin(ryMinus) * sunX + math.cos(ryMinus) * sunZ
			autoFitTargetRot = dotPlus > dotMinus and HALFPI or -HALFPI
			spEcho("[MinimapManager] AutoFit: sun=(" .. sunX .. ", " .. sunZ .. ") ry=" .. ry .. " dotPlus=" .. dotPlus .. " dotMinus=" .. dotMinus .. " -> " .. (autoFitTargetRot > 0 and "+90" or "-90"))
		end

		spSetMiniRot(autoFitTargetRot)

		-- Rotate the camera to match (opposite direction to minimap)
		local camState = Spring.GetCameraState()
		if camState then
			local currentRy = camState.ry or 0
			if not autoFitCameraApplied then
				camState.ry = currentRy - autoFitTargetRot
				Spring.SetCameraState(camState, 0)
				autoFitCameraApplied = true
				spEcho("[MinimapManager] AutoFit: camera rotated to ry=" .. camState.ry)
			end
		end

		-- Verify minimap rotation actually took effect
		local currentRot = spGetMiniRot()
		if currentRot and math.abs(currentRot - autoFitTargetRot) < 0.01 then
			autoFitApplied = true
			autoFitPending = false
		else
			autoFitPending = true
		end
	else
		-- Landscape or square map: no initial rotation needed
		autoFitApplied = true
		autoFitPending = false
	end
end

function widget:Initialize()
	WG['minimaprotationmanager'] = {}
	WG['minimaprotationmanager'].setMode = function(newMode)
		if isValidOption(newMode) then
			mode = newMode
			prevSnap = nil
			trackingLock = false
			if mode == CameraRotationModes.none then
				-- Reset to default unrotated angle when switching to none
				spSetMiniRot(0)
			elseif mode == CameraRotationModes.autoLandscape then
				-- Reset autofit state so it re-applies
				autoFitApplied = false
				autoFitTargetRot = nil
				autoFitCameraApplied = false
				applyAutoFitRotation()
			else
				widget:CameraRotationChanged(Spring.GetCameraRotation()) -- Force update on mode change
			end
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

	-- Auto-landscape will be applied in widget:Update once game is loaded
end

function widget:Shutdown()
	WG['minimaprotationmanager'] = nil
end

function widget:Update()
	if mode ~= CameraRotationModes.autoLandscape or autoFitApplied then return end

	local currentGameID = Game.gameID or Spring.GetGameRulesParam("GameID")
	if not currentGameID then return end  -- game not loaded yet

	if currentGameID ~= lastGameID then
		-- New game: reset so it recalculates direction
		lastGameID = currentGameID
		autoFitTargetRot = nil
		autoFitCameraApplied = false
	end

	-- Always try to apply when not yet applied (handles widget reload too)
	applyAutoFitRotation()
end

function widget:CameraRotationChanged(_, roty)
	if trackingLock then return end

	if mode == CameraRotationModes.autoLandscape then
		if Game.mapSizeZ > Game.mapSizeX then
			-- Portrait map: only allow the two landscape orientations (90° and 270°)
			local newRot
			local distFromBoundary
			-- Boundaries at 0° and 180° (midpoints between 90° and 270°)
			newRot = (PI * mathFloor(((roty - HALFPI) / PI) + 0.5) + HALFPI) % TWOPI
			-- Distance from nearest boundary (0° or 180°)
			local rem = roty % PI
			distFromBoundary = math.min(rem, PI - rem)
			-- Hysteresis: only flip when camera is well past the midpoint boundary
			if prevSnap ~= nil and newRot ~= prevSnap then
				if distFromBoundary < AUTOFIT_HYSTERESIS then
					return  -- too close to boundary, keep current orientation
				end
			end
			if newRot ~= prevSnap then
				prevSnap = newRot
				spSetMiniRot(newRot)
			end
			return
		elseif Game.mapSizeX > Game.mapSizeZ then
			-- Landscape map: only allow 0° and 180°
			local newRot
			local distFromBoundary
			newRot = (PI * mathFloor((roty / PI) + 0.5)) % TWOPI
			distFromBoundary = math.abs((roty % PI) - HALFPI)
			if prevSnap ~= nil and newRot ~= prevSnap then
				if distFromBoundary < AUTOFIT_HYSTERESIS then
					return
				end
			end
			if newRot ~= prevSnap then
				prevSnap = newRot
				spSetMiniRot(newRot)
			end
			return
		else
			-- Square map: free 90° rotation like autoRotate
			local newRot = HALFPI * (mathFloor((roty/HALFPI) + 0.5) % 4)
			if newRot ~= prevSnap then
				prevSnap = newRot
				spSetMiniRot(newRot)
			end
			return
		end
	end

	if mode == CameraRotationModes.none then return end
	local newRot
	if mode == CameraRotationModes.autoFlip then
		newRot = PI * mathFloor((roty/PI) + 0.5)
	elseif mode == CameraRotationModes.autoRotate then
		newRot = HALFPI * (mathFloor((roty/HALFPI) + 0.5) % 4)
	end
	if newRot and newRot ~= prevSnap then
		prevSnap = newRot
		spSetMiniRot(newRot)
	end
end

function widget:GetConfigData()
	return {
		mode = mode,
		lastGameID = lastGameID,
	}
end

function widget:SetConfigData(data)
	if data.mode ~= nil then
		mode = data.mode
	end
	if data.lastGameID ~= nil then
		lastGameID = data.lastGameID
	end
end
