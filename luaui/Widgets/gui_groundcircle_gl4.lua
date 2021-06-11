include("keysym.h.lua")

local versionNumber = "6.32"

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

-- GL4 Notes and TODO:
-- AA should be purple :D
-- heightboost is going to be a bitch - > use $heightmap and hope that heightboost is kinda linear
-- Vertex Buffer should have: a circle with 64 subdivs
  -- basically a set of vec2's  
  -- each elem of this vec2 should also have a normal vector, for ez heightboost
-- whole thing needs an 'override' type thing, 
-- needs masking of the instance buffer
-- Instance buffer params:
--  - 1k elements static
--  - vec4 pos,radius
--  - vec4 rgb, alpha
--  - vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout. 
--  - vec4 bitmask of type?

-- jobs of the vertex shader:
  -- pass butter, maybe discard early with even going into geom shader?
-- job of the geom shader
  -- circle generation
  -- sample heightmap, use heightboost?
  -- put heightboost into 
-- job of the fragment shader
  -- colorize ba
-- Uniforms:
  -- DrawType (ground, air, nuke, ally), a bitmask
  -- camheight ? -- in uniformmatrices
  -- globalalpha?
  -- heightmap need to be bound as 'texture'
  
-- Quick update: 
  -- store a table of instance buffer params, as to which unitID is slaved to which instance
  -- Also use a table as a reverse stack of free instance buffer elements - O(1) !!
  
-- configurability:
  -- have multiple VBOs' for each unit type?
  -- 
  
------ GL4 THINGS  -----

circleVBO = nil
circleVBOSize = 0
circleSegments = 127

circleInstanceVBO = nil
circleInstanceVBOSize = 1000
circleInstanceVBOStep = 16
circleInstanceVBONextFree = 1 -- index of the next 'free' element
circleInstanceData = {}

cVBOWrapper = {
	maxVBOSize = 1000,
	VBOStep = 1000,
	nextFree = 1,
	VBOData = {},
	instanceVBO = {}
}


circleVAO = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
circleShader = nil

local function goodbye(reason)
  Spring.Echo("Map Grass GL4 widget exiting with reason: "..reason)
  if grassPatchVBO then grassPatchVBO = nil end
  if grassInstanceVBO then grassInstanceVBO = nil end
  if grassVAO then grassVAO = nil end
  --if grassShader then grassShader:Finalize() end
  widgetHandler:RemoveWidget(self)
end

local function pushInstance(VBO, VBOData, VBOSize, VBOStep, NextFree, newElem)
	for i=1, #newElem do
		
	end
end

local function makeCircleVBO()
	circleVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleVBO == nil then goodbye("Failed to create circleVBO") end
	
	local VBOLayout = {
	 {id = 0, name = "position", size = 2},
	}
	
	local VBOData = {}
	circleVBOSize = (circleSegments + 1) 
	for i = 0, circleSegments  do -- this is +1
		VBOData[#VBOData+1] = math.sin(math.pi*2* i / circleSegments)
		VBOData[#VBOData+1] = math.cos(math.pi*2* i / circleSegments)
	end	
	circleVBO:Define(
		circleVBOSize,
		VBOLayout
	)
	circleVBO:Upload(VBOData)
end

local function makeInstanceVBO()
	-- we are gonna over allocate 
	circleInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER,true)
	if circleInstanceVBO == nil then goodbye("Failed to create circleInstanceVBO") end
	
	circleInstanceVBO:Define(
		circleInstanceVBOSize,--?we dont know how big yet!
		{
		  {id = 1, name = 'posscale', size = 4}, -- a vec4 for pos + scale
		  {id = 2, name = 'color1', size = 4}, --  vec4 the color of this circle
		  {id = 3, name = 'visibility', size = 4}, --- vec4 heightdrawstart, heightdrawend, fadefactorin, fadefactorout. 
		  {id = 4, name = 'circleparams', size = 4}, --- heightboost gradient
		  
		})
	
	for i = 1, circleInstanceVBOSize do
		--for j = 1, 16 do
			local px = math.random() * Game.mapSizeX
			local pz = math.random() * Game.mapSizeZ
			circleInstanceData[#circleInstanceData + 1] = px
			circleInstanceData[#circleInstanceData + 1] = Spring.GetGroundHeight(px,pz)
			circleInstanceData[#circleInstanceData + 1] = pz
			circleInstanceData[#circleInstanceData + 1] = 500 * math.random()
			circleInstanceData[#circleInstanceData + 1] =  math.random()
			circleInstanceData[#circleInstanceData + 1] =  math.random()
			circleInstanceData[#circleInstanceData + 1] = math.random()
			circleInstanceData[#circleInstanceData + 1] =  math.random()
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
			circleInstanceData[#circleInstanceData + 1] = 0 -- zero fill init
		--end
	end
	circleInstanceVBO:Upload(circleInstanceData)
end

local vsSrc = [[
#version 420
#line 10000

layout (location = 0) in vec2 circlepointposition;
layout (location = 1) in vec4 posscale;
layout (location = 2) in vec4 color1;
layout (location = 3) in vec4 visibility;
layout (location = 4) in vec4 circleparams;

uniform vec4 circleuniforms; // none yet

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

out DataVS {
	vec4 worldPos;
	vec4 blendedcolor;
	vec4 debuginfo;
};

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardProj;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;

	mat4 shadowView;
	mat4 shadowProj;
	mat4 shadowViewProj;
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

// glsl rotate convencience funcs: https://github.com/dmnsgn/glsl-rotate

mat3 rotation3dY(float a) {
	float s = sin(a);
	float c = cos(a);

  return mat3(
    c, 0.0, -s,
    0.0, 1.0, 0.0,
    s, 0.0, c);
}

mat4 scaleMat(vec3 s) {
	return mat4(
		s.x, 0.0, 0.0, 0.0,
		0.0, s.y, 0.0, 0.0,
		0.0, 0.0, s.z, 0.0,
		0.0, 0.0, 0.0, 1.0
	);
}

mat4 translationMat(vec3 t) {
	return mat4(
		1.0, 0.0, 0.0, 0.0,
		0.0, 1.0, 0.0, 0.0,
		0.0, 0.0, 1.0, 0.0,
		t.x, t.y, t.z, 1.0
	);
}

#line 11000

void main() {
	// translate to world pos:
	vec4 circleWorldPos = vec4(1.0);
	circleWorldPos.xz = circlepointposition * posscale.w +  posscale.xz;
	
	debuginfo = vec4(1.0);
	
	// get heightmap 
	vec2 uvHM =   vec2(clamp(circleWorldPos.x,8.0,mapSize.x-8.0),clamp(circleWorldPos.z,8.0, mapSize.y-8.0))/ mapSize.xy; // this proves to be an actually useable heightmap i think.
	float heightAtPoint = textureLod(heightmapTex, uvHM, 0.0).x;
	
	// boost out the circleworldpos by heightboostfactor
	float deltaheight = posscale.y - heightAtPoint;
	
	// this probably needs weighting by radius?
	
	vec2 deltaX = circlepointposition * deltaheight * circleparams.x;
	circleWorldPos.xz += deltaX; 
	
	// re-sample heightmap at new boosted pos
	uvHM =   vec2(clamp(circleWorldPos.x,8.0,mapSize.x-8.0),clamp(circleWorldPos.z,8.0, mapSize.y-8.0))/ mapSize.xy; // this proves to be an actually useable heightmap i think.
	
	float newHeight = textureLod(heightmapTex, uvHM, 0.0).x;
	// keep it above world height?
	circleWorldPos.y = newHeight + 6;
	
	// find distance of center point to cameraBillboardProj
	
	vec4 camPos = cameraViewInv[3];
	
	//--- DISTANCE FADE ---
	float distToCam = length(circleWorldPos.xyz - camPos.xyz); //dist from cam
	blendedcolor.a = clamp((visibility.x - distToCam)/(visibility.x- visibility.y + 1.0),0.0,1.0);
	
	// --- Fog like  a bitch?
	float fogDist = length((cameraView * vec4(circleWorldPos.xyz,1.0)).xyz);
	float fogFactor = (fogParams.y - fogDist) * fogParams.w;
	blendedcolor.rgb = mix(color1.rgb, fogColor.rgb, fogFactor);
	
	
	
	// ------------ dump the stuff for FS --------------------
	worldPos = circleWorldPos;

	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =  [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform vec4 circleuniforms; //windx, windz, windstrength, globalalpha

uniform sampler2D heightmapTex;
uniform sampler2D losTex; // hmm maybe?

in DataVS {
	vec4 worldPos;
	vec4 blendedcolor;
	vec4 debuginfo;
};

layout(std140, binding = 0) uniform UniformMatrixBuffer {
	mat4 screenView;
	mat4 screenProj;
	mat4 screenViewProj;

	mat4 cameraView;
	mat4 cameraProj;
	mat4 cameraViewProj;
	mat4 cameraBillboardProj;

	mat4 cameraViewInv;
	mat4 cameraProjInv;
	mat4 cameraViewProjInv;

	mat4 shadowView;
	mat4 shadowProj;
	mat4 shadowViewProj;
};

layout(std140, binding = 1) uniform UniformParamsBuffer {
	vec3 rndVec3; //new every draw frame.
	uint renderCaps; //various render booleans

	vec4 timeInfo; //gameFrame, gameSeconds, drawFrame, frameTimeOffset
	vec4 viewGeometry; //vsx, vsy, vpx, vpy
	vec4 mapSize; //xz, xzPO2

	vec4 fogColor; //fog color
	vec4 fogParams; //fog {start, end, 0.0, scale}
};

out vec4 fragColor;

void main() {
	fragColor.rgba = vec4(1.0);
	fragColor.rgb = blendedcolor.rgb;
	if (fragColor.a < 0.0001) // needed for depthmask
	discard;
}
]]


local function makeShader()
	circleShader =  LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        heightmapTex = 0, -- perlin
        losTex = 1, -- perlin
        },
      uniformFloat = {
        circleuniforms = {1,1,1,1},
      },
    },
    "circleShader GL4"
  )
  shaderCompiled = circleShader:Initialize()
  
  if not shaderCompiled then goodbye("Failed to compile circleShader GL4 ") end
end

local function makeAndAttachToVAO()
	if circleVAO then
		circleVAO = nil 
	end
	circleVAO = gl.GetVAO()
	if circleVAO == nil then goodbye("Failed to create circleVAO") end
	circleVAO:AttachVertexBuffer(circleVBO)
	circleVAO:AttachInstanceBuffer(circleInstanceVBO)
end


function widget:Initialize()
	makeCircleVBO()
	makeInstanceVBO()
	makeShader()
	makeAndAttachToVAO()
end


function widget:DrawWorld()
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)
	gl.Culling(GL.BACK) -- needs better front and back instead of using this

    gl.Texture(0, "$heightmap")
    gl.Texture(1, "$info")
	
    circleShader:Activate()
    --Spring.Echo("globalgrassfade",globalgrassfade)
    
    circleShader:SetUniform("circleuniforms", 1.0, 1.0, 1.0, 1.0)
    
    circleVAO:DrawArrays(GL.LINE_STRIP, 127, 0, circleInstanceVBOSize, 0)
	
    circleShader:Deactivate()
    gl.Texture(0, false)
    gl.Texture(1, false)


    gl.DepthTest(GL.ALWAYS)
    gl.DepthMask(false)
    gl.Culling(GL.BACK)
end


--SAVE / LOAD CONFIG FILE
function widget:GetConfigData()
	--[[
	local data = {}
	data["enabled"] = buttonConfig["enabled"]
	return data]]--
end

function widget:SetConfigData(data)
	--[[
	if data ~= nil then
		if data["enabled"] ~= nil then
			buttonConfig["enabled"] = data["enabled"]
			printDebug("enabled config found...")
		end
	end]]--
end

