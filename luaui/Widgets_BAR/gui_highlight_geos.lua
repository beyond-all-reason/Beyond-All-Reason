
function widget:GetInfo()
	return {
		name      = 'Highlight Geos',
		desc      = 'Highlights geothermal spots when in metal map view',
		author    = 'Niobium',
		version   = '1.0',
		date      = 'Mar, 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true,  --  loaded by default?
	}
end

local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glCallList = gl.CallList
local glColor = gl.Color
local spGetMapDrawMode = Spring.GetMapDrawMode
local chobbyInterface

local geoUnits = {}
for defID, def in pairs(UnitDefs) do
	if def.needGeo then
		geoUnits[defID] = true
	end
end

local geoThermalFeatures = {}
for defID, def in pairs(FeatureDefs) do
	if def.geoThermal then
		geoThermalFeatures[defID] = true
	end
end

local geoDisplayList

----------------------------------------------------------------
-- Functions
----------------------------------------------------------------

local function PillarVerts(x, y, z)
	gl.Color(1, 1, 0, 1)
	gl.Vertex(x, y, z)
	gl.Color(1, 1, 0, 0)
	gl.Vertex(x, y + 1000, z)
end

local function HighlightGeos()
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			local fx, fy, fz = Spring.GetFeaturePosition(features[i])
			gl.BeginEnd(GL.LINE_STRIP, PillarVerts, fx, fy, fz)
		end
	end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------
function widget:Shutdown()
	if geoDisplayList then
		gl.DeleteList(geoDisplayList)
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	local _, cmdID = Spring.GetActiveCommand()
	if spGetMapDrawMode() == 'metal' or (cmdID~=nil and geoUnits[-cmdID]) then

		if not geoDisplayList then
			geoDisplayList = gl.CreateList(HighlightGeos)
		end

		glLineWidth(20)
		glDepthTest(true)
		glCallList(geoDisplayList)
		glColor(1, 1, 1, 1)
		glLineWidth(1)
	end
end
