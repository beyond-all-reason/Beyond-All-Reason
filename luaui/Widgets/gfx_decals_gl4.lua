--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--https://gist.github.com/lhog/77f3fb10fed0c4e054b6c67eb24efeed#file-test_unitshape_instancing-lua-L177-L178

--------------------------------------------OLD AIRJETS---------------------------
function widget:GetInfo()
	return {
		name = "Decals GL4",
		desc = "Decals that Fade out over time",
		author = "GoogleFrog, jK, Floris, Beherith",
		date = "2021.05.16",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end

-- GL4 notes
-- Needs an atlassed PBR input?
-- Always a square, maybe with 4 cardinal direction possible rotations?
-- Should be able to output at least an 8x8 subdivided decal
-- Decals should have a lifetime param, with a table tracking their expected deaths
-- 'permanent' decals assigned to units too
-- Nice normal maps too
-- since we have 1024 elements in geom shader output, use those wisely (8x8 square)
-- Depth test should be less deep than other shit
-- should it write to map deferred buffer? (would be best if it did)
-- maybe position could be assigned to track units
-- how to deal with multiple, overlapping scars? additional Z sort by lifetime?
-- add some Z in fragment shader to hack around depth testing? Do double transforms and lift it up?
-- This should probably be a gadget tbh
-- Each decal should have a:
-- A. diffuse texture with teamcolor in alpha
-- An (optional) glow, metalness, roughness, transparency
-- A normal map (with optional alpha)? 
-- geometry shader is needed for faster occlusion culling!

-- we ideally should be using the new atlas texture framework for this!

-- Decal Attributes
-- vec4 Center XYZ, radius (or width)
-- rotation (only around Y)
-- fade in rate, fadeout start time, fadeout rate, lifetime
-- texture offsets (for atlasses, this should be 3 vec4's (ugh)
-- additional vec4 custom stuff:
	-- Rotate rate
	-- fade period
	-- colormod RGBA (multiply) 
-- 

-- VS to GS passthrough:
-- Everything above

-- GS to FS passthrough:
-- worldpos XYZW
-- normal XYZW
-- TEXCOORD 0, 1, 2
-- entire fucking TBN matrix?
-- colormod * fade
-- This is 4+4+4+6 ~ 20 out of 1024? ugh we may need to pack more for 64 verts?
-- ugh 1024 floats is max? thats shit
-- for a 6x6 we need like 50 verts :/
 

local decaldefs = { -- the only real 
	scar1 = { 
		tex1 = "bitmaps/scars/scar1.bmp",
		tex2 = "bitmaps/scars/scar1.bmp",
		normals = "bitmaps/scars/scar1.bmp",
		texsize = 256, -- this is needed so that the atlas knows how big it should get
		rotstart = 0.2, 
		size = 250,
		fadein = 0.1,
		fadeoutstart = 1000,
		fadeoutrate = 0.01,
		lifetime = 5000,
		rotationrate = 0.01,
		fadeperiod = 0.07,
		colormod = {1.0, 1.0, 1.0, 1.0},
	}
}

--------------------------------------------------------------------------------
-- Configuration

local decalVBO = nil
local decalShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =  
[[
#version 420
#line 10000

//__DEFINES__

layout (location = 0) in vec4 circlepointposition;
layout (location = 1) in vec4 startposrad;
layout (location = 2) in vec4 endposrad;
layout (location = 3) in vec4 color; 
uniform float circleopacity; 

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
	// blend start to end on mod gf%15
	float timemix = mod(timeInfo.x,15)*0.06666;
	vec4 circleWorldPos = mix(startposrad, endposrad, timemix);
	circleWorldPos.xz = circlepointposition.xy * circleWorldPos.w +  circleWorldPos.xz;
	
	// get heightmap 
	circleWorldPos.y = max(0.0,heightAtWorldPos(circleWorldPos.xz))+32.0;
	
	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(circleWorldPos.xz,mapSize.xy - circleWorldPos.xz);
	float inboundsness = min(mymin.x, mymin.y);
	
	// dump to FS
	worldscale_circumference = startposrad.w * circlepointposition.z * 5.2345;
	worldPos = circleWorldPos;
	blendedcolor = color;
	blendedcolor.a = 1.0; // opacity override!
	blendedcolor.a *= 1.0 - clamp(inboundsness*(-0.03),0.0,1.0);
	gl_Position = cameraViewProj * vec4(circleWorldPos.xyz, 1.0);
}
]]

local fsSrc =
[[
#version 420
#line 20000
uniform sampler2D noiseMap;
uniform sampler2D mask;

//__ENGINEUNIFORMBUFFERDEFS__

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#define DISTORTION 0.01
in DataVS {
	vec4 texCoords;
	vec4 jetcolor;
};

out vec4 fragColor;

void main(void)
{
		vec2 displacement = texCoords.pq;

		vec2 txCoord = texCoords.st;
		txCoord.s += (texture2D(noiseMap, displacement * DISTORTION * 20.0).y - 0.5) * 40.0 * DISTORTION;
		txCoord.t +=  texture2D(noiseMap, displacement).x * (1.0-texCoords.t)        * 15.0 * DISTORTION;
		float opac = texture2D(mask,txCoord.st).r;

		fragColor.rgb  = opac * jetcolor.rgb; //color
		fragColor.rgb += pow(opac, 5.0 );     //white flame
		fragColor.a    = min(opac*1.5, 1.0); // 
		fragColor.rgba = clamp(fragColor, 0.0, 1.0);
		
		fragColor.rgba *= jetcolor.a;
		//	fragColor.rgb = vec3(jetcolor.a);
		
}

]]
	
	


local function goodbye(reason)
  Spring.Echo("Airjet GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end


local function initGL4()

	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	jetShader =  LuaShader(
    {
      vertex = vsSrc,
      fragment = fsSrc,
      --geometry = gsSrc, no geom shader for now
      uniformInt = {
        noiseMap = 0,
        mask = 1,
        },
	uniformFloat = {
        jetuniforms = {1,1,1,1}, --unused
      },
    },
    "jetShader GL4"
  )
  shaderCompiled = jetShader:Initialize()
  if not shaderCompiled then goodbye("Failed to compile jetShader GL4 ") end
  local quadVBO,numVertices = makeRectVBO(-1,0,1,-1,0,1,1,0) --(minX,minY, maxX, maxY, minU, minV, maxU, maxV)
  local jetInstanceVBOLayout = {
		  {id = 1, name = 'widthlengthtime', size = 3}, -- widthlength
		  {id = 2, name = 'emitdir', size = 3}, --  emit dir
		  {id = 3, name = 'color', size = 3}, --- color
		  {id = 4, name = 'pieceIndex', type = GL.UNSIGNED_INT, size= 1}, 
		  {id = 5, name = 'instData', type = GL.UNSIGNED_INT, size= 4}, 
		}
  jetInstanceVBO = makeInstanceVBOTable(jetInstanceVBOLayout,256, "jetInstanceVBO", 5)
  jetInstanceVBO.numVertices = numVertices
  jetInstanceVBO.vertexVBO = quadVBO
  jetInstanceVBO.VAO = makeVAOandAttach(jetInstanceVBO.vertexVBO, jetInstanceVBO.instanceVBO)
  jetInstanceVBO.primitiveType = GL.TRIANGLES
  jetInstanceVBO.indexVBO = makeRectIndexVBO()
  jetInstanceVBO.VAO:AttachIndexBuffer(jetInstanceVBO.indexVBO)
  
end



--------------------------------------------------------------------------------
-- Draw Iteration
--------------------------------------------------------------------------------


local function DrawParticles()
	if not enabled then return false end
	-- validate unitID buffer
	
	glDepthTest(true)
	glAlphaTest(GL_GREATER, 0)

	glTexture(0, texture1)
	glTexture(1, texture2)
	glBlending(GL_ONE, GL_ONE)
	jetShader:Activate()
	
	drawInstanceVBO(jetInstanceVBO)
	
	jetShader:Deactivate()
	glTexture(0, false)
	glTexture(1, false)
	glBlending(GL_SRC_ALPHA, GL_ONE_MINUS_SRC_ALPHA)

	glAlphaTest(false)
	--glDepthTest(false)
	
end


	

--------------------------------------------------------------------------------
-- Widget Interface
--------------------------------------------------------------------------------

function widget:Update(dt)

end


function widget:Initialize()
	--shaders = CreateShader()
	
	initGL4()
		pushElementInstance(
			jetInstanceVBO,
			{
				width, length, spGetGameFrame(),
				emitVector[1], emitVector[2], emitVector[3],
				color[1], color[2], color[3],
				piecenum,
				0,0,0,0 -- this is needed to keep the lua copy of the vbo the correct size
			},
			airjetkey,
			true, -- update exisiting
			nil,  -- noupload
			unitID -- unitID
			)
		return airjetkey
	end

	WG['airjets'].removeAirJet =  function (airjetkey) ---- for WG external calls
		return popElementInstance(jetInstanceVBO,airjetkey)
	end

end


