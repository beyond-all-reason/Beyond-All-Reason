
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

----------------------------------------------------------------
-- Globals
----------------------------------------------------------------
local geoDisplayList

----------------------------------------------------------------
-- Speedups
----------------------------------------------------------------
local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local glCallList = gl.CallList
local glColor = gl.Color
local spGetMapDrawMode = Spring.GetMapDrawMode
local SpGetSelectedUnits = Spring.GetSelectedUnits

local am_geo = UnitDefNames.armageo.id
local arm_geo = UnitDefNames.armgeo.id
local arm_gmm = UnitDefNames.armgmm.id
local cm_geo = UnitDefNames.corageo.id
local corbhmth_geo = UnitDefNames.corbhmth.id
local cor_geo = UnitDefNames.corgeo.id






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
		local fID = features[i]
		if FeatureDefs[Spring.GetFeatureDefID(fID)].geoThermal then
			local fx, fy, fz = Spring.GetFeaturePosition(fID)
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

function widget:DrawWorld()
    local _, cmdID = Spring.GetActiveCommand()
	if spGetMapDrawMode() == 'metal' or cmdID == -am_geo or cmdID == -arm_geo or cmdID == -cm_geo
	or cmdID == -corbhmth_geo or cmdID == -cor_geo or cmdID == -arm_gmm then
		
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
