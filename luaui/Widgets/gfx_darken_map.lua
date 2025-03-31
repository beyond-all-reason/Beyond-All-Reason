
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Darken map",
    desc      = "darkens the map, not units",
    author    = "Floris",
    date      = "2015",
    license   = "GNU GPL, v2 or later",
    layer     = 10000,
    enabled   = true
  }
end


local darknessvalue = 0
local maxDarkness = 0.6
local darkenFeatures = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local features

local camX, camY, camZ = Spring.GetCameraPosition()
local camDirX,camDirY,camDirZ = Spring.GetCameraDirection()

function widget:Shutdown()
	WG['darkenmap'] = nil
end


local function mapDarkness(_,_,params)
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			darknessvalue = tonumber(params[1])
			if darknessvalue > maxDarkness then
				darknessvalue = maxDarkness
			end
		end
	end
end

function widget:Initialize()
	WG['darkenmap'] = {}
	WG['darkenmap'].getMapDarkness = function()
		return darknessvalue
	end
	WG['darkenmap'].setMapDarkness = function(value)
		darknessvalue = tonumber(value)
	end
	WG['darkenmap'].getDarkenFeatures = function()
		return darkenFeatures
	end
	WG['darkenmap'].setDarkenFeatures = function(value)
		darkenFeatures = value
	end

	widgetHandler:AddAction("mapdarkness", mapDarkness, nil, "t")
end


local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = Spring.GetCameraPosition()
function widget:Update(dt)
    if darknessvalue >= 0.01 then
        camX, camY, camZ = Spring.GetCameraPosition()
        camDirX,camDirY,camDirZ = Spring.GetCameraDirection()
        if darkenFeatures and (camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3]) then
            features = Spring.GetVisibleFeatures(-1, 250, false)
        end
    end
end

function widget:DrawWorldPreUnit()
	if darknessvalue >= 0.01 then

		local drawMode = Spring.GetMapDrawMode()
		if (drawMode=="height") or (drawMode=="path") then return end

        gl.PushMatrix()
        gl.Color(0,0,0,darknessvalue)
        gl.Translate(camX+(camDirX*360),camY+(camDirY*360),camZ+(camDirZ*360))
        gl.Billboard()
        gl.Rect(-5000, -5000, 5000, 5000)
        gl.PopMatrix()
    end
end

local spGetFeatureDefID = Spring.GetFeatureDefID
function widget:DrawWorld()
	if darkenFeatures and darknessvalue >= 0.01 then
		if features == nil then
			features = Spring.GetVisibleFeatures(-1, 250, false)
		end

		if features ~= nil then
			gl.DepthTest(true)
			gl.PolygonOffset(-2, -2)
			gl.Color(0,0,0,darknessvalue)
			for i, featureID in pairs(features) do
				local fdefID = spGetFeatureDefID(featureID)
				if fdefID then
					gl.Texture('%-'..fdefID..':1')
					gl.Feature(featureID, true)
				end
			end
			gl.PolygonOffset(false)
			gl.DepthTest(false)
			gl.Texture(false)
		end
	end
end


function widget:GetConfigData(data)
    return {
		darknessvalue = darknessvalue,
		darkenFeatures = darkenFeatures
	}
end

function widget:SetConfigData(data)
	if data.darknessvalue ~= nil then
		darknessvalue = data.darknessvalue
	end
	if data.darkenFeatures ~= nil then
		darkenFeatures = data.darkenFeatures
	end
end
