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

local math_clamp = math.clamp
local math_sqrt = math.sqrt
local math_round = math.round
local spIsUnitInView = Spring.IsUnitInView
local spGetCameraState = Spring.GetCameraState
local spGetConfigFloat = Spring.GetConfigFloat
local spGetConfigInt = Spring.GetConfigInt
local spSetConfigInt = Spring.SetConfigInt

local VolumeSetting = spGetConfigInt("snd_volbattle_options", 100)
local VolumeTarget = 1
local PreviousVolumeTarget = 1

local timer = 0
local cameraHeight = 0

local unitDamagedScale = 1
function gadget:Update(dt)
    timer = timer + dt
    if timer > 0.2 then
        timer = 0
        local camera = spGetCameraState()
        if camera.name == "spring" then
            cameraHeight = camera.dist
        elseif camera.name == "ta" then
            cameraHeight = camera.height
        elseif camera.name == "rot" or camera.name == "fps" or camera.name == "free" then
            cameraHeight = camera.py
        end
        cameraHeight = (cameraHeight/2) * spGetConfigFloat("snd_zoomVolume", 1.00)
        VolumeSetting = spGetConfigInt("snd_volbattle_options", 100)

        local cameraScale = math_clamp((100-math_sqrt(cameraHeight)), 3, 100)/100

        VolumeTarget = math_round(math_clamp(VolumeSetting * cameraScale * unitDamagedScale, 1, 100))
        if VolumeTarget ~= PreviousVolumeTarget then
            spSetConfigInt("snd_volbattle", VolumeTarget)
            PreviousVolumeTarget = VolumeTarget
        end
    end

    if unitDamagedScale < 1 then
        unitDamagedScale = math_clamp(unitDamagedScale + dt*(0.1-(unitDamagedScale*0.1)), 0.4, 1)
        if unitDamagedScale > 0.9999 then unitDamagedScale = 1 end
    end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponDefID, projectileID, attackerID, attackerDefID, attackerTeam)
    if paralyzer or damage <= 0 or unitDamagedScale <= 0.4 then
        return
    end

    if spIsUnitInView(unitID) then
        -- collapse cascading thresholds into a single multiplier
        local mult = 0.9995
        if damage > 100000 then
            mult = 0.9995 * 0.9995 * 0.9995 * 0.9995 -- ~0.998
        elseif damage > 10000 then
            mult = 0.9995 * 0.9995 * 0.9995 -- ~0.9985
        elseif damage > 1000 then
            mult = 0.9995 * 0.9995 -- ~0.999
        end
        unitDamagedScale = unitDamagedScale * mult
    end
end
