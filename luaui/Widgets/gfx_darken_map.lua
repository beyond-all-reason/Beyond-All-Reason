
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



-- Localized functions for performance

-- Localized Spring API for performance
local spGetCameraPosition = Spring.GetCameraPosition

local darknessvalue = 0
local maxDarkness = 0.6

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local features

local camX, camY, camZ = spGetCameraPosition()
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
	widgetHandler:AddAction("mapdarkness", mapDarkness, nil, "t")
end


local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = spGetCameraPosition()
function widget:Update(dt)
    if darknessvalue >= 0.01 then
        camX, camY, camZ = spGetCameraPosition()
        camDirX,camDirY,camDirZ = Spring.GetCameraDirection()
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


function widget:GetConfigData(data)
    return {
		darknessvalue = darknessvalue,
	}
end

function widget:SetConfigData(data)
	if data.darknessvalue ~= nil then
		darknessvalue = data.darknessvalue
	end
end
