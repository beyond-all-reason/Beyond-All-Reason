function widget:GetInfo()
	return {
		name = "Fog Volumes GL4",
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

local noisetex3d64 =  "LuaUI/images/noise3d64rgb.bmp"
local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"
local dithernoise2d =  "LuaUI/images/rgbnoise.png"
--local noisetex3dcube =  "LuaUI/images/lavadistortion.png"
--local noisetex3d64 =  "LuaUI/images/grid3d64rgb.bmp"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	HEIGHTOFFSET = 1, -- Additional height added to everything
	SPHERESEGMENTS = 16,
	RESOLUTION = 2,
}

---- GL4 Backend Stuff----
-- omg all possible object-object intersection tests: http://www.realtimerendering.com/intersections.html

-- TODO: 
	-- expose spawning funcs
	-- handle being inside at most 1 sphere

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local fogSphereInstanceVBO = nil 

local fogTexture
local vsx, vsy
local combineShader

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec3 position; // l w rot and maxalpha
layout (location = 1) in vec3 normals;
layout (location = 2) in vec2 uvs;

layout (location = 3) in vec4 worldPosRad; 
layout (location = 4) in vec4 colordensity; 
layout (location = 5) in vec4 velocity; 
layout (location = 6) in vec4 fadeparameters; //fadeinstart, fadeinrate, fadeoutstart, fadeoutrate, 
layout (location = 7) in vec4 spawnframe_frequency_riserate_windstrength;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

out DataVS {
	vec4 v_worldPosRad;
	vec4 v_colordensity;
	vec4 v_spawnframe_frequency_riserate_windstrength;
	vec2 v_uvs;
	vec3 v_fragWorld;
	float currfade;
};

void main()
{
	float time = timeInfo.x + timeInfo.w;
	v_worldPosRad = worldPosRad + (time - spawnframe_frequency_riserate_windstrength.x) * velocity;
	v_colordensity = colordensity;
	v_spawnframe_frequency_riserate_windstrength = spawnframe_frequency_riserate_windstrength;
	v_uvs = v_uvs;
	vec3 worldPos = position * v_worldPosRad.w + v_worldPosRad.xyz ;
	
	gl_Position = cameraViewProj * vec4(worldPos, 1.0);
	
	vec3 camPos = cameraViewInv[3].xyz;
	v_fragWorld = worldPos.xyz;
	
	float fadeinstart = fadeparameters.x;
	float fadeinrate = fadeparameters.y;
	float fadeoutstart = fadeparameters.z;
	float fadeoutrate = fadeparameters.w;
	currfade = clamp((time - fadeinstart) * fadeinrate, 0.0, 1.0) - clamp((time - fadeoutstart) * fadeoutrate, 0.0, 1.0);
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
	vec4 v_colordensity;
	vec4 v_spawnframe_frequency_riserate_windstrength;
	vec2 v_uvs;
	vec3 v_fragWorld;
	float currfade;
};

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D heightmapTex;
uniform sampler2D infoTex;
uniform sampler2DShadow shadowTex;
uniform sampler3D noise64cube;
uniform sampler2D dithernoise2d;

out vec4 fragColor;

float frequency;

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

float shadowAtWorldPos(vec3 worldPos){
		vec4 shadowVertexPos = shadowView * vec4(worldPos,1.0);
		shadowVertexPos.xy += vec2(0.5);
		return clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
}

vec4 raymarch(vec3 startpoint, vec3 endpoint, float steps, vec4 sphereposrad){
	float noisescale = 0.002 * v_spawnframe_frequency_riserate_windstrength.y;
	float fulldist = length((startpoint - endpoint));
	float stepsize = fulldist / steps; // this is number of elmos per sample
	float interval = 1.0/ steps; // step interval
	
	float fogaccum = 1.0; 
	float shadowamount = 0.0;
	// we need a better way to accumulate, kind of like how much light is let through
	float currenttime = timeInfo.x+ timeInfo.w;
	vec4 dithernoise = textureLod(dithernoise2d, startpoint.xz, 0.0);
	vec3 noiseoffset;
	noiseoffset.y = -1 * currenttime * v_spawnframe_frequency_riserate_windstrength.z; 
	noiseoffset.xz = -0.0001 * currenttime * (windInfo.xz*windInfo.w) * v_spawnframe_frequency_riserate_windstrength.w;
	
	for (float f = dithernoise.x*interval*2; f < 1.0; f = f + interval){
		vec3 currpos = mix(startpoint, endpoint, f);
		vec3 noisepos = currpos;
		//	noisepos.y -= currenttime * v_spawnframe_frequency_riserate_windstrength.z;
		noisepos += noiseoffset;
		//noisepos.xz -= currenttime * (windInfo.xz*windInfo.w) * v_spawnframe_frequency_riserate_windstrength.w; // windx, windy, windz, windStrength
		
		float justnoiseval = (textureLod(noise64cube, fract(noisepos * noisescale), 0.0).a * 2.0 - 1.0);
		
		fogaccum = fogaccum  * (1.0 -  clamp(justnoiseval * stepsize * interval * 5, 0.0, 0.8));
		
		shadowamount = shadowamount + shadowAtWorldPos(currpos);
	}
	shadowamount = shadowamount / steps;
	shadowamount = pow(shadowamount, 2.0);
	return vec4(fogaccum, shadowamount, 0.0, 0.0);
}


#line 31000
void main(void)
{
	frequency = v_spawnframe_frequency_riserate_windstrength.y;
	vec3 camPos = cameraViewInv[3].xyz ;
	vec3 camDir = normalize(camPos-v_fragWorld);
	float radiusmult = 0.98; //0.98;
	vec2 closeandfarsphere = raySphereIntersect(camPos, -1.0 * normalize(camDir), v_worldPosRad.xyz, radiusmult * v_worldPosRad.w);
	
	// sample the fucking world:
	
	vec2 screenUV = gl_FragCoord.xy * RESOLUTION / viewGeometry.xy;

	// Sample the depth buffers, and choose whichever is closer to the screen
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	mapdepth = min(mapdepth, modeldepth);
	
	vec4 mapWorldPos =  vec4( vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz / mapWorldPos.w; // YAAAY this works!
	
	float distancetoeye = length(camPos - mapWorldPos.xyz);
	closeandfarsphere.y = min(closeandfarsphere.y, distancetoeye);
	
	// some helper positions:
	vec3 close_spherepoint = -1 * camDir * closeandfarsphere.x  + camPos;
	vec3 far_spherepoint   = -1 * camDir * closeandfarsphere.y  + camPos;
	
	float distthroughsphere = clamp((closeandfarsphere.y - closeandfarsphere.x )/ (2*v_worldPosRad.w*radiusmult), 0.0, 1.0);
		
	float distancetosphere = length(camPos - v_worldPosRad.xyz);
	if (distancetosphere < radiusmult * v_worldPosRad.w) { // then we WILL intersect, but where?
		close_spherepoint = camPos;
		far_spherepoint = -1 * camDir * max(closeandfarsphere.x, closeandfarsphere.y)  + camPos;
		distthroughsphere = clamp(length(camPos - far_spherepoint) / (2*v_worldPosRad.w*radiusmult), 0.0, 1.0);
		fragColor.rgba = vec4( vec3(distthroughsphere), 1.0);
		//distthroughsphere *= 1.5;
	}

	fragColor.rgba = vec4( vec3(distthroughsphere), 1.0);
	
	//return;
	//fragColor.rgba = vec4( fract(far_spherepoint * 0.01), 1.0);
		
	float fogamout = pow(distthroughsphere ,1);
	
	//fogamout = smoothstep(0.0,1.0,fogamout) * 0.9 ;
	
	
	
	
	
	//fragColor.rgba = vec4(vec3(fract(closeandfarsphere.x * 0.01)), fogamout);
	fragColor.rgba = vec4(vec3(1.0), distthroughsphere);
	
	//vec3 dbgdist = clamp(vec3( closeandfarsphere.x, closeandfarsphere.y, distancetoeye)*0.001, 0.0, 1.0);
	

	vec4 rm = raymarch(far_spherepoint, close_spherepoint, 128.0, v_worldPosRad);
	fragColor.rgba = vec4(vec3(rm.rgb), 1.0);
	rm.r = clamp(rm.r, 0.0, 1.0);
	fragColor.rgba = vec4(vec3(rm.g), (1.0 - rm.r) * fogamout);
	
	//fragColor.rgba = vec4( dbgdist.bbb	, 1.0);

	//fragColor.rgb = vec3(shadowAtWorldPos(close_spherepoint.xyz));
	
	fragColor.rgba *= v_colordensity;
	
	//if ((closeandfarsphere.x < 0.0) || (closeandfarsphere.y < 0.0)) fragColor.a = 0.0;
	//fragColor.rgba = vec4( fract(far_spherepoint * 0.02), 1.0);
	//fragColor.a = 1.0;
	
}
]]

local function goodbye(reason)
  Spring.Echo("Fog Volumes GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	if Spring.GetMiniMapDualScreen() == 'left' then
		vsx = vsx / 2
	end
	if Spring.GetMiniMapDualScreen() == 'right' then
		vsx = vsx / 2
	end

	if fogTexture then gl.DeleteTexture(fogTexture) end

	fogTexture = gl.CreateTexture(vsx/ shaderConfig.RESOLUTION, vsy/shaderConfig.RESOLUTION, {
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP_TO_EDGE,
		wrap_t = GL.CLAMP_TO_EDGE,
		fbo = true,
		})
end

local function initFogGL4(shaderConfig, DPATname)
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
			noise64cube = 5,
			dithernoise2d = 6,
			},
		uniformFloat = {
			fadeDistance = 300000,
			},
		},
		DPATname .. "Shader"
	  )
	local shaderCompiled = fogSphereShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	local sphereVBO, numVertices, sphereIndexVBO, numIndices = makeSphereVBO(shaderConfig.SPHERESEGMENTS, shaderConfig.SPHERESEGMENTS/2, 1)
	Spring.Echo(sphereVBO, numVertices, sphereIndexVBO, numIndices)

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 3, name = 'worldPosRad', size = 4},
			{id = 4, name = 'colordensity', size = 4},
			{id = 5, name = 'velocity', size = 4},
			{id = 6, name = 'fadeparameters', size = 4},
			{id = 7, name = 'spawnframe_frequency', size = 4},
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

	widget:ViewResize()
	
	combineShader = gl.CreateShader({
		--while this vertex shader seems to do nothing, it actually does the very important world space to screen space mapping for gl.TexRect!
		vertex = [[
			#version 150 compatibility
			void main(void)
			{
				gl_TexCoord[0] = gl_MultiTexCoord0;
				gl_Position    = gl_Vertex;
			} ]],
		fragment = [[
			#version 150 compatibility
			uniform sampler2D texture0;
			void main(void) {gl_FragColor = texture2D(texture0, gl_TexCoord[0].st); }
		]],
		uniformInt = { texture0 = 0, },
	})

	if (combineShader == nil) then
		goodbye("[Fog Volumes::combineShader] combineShader compilation failed")
	end

	return DrawPrimitiveAtUnitVBO, fogSphereShader
end

local fogSphereIndex = 0
local fogSphereTimes = {} -- maps instanceID to expected fadeout timeInfo
local fogSphereRemoveQueue = {} -- maps gameframes to list of fogSpheres that will be removed

local function AddFogSphere(px,py, pz, r, 
							red, green, blue, density, 
							velocityx, veloctity, velocityz, velocityradius, 
							fadeinstart, fadeinrate, fadeoutstart, fadeoutrate, 
							spawnframe, frequency, riserate, windstrength)
	local gf = Spring.GetGameFrame()
	red = red or 1
	green = green or 1
	blue = blue or 1
	density = density or 1
	riserate = riserate or 1
	windstrength = windstrength or 1
	

	--Spring.Echo(px,py, pz, r, 
	--						red, green, blue, density, 
	--						velocityx, veloctity, velocityz, velocityradius, 
	--						fadeinstart, fadeinrate, fadeoutstart, fadeoutrate, 
	--						spawnframe, frequency)

	--Spring.Echo (unitDefID,fogSphereInfo.texfile, width, length, alpha)
	local lifetime = 1000000
	fogSphereIndex = fogSphereIndex + 1
	pushElementInstance(
		fogSphereVBO, -- push into this Instance VBO Table
			{px,py, pz, r ,  -- lengthwidthrotation maxalpha
			red, green, blue, density, 
			velocityx, veloctity, velocityz, velocityradius, 
			fadeinstart, fadeinrate, fadeoutstart, fadeoutrate,
			spawnframe, frequency, riserate, windstrength },
		fogSphereIndex, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	local deathtime = math.floor(fadeoutstart + 1.0/fadeoutrate)
	fogSphereTimes[fogSphereIndex] = deathtime
	if fogSphereRemoveQueue[deathtime] == nil then 
		fogSphereRemoveQueue[deathtime] = {fogSphereIndex}
	else
		fogSphereRemoveQueue[deathtime][#fogSphereRemoveQueue[deathtime] + 1 ] = fogSphereIndex
	end
	return fogSphereIndex, lifetime
end

local toTexture = true

local function renderToTextureFunc() -- this draws the fogspheres onto the texture

	glCulling(GL.FRONT)
	fogSphereVBO.VAO:DrawElements(GL.TRIANGLES,nil,0, fogSphereVBO.usedElements,0)
	glCulling(GL.BACK)
end

local function renderToTextureClear() -- this func is needed to clear the render target
	gl.Blending(GL.ZERO, GL.ZERO)
	gl.Color(1,1,1,1)
	gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end


function widget:DrawWorld()
	if fogSphereVBO.usedElements > 0 then
		if toTexture then 
			gl.RenderToTexture(fogTexture, renderToTextureClear)
		end
		--Spring.Echo(fogSphereVBO.usedElements)
		--glCulling(GL_BACK)
		--glDepthTest(GL_LEQUAL)
		--glDepthTest(false)
		gl.DepthMask(false)
		gl.Texture(0, "$map_gbuffer_zvaltex")
		gl.Texture(1, "$model_gbuffer_zvaltex")
		gl.Texture(2, "$heightmap")
		gl.Texture(3, "$info")
		gl.Texture(4, "$shadow")
		gl.Texture(5, noisetex3dcube)
		gl.Texture(6, dithernoise2d)
		
		fogSphereShader:Activate()
		if toTexture then 
			gl.RenderToTexture(fogTexture, renderToTextureFunc)
		else
			fogSphereVBO.VAO:DrawElements(GL.TRIANGLES,nil,0, fogSphereVBO.usedElements,0)
		end
		
		fogSphereShader:Deactivate()
		glTexture(0, false)
		glTexture(1, false)
		glTexture(2, false)
		glTexture(3, false)
		glTexture(4, false)
		glTexture(5, false)
		glTexture(6, false)
		--glCulling(false)
		glDepthTest(false)
		
		
		
		if toTexture then
			gl.UseShader(combineShader)
			gl.Texture(0, fogTexture)
			gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
			gl.UseShader(0)
			--gl.TexRect(0, 0, 10000, 10000, 0, 0, 1, 1) -- dis is for debuggin!
			gl.Texture(0, false)
		end
	end
end

local function RemovefogSphere(instanceID)
	if fogSphereVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(fogSphereVBO, instanceID)
	end
	fogSphereTimes[instanceID] = nil
end

local function AddRandomFogSphere()
	local gf = Spring.GetGameFrame()
	local radius = math.random() * 300 + 100
	local posx = Game.mapSizeX * math.random() * 1.0
	local posz = Game.mapSizeZ * math.random() * 1.0
	local posy = Spring.GetGroundHeight(posx, posz) + math.random() * 0.5 * radius
	AddFogSphere(
			posx, posy, posz, radius,
			math.random(), math.random(), math.random() , math.random()*0.1 + 0.9 ,
			math.random() - 0.5, math.random() - 0.5, math.random() - 0.5, math.random() -0.5,
			gf, math.random() * 0.1, gf + math.random() * 1000, math.random() * 0.01,
			gf, math.random() + 0.5, math.random()*2, math.random()*2
			)
end

function widget:GameFrame(n)
	if fogSphereRemoveQueue[n] then 
		for i=1, #fogSphereRemoveQueue[n] do
			RemovefogSphere(fogSphereRemoveQueue[n][i])
			AddRandomFogSphere()
		end
		fogSphereRemoveQueue[n] = nil
	end
end

function widget:Initialize()
	--shaderConfig.MAXVERTICES = 4
	fogSphereVBO, fogSphereShader = initFogGL4(shaderConfig, "fogSpheres")
	math.randomseed(1)
	if true then 
		for i= 1, 100 do 
			AddRandomFogSphere()
		end
	end
end
