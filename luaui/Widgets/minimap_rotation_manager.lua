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

local mode = 2 -- 1 = manual, 2 = auto flip, 3 = auto rotate
local oldRotation
local prevSnap


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spSetMiniRot		= 	Spring.SetMiniMapRotation
local spGetMiniRot		= 	Spring.GetMiniMapRotation

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function manual_rotate(_,_,_, clock)
	if mode ~= 1 then return end
	local currentRadians = spGetMiniRot()
	local currRotOption = math.floor((currentRadians / (math.pi / 2) + 0.5) % 4)
	local newOption = (clock[1]) and ((currRotOption + 1) % 4) or ((currRotOption - 1) % 4)

	spSetMiniRot(newOption * (math.pi / 2))
end



local function reloadBindings()
	if mode ~= 1 then
		widgetHandler:RemoveAction("rotate_clockwise")
		widgetHandler:RemoveAction("rotate_counterclockwise")
	else
		widgetHandler:AddAction("rotate_clockwise", manual_rotate, {true}, "p")
		widgetHandler:AddAction("rotate_counterclockwise", manual_rotate, {false}, "p")
	end
end


function widget:Initialize()
	WG['minimaprotationmanager'] = {}
	WG['minimaprotationmanager'].setMode = function(newMode)
		mode = newMode
		reloadBindings()
	end
	WG['minimaprotationmanager'].getMode = function()
		return mode
	end
	mode = WG['options'].getOptionValue("minimaprotation") -- Sync up when the widget was unloaded
	oldRotation = Spring.GetConfigInt("MiniMapCanFlip", 0) -- Store engine legacy behavior
	Spring.SetConfigInt("MiniMapCanFlip", 0)
	reloadBindings()
end

function widget:Shutdown()
	WG['minimaprotationmanager'] = nil
	Spring.SetConfigInt("MiniMapCanFlip", oldRotation)
end

function widget:CameraRotationChanged(_, roty)
	if mode == 1 then return end
	local newRot
	if mode == 2 then
		newRot = math.pi * math.floor((roty/math.pi) + 0.5)
	elseif mode == 3 then
		newRot = math.pi/2 * (math.floor((roty/(math.pi/2)) + 0.5) % 4)
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
