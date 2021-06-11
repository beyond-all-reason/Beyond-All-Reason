
function widget:GetInfo()
	return {
		name      = 'Highlight Geos GL4',
		desc      = 'Highlights geothermal spots when in metal map view',
		author    = 'Niobium, Beherith GL4',
		version   = '1.0',
		date      = 'Mar, 2011',
		license   = 'GNU GPL, v2 or later',
		layer     = 0,
		enabled   = true,  --  loaded by default?
	}
end

local glLineWidth = gl.LineWidth
local glDepthTest = gl.DepthTest
local GL_LINES = GL.LINES
local spGetMapDrawMode = Spring.GetMapDrawMode
local spGetActiveCommand = Spring.GetActiveCommand
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

----------------------------------------------------------------
-- GL4 STUFF
----------------------------------------------------------------

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")
local pillarShader = nil
local pillarInstaceVBO = nil
local pillarVAO = nil

local vsSrc = [[
#version 420
#line 10000
layout (location = 0) in vec4 localposalpha;
layout (location = 1) in vec4 worldposscale;

out DataVS {
	vec4 blendedcolor;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000
void main() {
	vec4 newWorldPos = vec4(localposalpha.xyz + worldposscale.xyz,1.0);
	blendedcolor = vec4(1.0,1.0,0.0,localposalpha.a);
	gl_Position = cameraViewProj * vec4(newWorldPos.xyz, 1.0);
}
]]

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__ENGINEUNIFORMBUFFERDEFS__

in DataVS {
	vec4 blendedcolor;
};

out vec4 fragColor;

#line 20000
void main() {
	float decoralpha = fract(blendedcolor.a*50 - timeInfo.y);
	fragColor = blendedcolor;
	fragColor.a *= decoralpha;
}
]]

local function goodbye(reason)
  Spring.Echo(widget:GetInfo().name .." widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget(self)
end

local function makepillarVBO()
	local pillarVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if pillarVBO == nil then goodbye("Failed to create pillarVBO") end
	local VBOData = {0,1,0,1,   0,1000,1,0}
	pillarVBO:Define(2,	{{id = 0, name = "localposalpha", size = 4}})
	pillarVBO:Upload(VBOData)
	return pillarVBO
end

local function makeShaders()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	pillarShader =  LuaShader(
		{
			vertex = vsSrc,
			fragment = fsSrc,
		},
		"pillarShader GL4"
	)
	shaderCompiled = pillarShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile pillarShader GL4 ") end
end

----------------------------------------------------------------
-- Callins
----------------------------------------------------------------

function widget:Initialize()
	pillarInstaceVBO = makeInstanceVBOTable({{id = 1, name = 'worldposscale', size = 4}},16, "GeoInstanceVBO")
	pillarInstaceVBO.vertexVBO = makepillarVBO()
	pillarInstaceVBO.numVertices = 2
	pillarInstaceVBO.VAO = makeVAOandAttach(pillarInstaceVBO.vertexVBO,pillarInstaceVBO.instanceVBO)
	makeShaders()
	local features = Spring.GetAllFeatures()
	for i = 1, #features do
		if geoThermalFeatures[Spring.GetFeatureDefID(features[i])] then
			local fx, fy, fz = Spring.GetFeaturePosition(features[i])
			local position_based_key_to_prevent_duplicates = string.format("%d_%d",fx,fz)
			pushElementInstance(pillarInstaceVBO, {fx,fy,fz,0}, position_based_key_to_prevent_duplicates, true)
		end
	end
end

function widget:Shutdown()
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawWorld()
	if chobbyInterface then return end
	local _, cmdID = spGetActiveCommand()
	if spGetMapDrawMode() == 'metal' or (cmdID~=nil and geoUnits[-cmdID]) then
		if pillarInstaceVBO.usedElements > 0 then
			glLineWidth(20)
			glDepthTest(true)
			pillarShader:Activate()
			pillarInstaceVBO.VAO:DrawArrays(GL_LINES,pillarInstaceVBO.numVertices,0,pillarInstaceVBO.usedElements,0)
			pillarShader:Deactivate()
			glLineWidth(1)
		end
	end
end
