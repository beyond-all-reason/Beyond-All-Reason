
local widget = widget ---@type Widget

function widget:GetInfo()
  return {
    name      = "Map Edge Extension",
    version   = "v0.7",
    desc      = "Draws a mirrored map next to the edges of the real map",
    author    = "ivand",
    date      = "2020",
    license   = "GPL",
    layer     = 0,
    enabled   = true,
  }
end


-- Localized Spring API for performance
local spEcho = Spring.Echo

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- fix seams?

local brightness = 0.3
local nightFactor = 1.0
local curvature = true
local fogEffect = true

local mapBorderStyle = 'texture'	-- either 'texture' or 'cutaway'

local gridSize = 32
local gridSizeDeferred = 2*gridSize

local hasBadCulling = false

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spIsAABBInView = Spring.IsAABBInView
local mapSizeX, mapSizeZ = Game.mapSizeX, Game.mapSizeZ

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local gridTex = "LuaUI/Images/vr_grid_large.dds"
local realTex = "$grass"
local colorTex = (mapBorderStyle == 'texture' and realTex) or gridTex
local normalTex = '$ssmf_normals'

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local restoreMapBorder = true
local mapExtensionShader = nil
local mapExtensionShaderDeferred = nil
local terrainVAO = nil
local terrainInstanceVBO = nil
local terrainInstanceVBODeferred = nil

local planeVAO

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local function UpdateShader()
	mapExtensionShader:ActivateWith(function()
		mapExtensionShader:SetUniformAlways("shaderParams", gridSize, brightness * nightFactor, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0)
	end)
	mapExtensionShaderDeferred:ActivateWith(function()
		mapExtensionShaderDeferred:SetUniformAlways("shaderParams", gridSize, brightness * nightFactor, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0)
	end)
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local vsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10077

layout (location = 0) in vec4 aMirrorParams;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform vec4 shaderParams;

#define gridSize shaderParams.x

out DataVS {
	vec4 vMirrorParams;
};

void main() {

		float vID = float(gl_VertexID);

		float X = mapSize.x / gridSize;

		float modX = mod(vID, X); 
		//this is sometimes true in the magic land of amd drivers!
		if (modX >= X) 	modX=0;

		// Position the vertex in world XZ space of actual map dimensions, flipping will be done later
		float x = (  modX          )* gridSize;
		float y = ((vID - modX) / X)* gridSize;

		gl_Position = vec4(x, 0.0, y, 1.0);

		vMirrorParams = aMirrorParams;
	
}
]]


local gsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

layout (points) in;
layout (triangle_strip, max_vertices = 12) out;

#line 20090

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightTex;
#ifdef DEFERRED_MODE
	//uniform sampler2D mapNormalTex;
#endif


uniform vec4 shaderParams;

#define gridSize shaderParams.x
#define curvature shaderParams.z
#define edgeFog shaderParams.w

in DataVS {
	vec4 vMirrorParams;
} dataIn[];

out DataGS {
	vec2 alphaFog;
	vec2 uv; // uvs are [0.0,2.0]  for flipping, where > 1.0 means flip
	vec2 mirrorParams;
};


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)
#line 21160
bool MyEmitTestVertex(vec3 vertexOffset, bool testme) {
	vec4 worldPos = gl_in[0].gl_Position + vec4(vertexOffset.x, vertexOffset.y, vertexOffset.z, 0.0);
	uv = worldPos.xz / mapSize.xy;
	mirrorParams.xy = dataIn[0].vMirrorParams.xy;
	//uv = uv + abs(dataIn[0].vMirrorParams.xy); // So negative UVs mean flipping
	//uv = dataIn[0].vMirrorParams.xy;
	vec2 UVHM =  heightmapUVatWorldPos(worldPos.xz);
	worldPos.y = textureLod(heightTex, UVHM, 0.0).x + vertexOffset.y;
	
	#ifdef DEFERRED_MODE
		//normalxz = textureLod(mapNormalTex, UVHM, 0.0).ra;
	#endif

	const vec2 edgeTightening = vec2(0.0); // to tighten edges a little better
	worldPos.xz = abs(dataIn[0].vMirrorParams.xy * mapSize.xy - worldPos.xz);
	worldPos.xz += dataIn[0].vMirrorParams.zw * (mapSize.xy - edgeTightening);

	float alpha = 1.0;

	if (curvature == 1.0) {
		const float curvatureBend = 150.0;

		alpha = 0.0;

		vec2 refPoint = SNORM2NORM(dataIn[0].vMirrorParams.zw) * mapSize.xy;
		if (dataIn[0].vMirrorParams.x != 0.0) {
			worldPos.y -= pow((worldPos.x - refPoint.x) / curvatureBend, 2.0);
			alpha -= pow((worldPos.x - refPoint.x) / mapSize.x, 2.0);
		}

		if (dataIn[0].vMirrorParams.y != 0.0) {
			worldPos.y -= pow((worldPos.z - refPoint.y) / curvatureBend, 2.0);
			alpha -= pow((worldPos.z - refPoint.y) / mapSize.y, 2.0);
		}

		alpha = 1.0 + (6.0 * (alpha + 0.18));
		alpha = clamp(alpha, 0.0, 1.0);
	}

	float fogFactor = 1.0;
	if (edgeFog == 1.0) {
		vec4 forCoord = cameraView * worldPos;

		// emulate linear fog
		// vec4 fogParams; //fog {start, end, 0.0, scale}
		float fogDist = length(forCoord.xyz);
		fogFactor = (fogParams.y - fogDist) * fogParams.w;
		fogFactor = clamp(fogFactor, 0.0, 1.0);
	}

	alphaFog = vec2(alpha, fogFactor);
	if (testme ) {
		// this 'early clipping' will prevent generation of triangle strips is the quad is out of view
		// use a 25x multiplier on the tolerance radius, as some triangles arent in spheres, but are highly elongated
		bool invisible = isSphereVisibleXY(worldPos, 25.0*gridSize);
		if ((invisible) || (alpha < 0.05))  return true; // also could be ||  (fogFactor < 0.025))
	}
	gl_Position = cameraViewProj * worldPos;
	EmitVertex();
	return false;
}

void main() {
	if (all(equal(dataIn[0].vMirrorParams, vec4(0.0)))){ 
		// No mirror params, so just draw the seam quad
		// Note that this is a terrible hack, and I should feel bad for doing it

		vec3 localPos = gl_in[0].gl_Position.xyz;
		// Isolate the edge positions
		vec2 mapCenterHPG = (mapSize.xy - vec2(gridSize)) * 0.5;
		vec2 disttoMapCenter = abs(localPos.xz - mapCenterHPG) + vec2(gridSize) * 0.5;	
		if (all(lessThan(disttoMapCenter, mapCenterHPG))) return;
		//if (localPos.z > (mapSize.z - 1.0-gridSize)) return;

		#define WF 0.0
		#define SEAMHEIGHT -128.0
		vec4 edgePos = vec4(0.0);
		if (localPos.x == 0){
			if (MyEmitTestVertex(vec3(WF,       0, gridSize),true)) return; //TL
				MyEmitTestVertex(vec3(WF,  SEAMHEIGHT, gridSize),false); //BL
				MyEmitTestVertex(vec3(WF,       0, 0),false); //TR
				MyEmitTestVertex(vec3(WF,  SEAMHEIGHT, 0),false); //BR
			EndPrimitive();
			return;
		}else if (localPos.z == 0){
			if (MyEmitTestVertex(vec3(gridSize,       0, WF),true)) return; //TL
				MyEmitTestVertex(vec3(00,       0, WF),false); //TR
				MyEmitTestVertex(vec3(gridSize,  SEAMHEIGHT, WF),false); //BL
				MyEmitTestVertex(vec3(00,  SEAMHEIGHT, WF),false); //BR
			EndPrimitive();
			return;
		}else if (localPos.x >= mapSize.x - gridSize){
			if (MyEmitTestVertex(vec3(gridSize - WF,       0, gridSize),true)) return; //TL
				MyEmitTestVertex(vec3(gridSize - WF,       0, 0),false); //TR
				MyEmitTestVertex(vec3(gridSize - WF,  SEAMHEIGHT, gridSize),false); //BL
				MyEmitTestVertex(vec3(gridSize - WF,  SEAMHEIGHT, 0),false); //BR
			EndPrimitive();
			return;
		}else {	
		
			if (MyEmitTestVertex(vec3(gridSize,       0, gridSize - WF ),true)) return; //TL
				MyEmitTestVertex(vec3(gridSize,  SEAMHEIGHT, gridSize - WF),false); //BL
				MyEmitTestVertex(vec3(00,       0, gridSize - WF),false); //TR
				MyEmitTestVertex(vec3(00,  SEAMHEIGHT, gridSize - WF),false); //BR
			EndPrimitive();
			return;
	
		}
	}else{
		if ( all(equal(dataIn[0].vMirrorParams.xy, vec2(1.0))) ) {
			if (MyEmitTestVertex(vec3(gridSize, 0.0,      0.0), true)) return;; //TR
				MyEmitTestVertex(vec3(0.0     , 0.0,      0.0),false); //TL
				MyEmitTestVertex(vec3(gridSize, 0.0, gridSize),false); //BR
				MyEmitTestVertex(vec3(0.0     , 0.0, gridSize),false); //BL
		} else {
			if (MyEmitTestVertex(vec3(0.0     , 0.0, gridSize),true)) return; //BL
				MyEmitTestVertex(vec3(0.0     , 0.0,      0.0),false); //TL
				MyEmitTestVertex(vec3(gridSize, 0.0, gridSize),false); //BR
				MyEmitTestVertex(vec3(gridSize, 0.0,      0.0),false); //TR
		}
	}
	EndPrimitive();
}
]]


--[[

Results:
no deferred pass: 428 fps
depth only (GBUFFER_COUNT ==0) 423fps
1 buffer: 373 fps
2 buffers: 399 fps
3 buffers: 388 fps
4 buffers: 379 fps
5 buffers: 370 fps 

]]--

local fsSrc = [[
#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

#ifdef DEFERRED_MODE
	#define GBUFFER_NORMTEX_IDX 0
	#define GBUFFER_DIFFTEX_IDX 1
	#define GBUFFER_SPECTEX_IDX 2
	#define GBUFFER_EMITTEX_IDX 3
	#define GBUFFER_MISCTEX_IDX 4

	#define GBUFFER_COUNT 2
#endif

uniform sampler2D colorTex;
uniform sampler2D mapNormalTex;

uniform vec4 shaderParams;
#define brightness shaderParams.y

in DataGS {
	vec2 alphaFog;
	vec2 uv;
	vec2 mirrorParams;
};

#ifdef DEFERRED_MODE
	#if GBUFFER_COUNT > 0
		out vec4 fragData[GBUFFER_COUNT];
	#endif
#else
	out vec4 fragColor;
#endif

const mat3 RGB2YCBCR = mat3(
	0.2126, -0.114572, 0.5,
	0.7152, -0.385428, -0.454153,
	0.0722, 0.5, -0.0458471);

const mat3 YCBCR2RGB = mat3(
	1.0, 1.0, 1.0,
	0.0, -0.187324, 1.8556,
	1.5748, -0.468124, -5.55112e-17);

void main() {
	vec2 fractUV = uv;

	#define MINIMAP_HALF_TEXEL (0.5/1024.0)

	// remove tiling seams from minimap texel edges
	vec2 clampeduv = clamp(uv, MINIMAP_HALF_TEXEL, 1.0 - MINIMAP_HALF_TEXEL); 
	
	vec4 finalColor = texture(colorTex, clampeduv);
	#if 1
		vec3 yCbCr = RGB2YCBCR * finalColor.rgb;
		yCbCr.x = clamp(yCbCr.x * brightness, 0.0, 1.0);
		finalColor.rgb = YCBCR2RGB * yCbCr;
	#else
		finalColor.rgb *= brightness;
	#endif
	
	// Note that normals are Z up in textures, but Y up in the world
	vec3 mapNormal = vec3(0);
	#ifdef DEFERRED_MODE
		mapNormal.xz = texture(mapNormalTex,clampeduv).ra;
		mapNormal.y = sqrt(1.0 - dot(mapNormal.xz, mapNormal.xz));
		mapNormal = normalize(mapNormal);
	#else
		mapNormal = normalize(texture(mapNormalTex,clamp(uv, MINIMAP_HALF_TEXEL / 4.0, 1.0 - (MINIMAP_HALF_TEXEL/4.0))).rbg * 2.0 - 1.0);
	#endif

	// Flip normals if the mirror is flipped
	if (abs(mirrorParams.x) > 0.5) mapNormal.x *= -1.0; 
	if (abs(mirrorParams.y) > 0.5)  mapNormal.z *= -1.0;

	// Apply some lighting based on the normal vector
	finalColor.rgb = finalColor.rgb * (dot(mapNormal, sunDir.xyz) * 0.5 + 1.0);

	finalColor.rgb = mix(fogColor.rgb, finalColor.rgb, alphaFog.y);
	finalColor.a = alphaFog.x; 
	//finalColor.rg = uv;
	//finalColor.rgba = vec4(mapNormal.rgb * 0.5 + 0.5, 1.0);

	#ifdef DEFERRED_MODE
		#if GBUFFER_COUNT > 0
			fragData[GBUFFER_NORMTEX_IDX] = vec4(mapNormal * 0.5 + 0.5, 1);
		#endif
		#if GBUFFER_COUNT > 1
			fragData[GBUFFER_DIFFTEX_IDX] = finalColor;
		#endif
		#if GBUFFER_COUNT > 2
			fragData[GBUFFER_SPECTEX_IDX] = vec4(0);		
		#endif
		#if GBUFFER_COUNT > 3
			fragData[GBUFFER_EMITTEX_IDX] = vec4(0);
		#endif
		#if GBUFFER_COUNT > 4
			fragData[GBUFFER_MISCTEX_IDX] = vec4(0);
		#endif
	#else
		// Forward pass
		fragColor = finalColor;
	#endif
	
	//fragColor.a *= 0.5;
}
]]

local vsSrcDeferred = [[

#version 330

#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 10077

layout (location = 0) in vec2 xyworld_xyfract;

//xy is flipx flipy
//zw is offsetx offsety
layout (location = 1) in vec4 aMirrorParams;

//__DEFINES__
//__ENGINEUNIFORMBUFFERDEFS__

uniform sampler2D heightTex;
uniform vec4 shaderParams;

#define gridSize shaderParams.x
#define curvature shaderParams.z
#define edgeFog shaderParams.w


#define NORM2SNORM(value) (value * 2.0 - 1.0)
#define SNORM2NORM(value) (value * 0.5 + 0.5)

out DataGS {
	vec2 alphaFog;
	vec2 uv;
	vec2 mirrorParams;
};
#line 11000
void main() {
	vec2 flip = aMirrorParams.xy;
	vec2 offset = aMirrorParams.zw;

	uv = xyworld_xyfract * 0.5 + 0.5;
	vec4 worldPos = vec4(uv.x, 0.0, uv.y, 1.0);
	
	
	//worldPos.xz = mix(worldPos.xz, 1.0 - worldPos.xz, flip) + offset;
	worldPos.xz += offset;
	
	worldPos.xz *= mapSize.xy;
	
	uv = mix(uv, 1.0 - uv, flip);

	mirrorParams = aMirrorParams.xy;
	
	worldPos.y = textureLod(heightTex, heightmapUVatWorldPos(uv * mapSize.xy), 0.0).x;
	
	const vec2 edgeTightening = vec2(0.5); // to tighten edges a little better

	worldPos.xz -= offset * edgeTightening;
	
	float alpha = 1.0;

	if (curvature == 1.0) {
		const float curvatureBend = 150.0;

		alpha = 0.0;

		vec2 refPoint = SNORM2NORM(offset) * mapSize.xy;
		if (flip.x != 0.0) {
			worldPos.y -= pow((worldPos.x - refPoint.x) / curvatureBend, 2.0);
			alpha -= pow((worldPos.x - refPoint.x) / mapSize.x, 2.0);
		}

		if (flip.y != 0.0) {
			worldPos.y -= pow((worldPos.z - refPoint.y) / curvatureBend, 2.0);
			alpha -= pow((worldPos.z - refPoint.y) / mapSize.y, 2.0);
		}

		alpha = 1.0 + (6.0 * (alpha + 0.18));
		alpha = clamp(alpha, 0.0, 1.0);
	}
	

	float fogFactor = 1.0;
	if (edgeFog == 1.0) {
		vec4 fogCoord = cameraView * worldPos;
		// emulate linear fog
		// vec4 fogParams; //fog {start, end, 0.0, scale}
		float fogDist = length(fogCoord.xyz);
		fogFactor = (fogParams.y - fogDist) * fogParams.w;
		fogFactor = clamp(fogFactor, 0.0, 1.0);
	}

	alphaFog = vec2(alpha, fogFactor);
	//alphaFog = vec2(1,1);
	gl_Position = cameraViewProj * worldPos;
}


]]

local numPoints
local mirrorParams = {}


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if Spring.Lava.isLavaMap == true then
		widgetHandler:RemoveWidget(self)
	end

	WG['mapedgeextension'] = {}
	WG['mapedgeextension'].getBrightness = function()
		return brightness
	end
	WG['mapedgeextension'].setBrightness = function(value)
		brightness = value
		--UpdateShader()
	end
	WG['mapedgeextension'].getCurvature = function()
		return curvature
	end
	WG['mapedgeextension'].setCurvature = function(value)
		curvature = value
		--UpdateShader()
	end

	Spring.SendCommands("mapborder 1")--..(mapBorderStyle == 'cutaway' and "1" or "0"))

	if gl.GetMapRendering("voidGround") then
		restoreMapBorder = false
		widgetHandler:RemoveWidget()
	end

	if gl.GetMapRendering("voidWater") then
		restoreMapBorder = false
		widgetHandler:RemoveWidget()
	end

	-----------
	terrainVAO = gl.GetVAO()
	if terrainVAO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget()
	end

	terrainInstanceVBO = gl.GetVBO(GL.ARRAY_BUFFER, true) -- GL.ARRAY_BUFFER, false
	if terrainInstanceVBO == nil then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget()
	end
	
	-----------

	numPoints = (mapSizeX / gridSize) * (mapSizeZ / gridSize)

	terrainInstanceVBO:Define(9, {
		{id = 0, name = "mirrorParams", size = 4},
	})

	terrainVAO:AttachInstanceBuffer(terrainInstanceVBO)
	
	
	
	terrainInstanceVBODeferred = gl.GetVBO(GL.ARRAY_BUFFER, true)
	
	terrainInstanceVBODeferred:Define(9, {
		{id = 1, name = "mirrorParams", size = 4},
	})
	
	local planeVBO, numVertices = InstanceVBOTable.makePlaneVBO(1,1,Game.mapSizeX/gridSizeDeferred,Game.mapSizeZ/gridSizeDeferred)
	local planeIndexVBO, numIndices =  InstanceVBOTable.makePlaneIndexVBO(Game.mapSizeX/gridSizeDeferred,Game.mapSizeZ/gridSizeDeferred)
	planeVAO = gl.GetVAO()
	planeVAO:AttachVertexBuffer(planeVBO)
	planeVAO:AttachIndexBuffer(planeIndexVBO)
	planeVAO:AttachInstanceBuffer(terrainInstanceVBODeferred)


	hasBadCulling = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == false)
	--spEcho(gsSrc)
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
	vsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	fsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)

	mapExtensionShader = LuaShader({
		vertex = vsSrc,
		geometry = gsSrc,
		fragment = fsSrc,
		uniformInt = {
			colorTex = 0,
			heightTex = 1,
			--mapDepthTex = 2,
			mapNormalTex = 2,
		},
		uniformFloat = {
			shaderParams = {gridSize, brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0},
		},
	}, "Map Extension Shader2")
	local shaderCompiled = mapExtensionShader:Initialize()

	if not shaderCompiled then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget()
	end
	
	
	vsSrcDeferred = vsSrcDeferred:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	mapExtensionShaderDeferred = LuaShader({
		vertex = vsSrcDeferred:gsub("//__DEFINES__","#define DEFERRED_MODE 1"),
		--geometry = gsSrc:gsub("//__DEFINES__","#define DEFERRED_MODE 1"),
		fragment = fsSrc:gsub("//__DEFINES__","#define DEFERRED_MODE 1"),
		uniformInt = {
			colorTex = 0,
			heightTex = 1,
			mapNormalTex = 2,
		},
		uniformFloat = {
			shaderParams = {gridSize, brightness, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0},
		},
	}, "Map Extension Shader Deferred")
	local shaderCompiled = mapExtensionShaderDeferred:Initialize()

	if not shaderCompiled then
		Spring.SendCommands("luaui enablewidget Map Edge Extension Old")
		widgetHandler:RemoveWidget()
	end

	Spring.SendCommands("luaui disablewidget External VR Grid")
end

function widget:Shutdown()
	Spring.SendCommands('mapborder '..(restoreMapBorder and '1' or '0'))

	if mapExtensionShader then
		mapExtensionShader:Finalize()
	end

	if terrainVAO then
		--terrainVAO:Delete()
		terrainVAO = nil
	end

	if terrainInstanceVBO then
		--terrainInstanceVBO:Delete()
		terrainInstanceVBO = nil
	end
	--collectgarbage("collect")
end

local borderMargin = 40
local cachedCameraPosDir = {0, 0, 0, 0, 0, 0}
local function UpdateMirrorParams()
	local function Distance2(x1, y1, z1, x2, y2, z2)
		local dx, dy, dz = x1 - x2, y1 - y2, z1 - z2
		return dx*dx + dy*dy + dz*dz
	end

	-- presumes normalized vectors
	local function DotProduct(x1, y1, z1, x2, y2, z2)
		return x1*x2 + y1*y2 + z1*z2
	end

	local cpX, cpY, cpZ = Spring.GetCameraPosition()
	local cdX, cdY, cdZ = Spring.GetCameraDirection()

	local checkInView = false

	if Distance2(cpX, cpY, cpZ, cachedCameraPosDir[1], cachedCameraPosDir[2], cachedCameraPosDir[3]) > 900 then
		checkInView = true
		cachedCameraPosDir[1] = cpX
		cachedCameraPosDir[2] = cpY
		cachedCameraPosDir[3] = cpZ
	end

	if checkInView or DotProduct(cdX, cdY, cdZ, cachedCameraPosDir[4], cachedCameraPosDir[5], cachedCameraPosDir[6]) < 0.95 then
		checkInView = true
		cachedCameraPosDir[4] = cdX
		cachedCameraPosDir[5] = cdY
		cachedCameraPosDir[6] = cdZ
	end

	if not checkInView then
		return
	end

	local minY, maxY = Spring.GetGroundExtremes()

	mirrorParams = {} 
	-- spIsAABBInView params are copied from map_edge_extension.lua
	if spIsAABBInView(-Game.mapSizeX, minY, -Game.mapSizeZ, borderMargin, maxY, borderMargin) then
		--TL {1, 1, -1, -1}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] = -1
		mirrorParams[#mirrorParams + 1] = -1
	end

	if spIsAABBInView(-Game.mapSizeX, minY, -borderMargin, 0, maxY, Game.mapSizeZ) then
		--ML {1, 0, -1,  0}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] = -1
		mirrorParams[#mirrorParams + 1] =  0
	end

	if spIsAABBInView(-Game.mapSizeX, minY, Game.mapSizeZ - borderMargin, borderMargin, maxY, Game.mapSizeZ * 2) then
		--BL {1, 1, -1,  1}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] = -1
		mirrorParams[#mirrorParams + 1] =  1
	end

	if spIsAABBInView(-borderMargin, minY, -Game.mapSizeZ, Game.mapSizeX + borderMargin, maxY, borderMargin) then
		--TM {0, 1,  0, -1}
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] = -1
	end

	if spIsAABBInView(-borderMargin, minY, Game.mapSizeZ * 2, Game.mapSizeX + borderMargin, maxY, Game.mapSizeZ - borderMargin) then
		--BM {0, 1,  0,  1}
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] =  1
	end

	if spIsAABBInView(Game.mapSizeX - borderMargin, minY, -Game.mapSizeZ, Game.mapSizeX * 2, maxY, borderMargin) then
		--TR {1, 1,  1, -1}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] = -1
	end

	if spIsAABBInView(Game.mapSizeX - borderMargin, minY, -borderMargin, Game.mapSizeX * 2, maxY, Game.mapSizeZ) then
		--MR {1, 0,  1,  0}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  0
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  0
	end

	if spIsAABBInView(Game.mapSizeX - borderMargin, minY, Game.mapSizeZ - borderMargin, Game.mapSizeX * 2, maxY, Game.mapSizeZ * 2) then
		--BR {1, 1,  1,  1}
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
		mirrorParams[#mirrorParams + 1] =  1
	end
	if #mirrorParams > 0 then
		
		terrainInstanceVBODeferred:Upload(mirrorParams)
		
		-- EXTREMELY IMPORTANT: 
		-- Add a blank, non-mirrored or offset one to the forward pass for the edge seams
		mirrorParams[#mirrorParams + 1] = 0
		mirrorParams[#mirrorParams + 1] = 0
		mirrorParams[#mirrorParams + 1] = 0
		mirrorParams[#mirrorParams + 1] = 0
		terrainInstanceVBO:Upload(mirrorParams)
	end
end



-- depth defaults:
--[[
	false
	false
	GL_DEPTH_FUNC = GL_ALWAYS
]]--
-- blending defaults:
--[[
	true
	GL_SRC_ALPHA
	GL_ONE_MINUS_SRC_ALPHA
]]--
-- culling defaults
--[[
	false
	GL_CULL_FACE_MODE = GL_BACK
]]--


-- This requires both the callin and the config int to be enabled
-- Note that the performance of this draw call is somehow much greater than the screen space one. Very sad :?


function widget:DrawGroundDeferred()
	--spEcho("widget:DrawGroundDeferred")
	if #mirrorParams == 0 then
		return
	end
	--if true then return end
	--local q = gl.CreateQuery()
	if hasBadCulling then
		gl.Culling(true)
	else
		gl.Culling(false) -- amdlinux on steam deck or else half the tris are invisible
	end
	--gl.DepthTest(GL.LEQUAL)
	--gl.DepthMask(true)

		--gl.Culling(false) -- needed for deferred one, as flipping fucks tri order	
	gl.Texture(0, colorTex)
	gl.Texture(1, "$heightmap")
	gl.Texture(2, "$normals")
	mapExtensionShaderDeferred:Activate()
	mapExtensionShaderDeferred:SetUniform("shaderParams", gridSize, brightness * nightFactor, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0)
	--gl.RunQuery(q, function()
		--terrainVAO:DrawArrays(GL.POINTS, numPoints, 0, #mirrorParams / 4)
		--planeVAO:DrawElements(GL.TRIANGLES, 1000, 0, 8 ,0)
		-- draw one less element as that is unmirrored one for the seam
		planeVAO:DrawElements(GL.TRIANGLES, nil, 0, math.max(0, (#mirrorParams / 4)-1) )
	--end)
	mapExtensionShaderDeferred:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)

	--gl.DepthTest(GL.ALWAYS)
	--gl.DepthTest(false)
	--gl.DepthMask(false)
	gl.Culling(GL.BACK)

end


function widget:DrawWorldPreUnit()
	UpdateMirrorParams()

	if #mirrorParams == 0 then
		return
	end

	--local q = gl.CreateQuery()
	if hasBadCulling then
		gl.Culling(true)
	else
		gl.Culling(false) -- amdlinux on steam deck or else half the tris are invisible
	end
	gl.DepthTest(GL.LEQUAL)
	gl.DepthMask(true)

	gl.Texture(0, colorTex)
	gl.Texture(1, "$heightmap")
	gl.Texture(2, "$ssmf_normals")
	mapExtensionShader:Activate()
	mapExtensionShader:SetUniform("shaderParams", gridSize, brightness * nightFactor, (curvature and 1.0) or 0.0, (fogEffect and 1.0) or 0.0)
	--gl.RunQuery(q, function()
		terrainVAO:DrawArrays(GL.POINTS, numPoints, 0, #mirrorParams / 4)
	--end)
	mapExtensionShader:Deactivate()
	gl.Texture(0, false)
	gl.Texture(1, false)
	gl.Texture(2, false)

	gl.DepthTest(GL.ALWAYS)
	gl.DepthTest(false)
	gl.DepthMask(false)
	gl.Culling(GL.BACK)
end

local lastSunChanged = -1
function widget:SunChanged() -- Note that map_nightmode.lua gadget has to change sun twice in a single draw frame to update all
	local df = Spring.GetDrawFrame()

	if df == lastSunChanged then return end
	lastSunChanged = df
	-- Do the math:
	if WG['NightFactor'] then
		nightFactor = (WG['NightFactor'].red + WG['NightFactor'].green + WG['NightFactor'].blue) * 0.33
	end
end

function widget:GetConfigData(data)
	return {
		brightness = brightness,
		curvature = curvature,
		fogEffect = fogEffect
	}
end


function widget:SetConfigData(data)
	if data.brightness ~= nil then
		brightness = data.brightness
	end
	if data.curvature ~= nil then
		curvature = data.curvature
	end
	if data.fogEffect ~= nil then
		fogEffect = data.fogEffect
	end
end
