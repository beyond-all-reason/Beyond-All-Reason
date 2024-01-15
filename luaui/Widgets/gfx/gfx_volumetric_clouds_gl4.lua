function widget:GetInfo()
	return {
		name = "Fog Volumes Old GL4",
		desc = "Try to draw fog spheres",
		author = "Beherith",
		date = "2022.04.16",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end

local fogSphereVBO = nil
local fogSphereShader = nil
local fogSphereShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local spec, fullview = Spring.GetSpectatingState()

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
	FULL_ROTATION = 0, -- the primitive is fully rotated in the units plane
}

---- GL4 Backend Stuff----

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local fogSphereInstanceVBO = nil 

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 position; // l w rot and maxalpha
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 worldPosRad; 
layout (location = 4) in vec4 colordensity1; 
layout (location = 5) in vec4 colordensity2; 
layout (location = 6) in vec4 parameters; 


//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_colordensity1;
	vec4 v_colordensity2;
	vec4 v_parameters;
	vec3 v_normals;
	vec2 v_uvs;
	vec3 v_tocamera;
	vec3 v_fragWorld;
};


#line 11000
void main()
{
	v_worldPosRad = worldPosRad;
	v_colordensity1 = colordensity1;
	v_colordensity2 = colordensity2;
	v_parameters = parameters;
	v_normals = normals;
	v_uvs = v_uvs;
	//v_worldPosRad.xzw = v_worldPosRad.xzw * sin(vec3(1.1, 1.2, 1.3) * timeInfo.x * 0.1);
	
	vec3 worldPos = position.xyz * v_worldPosRad.w + v_worldPosRad.xyz;
	
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
	
	vec3 camPos = cameraViewInv[3].xyz ;
	v_tocamera = normalize(camPos- worldPos);
	v_fragWorld = worldPos.xyz;
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
uniform float iconDistance;
in DataVS {
	vec4 v_worldPosRad;
	vec4 v_colordensity1;
	vec4 v_colordensity2;
	vec4 v_parameters;
	vec3 v_normals;
	vec2 v_uvs;
	vec3 v_tocamera;
	vec3 v_fragWorld;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D infoTex;
uniform sampler2DShadow shadowTex;


out vec4 fragColor;

//https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl
float SimplexPerlin3D( vec3 P )
{
    //  https://github.com/BrianSharpe/Wombat/blob/master/SimplexPerlin3D.glsl

    //  simplex math constants
    const float SKEWFACTOR = 1.0/3.0;
    const float UNSKEWFACTOR = 1.0/6.0;
    const float SIMPLEX_CORNER_POS = 0.5;
    const float SIMPLEX_TETRAHEDRON_HEIGHT = 0.70710678118654752440084436210485;    // sqrt( 0.5 )

    //  establish our grid cell.
    P *= SIMPLEX_TETRAHEDRON_HEIGHT;    // scale space so we can have an approx feature size of 1.0
    vec3 Pi = floor( P + dot( P, vec3( SKEWFACTOR) ) );

    //  Find the vectors to the corners of our simplex tetrahedron
    vec3 x0 = P - Pi + dot(Pi, vec3( UNSKEWFACTOR ) );
    vec3 g = step(x0.yzx, x0.xyz);
    vec3 l = 1.0 - g;
    vec3 Pi_1 = min( g.xyz, l.zxy );
    vec3 Pi_2 = max( g.xyz, l.zxy );
    vec3 x1 = x0 - Pi_1 + UNSKEWFACTOR;
    vec3 x2 = x0 - Pi_2 + SKEWFACTOR;
    vec3 x3 = x0 - SIMPLEX_CORNER_POS;

    //  pack them into a parallel-friendly arrangement
    vec4 v1234_x = vec4( x0.x, x1.x, x2.x, x3.x );
    vec4 v1234_y = vec4( x0.y, x1.y, x2.y, x3.y );
    vec4 v1234_z = vec4( x0.z, x1.z, x2.z, x3.z );

    // clamp the domain of our grid cell
    Pi.xyz = Pi.xyz - floor(Pi.xyz * ( 1.0 / 69.0 )) * 69.0;
    vec3 Pi_inc1 = step( Pi, vec3( 69.0 - 1.5 ) ) * ( Pi + 1.0 );

    //	generate the random vectors
    vec4 Pt = vec4( Pi.xy, Pi_inc1.xy ) + vec2( 50.0, 161.0 ).xyxy;
    Pt *= Pt;
    vec4 V1xy_V2xy = mix( Pt.xyxy, Pt.zwzw, vec4( Pi_1.xy, Pi_2.xy ) );
    Pt = vec4( Pt.x, V1xy_V2xy.xz, Pt.z ) * vec4( Pt.y, V1xy_V2xy.yw, Pt.w );
    const vec3 SOMELARGEFLOATS = vec3( 635.298681, 682.357502, 668.926525 );
    const vec3 ZINC = vec3( 48.500388, 65.294118, 63.934599 );
    vec3 lowz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi.zzz * ZINC.xyz ) );
    vec3 highz_mods = vec3( 1.0 / ( SOMELARGEFLOATS.xyz + Pi_inc1.zzz * ZINC.xyz ) );
    Pi_1 = ( Pi_1.z < 0.5 ) ? lowz_mods : highz_mods;
    Pi_2 = ( Pi_2.z < 0.5 ) ? lowz_mods : highz_mods;
    vec4 hash_0 = fract( Pt * vec4( lowz_mods.x, Pi_1.x, Pi_2.x, highz_mods.x ) ) - 0.49999;
    vec4 hash_1 = fract( Pt * vec4( lowz_mods.y, Pi_1.y, Pi_2.y, highz_mods.y ) ) - 0.49999;
    vec4 hash_2 = fract( Pt * vec4( lowz_mods.z, Pi_1.z, Pi_2.z, highz_mods.z ) ) - 0.49999;

    //	evaluate gradients
    vec4 grad_results = inversesqrt( hash_0 * hash_0 + hash_1 * hash_1 + hash_2 * hash_2 ) * ( hash_0 * v1234_x + hash_1 * v1234_y + hash_2 * v1234_z );

    //	Normalization factor to scale the final result to a strict 1.0->-1.0 range
    //	http://briansharpe.wordpress.com/2012/01/13/simplex-noise/#comment-36
    const float FINAL_NORMALIZATION = 37.837227241611314102871574478976;

    //  evaulate the kernel weights ( use (0.5-x*x)^3 instead of (0.6-x*x)^4 to fix discontinuities )
    vec4 kernel_weights = v1234_x * v1234_x + v1234_y * v1234_y + v1234_z * v1234_z;
    kernel_weights = max(0.5 - kernel_weights, 0.0);
    kernel_weights = kernel_weights*kernel_weights*kernel_weights;

    //	sum with the kernel and return
    return dot( kernel_weights, grad_results ) * FINAL_NORMALIZATION;
}

// https://gist.github.com/wwwtyro/beecc31d65d1004f5a9d
vec2 raySphereIntersect(vec3 r0, vec3 rd, vec3 s0, float sr) {
    // - r0: ray origin
    // - rd: normalized ray direction
    // - s0: sphere center
    // - sr: sphere radius
    // - Returns distance from r0 to first intersection with sphere,
    //   or -1.0 if no intersection.
    float a = dot(rd, rd);
    vec3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sr * sr);
	float disc = b * b - 4.0 * a* c;
    if (disc < 0.0) {
        return vec2(-1.0, -1.0);
    }else{
		disc = sqrt(disc);
		return vec2(-b - disc, -b + disc) / (2.0 * a);
	}
}



vec4 raymarch(vec3 startpoint, vec3 endpoint, float steps, vec4 sphereposrad){
	
	float noisescale = 0.01;
	float fulldist = length((startpoint - endpoint));
	float stepsize = fulldist / steps;
	float interval = 1.0/ steps;
	
	float fogaccum = 1.0; SimplexPerlin3D(startpoint * noisescale);
	for (float f = 0; f < 1.0; f = f + interval){
		vec3 currpos = mix(startpoint, endpoint, f);
		currpos.y -= timeInfo.x;
		fogaccum = fogaccum +  max(0.0, SimplexPerlin3D(currpos * noisescale)) * stepsize * interval;
		
	}
	
	return vec4(fogaccum * 0.2);
}


#line 31000
void main(void)
{
	vec3 camPos = cameraViewInv[3].xyz ;
	vec3 camDir = normalize(camPos-v_fragWorld);
	float radiusmult = 0.95;
	vec2 closeandfarsphere = raySphereIntersect(camPos, -1.0 * normalize(camDir), v_worldPosRad.xyz, radiusmult * v_worldPosRad.w);
	
	// sample the fucking world:
	
	vec2 screenUV = gl_FragCoord.xy/ viewGeometry.xy;

	// Sample the depth buffers, and choose whichever is closer to the screen
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);
	
	vec4 mapWorldPos =  vec4(  vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz/ mapWorldPos.w; // YAAAY this works!
	
	float distancetoeye = length (camPos - mapWorldPos.xyz);
	//closeandfarsphere.y = min(closeandfarsphere.y, distancetoeye);
	
	float distthroughsphere = clamp((closeandfarsphere.y - closeandfarsphere.x )/ (2*v_worldPosRad.w*radiusmult), 0.0, 0.95);
	
	float fogamout = pow(distthroughsphere ,2.0);
	
	fogamout = smoothstep(0.0,1.5,fogamout);
	
	// some helper data structures:
	
	vec3 close_spherepoint = -1 * camDir * closeandfarsphere.x  + camPos;
	vec3 far_spherepoint   = -1 * camDir * closeandfarsphere.y  + camPos;
	
	
	
	//vec4 tex1color = texture(atlasColor, g_uv.xy);
	//vec4 tex2color = texture(atlasNormal, g_uv.xy);
	//vec4 minimapcolor = minimapAtWorldPos( g_params.xy );
	//fragColor.rgba = vec4(g_color.rgb * tex1color.rgb, tex1color.a );
	//fragColor.rgba = vec4(minimapcolor.rgb* tex1color.r,  tex1color.g + g_params.z);
	//fragColor.rgba = minimapcolor;
	//fragColor.rgba = vec4(g_uv.x, g_uv.y, 0.0, 0.6);
	//fragColor.rgba = vec4(vec3(v_normals * dot(sunDir.xyz,v_normals) * 0.5 + 0.5), 1.0);
	//fragColor.rgba = vec4(vec3(v_normals * 0.5 + 0.5), 1.0);
	//fragColor.rgba = vec4(vec3(fract(closeandfarsphere.x * 0.01)), fogamout);
	fragColor.rgba = vec4(vec3(1.0), distthroughsphere);
	
	
	vec3 dbgdist = clamp(vec3( closeandfarsphere.x, closeandfarsphere.y, distancetoeye)*0.001, 0.0, 1.0);
	fragColor.rgba = vec4( dbgdist.rgb, 1.0);
	fragColor.rgba = vec4( fract(far_spherepoint * 0.02), 1.0);
	//fragColor.rgba = vec4( vec3(SimplexPerlin3D(far_spherepoint* 0.02)), 1.0);

	vec4 rm = raymarch(far_spherepoint, close_spherepoint, 20.0, v_worldPosRad);
	fragColor.rgba = vec4(vec3(rm.rgb), 1.0);
	rm.r = clamp(rm.r, 0.0, 1.0);
	fragColor.rgba = vec4(vec3(2.0-rm.r*rm.r), rm.r*fogamout);
	
}
]]

local function goodbye(reason)
  Spring.Echo("DrawPrimitiveAtUnits GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function InitDrawPrimitiveAtUnit(shaderConfig, DPATname)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fogSphereShader =  LuaShader(
		{
		  vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  uniformInt = {
			mapDepths = 0,
			modelDepths = 1,
			heightmapTex = 2,
			infoTex = 3,
			shadowTex = 4,
			},
		uniformFloat = {
			fadeDistance = 300000,
		  },
		},
		DPATname .. "Shader"
	  )
	local shaderCompiled = fogSphereShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	local sphereVBO, numVertices, sphereIndexVBO, numIndices = makeSphereVBO(32,16	,1)
	Spring.Echo(sphereVBO,numVertices, sphereIndexVBO, numIndices)

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 3, name = 'worldPosRad', size = 4},
			{id = 4, name = 'colordensity1', size = 4},
			{id = 5, name = 'colordensity2', size = 4},
			{id = 6, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if DrawPrimitiveAtUnitVBO == nil then goodbye("Failed to create DrawPrimitiveAtUnitVBO") end
	
	DrawPrimitiveAtUnitVBO.vertexVBO = sphereVBO
	DrawPrimitiveAtUnitVBO.indexVBO  = sphereIndexVBO
	
	DrawPrimitiveAtUnitVBO.VAO = makeVAOandAttach(
		DrawPrimitiveAtUnitVBO.vertexVBO, 
		DrawPrimitiveAtUnitVBO.instanceVBO, 
		DrawPrimitiveAtUnitVBO.indexVBO)
	
	return  DrawPrimitiveAtUnitVBO, fogSphereShader
end

local fogSphereIndex = 0
local fogSphereTimes = {} -- maps instanceID to expected fadeout timeInfo
local fogSphereRemoveQueue = {} -- maps gameframes to list of fogSpheres that will be removed

local function AddFogSphere(px,py, pz, r)
	
	local gf = Spring.GetGameFrame()

	--Spring.Echo (unitDefID,fogSphereInfo.texfile, width, length, alpha)
	local lifetime = 1000000
	fogSphereIndex = fogSphereIndex + 1
	pushElementInstance(
		fogSphereVBO, -- push into this Instance VBO Table
			{px,py, pz, r ,  -- lengthwidthrotation maxalpha
			1,1,1,1,
			1,1,1,1,
			0,0,0,0,},
		fogSphereIndex, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	local deathtime = gf + lifetime
	fogSphereTimes[fogSphereIndex] = deathtime
	if fogSphereRemoveQueue[deathtime] == nil then 
		fogSphereRemoveQueue[deathtime] = {fogSphereIndex}
	else
		fogSphereRemoveQueue[deathtime][#fogSphereRemoveQueue[deathtime] + 1 ] = fogSphereIndex
	end
	return fogSphereIndex, lifetime
end

function widget:DrawWorld()
	if fogSphereVBO.usedElements > 0 then
		--local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		Spring.Echo(fogSphereVBO.usedElements)
		glCulling(GL_BACK)
		--glCulling(false)
		glDepthTest(GL_LEQUAL)
		--glDepthTest(false)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		gl.Texture(0, "$map_gbuffer_zvaltex")-- Texture file
		gl.Texture(1, "$model_gbuffer_zvaltex")-- Texture file
		gl.Texture(2, "$heightmap")-- Texture file
		gl.Texture(3, "$info")-- Texture file
		gl.Texture(4, "$shadow")-- Texture file
		
		fogSphereShader:Activate()
		--fogSphereVBO.VAO:DrawArrays(GL.TRIANGLES,fogSphereVBO.numVertices,0, fogSphereVBO.usedElements,0	)
		fogSphereVBO.VAO:DrawElements(GL.TRIANGLES,nil,0, fogSphereVBO.usedElements,0)
		--drawInstanceVBO(fogSphereVBO)
		fogSphereShader:Deactivate()
		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
		glTexture(4, false)
		--glCulling(false)
		glDepthTest(false)
	end
end

local function RemovefogSphere(instanceID)
	if fogSphereVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(fogSphereVBO, instanceID)
	end
	fogSphereTimes[instanceID] = nil
end

function widget:GameFrame(n)
--[[
	if fogSphereRemoveQueue[n] then 
		for i=1, #fogSphereRemoveQueue[n] do
			RemovefogSphere(fogSphereRemoveQueue[n][i])
		end
		fogSphereRemoveQueue[n] = nil
	end
]]--
end

function widget:Initialize()
	--shaderConfig.MAXVERTICES = 4
	fogSphereVBO, fogSphereShader = InitDrawPrimitiveAtUnit(shaderConfig, "fogSpheres")
	math.randomseed(1)
	if true then 
		for i= 1, 20 do 
			local radius = math.random() * 300 + 100
			local posx = Game.mapSizeX * math.random() * 1.0
			local posz = Game.mapSizeZ * math.random() * 1.0
			local posy = Spring.GetGroundHeight(posx, posz) + math.random() * radius
			AddFogSphere(
					posx, posy, posz, radius,
					1,1,1,1,
					1,1,1,1,
					0,0,0,0
					)
			
		end
	end
end
