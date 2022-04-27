-------------------------------------------------
-- An API wrapper to draw simple graphical primitives at units extremely efficiently
-- License: Lua code  GPL V2, GLSL shader code: (c) Beherith (mysterme@gmail.com)
-------------------------------------------------


local DrawPrimitiveAtUnit = {}

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	HEIGHTOFFSET = 1, -- Additional height added to everything
	ANIMATION = 1, -- set to 0 if you dont want animation
	INITIALSIZE = 0.66, -- What size the stuff starts off at when spawned
	GROWTHRATE = 4, -- How fast it grows to full size
	BREATHERATE = 30.0, -- how fast it periodicly grows
	BREATHESIZE = 0.05, -- how much it periodicly grows
	TEAMCOLORIZATION = 1.0, -- not used yet
	CLIPTOLERANCE = 1.1, -- At 1.0 it wont draw at units just outside of view (may pop in), 1.1 is a good safe amount
	USETEXTURE = 1, -- 1 if you want to use textures (atlasses too!) , 0 if not
	BILLBOARD = 0, -- 1 if you want camera facing billboards, 0 is flat on ground
	POST_ANIM = " ", -- what you want to do in the animation post function (glsl snippet, see shader source)
	POST_VERTEX = "v_color = v_color;", -- noop
	POST_GEOMETRY = "gl_Position.z = (gl_Position.z) - 256.0 / (gl_Position.w);",	--"g_uv.zw = dataIn[0].v_parameters.xy;", -- noop
	POST_SHADING = "fragColor.rgba = fragColor.rgba;", -- noop
	MAXVERTICES = 64, -- The max number of vertices we can emit, make sure this is consistent with what you are trying to draw (tris 3, quads 4, corneredrect 8, circle 64
	USE_CIRCLES = 1, -- set to nil if you dont want circles
	USE_CORNERRECT = 1, -- set to nil if you dont want cornerrect
	USE_TRIANGLES = 1, -- set to nil if you dont want to use tris
	USE_QUADS = 1, -- set to nil if you dont want to use quads
	FULL_ROTATION = 0, -- the primitive is fully rotated in the units plane
	DISCARD = 0, -- Enable alpha threshold to discard fragments below 0.01
	ROTATE_CIRCLES = 1, -- Set to 0 if you dont want circles to be rotated
}

---- GL4 Backend Stuff----
local DrawPrimitiveAtUnitVBO = nil
local DrawPrimitiveAtUnitShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 lengthwidthcornerheight;
layout (location = 1) in uint teamID;
layout (location = 2) in uint numvertices;
layout (location = 3) in vec4 parameters; // lifestart, ismine
layout (location = 4) in vec4 uvoffsets; // this is optional, for using an Atlas
layout (location = 5) in uvec4 instData;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

struct SUniformsBuffer {
    uint composite; //     u8 drawFlag; u8 unused1; u16 id;
    
    uint unused2;
    uint unused3;
    uint unused4;

    float maxHealth;
    float health;
    float unused5;
    float unused6;
    
    vec4 speed;    
    vec4[5] userDefined; //can't use float[20] because float in arrays occupies 4 * float space
};

layout(std140, binding=1) readonly buffer UniformsBuffer {
    SUniformsBuffer uni[];
}; 

#line 10000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

out DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation;
	#endif
};

layout(std140, binding=0) readonly buffer MatrixBuffer {
	mat4 UnitPieces[];
};


bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}

void main()
{
	uint baseIndex = instData.x; // this tells us which unit matrix to find
	mat4 modelMatrix = UnitPieces[baseIndex]; // This gives us the models  world pos and rot matrix

	gl_Position = cameraViewProj * vec4(modelMatrix[3].xyz, 1.0); // We transform this vertex into the center of the model
	v_rotationY = atan(modelMatrix[0][2], modelMatrix[0][0]); // we can get the euler Y rot of the model from the model matrix
	v_uvoffsets = uvoffsets;
	v_parameters = parameters;
	v_color = teamColor[teamID];  // We can lookup the teamcolor right here
	v_centerpos = vec4( modelMatrix[3].xyz, 1.0); // We are going to pass the centerpoint to the GS
	v_lengthwidthcornerheight = lengthwidthcornerheight;
	#if (ANIMATION == 1)
		float animation = clamp(((timeInfo.x + timeInfo.w) - parameters.x)/GROWTHRATE + INITIALSIZE, INITIALSIZE, 1.0) + sin((timeInfo.x)/BREATHERATE)*BREATHESIZE;
		v_lengthwidthcornerheight.xy *= animation; // modulate it with animation factor
	#endif
	POST_ANIM
	v_numvertices = numvertices;
	if (vertexClipped(gl_Position, CLIPTOLERANCE)) v_numvertices = 0; // Make no primitives on stuff outside of screen
	// TODO: take into account size of primitive before clipping

	// this sets the num prims to 0 for units further from cam than iconDistance
	float cameraDistance = length((cameraViewInv[3]).xyz - v_centerpos.xyz);
	if (cameraDistance > iconDistance) v_numvertices = 0;

	if (dot(v_centerpos.xyz, v_centerpos.xyz) < 1.0) v_numvertices = 0; // if the center pos is at (0,0,0) then we probably dont have the matrix yet for this unit, because it entered LOS but has not been drawn yet.

	v_centerpos.y += HEIGHTOFFSET; // Add some height to ensure above groundness
	v_centerpos.y += lengthwidthcornerheight.w; // Add per-instance height offset
	#if (FULL_ROTATION == 1)
		v_fullrotation = mat3(modelMatrix);
	#endif
	if ((uni[instData.y].composite & 0x00000003u) < 1u ) v_numvertices = 0u; // this checks the drawFlag of wether the unit is actually being drawn (this is ==1 when then unit is both visible and drawn as a full model (not icon)) 
	// TODO: allow overriding this check, to draw things even if unit (like a building) is not drawn
	POST_VERTEX
}
]]

local gsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__
layout(points) in;
layout(triangle_strip, max_vertices = MAXVERTICES) out;
#line 20000

uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;

in DataVS {
	uint v_numvertices;
	float v_rotationY;
	vec4 v_color;
	vec4 v_lengthwidthcornerheight;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
	#if (FULL_ROTATION == 1)
		mat3 v_fullrotation;
	#endif
} dataIn[];

out DataGS {
	vec4 g_color;
	vec4 g_uv;
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
vec2 transformUV(float u, float v){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * u, uvoffsets.p + b * v);
}

void offsetVertex4( float x, float y, float z, float u, float v){
	g_uv.xy = transformUV(u,v);
	vec3 primitiveCoords = vec3(x,y,z);
	vec3 vecnorm = normalize(primitiveCoords);
	gl_Position = cameraViewProj * vec4(centerpos.xyz + rotY * ( addRadius * vecnorm + primitiveCoords ), 1.0);
	g_uv.zw = dataIn[0].v_parameters.zw;
	POST_GEOMETRY
	EmitVertex();
}
#line 22000
void main(){
	uint numVertices = dataIn[0].v_numvertices;
	centerpos = dataIn[0].v_centerpos;
	#if (BILLBOARD == 1 )
		rotY = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	#else
		#if (FULL_ROTATION == 1)
			rotY = dataIn[0].v_fullrotation; // Use the units true rotation
		#else
			#if (ROTATE_CIRCLES == 1)
				rotY = rotation3dY(-1*dataIn[0].v_rotationY); // Create a rotation matrix around Y from the unit's rotation
			#else
				if (numVertices > uint(5)) rotY = mat3(1.0) ;
				else rotY = rotation3dY(-1*dataIn[0].v_rotationY);
			#endif
		#endif
	#endif

	g_color = dataIn[0].v_color;

	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float length = dataIn[0].v_lengthwidthcornerheight.x;
	float width = dataIn[0].v_lengthwidthcornerheight.y;
	float cs = dataIn[0].v_lengthwidthcornerheight.z;
	float height = dataIn[0].v_lengthwidthcornerheight.w;
	
	#ifdef USE_TRIANGLES
		if (numVertices == uint(3)){ // triangle pointing "forward"
			offsetVertex4(0.0, 0.0, length, 0.5, 1.0); // xyz uv
			offsetVertex4(-0.866 * width, 0.0, -0.5 * length, 0.0, 0.0);
			offsetVertex4(0.866* width, 0.0, -0.5 * length, 1.0, 0.0);
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_QUADS
		if (numVertices == uint(4)){ // A quad
			offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0);
			offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0);
			offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0);
			offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0);
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_CORNERRECT
		if (numVertices == uint(2)){ // A quad with chopped off corners
			float csuv = (cs / (length + width))*2.0;
			offsetVertex4( - width * 0.5 , 0.0,  - length * 0.5 + cs, 0, csuv); // bottom left
			offsetVertex4( - width * 0.5 , 0.0,  + length * 0.5 - cs, 0, 1.0 - csuv); // top left
			offsetVertex4( - width * 0.5 + cs, 0.0,  - length * 0.5 , csuv, 0); // bottom left
			offsetVertex4( - width * 0.5 + cs, 0.0,  + length * 0.5, csuv, 1.0); // top left
			offsetVertex4( + width * 0.5 - cs, 0.0,  - length * 0.5 , 1.0 - csuv, 0.0); // bottom right
			offsetVertex4( + width * 0.5 - cs, 0.0,  + length * 0.5 ,1.0 - csuv, 1.0 ); // top right
			offsetVertex4( + width * 0.5 , 0.0,  - length * 0.5 + cs , 1.0 , csuv ); // bottom right
			offsetVertex4( + width * 0.5 , 0.0,  + length * 0.5 - cs , 1.0 -csuv , 1.0 ); // top right
			EndPrimitive();
		}
	#endif
	
	#ifdef USE_CIRCLES
		if (numVertices > uint(5)) { //A circle with even subdivisions
			numVertices = min(numVertices,62u); // to make sure that we dont emit more than 64 vertices
			//left most vertex
			offsetVertex4(- width * 0.5, 0.0,  0, 0.0, 0.5);
			int numSides = int(numVertices) / 2;
			//for each phi in (-PI/2, Pi/2) omit the first and last one
			for (int i = 1; i < numSides; i++){
				float phi = ((i * 3.141592) / numSides) -  1.5707963;
				float sinphi = sin(phi);
				float cosphi = cos(phi);
				offsetVertex4( width * 0.5 * sinphi, 0.0,  length * 0.5 * cosphi, sinphi*0.5 + 0.5, cosphi * 0.5 + 0.5);
				offsetVertex4( width * 0.5 * sinphi, 0.0,  -length * 0.5 * cosphi, sinphi*0.5 + 0.5, cosphi *(-0.5) + 0.5);
			}
			// add right most vertex
			offsetVertex4(width * 0.5, 0.0,  0, 1.0, 0.5);
			EndPrimitive();
		}
	#endif
}
]]

local fsSrc =
[[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 30000
uniform float addRadius = 0.0;
uniform float iconDistance = 20000.0;
in DataGS {
	vec4 g_color;
	vec4 g_uv;
};

uniform sampler2D DrawPrimitiveAtUnitTexture;
out vec4 fragColor;

void main(void)
{
	vec4 texcolor = vec4(1.0);
	#if (USETEXTURE == 1)
		texcolor = texture(DrawPrimitiveAtUnitTexture, g_uv.xy);
	#endif
	fragColor.rgba = vec4(g_color.rgb * texcolor.rgb + addRadius, texcolor.a * TRANSPARENCY + addRadius);
	POST_SHADING
	//fragColor.rgba = vec4(1.0);
	#if (DISCARD == 1)
		if (fragColor.a < 0.01) discard;
	#endif
}
]]

local function InitDrawPrimitiveAtUnit(shaderConfig, DPATname)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	DrawPrimitiveAtUnitShader =  LuaShader(
		{
		  vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  geometry = gsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  uniformInt = (shaderConfig.USETEXTURE== 1 and {
				DrawPrimitiveAtUnitTexture = 0;
			}) or {}, -- dont pass any texture units to this unless told to do so
		uniformFloat = {
			addRadius = 0.0,
			iconDistance = 20000.0,
		  },
		},
		DPATname .. "Shader GL4"
	  )
	local shaderCompiled = DrawPrimitiveAtUnitShader:Initialize()
	if not shaderCompiled then 
		Spring.Echo("Failed to compile shader for ", DPATname)
		return nil
	end

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 2, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'parameters', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		},
		64, -- maxelements
		DPATname .. "VBO", -- name
		5  -- unitIDattribID (instData)
	)
	if DrawPrimitiveAtUnitVBO == nil then 
		Spring.Echo("Failed to create DrawPrimitiveAtUnitVBO for ", DPATname) 
		return nil
	end

	local DrawPrimitiveAtUnitVAO = gl.GetVAO()
	DrawPrimitiveAtUnitVAO:AttachVertexBuffer(DrawPrimitiveAtUnitVBO.instanceVBO)
	DrawPrimitiveAtUnitVBO.VAO = DrawPrimitiveAtUnitVAO
	return  DrawPrimitiveAtUnitVBO, DrawPrimitiveAtUnitShader
end

return {InitDrawPrimitiveAtUnit = InitDrawPrimitiveAtUnit, shaderConfig = shaderConfig}
