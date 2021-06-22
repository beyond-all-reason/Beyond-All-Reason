function widget:GetInfo()
	return {
		name      = "Ground Circle GL4",
		desc      = "Draws A bunch of circles on the ground",
		author    = "Beherith",
		date      = "2021.04.26",
		license   = "CC-BY-NC-ND 4.0",
		layer     = -100,
		enabled   = false
	}
end

local circleSegments = 64

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local circleShader = nil
local circleInstanceVBO = nil

local function goodbye(reason)
  Spring.Echo("Ground Circle GL4 widget exiting with reason: "..reason)
  if circleShader then circleShader:Finalize() end
  widgetHandler:RemoveWidget(self)
end

local vsSrc = [[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition; // points of the circle
layout (location = 1) in vec4 posrad; // per-instance parameters
layout (location = 2) in vec4 color;  // per-instance
uniform vec4 circleuniforms; // none yet

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
	vec4 circleWorldPos = posrad;
	circleWorldPos.xz = circlepointposition.xy * circleWorldPos.w +  circleWorldPos.xz;
	
	// get heightmap 
	circleWorldPos.y = max(0.0,heightAtWorldPos(circleWorldPos.xz))+32.0;
	
	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	
	// dump to FS
	worldscale_circumference = posrad.w * circlepointposition.z * 0.62831853;
	worldPos = circleWorldPos;
	blendedcolor = color;
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.03),0.0,1.0);
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform vec4 circleuniforms; 

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
  //fragColor.a *= 2.0 * sin(worldscale_circumference + timeInfo.x*0.1); // stipple
}
]]

local function initgl4()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	circleShader =  LuaShader(
	{
	  vertex = vsSrc:gsub("//__DEFINES__", "#define MYGRAVITY " .. tostring(Game.gravity+0.1)),
	  fragment = fsSrc:gsub("//__DEFINES__", "#define USE_STIPPLE ".. tostring(0) ),
	  --geometry = gsSrc, no geom shader for now
	  uniformInt = {
      heightmapTex = 0,
		},
	  uniformFloat = {
      circleuniforms = {1,1,1,1}, -- unused
	  },
	},
	"ground circles shader GL4"
  )
  shaderCompiled = circleShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile circleShader GL4 ") end
  local circleVBO,numVertices = makeCircleVBO(circleSegments)
  local circleInstanceVBOLayout = {
		  {id = 1, name = 'posrad', size = 4}, -- the start pos + radius
		  {id = 2, name = 'color', size = 4}, --- color
		}
  circleInstanceVBO = makeInstanceVBOTable(circleInstanceVBOLayout,32, "groundcirclevbo")
  circleInstanceVBO.numVertices = numVertices
  circleInstanceVBO.vertexVBO = circleVBO
  circleInstanceVBO.VAO = makeVAOandAttach(circleInstanceVBO.vertexVBO,       circleInstanceVBO.instanceVBO)
end

function widget:Initialize()
  initgl4()
  for i = 1, 500 do
    pushElementInstance(circleInstanceVBO,
      {math.random()* Game.mapSizeX, 0, math.random()* Game.mapSizeZ, math.random() * 500,
      math.random(),math.random(),math.random(),math.random(),
      },
      i  -- key is gonna be i
    )
  end
end

function widget:DrawWorld()
    pushElementInstance(circleInstanceVBO,
      {math.random()* Game.mapSizeX, 0, math.random()* Game.mapSizeZ, math.random() * 500,
      math.random(),math.random(),math.random(),math.random(),
      },
      math.ceil(math.random() * 500),  -- key is gonna be i
      true -- updateexising
    )
  
  gl.DepthTest(GL.LEQUAL)

  gl.Texture(0, "$heightmap")

  circleShader:Activate()
  --circleShader:SetUniform("circleuniforms", 1.0, 1.0, 1.0, 1.0) -- unused

  circleInstanceVBO.VAO:DrawArrays(GL.LINE_STRIP, circleInstanceVBO.numVertices, 0, circleInstanceVBO.usedElements, 0) -- could be GL.TRIANGLE_FAN too

  circleShader:Deactivate()
  gl.Texture(0, false)

  gl.DepthTest(GL.ALWAYS)
end


