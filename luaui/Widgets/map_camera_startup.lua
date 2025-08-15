local widget = widget ---@type Widget

function widget:GetInfo()
    return {
        name    = "Map Camera Startup",
        desc    = "",
        author  = "uBdead",
        date    = "Jul 28 2025",
        license = "GPL v3 or later",
        layer   = 0,
        enabled = true
    }
end

local startTimer = 1
if Spring.GetConfigInt('enableintrocamera', 1) == 0 then
    startTimer = -5
end
local fase = 0

local oldCam = Spring.GetCameraState()

WG["IntroCameraIsDone"] = false

function widget:Update(dt)
    if (dt > 0.5) then
        -- If the dt is too large, we might be lagging, so we skip this update
        return
    end

    local cameraName = Spring.GetCameraState(false)
    if cameraName ~= "spring" and cameraName ~= "ta" then -- If the camera is not in spring or ta mode, we don't need to do anything
        if not WG["IntroCameraIsDone"] then
            WG["IntroCameraIsDone"] = true
        end
        return
    end
    
    if fase == 0 then
        WG["IntroCameraInitialised"] = true
        -- Start by zooming out to the maximum zoom level
        local mapcx = Game.mapSizeX / 2
        local mapcz = Game.mapSizeZ / 2
        local mapcy = Spring.GetGroundHeight(mapcx, mapcz)
        oldCam = Spring.GetCameraState()
        local newCam = {
            px = mapcx,
            py = mapcy + 1000000, -- Set a high initial height to zoom out
            pz = mapcz,
            dx = 0,
            dy = -0.85,
            dz = -0.50,
            rx = 5,
            ry = 0,
            rz = 0,
            angle = 0.0,
            height = 1000000, -- Set a high initial height to zoom out
            dist = 1000000,
        }
        Spring.SetCameraState(newCam, 0)

        fase = 1
        WG["IntroCameraIsDone"] = false
        return
    end

    local _,_,spec = Spring.GetPlayerInfo(Spring.GetMyPlayerID()) 
    if startTimer <= 0 and startTimer >= -5 and not spec then
        local camState = Spring.GetCameraState()

        -- Center the camera on the startbox
        local myAllyTeamID = Spring.GetMyAllyTeamID()
        local xn, zn, xp, zp = Spring.GetAllyTeamStartBox(myAllyTeamID)
        local x = (xn + xp) / 2
        local z = (zn + zp) / 2

        local mapHeightAtPos = Spring.GetGroundHeight(x, z)
        -- calculate the height based on the diagonal of the startbox
        local width = math.abs(xp - xn)
        local depth = math.abs(zp - zn)
        local diagonal = math.sqrt(width * width + depth * depth)
        local height = diagonal * 1.1 + mapHeightAtPos -- adjust multiplier as needed

        camState.px = x
        camState.pz = z
        camState.height = height
        camState.dist = height
        camState.zoom = height / 2 -- Set a reasonable zoom level

        if Spring.GetConfigInt('camerapreserveangleonstart', 0) == 1 then
            camState.dx = oldCam.dx
            camState.dy = oldCam.dy
            camState.dz = oldCam.dz
            camState.rx = oldCam.rx
            camState.ry = math.clamp(oldCam.ry, -6.5, 6.5)
            camState.rz = oldCam.rz
            camState.angle = oldCam.angle
        else
            camState.dx = 0
            camState.dy = -0.85
            camState.dz = -0.50
            camState.rx = 2.6
            camState.ry = 0
            camState.rz = 0
            camState.angle = 0.54
        end



        WG["IntroCameraIsDone"] = false
        Spring.SetCameraState(camState, 3.25)
        
    end

    if startTimer < -5 or spec then
        WG["IntroCameraIsDone"] = true
        
        local camState = Spring.GetCameraState()
        if camState.ry > 6.5 or camState.ry < -6.5 then
            camState.ry = 0
            Spring.SetCameraState(camState, 0)
        end
    end

    startTimer = startTimer - dt
end
