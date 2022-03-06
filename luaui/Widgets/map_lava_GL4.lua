function widget:GetInfo()
  return {
    name      = "Lava GL4",
    desc      = "Draw Lava, for internal use",
    author    = "Beherith",
    date      = "2022.03.04",
    license   = "Lua: GNU GPL, v2 or later, GLSL: (c) Beherith (mysterme@gmail.com)",
    layer     = 500000,
    enabled   = false
  }
end
-----------------
local texturesamplingmode = '' -- ':l:' causes MASSIVE load on zoom out and downsampling textures!
local lavaDiffuseEmit = texturesamplingmode .. "LuaUI/images/lava2_diffuseemit.tga" -- pack emissiveness into alpha channel (this is also used as heat for distortion)
local lavaNormalHeight = texturesamplingmode .."LuaUI/images/lava2_normalheight.tga"
local lavaDistortion = texturesamplingmode .. "LuaUI/images/lavadistortion.png"

local lavaShader 
local lavaPlaneVAO
local lavalevel = 50

local foglightShader
local foglightVAO
local numfoglightVerts

local foglightenabled = true
local fogheightabovelava = 50

local heatdistortx = 0
local heatdistortz = 0


local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua") -- we are only gonna use the plane maker func of this


local elmosPerSquare = 256 -- larger numbers are lower resolution 
local unifiedShaderConfig = {
	vertex_displacement = 0, 
	HEIGHTOFFSET = 2.0, 
	COASTWIDTH = 20.0,
	WORLDUVSCALE = 4.0,
	COASTCOLOR = "vec3(2.0, 0.5, 0.0)",
	SPECULAREXPONENT = 64.0, 
	SPECULARSTRENGTH = 1.0, 
	LOSDARKNESS = 0.5,
	FOGHEIGHTABOVELAVA = fogheightabovelava,
	FOGCOLOR = "vec3(2.0, 0.5, 0.0)",
	FOGFACTOR = 0.1,
	EXTRALIGHTCOAST = 0.4,
}


local lavaVSSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
layout (location = 0) in vec2 planePos;

uniform float lavaHeight;

out DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
	vec4 randpervertex;
};
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

const vec2 inverseMapSize = 1.0 / mapSize.xy;

float rand(vec2 co){ // a pretty crappy random function
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	// mapSize.xy is the actual map size, 
	//place the vertices into the world:
	worldPos.y = lavaHeight;
	worldPos.w = 1.0;
	worldPos.xz =  (1.5 * planePos +0.5) * mapSize.xy; 
	
	// pass the world-space UVs out
	float mapratio = mapSize.y / mapSize.x;
	worldUV.xy = (1.5 * planePos +0.5);
	worldUV.y *= mapratio;
	
	float gametime = (timeInfo.x + timeInfo.w) * 0.006666;
	
	randpervertex = vec4(rand(worldPos.xz), rand(worldPos.xz * vec2(17.876234, 9.283)), rand(worldPos.xz + gametime + 2.0), rand(worldPos.xz + gametime + 3.0));
	worldUV.zw = sin(randpervertex.xy + gametime * (0.5 + randpervertex.xy));

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(worldPos.xz, mapSize.xy  - worldPos.xz) * inverseMapSize;
	inboundsness = min(mymin.x, mymin.y);

	// Assign world position:
	gl_Position = cameraViewProj * worldPos;
}
]]

local lavaFSSrc =  [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform float lavaHeight;
uniform float heatdistortx;
uniform float heatdistortz;

uniform sampler2D heightmapTex;
uniform sampler2D lavaDiffuseEmit;
uniform sampler2D lavaNormalHeight;
uniform sampler2D lavaDistortion;
uniform sampler2DShadow shadowTex;
uniform sampler2D infoTex;

in DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
	vec4 randpervertex;
};

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

const vec2 inverseMapSize = 1.0 / mapSize.xy;

float heightAtWorldPos(vec2 w){
	// Some texel magic to make the heightmap tex perfectly align:
	const vec2 heightmaptexel = vec2(8.0, 8.0);
	w +=  vec2(-8.0, -8.0) * (w * inverseMapSize) + vec2(4.0, 4.0) ;
	vec2 uvhm = clamp(w, heightmaptexel, mapSize.xy - heightmaptexel) * inverseMapSize;
	return texture(heightmapTex, uvhm, 0.0).x; 
}

out vec4 fragColor;

#line 22000


void main() {
	
	vec4 camPos = cameraViewInv[3];
	 
	float gametime = (timeInfo.x + timeInfo.w) * 0.006666 + randpervertex.x ;
	
	// Sample emissive as heat indicator here for later displacement
	vec4 nodiffuseEmit =  texture(lavaDiffuseEmit, worldUV.xy * WORLDUVSCALE );
	
	vec2 rotatearoundvertices = worldUV.zw * 0.003;
	
	float localheight = heightAtWorldPos(worldPos.xz);
	
	if (localheight > lavaHeight - HEIGHTOFFSET ) discard; 
	// Calculate how far the fragment is from the coast
	float coastfactor = clamp((localheight-lavaHeight + COASTWIDTH + HEIGHTOFFSET) * 0.05,  0.0, 1.0);
	
	// this is ramp function that ramps up for 90% of the coast, then ramps down at the last 10% of coastwidth
	if (coastfactor > 0.90)
	{coastfactor = 9*( 1.0 - coastfactor);
		coastfactor = pow(coastfactor/0.9, 1.0);
	}else{
		coastfactor = pow(coastfactor/0.9, 3.0);
	}
	
	// Sample shadow map for shadow factor:
	vec4 shadowVertexPos = shadowView * vec4(worldPos.xyz,1.0);
    shadowVertexPos.xy += vec2(0.5);
    float shadow = clamp(textureProj(shadowTex, shadowVertexPos), 0.0, 1.0);
	
	// Sample LOS texture for LOS, and scale it into a sane range
	vec2 losUV = clamp(worldPos.xz, vec2(0.0), mapSize.xy ) / mapSize.zw;
	float losTexSample = dot(vec3(0.33), texture(infoTex, losUV).rgb) ; // lostex is PO2
	losTexSample = clamp(losTexSample * 4.0 - 1.0, LOSDARKNESS, 1.0);
	if (inboundsness < 0.0) losTexSample = 1.0;

	// We shift the distortion texture camera-upwards according to the uniforms that got passed in
	vec2 camshift =  vec2(heatdistortx, heatdistortz) * 0.001;
	vec4 distortionTexture = texture(lavaDistortion, (worldUV.xy + camshift) *45.2 ) ;
	
	vec2 distortion = distortionTexture.xy * 0.2 *0.02;
	distortion.xy *=  clamp(nodiffuseEmit.a * 0.5 + coastfactor, 0.2, 2.0);

	vec2 diffuseNormalUVs =  worldUV.xy * WORLDUVSCALE + distortion .xy + rotatearoundvertices;
	vec4 diffuseEmit =   texture(lavaDiffuseEmit , diffuseNormalUVs);
	vec4 normalHeight =  texture(lavaNormalHeight, diffuseNormalUVs);
	
	fragColor.rgba = diffuseEmit;
	
	// Calculate lighting based on normal map
	vec3 fragNormal = (normalHeight.xzy * 2.0 -1.0);
	fragNormal.z = -1 * fragNormal.z; // for some goddamned reason Z(G) is inverted again
	fragNormal = normalize(fragNormal);
	float lightamount = clamp(dot(sunDir.xyz, fragNormal), 0.2, 1.0) * max(0.5,shadow);
	fragColor.rgb *= lightamount;
	
	fragColor.rgb += COASTCOLOR * coastfactor; 
	
	// Specular Color
	vec3 reflvect = reflect(normalize(-1.0 * sunDir.xyz), normalize(fragNormal));
	vec3 worldtocam = camPos.xyz - worldPos.xyz;
	float specular = clamp(pow(dot(normalize(worldtocam), normalize(reflvect)), SPECULAREXPONENT), 0.0, SPECULARSTRENGTH) * shadow;	
	fragColor.rgb += fragColor.rgb * specular;

	fragColor.rgb += fragColor.rgb * (diffuseEmit.a * distortion.y * 700.0); 
	
	fragColor.rgb *= losTexSample;
	
	// some debugging stuff:
	//fragColor.rgb = fragNormal.xzy;
	//fragColor.rgb = vec3(losTexSample);
	//fragColor.rgb = vec3(shadow);
	//fragColor.rgb = distortionTexture.rgb ;
	//fragColor.rg = worldUV.zw  ;
	//fragColor.rgba *= vec4(fract(hmap*0.05));
	//fragColor.rgb = vec3(randpervertex.w * 0.5 + 0.5);
	//fragColor.rgb = fract(4*vec3(coastfactor));
	fragColor.a = 1.0;
	fragColor.a = clamp(  inboundsness * 2.0 +2.0, 0.0, 1.0);
}
]]


local fogLightVSSrc = [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
#line 10000
layout (location = 0) in vec2 planePos;

uniform float lavaHeight;

out DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
};
//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#line 11000

const vec2 inverseMapSize = 1.0 / mapSize.xy;

float rand(vec2 co){ // a pretty crappy random function
    return fract(sin(dot(co, vec2(12.9898, 78.233))) * 43758.5453);
}

void main() {
	// mapSize.xy is the actual map size, 
	//place the vertices into the world:
	worldPos.y = lavaHeight;
	worldPos.w = 1.0;
	worldPos.xz =  (1.5 * planePos +0.5) * mapSize.xy; 
	
	// pass the world-space UVs out
	float mapratio = mapSize.y / mapSize.x;
	worldUV.xy = (1.5 * planePos +0.5);
	worldUV.y *= mapratio;
	
	float gametime = (timeInfo.x + timeInfo.w) * 0.006666;
	
	vec4 randpervertex = vec4(rand(worldPos.xz), rand(worldPos.xz * vec2(17.876234, 9.283)), rand(worldPos.xz + gametime + 2.0), rand(worldPos.xz + gametime + 3.0));
	worldUV.zw = sin(randpervertex.xy + gametime * (0.5 + randpervertex.xy));

	// -- MAP OUT OF BOUNDS
	vec2 mymin = min(worldPos.xz, mapSize.xy  - worldPos.xz) * inverseMapSize;
	inboundsness = min(mymin.x, mymin.y);

	// Assign world position:
	gl_Position = cameraViewProj * worldPos;
}
]]

local foglightFSSrc =  [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 20000

uniform float lavaHeight;
uniform float heatdistortx;
uniform float heatdistortz;

uniform sampler2D mapDepths;
uniform sampler2D modelDepths;
uniform sampler2D lavaDistortion;
//uniform sampler2D mapNormals;
//uniform sampler2D modelNormals;

in DataVS {
	vec4 worldPos;
	vec4 worldUV;
	float inboundsness;
};

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

const vec2 inverseMapSize = 1.0 / mapSize.xy;



out vec4 fragColor;

#line 22000


void main() {
	
	vec4 camPos = cameraViewInv[3];
	 

	
	vec2 rotatearoundvertices = worldUV.zw * 0.003;

	// Calculate how far the fragment is from the coast
	// We shift the distortion texture camera-upwards according to the uniforms that got passed in
	vec2 camshift =  vec2(heatdistortx, heatdistortz) * 0.01;
	
	//Get the fragment depth 
	// note that WE CANT GO LOWER THAN THE ACTUAL LAVA LEVEL!
	
	vec2 screenUV = gl_FragCoord.xy/ viewGeometry.xy;
	
	float mapdepth = texture(mapDepths, screenUV).x;
	float modeldepth = texture(modelDepths, screenUV).x;
	
	// we need to get the world position of each depth fragment... 
	// the W weight factor here is incorrect, as it comes from the depth buffers, and not the fragments own depth.
	
	mapdepth = min(mapdepth, modeldepth); // choose map or model
	
	vec4 mapWorldPos =  vec4(  vec3(screenUV.xy * 2.0 - 1.0, mapdepth),  1.0);
	mapWorldPos = cameraViewProjInv * mapWorldPos;
	mapWorldPos.xyz = mapWorldPos.xyz/ mapWorldPos.w; // YAAAY this works!
	float origmapy = mapWorldPos.y;
	
	// clip mapWorldPos according to true lava height
	if (mapWorldPos.y< lavaHeight - FOGHEIGHTABOVELAVA) {
		// we need to make a vector from cam to fogplane position
		vec3 camtofogplane = mapWorldPos.xyz - camPos.xyz;
		camtofogplane = 50* camtofogplane /abs(camtofogplane.y);
		mapWorldPos.xyz = worldPos.xyz + camtofogplane;
	}
	
	vec4 distortionTexture = texture(lavaDistortion, (worldUV.xy * 22.0  + camshift)) ;
	const float normalizingfactor = 4.0;
	float fogdistort = (normalizingfactor + distortionTexture.x + distortionTexture.y)/ normalizingfactor ;
	
	float actualfogdepth = length(mapWorldPos.xyz - worldPos.xyz) ;
	
	float fogAmount = 1.0 - exp2(- FOGFACTOR * FOGFACTOR * actualfogdepth  * 0.5);
	
	fogAmount *= fogdistort;
	
	// ok good, lets add some extra brigtness near the coasts!
	float disttocoast = abs(origmapy- (lavaHeight - FOGHEIGHTABOVELAVA - HEIGHTOFFSET));
	
	float extralightcoast =  clamp(1.0 - disttocoast * 0.05, 0.0, 1.0);
	extralightcoast = pow(extralightcoast, 3.0) * EXTRALIGHTCOAST;
	
	fogAmount += extralightcoast;
	
	
	//fragColor.rgb = mapnormal.xyz; // ok good normals works
	//fragColor.rgb = fract(vec3(mapdepth) * 0.01);
	
	//fragColor.rgb = fract(vec3(gl_FragCoord.z * 11.1 )); // good this works too
	//fragColor.rgb = fract(mapWorldPos.xyz * 0.02);
	fragColor.rgb = FOGCOLOR;
	fragColor.a = fogAmount;
	
	fragColor.a *= clamp(  inboundsness * 2.0 +2.0, 0.0, 1.0);
	//fragColor.a += sin(heatdistortx+ heatdistortz) * 0.01;
	//if (camPos.y < lavaHeight - FOGHEIGHTABOVELAVA) fragColor.a = 1.0;
}
]]



function widget:GameFrame()
	local gf = Spring.GetGameFrame()
	lavalevel = math.sin(gf/1000) * 50 + 50
end

function widget:Initialize()
	Spring.SetDrawWater(false)

	-- Now for all intents and purposes, we kinda need to make a lava plane that is 3x the rez of our map
	-- If, e.g our map size is 16x16, we will have 1024 heightmap. If we make a 128 size vbo, then what?
	-- numverts = 128 * 384 * 384 *2 tris then we will get 280k tris ....
	local xsquares = 3 * Game.mapSizeX / elmosPerSquare
	local zsquares = 3 * Game.mapSizeZ / elmosPerSquare
	local vertexBuffer, vertexBufferSize = makePlaneVBO(1, 1,  xsquares, zsquares)
	local indexBuffer, indexBufferSize = makePlaneIndexVBO(xsquares, zsquares)
	lavaPlaneVAO = gl.GetVAO()
	lavaPlaneVAO:AttachVertexBuffer(vertexBuffer)
	lavaPlaneVAO:AttachIndexBuffer(indexBuffer)
	
	
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	lavaVSSrc = lavaVSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	lavaFSSrc = lavaFSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	
	lavaShader = LuaShader({
		vertex = lavaVSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
		fragment = lavaFSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
		uniformInt = {
			heightmapTex = 0,
			lavaDiffuseEmit = 1,
			lavaNormalHeight = 2,
			lavaDistortion = 3,
			shadowTex = 4, 
			infoTex = 5, 
		},
		uniformFloat = {
			lavaHeight = 1,
			heatdistortx = 1,
			heatdistortz = 1,
		  },
	}, "Lava Shader API")
	
	
	fogLightVSSrc = fogLightVSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	foglightFSSrc = foglightFSSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	foglightShader = LuaShader({
		vertex = fogLightVSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
		fragment = foglightFSSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(unifiedShaderConfig)),
		uniformInt = {
			--heightmapTex = 0,
			mapDepths = 0,
			modelDepths = 1,
			lavaDistortion = 2,
			--mapNormals = 2, 
			--modelNormals = 5,
		},
		uniformFloat = {
			lavaHeight = 1,
			heatdistortx = 1,
			heatdistortz = 1,
		  },
	}, "FogLight shader ")
	local shaderCompiled = lavaShader:Initialize()
	if not shaderCompiled then 
		Spring.Echo("Failed to compile Lava Shader")
		widgetHandler:RemoveWidget()
	end
	
	shaderCompiled = foglightShader:Initialize()
	if not shaderCompiled then 
		Spring.Echo("Failed to compile foglightShader")
		widgetHandler:RemoveWidget()
	end
end

function widget:DrawWorldPreUnit()
	if lavalevel then 
		local _, gameSpeed, isPaused = Spring.GetGameSpeed()
		if not isPaused then 
			local camX, camY, camZ = Spring.GetCameraDirection()
			local camvlength = math.sqrt(camX*camX + camZ *camZ + 0.01)
			local fps = math.max(Spring.GetFPS(), 15)
			heatdistortx = heatdistortx - camX / (camvlength * fps)
			heatdistortz = heatdistortz - camZ / (camvlength * fps)
		end
		--Spring.Echo(camX, camZ, heatdistortx, heatdistortz,gameSpeed, isPaused)

		lavaShader:Activate()
		lavaShader:SetUniform("lavaHeight",lavalevel)
		lavaShader:SetUniform("heatdistortx",heatdistortx)
		lavaShader:SetUniform("heatdistortz",heatdistortz)

		gl.Texture(0, "$heightmap")-- Texture file
		gl.Texture(1, lavaDiffuseEmit)-- Texture file
		gl.Texture(2, lavaNormalHeight)-- Texture file
		gl.Texture(3, lavaDistortion)-- Texture file
		gl.Texture(4, "$shadow")-- Texture file
		gl.Texture(5, "$info")-- Texture file

		gl.DepthTest(GL.LEQUAL)
		gl.DepthMask(true)
		
		lavaPlaneVAO:DrawElements(GL.TRIANGLES)
		lavaShader:Deactivate()
		
		gl.DepthTest(false)
		gl.DepthMask(false)

		gl.Texture(0, false)-- Texture file
		gl.Texture(1, false)-- Texture file
		gl.Texture(2, false)-- Texture file
		gl.Texture(3, false)-- Texture file
		gl.Texture(4, false)-- Texture file
		gl.Texture(5, false)-- Texture file
		
		

	end
end
function widget:DrawWorld()
	if lavalevel and foglightenabled then 
			--Now to draw the fog light a good 32 elmos above it :)
		foglightShader:Activate()
		foglightShader:SetUniform("lavaHeight",lavalevel + fogheightabovelava)
		foglightShader:SetUniform("heatdistortx",heatdistortx)
		foglightShader:SetUniform("heatdistortz",heatdistortz)

		--gl.Texture(0, "$heightmap")-- Texture file
		gl.Texture(0, "$map_gbuffer_zvaltex")-- Texture file
		gl.Texture(1, "$model_gbuffer_zvaltex")-- Texture file
		gl.Texture(2, lavaDistortion)-- Texture file
		--gl.Texture(2, "$map_gbuffer_normtex")-- Texture file
		--gl.Texture(5, "$model_gbuffer_normtex")-- Texture file

		
		gl.Blending(GL.SRC_ALPHA, GL.ONE)
		gl.DepthTest(GL.LEQUAL)
		gl.DepthMask(false)
		
		lavaPlaneVAO:DrawElements(GL.TRIANGLES)
		foglightShader:Deactivate()
		
		gl.DepthTest(false)
		gl.DepthMask(false)

		gl.Texture(0, false)-- Texture file
		gl.Texture(1, false)-- Texture file
		gl.Texture(2, false)-- Texture file
		
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end