local STARTUP_CAMERA_INITIAL_ZOOM_DISTANCE = 5000

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Camera Startup",
		desc = "Organize the camera to point at the startbox at the start of the game",
		author = "uBdead",
		date = "June 2026",
		license = "GNU LGPL, v2.1 or later",
		layer = 1, -- hypothetical stuff in layer = 0 could be doing things to boxes
		enabled = true,
	}
end

function removeSelf()
	widgetHandler:RemoveWidget()
end

function widget:Initialize()
	if Spring.GetGameFrame() > 0 then
		removeSelf()
		return
	end

	local nameCameraState = Spring.GetCameraState(true)
	if nameCameraState.name ~= "ta" and nameCameraState.name ~= "spring" then
		removeSelf()
		return
	end

	-- Calculate the center of the startbox (or map for spectators)
	local xMin, zMin, xMax, zMax

	local isSpectator = select(1, Spring.GetSpectatingState())
	if isSpectator then
		xMin = 0
		zMin = 0
		xMax = Game.mapSizeX
		zMax = Game.mapSizeZ
	else
		xMin, zMin, xMax, zMax = Spring.GetAllyTeamStartBox(Spring.GetLocalAllyTeamID())
	end

	if not xMin or not zMin or not xMax or not zMax then
		return
	end

	local centerX = (xMin + xMax) / 2
	local centerZ = (zMin + zMax) / 2

	Spring.SetCameraTarget(centerX, 0, centerZ, 0.0000001)

	-- Set a reasonable zoom level
	-- We need to get the camera state again due to the earlier SetCameraTarget call changed it
	local currentCameraState = Spring.GetCameraState(true)
	currentCameraState.height = STARTUP_CAMERA_INITIAL_ZOOM_DISTANCE
	currentCameraState.dist = STARTUP_CAMERA_INITIAL_ZOOM_DISTANCE

	Spring.SetCameraState(currentCameraState)

	removeSelf()
end
