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
	manual = 1,
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

local function manual_rotate(_,_,_, clock)
	if mode ~= CameraRotationModes.manual then return end
	local currentRadians = spGetMiniRot()
	local currRotOption = math.floor((currentRadians / (math.pi / 2) + 0.5) % 4)
	local newOption = (clock[1]) and ((currRotOption + 1) % 4) or ((currRotOption - 1) % 4)

	spSetMiniRot(newOption * (math.pi / 2))
end



local function reloadBindings()
	if mode ~= CameraRotationModes.manual then
		widgetHandler:RemoveAction("rotate_minimap_clockwise")
		widgetHandler:RemoveAction("rotate_minimap_counterclockwise")
	else
		widgetHandler:AddAction("rotate_minimap_clockwise", manual_rotate, {true}, "p")
		widgetHandler:AddAction("rotate_minimap_counterclockwise", manual_rotate, {false}, "p")
	end
end

local function isValidOption(num)
	if num == nil then return false end
	if num < CameraRotationModes.manual or num > CameraRotationModes.autoRotate then return false end
	return true
end

function widget:Initialize()
	WG['minimaprotationmanager'] = {}
	WG['minimaprotationmanager'].setMode = function(newMode)
		if isValidOption(newMode) then
			mode = newMode
			reloadBindings()
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
	reloadBindings()
end

function widget:Shutdown()
	WG['minimaprotationmanager'] = nil
	if mode == 1 then
		widgetHandler:RemoveAction("rotate_minimap_clockwise")
		widgetHandler:RemoveAction("rotate_minimap_counterclockwise")
	end
end

function widget:CameraRotationChanged(_, roty)
	if mode == CameraRotationModes.manual then return end
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
