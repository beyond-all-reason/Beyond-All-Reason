
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
local radiusMult = 1.5
local strengthMult = 0.5

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


local function GetLights(beamLights, beamLightCount, pointLights, pointLightCount)
    local mx,my,m1,m2,m3 = Spring.GetMouseState()
    local traceType, tracedScreenRay = Spring.TraceScreenRay(mx, my, true)
    if tracedScreenRay ~= nil then
        local params = {param={} }
        params.px, params.py, params.pz = tracedScreenRay[1],tracedScreenRay[2],tracedScreenRay[3]
        params.param.r, params.param.g, params.param.b = colorR,colorG,colorB
        params.colMult = 1 * strengthMult
        params.param.radius = 350 * radiusMult
        params.py = params.py + 50
        pointLightCount = pointLightCount + 1
        pointLights[pointLightCount] = params
        params.colMult = params.colMult * 0.4
        params.param.radius = 1000 * radiusMult
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
end

function widget:Shutdown()
    if functionID and WG.DeferredLighting_UnRegisterFunction then
        WG.DeferredLighting_UnRegisterFunction(functionID)
    end
end


