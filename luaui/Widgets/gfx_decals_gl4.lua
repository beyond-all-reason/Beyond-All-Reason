function widget:GetInfo()
	return {
		name = "Decals GL4",
		desc = "Try to draw some nice normalmapped decals",
		author = "Beherith",
		date = "2021.11.02",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end



-- Notes and TODO
-- yes these are geoshader decals
-- we are gonna try to smaple heightmap
-- atlasColor is diffuse + alpha
-- atlasNormals is normals + emission

-- advanced geoshader tricount for quads
-- 2x2 - 4
-- 3x3 - 12
-- 4x4 - 40
-- 5x5 - 65! == 1+3 vec4's per vertex
-- Configurable Parts:



local atlasNormals = nil
local atlasColor = nil
local atlasSize = 2048
local atlassedImages = {}
local unitDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas

local function addDirToAtlas(atlas, path)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	Spring.Echo("Adding",#files, "images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			gl.AddAtlasTexture(atlas,files[i])
			atlassedImages[files[i]] = true
		end
	end
end

local function makeAtlas()
	atlasColor = gl.CreateTextureAtlas(atlasSize,atlasSize,0)
	addDirToAtlas(atlasColor, "bitmaps/scars")
	gl.FinalizeTextureAtlas(atlasColor)
	
	atlasNormals = gl.CreateTextureAtlas(atlasSize,atlasSize,0)
	addDirToAtlas(atlasNormals, "bitmaps/scars")
	gl.FinalizeTextureAtlas(atlasNormals)	
	
end

local decalVBO = nil
local decalShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local spValidUnitID = Spring.ValidUnitID

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

local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

layout (location = 0) in vec4 lengthwidthrotation; // l w rot and maxalpha
layout (location = 1) in vec4 uvoffsets;
layout (location = 2) in vec4 alphastart_alphadecay_heatstart_heatdecay;
layout (location = 3) in vec4 worldPos; // also gameframe it was created on



//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float fadeDistance;
uniform sampler2D heightmapTex;

out DataVS {
	uint v_skipdraw;
	vec4 v_lengthwidthrotation;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
};

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

bool vertexClipped(vec4 clipspace, float tolerance) {
  return any(lessThan(clipspace.xyz, -clipspace.www * tolerance)) ||
         any(greaterThan(clipspace.xyz, clipspace.www * tolerance));
}
#line 11000
void main()
{
	v_centerpos = worldPos;
	v_centerpos.y = heightAtWorldPos(v_centerpos.xz);
	v_centerpos.w = 1.0;
	v_uvoffsets = uvoffsets;
	
	v_parameters = alphastart_alphadecay_heatstart_heatdecay;
	
	v_parameters.zw = alphastart_alphadecay_heatstart_heatdecay.xz - alphastart_alphadecay_heatstart_heatdecay.yw * timeInfo.x * 0.03333;
	
	v_parameters.x = 0.0;
	
	v_lengthwidthrotation = lengthwidthrotation;
	bvec4 isClipped = bvec4(
		vertexClipped(cameraViewProj * (v_centerpos + vec4( lengthwidthrotation.x, 0, lengthwidthrotation.y, 0)), 1.1),
		vertexClipped(cameraViewProj * (v_centerpos - vec4( lengthwidthrotation.x, 0, lengthwidthrotation.y, 0)), 1.1),
		vertexClipped(cameraViewProj * (v_centerpos - vec4(-lengthwidthrotation.x, 0, lengthwidthrotation.y, 0)), 1.1),
		vertexClipped(cameraViewProj * (v_centerpos + vec4(-lengthwidthrotation.x, 0, lengthwidthrotation.y, 0)), 1.1)
	);
	v_skipdraw = 0u;
	
	if (all(isClipped.xyz)) { // this doesnt seem to work, clips close stuff...
		//v_skipdraw = 1u;
		//v_parameters.x = 1.0;
	}

	vec3 toCamera = cameraViewInv[3].xyz - v_centerpos.xyz;
	if (dot(toCamera, toCamera) >  fadeDistance * fadeDistance) v_skipdraw = 1u;
	gl_Position = cameraViewProj * v_centerpos;
}
]]

local gsSrc = [[
#version 330
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shading_language_420pack: require
//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

layout(points) in;
layout(triangle_strip, max_vertices = 40) out;
#line 20000

uniform float fadeDistance;
uniform sampler2D heightmapTex;
uniform sampler2D miniMapTex;

in DataVS {
	uint v_skipdraw;
	vec4 v_lengthwidthrotation;
	vec4 v_centerpos;
	vec4 v_uvoffsets;
	vec4 v_parameters;
} dataIn[];

out DataGS {
	vec4 g_color;
	vec4 g_uv;
	vec4 g_params; // how to get tbnmatrix here?
};

mat3 rotY;
vec4 centerpos;
vec4 uvoffsets;

float heightAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(heightmapTex, uvhm, 0.0).x;
}

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
	//vec3 vecnorm = normalize(primitiveCoords);// AHA zero case!
	vec4 worldPos = vec4(centerpos.xyz + rotY * ( primitiveCoords ), 1.0);
	worldPos.y = heightAtWorldPos(worldPos.xz) + 1.0;
	gl_Position = cameraViewProj * worldPos;
	gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in Z
	g_uv.zw = dataIn[0].v_parameters.zw;
	g_params.z = dataIn[0].v_parameters.x;
	g_color =  textureLod(heightmapTex, centerpos.xz*0.0001, 0.0);
	g_params.xy = worldPos.xz;
	EmitVertex();
}
#line 22000
void main(){
	if (dataIn[0].v_skipdraw > 0u) return; //bail

	centerpos = dataIn[0].v_centerpos;
	rotY = rotation3dY(dataIn[0].v_lengthwidthrotation.z); // Create a rotation matrix around Y from the unit's rotation


	uvoffsets = dataIn[0].v_uvoffsets; // if an atlas is used, then use this, otherwise dont

	float length = dataIn[0].v_lengthwidthrotation.x;
	float width = dataIn[0].v_lengthwidthrotation.y;
	vec4 heights;
	//heights.x = 
	// for a simple quad
	/*
		offsetVertex4( width * 0.5, 0.0,  length * 0.5, 0.0, 1.0); // bottom right
		offsetVertex4( width * 0.5, 0.0, -length * 0.5, 0.0, 0.0); // top right
		offsetVertex4(-width * 0.5, 0.0,  length * 0.5, 1.0, 1.0); // bottom left
		offsetVertex4(-width * 0.5, 0.0, -length * 0.5, 1.0, 0.0); // top left
		EndPrimitive();
	*/
	
	// for a 4x4 quad
	for (int i = 0; i<4; i++){ //draw from bottom (front) to back
		float v = float(i)*0.25;
		// draw 4 strips of 9 verts
		//10 8 6 4 2
		// 9 7 5 3 1
		float striptop = (v - 0.25) * length;
		float stripbot = (v - 0.5 ) * length;
		offsetVertex4( width * 0.5, 0.0,  stripbot, 1.0 , v       ); // 1
		offsetVertex4( width * 0.5, 0.0,  striptop, 1.0 , v + 0.25); // 2
		offsetVertex4( width * 0.25, 0.0, stripbot, 0.75, v       ); // 3
		offsetVertex4( width * 0.25, 0.0, striptop, 0.75, v + 0.25); // 4
		offsetVertex4( width * 0.0 , 0.0, stripbot, 0.5, v ); // 5
		offsetVertex4( width * 0.0 , 0.0, striptop, 0.5, v + 0.25); // 6
		offsetVertex4( width * -0.25, 0.0, stripbot, 0.25, v ); // 7
		offsetVertex4( width * -0.25, 0.0, striptop, 0.25, v + 0.25); // 8
		offsetVertex4( width * -0.5, 0.0, stripbot, 0.0, v ); // 8
		offsetVertex4( width * -0.5, 0.0, striptop, 0.0, v + 0.25); // 10
		EndPrimitive();
	}
	
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
in DataGS {
	vec4 g_color;
	vec4 g_uv;
	vec4 g_params; // how to get tbnmatrix here?
};

uniform sampler2D atlasColor;
uniform sampler2D atlasNormal;
uniform sampler2D miniMapTex;
out vec4 fragColor;

vec4 minimapAtWorldPos(vec2 w){
	vec2 uvhm =   vec2(clamp(w.x,8.0,mapSize.x-8.0),clamp(w.y,8.0, mapSize.y-8.0))/ mapSize.xy; 
	return textureLod(miniMapTex, uvhm, 0.0);
}

vec3 Temperature(float temperatureInKelvins)
{
	vec3 retColor;
	
	temperatureInKelvins = clamp(temperatureInKelvins, 1000.0, 40000.0) / 100.0;
	
	if (temperatureInKelvins <= 66.0)
	{
		retColor.r = 1.0;
		retColor.g = 0.39008157876901960784 * log(temperatureInKelvins) - 0.63184144378862745098;
	}
	else
	{
		float t = temperatureInKelvins - 60.0;
		retColor.r = 1.29293618606274509804 * pow(t, -0.1332047592);
		retColor.g = 1.12989086089529411765 * pow(t, -0.0755148492);
	}
	
	if (temperatureInKelvins >= 66.0)
		retColor.b = 1.0;
	else if(temperatureInKelvins <= 19.0)
		retColor.b = 0.0;
	else
		retColor.b = 0.54320678911019607843 * log(temperatureInKelvins - 10.0) - 1.19625408914;

	retColor = clamp(retColor,0.0,1.0);
	return retColor;
}

#line 31000
void main(void)
{
	vec4 tex1color = texture(atlasColor, g_uv.xy);
	vec4 tex2color = texture(atlasNormal, g_uv.xy);
	vec4 minimapcolor = minimapAtWorldPos( g_params.xy );
	fragColor.rgba = vec4(g_color.rgb * tex1color.rgb, tex1color.a );
	fragColor.rgba = vec4(minimapcolor.rgb* tex1color.r,  tex1color.g + g_params.z);
	//fragColor.rgba = minimapcolor;
	//fragColor.rgba = vec4(g_uv.x, g_uv.y, 0.0, 0.6);
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
	gsSrc = gsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
	DrawPrimitiveAtUnitShader =  LuaShader(
		{
		  vertex = vsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  fragment = fsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  geometry = gsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
		  uniformInt = {
			atlasColor = 0,
			atlasNormal = 1,
			heightmapTex = 2,
			miniMapTex = 3,
			},
		uniformFloat = {
			fadeDistance = 3000,
		  },
		},
		DPATname .. "Shader"
	  )
	local shaderCompiled = DrawPrimitiveAtUnitShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	DrawPrimitiveAtUnitVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthrotation', size = 4},
			{id = 1, name = 'uv_atlaspos', size = 4},
			{id = 2, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 3, name = 'worldPos', size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if DrawPrimitiveAtUnitVBO == nil then goodbye("Failed to create DrawPrimitiveAtUnitVBO") end

	local DrawPrimitiveAtUnitVAO = gl.GetVAO()
	DrawPrimitiveAtUnitVAO:AttachVertexBuffer(DrawPrimitiveAtUnitVBO.instanceVBO)
	DrawPrimitiveAtUnitVBO.VAO = DrawPrimitiveAtUnitVAO
	return  DrawPrimitiveAtUnitVBO, DrawPrimitiveAtUnitShader
end

local decalIndex = 0
local decalTimes = {} -- maps instanceID to expected fadeout timeInfo
local decalRemoveQueue = {} -- maps gameframes to list of decals that will be removed

local function AddDecal(decaltexturename, posx, posz, rotation, width, length, heatstart, heatdecay, alphastart, alphadecay, maxalpha)
	-- Documentation
	-- decaltexturename, full path to the decal texture name, it must have been added to the atlasses, e.g. 'bitmaps/scars/scar1.bmp'
	-- posx, posz, world pos to place center of decal
	-- rotation: rotation around y in radians
	-- width, length in elmos
	-- heatstart: the initial temperature, in kelvins of the emissive parts (alpha channel of normal texture)
	-- heatdecay: the exponential rate at which the hot parts are cooled down each frame
	-- alphastart: The initial transparency amount, can be > 1 too
	-- alphadecay: How much alpha is reduced each frame, when alphastart/alphadecay goes below 0, the decal will get automatically removed.
	-- maxalpha: The highest amount of transparency this decal can have
	
	local gf = Spring.GetGameFrame()
	local p,q,s,t = gl.GetAtlasTexture(atlasColor, decaltexturename)
	local posy = Spring.GetGroundHeight(posx, posz)
	--Spring.Echo (unitDefID,decalInfo.texfile, width, length, alpha)
	local lifetime = alphastart/alphadecay
	decalIndex = decalIndex + 1
	pushElementInstance(
		decalVBO, -- push into this Instance VBO Table
			{length, width, rotation, maxalpha ,  -- lengthwidthrotation maxalpha
			q,p,s,t, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			alphastart, alphadecay, heatstart, heatdecay, -- alphastart_alphadecay_heatstart_heatdecay
			posx, posy, posz, 1.0 },
		decalIndex, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	local deathtime = gf + lifetime
	decalTimes[decalIndex] = deathtime
	if decalRemoveQueue[deathtime] == nil then 
		decalRemoveQueue[deathtime] = {decalIndex}
	else
		decalRemoveQueue[deathtime][#decalRemoveQueue[deathtime] + 1 ] = decalIndex
	end
	return decalIndex, lifetime
end

function widget:DrawWorldPreUnit()
	if decalVBO.usedElements > 0 then
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		Spring.Echo(decalVBO.usedElements)
		--glCulling(GL_BACK)
		glCulling(false)
		glDepthTest(GL_LEQUAL)
		--glDepthTest(false)
		gl.DepthMask(false)
		glTexture(0, atlasColor)
		glTexture(1, atlasNormals)
		glTexture(2, '$heightmap')
		glTexture(3, '$minimap')
		decalShader:Activate()
		decalShader:SetUniform("fadeDistance",disticon * 1000)
		decalVBO.VAO:DrawArrays(GL.POINTS,decalVBO.usedElements)
		decalShader:Deactivate()
		glTexture(0, false)
		glCulling(false)
		glDepthTest(false)
	end
end

local function RemoveDecal(instanceID)
	if decalVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalVBO, instanceID)
	end
	decalTimes[instanceID] = nil
end

function widget:GameFrame(n)
	if decalRemoveQueue[n] then 
		for i=1, #decalRemoveQueue[n] do
			RemoveDecal(decalRemoveQueue[n][i])
		end
		decalRemoveQueue[n] = nil
	end
end

function widget:Initialize()
	makeAtlas()
	--shaderConfig.MAXVERTICES = 4
	decalVBO, decalShader = InitDrawPrimitiveAtUnit(shaderConfig, "DecalsGL4")
	math.randomseed(1)
	if true then 
		for i= 1, 10000 do 
			local w = math.random() * 256 + 16
			AddDecal("bitmaps/scars/scar1.bmp", 
					Game.mapSizeX * math.random() * 1.0, --posx
					Game.mapSizeZ * math.random() * 1.0, --posz
					math.random() * 6.28, -- rotation
					w, -- width
					w, --height 
					math.random() * 10000, -- heatstart
					math.random() * 100, -- heatdecay
					math.random() * 1.0, -- alphastart
					math.random() * 0.01, -- alphadecay
					math.random() * 1.0 -- maxalpha
					)
		end
	end
end


function widget:ShutDown()
	if atlasNormals ~= nil then
		gl.DeleteTextureAtlas(atlasNormals)
	end
	if atlasColor ~= nil then
		gl.DeleteTextureAtlas(atlasColor)
	end
end
