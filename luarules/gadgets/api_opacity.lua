function gadget:GetInfo()
    return {
        name      = "Opacity control",
        desc      = "Provides opacity values, based on camera height, to widgets",
        author    = "Bluestone",
        date      = "June 2014",
        license   = "GPL v3 or later",
        layer     = 0,
        enabled   = true  -- loaded by default
    }
end

--[[
    INSTRUCTIONS: Each widget needs its own Script.LuaUI call added to the list below
                 The widget then needs to use widgetHandler:RegisterGlobal and widgetHandler:DeregisterGlobal to allow api_opacity to call it
]]

if gadgetHandler:IsSyncedCode() then
    return false
end

--mapBaseHeight
local mapBaseHeight 
local h = {}
for i=1,3 do
for i=1,3 do
   h[#h+1]=Spring.GetGroundHeight(Game.mapSizeX*i/4,Game.mapSizeZ*i/4)
end
end
mapBaseHeight = 0
for _,s in ipairs(h) do
    mapBaseHeight = mapBaseHeight + s
end
mapBaseHeight = mapBaseHeight / #h

--opacity
function GetOpacityDark(cy,gy)
    return math.max(0.1, 0.5 - (cy-gy-3000) * (1/10000))
end
function GetOpacityLight(cy,gy)
    return math.max(0.2, 0.8 - (cy-gy-3000) * (1/10000))
end

local gy = math.max(0,mapBaseHeight)
local spGetCameraPosition = Spring.GetCameraPosition
local cy = 0
local prevOpacityDark = GetOpacityDark(cy,gy)
local precOpacityLight = GetOpacityLight(cy,gy)

function SetOpacity() 
    cy = select(2,spGetCameraPosition())
    opacityDark = GetOpacityDark(cy,gy)
    opacityLight = GetOpacityLight(cy,gy)
    
    if math.abs(opacityDark-prevOpacityDark)>0.1 or math.abs(opacityDark-prevOpacityDark)>0.1 then
        prevOpacityDark = opacityDark
        prevOpacityLight = opacityLight

        -- each widget needs its own Script.LuaUI call :(
        ScriptLuaUICall("SetOpacity_Comblast_DGun_Range", opacityDark, opacityLight)
        ScriptLuaUICall("SetOpacity_Defense_Range", opacityDark, opacityLight)
    end
end

function ScriptLuaUICall(name, darkOpacity, lightOpacity)
    if Script.LuaUI(name) then
        Script.LuaUI[name](darkOpacity,lightOpacity)
    end
end

function gadget:Update()
    SetOpacity()
end

