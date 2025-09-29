-- Add to your uikeys.txt:
-- bind m,1   set_camera_anchor 1
-- bind n,1 focus_camera_anchor 1
-- quickly tap m followed by 1 to set anchor 1
-- quickly tap n followed by 1 to focus on anchor 1
-- etc etc
local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Camera Anchors",
		desc      = "Adds keybindings for Camera Anchors",
		author    = "badosu, lonewolfdesign",
		date      = "Mar 12, 2023",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local GetCameraState  = Spring.GetCameraState
local SetCameraState  = Spring.SetCameraState
local GetConfigInt    = Spring.GetConfigInt
local SendCommands    = Spring.SendCommands

function widget:Initialize()
	widgetHandler:AddAction("set_camera_anchor", SetCameraAnchor, nil, 'p')
	widgetHandler:AddAction("focus_camera_anchor", FocusCameraAnchor, nil, 'p')
end

local cameraAnchors = {}

function SetCameraAnchor(_, _, args)
	local anchorId = args[1]
	local cameraState = GetCameraState()

	cameraAnchors[anchorId] = cameraState

	Spring.Echo("Camera anchor set: " .. anchorId)

	return true
end

function FocusCameraAnchor(_, _, args)
	local anchorId = args[1]
	local cameraState = cameraAnchors[anchorId]

	if not cameraState then return end

	-- make sure if last camera state minimized minimap to unminimize it
	-- overview camera hides minimap
	if GetConfigInt("MinimapMinimize", 0) == 0 then
		SendCommands("minimap minimize 0")
	end

	SetCameraState(cameraState, 0)

	return true
end
