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

local CameraRotationModes = {
	none = 1,
	autoFlip = 2,
	autoRotate = 3,
}

local mode
local prevSnap


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spSetMiniRot		= 	Spring.SetMiniMapRotation
local spGetMiniRot		= 	Spring.GetMiniMapRotation
local PI = math.pi
local HALFPI = PI / 2

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function minimapRotateHandler(_, _, args)
	if mode ~= CameraRotationModes.none then
		mode = CameraRotationModes.none --TODO: settings menu doesn't update realtime (workaround reloading the options widget to force `getMode`)
	end

	args = args or {}
	local rotationArg = args[1] and tonumber(args[1])
	local absoluteArg = args[2] == "absolute"

	if not rotationArg then return end

	if rotationArg % 90 ~= 0 then
		Spring.Echo("[MinimapRotate] Invalid rotation argument. Received: " .. rotationArg)
		return
	end

	local rotationIndex = ((rotationArg / 90) % 4 + 4) % 4 -- Normalize to 0-3 range and Negative values

	local newRotation
	if absoluteArg then
		newRotation = rotationIndex * HALFPI
	else
		local currentRotation = spGetMiniRot()
		local currentIndex = math.floor((currentRotation / HALFPI + 0.5) % 4)
		newRotation = ((currentIndex + rotationIndex) % 4) * HALFPI
	end

	spSetMiniRot(newRotation)
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

	widgetHandler:AddAction("minimap_rotate", minimapRotateHandler, nil, "pR")
end

function widget:Shutdown()
	WG['minimaprotationmanager'] = nil
end

function widget:CameraRotationChanged(_, roty)
	if mode == CameraRotationModes.none then return end
	local newRot
	if mode == CameraRotationModes.autoFlip then
		newRot = PI * math.floor((roty/PI) + 0.5)
	elseif mode == CameraRotationModes.autoRotate then
		newRot = HALFPI * (math.floor((roty/HALFPI) + 0.5) % 4)
	end
	if newRot ~= prevSnap then
		prevSnap = newRot
		spSetMiniRot(newRot)
	end
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
