function widget:GetInfo()
	return {
		name      = "Sensor Ranges Radar Preview GL4",
		desc      = "Raytraced Radar Range Coverage on building Radar",
		author    = "Beherith",
		date      = "2021.07.12",
		license   = "CC BY-NC",
		layer     = 0,
		enabled   = true
	}
end
 
------- GL4 NOTES -----
-- There is regular radar and advanced radar, assumed to have identical ranges!
local miplevel = 3 -- matching radarmiplevel modrule

local smallradarrange = 2100
local largeradarrange = 3500
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.name == 'armarad' then largeradarrange = unitDef.radarRadius end
	if unitDef.name == 'armrad'  then smallradarrange = unitDef.radarRadius end
end

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local radarTruthShader = nil

local smallradVAO = nil
local largeradVAO = nil

local SHADERRESOLUTION = 24 -- THIS SHOULD MATCH RADARMIPLEVEL!

local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 xyworld_xyfract;
uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D heightmapTex;

out DataVS {
	vec4 worldPos; // pos and radius
	vec4 blendedcolor;
	float worldscale_circumference;
};

//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

void main() {
	// transform the point to the center of the radarcenter_range
	
	vec4 pointWorldPos = vec4(0.0); 
	
	pointWorldPos.xz = (radarcenter_range.xz +  (xyworld_xyfract.xy * radarcenter_range.w)); // transform it out in XZ
	pointWorldPos.y = heightAtWorldPos(pointWorldPos.xz); // get the world height at that point
	
	vec3 toradarcenter = vec3(radarcenter_range.xyz - pointWorldPos.xyz);
	float dist_to_center = length(toradarcenter.xyz);
	
	// get closer to the center in N mip steps, and if that point is obscured at any time, remove it
	
	vec3 smallstep =  toradarcenter / resolution; 
	float obscured = -100.0;
	float maxtracedheight = -10000.0;
	//for (float i = 0.0; i < mod(timeInfo.x/3,resolution); i += 1.0 ) {
	for (float i = 0.0; i < resolution; i += 1.0 ) {
		vec3 raypos = pointWorldPos.xyz + (smallstep) * i;
		float heightatsample = heightAtWorldPos(raypos.xz);
		obscured = max(obscured, heightatsample - raypos.y);
		maxtracedheight = max(maxtracedheight, heightatsample);
	}

	worldscale_circumference = 1.0; //startposrad.w * circlepointposition.z * 5.2345;
	worldPos = vec4(pointWorldPos);
	blendedcolor = vec4(0.0);
	blendedcolor.a = 0.5;
	//if (dist_to_center > radarcenter_range.w) blendedcolor.a = 0.0;  // do this in fs instead
	
	blendedcolor.g = 1.0-clamp(obscured*0.5,0.0,1.0);
	blendedcolor.a = min(blendedcolor.g,blendedcolor.a);
	
	pointWorldPos.y += 32.0;
	worldPos = pointWorldPos;
	gl_Position = cameraViewProj * vec4(pointWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform vec4 radarcenter_range;  // x y z range
uniform float resolution;  // how many steps are done

uniform sampler2D heightmapTex;

//__ENGINEUNIFORMBUFFERDEFS__

//__DEFINES__
in DataVS {
	vec4 worldPos; // w = range
	vec4 blendedcolor;
	float worldscale_circumference;
};

out vec4 fragColor;

void main() {
	fragColor.rgba = blendedcolor.rgba;
	
	vec2 mymin = min(worldPos.xz,mapSize.xy - worldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	fragColor.a = min(fragColor.a, 1.0 - clamp(inboundsness*(-0.1),0.0,1.0));
	
	if (length(worldPos.xz - radarcenter_range.xz) > radarcenter_range.w) fragColor.a = 0.0;
	
	//#if USE_STIPPLE > 0
	//	fragColor.a *= 2.0 * sin(worldscale_circumference + timeInfo.x*0.2) ; // PERFECT STIPPLING!
	//#endif
}
]]

local function goodbye(reason)
  Spring.Echo("radarTruthShader GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initgl4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	radarTruthShader =  LuaShader(
    {
      vertex = vsSrc:gsub("//__DEFINES__", "#define SHADERRESOLUTION "..tostring(SHADERRESOLUTION+0.0001)),
	  fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(usestipple) ),
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0,
        },
      uniformFloat = {
        radarcenter_range = {2000,100,2000,2000},
        resolution = {32},
      },
    },
    "radarTruthShader GL4"
  )
  shaderCompiled = radarTruthShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile radarTruthShader  GL4 ") end
  
  local smol,smolsize  = makePlaneVBO(1,1,smallradarrange / SHADERRESOLUTION)
  local smoli, smolisize = makePlaneIndexVBO(smallradarrange / SHADERRESOLUTION)
  smallradVAO = gl.GetVAO()
  smallradVAO:AttachVertexBuffer(smol)
  smallradVAO:AttachIndexBuffer(smoli)
  
  local larg,largsize  = makePlaneVBO(1,1,largeradarrange / SHADERRESOLUTION)
  local largi, largisize = makePlaneIndexVBO(largeradarrange / SHADERRESOLUTION)
  largeradVAO = gl.GetVAO()
  largeradVAO:AttachVertexBuffer(larg)
  largeradVAO:AttachIndexBuffer(largi)
end

-- Functions shortcuts
local spGetSpectatingState  = Spring.GetSpectatingState
local spGetUnitIsActive 	= Spring.GetUnitIsActive
local spGetUnitDefID        = Spring.GetUnitDefID
local spGetUnitPosition     = Spring.GetUnitPosition
local spIsGUIHidden 		= Spring.IsGUIHidden

-- Globals
local chobbyInterface

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1,18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1,19) == 'LobbyOverlayActive1')
	end
end

function widget:Initialize()
	initgl4()
end

function widget:Shutdown()
end
local mousepos = {0,0,0}
function widget:Update()
	local mx, my, lp, mp, rp, offscreen = Spring.GetMouseState ( )
	local _ , coords = Spring.TraceScreenRay(mx,my,true)
	if coords then 
		mousepos = {coords[1],coords[2],coords[3]}
	end
end

function widget:DrawWorld()
    if chobbyInterface then return end
    if spIsGUIHidden() or (WG['topbar'] and WG['topbar'].showingQuit()) then return end

	gl.DepthTest(false)
	gl.Culling(GL.BACK)	
	gl.Texture(0, "$heightmap")
	radarTruthShader:Activate()
	radarTruthShader:SetUniform("radarcenter_range", 
		mousepos[1],
		mousepos[2] + 64,
		mousepos[3],
		2100
		)
	
	smallradVAO:DrawElements(GL.TRIANGLES)
	radarTruthShader:Deactivate()
	gl.Texture(0, false)
	
	gl.DepthTest(true)
end

