function gadget:GetInfo()
    return {
    name      = "Battle Volume Controller",
    desc      = "Controls Volume of Battle sounds based on camera zoom",
    author    = "Damgam",
    date      = "2025",
    layer     = 5,
    enabled   = true  --  loaded by default?
    }
end

if gadgetHandler:IsSyncedCode() then
    return false
end

local math_sqrt = math.sqrt
local math_floor = math.floor
local spIsUnitInView = Spring.IsUnitInView
local spGetCameraState = Spring.GetCameraState
local spGetConfigFloat = Spring.GetConfigFloat
local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt

local UPDATE_INTERVAL = 0.2
local SETTINGS_POLL_INTERVAL = 1.0

local DMG_MULT = 0.9995
local DMG_MULT_1K = DMG_MULT * DMG_MULT
local DMG_MULT_10K = DMG_MULT_1K * DMG_MULT
local DMG_MULT_100K = DMG_MULT_10K * DMG_MULT

local VolumeSetting = spGetConfigInt("snd_volbattle_options", 100) or 100
local VolumeTarget = 1.0
local PreviousVolumeTarget = 1.0
local zoomVolume = spGetConfigFloat("snd_zoomVolume", 1.00) or 1.00

local timer = 0.0
local settingsPollTimer = 0.0
local cameraHeight = 0.0

local unitDamagedScale = 1.0
function gadget:Update(dt)
    if unitDamagedScale < 1 then
        local nextScale = unitDamagedScale + dt * (0.1 - (unitDamagedScale * 0.1))
        if nextScale < 0.4 then
            nextScale = 0.4
        elseif nextScale > 1 then
            nextScale = 1
        elseif nextScale > 0.9999 then
            nextScale = 1
        end
        unitDamagedScale = nextScale
    end

    timer = timer + dt
    if timer < UPDATE_INTERVAL then
        return
    end

    timer = timer - UPDATE_INTERVAL

    settingsPollTimer = settingsPollTimer + UPDATE_INTERVAL
    if settingsPollTimer >= SETTINGS_POLL_INTERVAL then
        settingsPollTimer = settingsPollTimer - SETTINGS_POLL_INTERVAL
        VolumeSetting = spGetConfigInt("snd_volbattle_options", 100) or 100
        zoomVolume = spGetConfigFloat("snd_zoomVolume", 1.00) or 1.00
    end

    local camera = spGetCameraState()
        if not camera then
        return
        end
    local cameraName = camera.name
    if cameraName == "spring" then
        cameraHeight = camera.dist or cameraHeight
    elseif cameraName == "ta" then
        cameraHeight = camera.height or cameraHeight
    elseif cameraName == "rot" or cameraName == "fps" or cameraName == "free" then
        cameraHeight = camera.py or cameraHeight
    end
    cameraHeight = (cameraHeight * 0.5) * zoomVolume

    local cameraScale = 100 - math_sqrt(cameraHeight)
    if cameraScale < 3 then
        cameraScale = 3
    elseif cameraScale > 100 then
        cameraScale = 100
    end
    cameraScale = cameraScale * 0.01

    local target = VolumeSetting * cameraScale * unitDamagedScale
    if target < 1 then
        target = 1
    elseif target > 100 then
        target = 100
    end

    VolumeTarget = math_floor(target + 0.5)
    if VolumeTarget ~= PreviousVolumeTarget then
        spSetConfigInt("snd_volbattle", VolumeTarget)
        PreviousVolumeTarget = VolumeTarget
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if paralyzer or damage <= 0 or unitDamagedScale <= 0.4 then
        return
    end

    if spIsUnitInView(unitID) then
        -- collapse cascading thresholds into a single multiplier
        local mult = DMG_MULT
        if damage > 100000 then
            mult = DMG_MULT_100K -- ~0.998
        elseif damage > 10000 then
            mult = DMG_MULT_10K -- ~0.9985
        elseif damage > 1000 then
            mult = DMG_MULT_1K -- ~0.999
        end
        unitDamagedScale = unitDamagedScale * mult
    end
end
