local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Camera Startup",
		desc = "Organize the camera to point at the startbox at the start of the game",
		author = "uBdead",
		date = "June 2026",
		license = "GNU LGPL, v2.1 or later",
		layer = 1,
		enabled = true
	}
end

function widget:Initialize()
    -- this is not accidental, we need to get the camera state twice
    local nameCameraState = Spring.GetCameraState(true)
    if nameCameraState.name ~= "ta" and nameCameraState.name ~= "spring" then
        Spring.Echo("Camera Startup: Unsupported camera mode, expected 'ta' or 'spring', got '" .. nameCameraState.name .. "'")
        return
    end

    -- Calculate the center of the startbox
    local xMin,zMin,xMax,zMax = Spring.GetAllyTeamStartBox(Spring.GetMyAllyTeamID())
    if not xMin or not zMin or not xMax or not zMax then
        Spring.Echo("Camera Startup: Failed to get startbox coordinates")
        return
    end

    local centerX = (xMin + xMax) / 2
    local centerZ = (zMin + zMax) / 2

    Spring.SetCameraTarget(centerX, 0, centerZ, 0.0000001)

    -- Set a reasonable zoom level
    local currentCameraState = Spring.GetCameraState(true)
    currentCameraState.height = 5000
    currentCameraState.dist = 5000

    Spring.SetCameraState(currentCameraState)
end
