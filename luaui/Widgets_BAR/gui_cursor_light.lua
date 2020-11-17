
function widget:GetInfo()
    return {
        name	= "Cursor Light",
        desc	= "adds light to the cursor",
        author	= "Floris",
        date	= "December 2017",
        license	= "GNU GPL, v2 or later",
        layer	= 5,
        enabled	= false,
    }
end

local colorR,colorG,colorB = 1, 0.8, 0.6

local lightRadiusMult = 1.5
local lightStrengthMult = 0.5

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function GetLights(beamLights, beamLightCount, pointLights, pointLightCount)

	local camPanning = select(7, Spring.GetMouseState())
    local mx,my,m1,m2,m3 = Spring.GetMouseState()
    local traceType, tracedScreenRay = Spring.TraceScreenRay(mx, my, true)
    if not camPanning and tracedScreenRay ~= nil then
        local params = {param={} }
        params.px, params.py, params.pz = tracedScreenRay[1],tracedScreenRay[2],tracedScreenRay[3]
        params.param.r, params.param.g, params.param.b = colorR,colorG,colorB
        params.colMult = 1 * lightStrengthMult
        --params.param.radius = 350 * lightRadiusMult
        --params.py = params.py + 50
        --pointLightCount = pointLightCount + 1
        --pointLights[pointLightCount] = params
        params.colMult = params.colMult * 0.4
        params.param.radius = 1000 * lightRadiusMult
        params.py = params.py + 50
        pointLightCount = pointLightCount + 1
        pointLights[pointLightCount] = params
    end
    return beamLights, beamLightCount, pointLights, pointLightCount
end


function widget:Initialize()
    if WG.DeferredLighting_RegisterFunction then
        functionID = WG.DeferredLighting_RegisterFunction(GetLights)
    end

    WG['cursorlight'] = {}
    WG['cursorlight'].setLightStrength = function(value)
        lightStrengthMult = value
        if functionID and WG.DeferredLighting_UnRegisterFunction then
            WG.DeferredLighting_UnRegisterFunction(functionID)
        end
        if WG.DeferredLighting_RegisterFunction then
            functionID = WG.DeferredLighting_RegisterFunction(GetLights)
        end
    end
    WG['cursorlight'].getLightStrength = function()
        return lightStrengthMult
    end
    WG['cursorlight'].setLightRadius = function(value)
        lightRadiusMult = value
        if functionID and WG.DeferredLighting_UnRegisterFunction then
            WG.DeferredLighting_UnRegisterFunction(functionID)
        end
        if WG.DeferredLighting_RegisterFunction then
            functionID = WG.DeferredLighting_RegisterFunction(GetLights)
        end
    end
    WG['cursorlight'].getLightRadius = function()
        return lightRadiusMult
    end
end

function widget:Shutdown()
    if functionID and WG.DeferredLighting_UnRegisterFunction then
        WG.DeferredLighting_UnRegisterFunction(functionID)
    end
    WG['cursorlight'] = nil
end


function widget:GetConfigData(data)
    savedTable = {}
    savedTable.lightRadiusMult = lightRadiusMult
    savedTable.lightStrengthMult = lightStrengthMult
    return savedTable
end

function widget:SetConfigData(data)
    if data.lightRadiusMult then
        lightRadiusMult = data.lightRadiusMult
        lightStrengthMult = data.lightStrengthMult
    end
end


