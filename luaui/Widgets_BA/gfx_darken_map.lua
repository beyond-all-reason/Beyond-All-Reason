
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
  return {
    name      = "Darken map",
    desc      = "use: Ctrl+Alt+] or [   or use /mapdarkness 0.3   remembers per map",
    author    = "Floris",
    date      = "2015",
    license   = "GNU GPL, v2 or later",
    layer     = 0,
    enabled   = true  --  loaded by default?
  }
end


local mapMargin = 20000
local darknessvalue = 0
local darknessIncrease = 'Ctrl+Alt+]'
local darknessDecrease = 'Ctrl+Alt+['
local darknessStep = 0.02
local maxDarkness = 0.6
local darkenFeatures = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local msx = Game.mapSizeX
local msz = Game.mapSizeZ
local currentMapname = Game.mapName:lower()
local maps = {}
local gaia = Spring.GetGaiaTeamID()

function widget:Initialize()
  darken = gl.CreateList(function()
		gl.PushMatrix()
		gl.Translate(0,0,0)
		gl.Rotate(90,1,0,0)
		gl.Rect(-mapMargin, -mapMargin, msx+mapMargin, msz+mapMargin)
		gl.PopMatrix()
  end)
  
  WG['darkenmap'] = {}
  WG['darkenmap'].getMapDarkness = function()
  	return darknessvalue
  end
  WG['darkenmap'].setMapDarkness = function(value)
  	darknessvalue = value
  	maps[currentMapname] = darknessvalue
  end
  WG['darkenmap'].getDarkenFeatures = function()
  	return darkenFeatures
  end
  WG['darkenmap'].setDarkenFeatures = function(value)
  	darkenFeatures = value
  end
  
	widgetHandler:AddAction("mapdarkness", mapDarkness, nil, "t")
	
	widgetHandler:AddAction("mapDarknessIncrease", mapDarknessIncrease, nil, "t")
	Spring.SendCommands({"bind "..darknessIncrease.." mapDarknessIncrease"})

	widgetHandler:AddAction("mapDarknessDecrease", mapDarknessDecrease, nil, "t")
	Spring.SendCommands({"bind "..darknessDecrease.." mapDarknessDecrease"})
end


function widget:Shutdown()
	gl.DeleteList(darken)
end


function mapDarkness(_,_,params)
	if #params == 1 then
		if type(tonumber(params[1])) == "number" then
			darknessvalue = tonumber(params[1])
			if darknessvalue > maxDarkness then
				darknessvalue = maxDarkness
			end
			maps[currentMapname] = darknessvalue
		end
	end
end

function mapDarknessIncrease()
	darknessvalue = darknessvalue + darknessStep
	if darknessvalue > maxDarkness then
		darknessvalue = maxDarkness
	end
	maps[currentMapname] = darknessvalue
end

function mapDarknessDecrease()
	darknessvalue = darknessvalue - darknessStep
	if darknessvalue < 0 then
		darknessvalue = 0
	end
	maps[currentMapname] = darknessvalue
end

function widget:DrawWorldPreUnit()
	
  local drawMode = Spring.GetMapDrawMode()
  if (drawMode=="height") or (drawMode=="path") then return end

	if darken ~= nil and darknessvalue > 0 then
		gl.Color(0,0,0,darknessvalue)
		gl.CallList(darken)
		gl.Color(1,1,1,1)
	end
end


local prevCam = {}
prevCam[1],prevCam[2],prevCam[3] = Spring.GetCameraPosition()
function widget:Update(dt)
	local camX, camY, camZ = Spring.GetCameraPosition()
	if camX ~= prevCam[1] or  camY ~= prevCam[2] or  camZ ~= prevCam[3] then
		features = Spring.GetVisibleFeatures(gaia, 250, false)
	end
end

local spGetFeatureDefID = Spring.GetFeatureDefID
function widget:DrawWorld()
	if darkenFeatures and darken ~= nil and darknessvalue > 0.03 then
		
		if features == nil then
			features = Spring.GetVisibleFeatures(gaia, 250, false)
		end
		
		if features ~= nil then
			gl.DepthTest(true)
			gl.PolygonOffset(-2, -2)
			gl.Color(0,0,0,darknessvalue)
			for i, featureID in pairs(features) do
				gl.Texture('%-'..spGetFeatureDefID(featureID)..':1')
			  gl.Feature(featureID, true)
			end
			gl.PolygonOffset(false)
			gl.DepthTest(false)
			gl.Texture(false)
		end
	end
end


function widget:GetConfigData(data)
    savedTable = {}
    savedTable.maps	= maps
    savedTable.darkenFeatures	= darkenFeatures
    return savedTable
end

function widget:SetConfigData(data)
	if data.maps ~= nil then
		maps = data.maps
		if data.darkenFeatures ~= nil then
			darkenFeatures = data.darkenFeatures
		end
		if data.maps[currentMapname] ~= nil then
			darknessvalue = data.maps[currentMapname]
		end
	end
end


function widget:TextCommand(command)
    if (string.find(command, "resetmapdarkness") == 1  and  string.len(command) == 16) then 
		maps = {}
		darknessvalue = 0
	end
end