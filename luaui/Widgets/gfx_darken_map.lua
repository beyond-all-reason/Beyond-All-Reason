--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Darken map",
		desc = "darkens the map, not units",
		author = "Floris",
		date = "2015",
		license = "GNU GPL, v2 or later",
		layer = 10000,
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetMapDrawMode = Spring.GetMapDrawMode
local glColor = gl.Color
local glCallList = gl.CallList

local darknessvalue = 0
local maxDarkness = 0.6

local darkenList ---@type integer
local drawCallInActive ---@type boolean?

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- DrawWorldPreUnit is only registered while the map is darkened
local function updateDrawCallIn()
	local active = darknessvalue >= 0.01
	if active ~= drawCallInActive then
		drawCallInActive = active
		if active then
			widgetHandler:UpdateCallIn("DrawWorldPreUnit")
		else
			widgetHandler:RemoveCallIn("DrawWorldPreUnit")
		end
	end
end

function widget:Shutdown()
	gl.DeleteList(darkenList)
	WG.darkenmap = nil
end

local function mapDarkness(_, _, params)
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			darknessvalue = tonumber(params[1])
			if darknessvalue > maxDarkness then
				darknessvalue = maxDarkness
			end
			updateDrawCallIn()
		end
	end
end

function widget:Initialize()
	-- quad 360 elmos ahead of the camera, in eye space so it needs no camera reads
	darkenList = gl.CreateList(function()
		-- a depth test leaked by an earlier widget hides it behind terrain closer than 360 elmos
		gl.DepthTest(false)
		gl.PushMatrix()
		gl.LoadIdentity()
		gl.Translate(0, 0, -360)
		gl.Rect(-5000, -5000, 5000, 5000)
		gl.PopMatrix()
	end)

	WG.darkenmap = {}
	WG.darkenmap.getMapDarkness = function()
		return darknessvalue
	end
	WG.darkenmap.setMapDarkness = function(value)
		darknessvalue = tonumber(value)
		updateDrawCallIn()
	end
	widgetHandler:AddAction("mapdarkness", mapDarkness, nil, "t")
	updateDrawCallIn()
end

function widget:DrawWorldPreUnit()
	local drawMode = spGetMapDrawMode()
	if (drawMode == "height") or (drawMode == "path") then
		return
	end

	glColor(0, 0, 0, darknessvalue)
	glCallList(darkenList)
end

function widget:GetConfigData(data)
	return {
		darknessvalue = darknessvalue,
	}
end

function widget:SetConfigData(data)
	if data.darknessvalue ~= nil then
		darknessvalue = data.darknessvalue
		-- nil until Initialize, which syncs the callin on load
		if drawCallInActive ~= nil then
			updateDrawCallIn()
		end
	end
end
