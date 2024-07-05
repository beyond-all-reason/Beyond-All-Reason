function widget:GetInfo()
	return {
		name = "Particle Smoke API",
		desc = "Draws smoke animated billboards", 
		author = "Beherith",
		license = "Lua: GNU GPL, v2 or later, GLSL: Apache 2.0 by Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end


-- localized speedup stuff ---------------------------------
local glTexture = gl.Texture

local atlas_alphaplusxyz = "LuaUI/Images/particlesGL4/particles_alphaplusxyz.dds"
local atlas_emissiveminusxyz = "LuaUI/Images/particlesGL4/particles_emissiveminusxyz.dds"

local particlesmokeatlasinfo = VFS.Include("LuaUI/Images/particlesGL4/particles_atlas.lua")

------------- SHADERS ----------------------------------------------
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local particleSmokeShader = nil

local autoupdate = false -- auto update shader, for debugging only!

local shaderConfig = { -- these will get #defined in shader headers
	HEIGHTOFFSET = 0.5, -- Additional height added to everything
}

-- TODO use this instead
local vsSrcPath = "LuaUI/Widgets/Shaders/chiligl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/chiligl4.frag.glsl"

-- the vertex shader maps to screen space
local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

// per vertex attributes
layout (location = 0) in vec4 xy_idx_rand; // each vertex of the rectVBO, range [0,1]

// per instance attributes, hmm, 24 floats per instance....
layout (location = 1) in vec4 startpos_scale; // pos xyz, scale w
layout (location = 2) in vec4 motionvector; // dir xyz, growth w
layout (location = 3) in vec4 atlasuv;
layout (location = 4) in vec4 numTiles_lifestart_animspeed;
layout (location = 5) in vec4 emissivecolor;


vec2 GetSpriteSheetAtlasUVs(in vec2 billboardUV, float time){
	// Origin of DDS Image is bottom left
	// Each spritesheet's origin is top left, and and starts with the top row. 
	// Figure out from timing info where we need to be:
	// calculate which loop we are in
	int spritesX = numTiles_lifestart_animspeed.x ;
	int spritesY = numTiles_lifestart_animspeed.y ;
	
	
	int loopIndex =mod( int(time), spritesX * spritesY);
	
	int rowIndex = loopIndex / spritesX;
	int colIndex = mod(loopIndex , spritesX);
	
	vec2 spriteSize = 1.0 / numTiles_lifestart_animspeed.xy;
	
	// Calculate current offset
	vec2 spriteOffset = vec2(float(colIndex) * spriteSize.x, float(rowIndex) * spriteSize.y);
	
	// Adjust the UV coordinates to get the correct frame
	vec2 newUV = billBoardUV * spriteSize + spriteOffset;
	return newUV;
}

// This function takes in a set of UV coordinates [0,1] and tranforms it to correspond to the correct UV slice of an atlassed texture
// uvoffsets is in the form of xXyY
vec2 transformUV(in vec2 inUV, in vec4 uvoffsets){// this is needed for atlassing
	//return vec2(uvoffsets.p * u + uvoffsets.q, uvoffsets.s * v + uvoffsets.t); old
	float a = uvoffsets.t - uvoffsets.s;
	float b = uvoffsets.q - uvoffsets.p;
	return vec2(uvoffsets.s + a * u, uvoffsets.p + b * v);
}

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform vec2 atlasSize;
uniform sampler2D mytex1;

// We could do smoothing in the VS by sampling depth or heightfield?

out DataVS {
	vec4 v_worldPos; // needed later depth buffers, alpha is alpha
	vec4 v_uvs; // now and next
	vec4 v_worldNormal;
	vec4 v_emissivecolor; 
	vec4 v_params; // x is blend factor
};


#line 11000
void main()
{

	// Calculate timing info
	float nowTime = timeInfo.x + timeInfo.w;
	float aliveTime = nowTime - numTiles_lifestart_animspeed.z;
	float animTime = aliveTime * numTiles_lifestart_animspeed.w;
	
	// Place it into the world:
	vec3 vertexNormal = vec3(0.0, -1.0, 0.0); // its pointing right at us!
	vec4 vertexPos = vec4(0);
	vertexPos.w = 1.0;
	
	// Expand the vertex to world scale as it grows
	vertexPos.xz = (xy_idx_rand.xy * 2.0 - 1.0) * (startpos_scale.w + motionvector.w * aliveTime);
	
	// Rotate it because its a billboard:
	mat3 billBoardMatrix = mat3(cameraViewInv[0].xyz,cameraViewInv[2].xyz, cameraViewInv[1].xyz); // swizzle cause we use xz
	vertexPos.xyz = billBoardMatrix * vertexPos.xyz;
	vertexNormal = billBoardMatrix * vertexNormal;
	
	// Transform it to world coords:
	vertexPos.xyz += startpos_scale.xyz + motionvector.xyz * aliveTime;
	v_worldPos = vertexPos;
	v_worldNormal.xyz = vertexNormal;
	
	// Project it:
	gl_Position = cameraViewProj * vertexPos;
	
	
	// Calculate the UVS for now and for next frame
	vec2 baseUV = xy_idx_rand.xy;
	vec2 uvnow  = GetSpriteSheetAtlasUVs(baseUV, animTime);
	vec2 uvnext = GetSpriteSheetAtlasUVs(baseUV, animTime + 1);
	v_uvs.st = transformUV(uvnow, atlasuv);
	v_uvs.pq = transformUV(uvnext, atlasuv);
	
	
	// Pass through various params.
	v_emissivecolor = emissivecolor;
	v_params.x = smoothstep(0,1,fract(animTime));
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

uniform vec2 atlasSize;
uniform sampler2D atlasTexPlus;
uniform sampler2D atlasTexMinus;

in DataVS {
	vec4 v_worldPos; // needed later depth buffers, alpha is alpha
	vec4 v_uvs; // now and next
	vec4 v_worldNormal;
	vec4 v_emissivecolor; 
	vec4 v_params; // x is blend factor
};

out vec4 fragColor;

#line 31000
void main(void)
{
	// sample the textures:
	vec4 texpluscolor  = mix(texture(atlasTexPlus, v_uvs.st), texture(atlasTexPlus, v_uvs.pq), v_params.x);
	vec4 texminuscolor = mix(texture(atlasTexMinus, v_uvs.st), texture(atlasTexMinus, v_uvs.pq), v_params.x);


	// Shade according to these normals
	
	// Calculate absorbtion:
	
	// Apply emissiveness
	
	fragColor.rgba = texpluscolor.rgba;
}
]]


local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	vsSrc = vsSrc,
	fsSrc = fsSrc,
	shaderConfig = shaderConfig,
	forceupdate = true, -- this is just so that we can avoid using the paths for now
	uniformInt = { -- specify texture units here
		atlasTexPlus = 0,
		atlasTexMinus = 1,
	},
	uniformFloat = { -- specify uniform floats here
		myFloat = 3000,
		myZDepth = 0.7,
		atlasSize = {4096, 4096},
		myFloat4 = {0,1,2,3},
		},
	shaderName = "particleSmoke Gl4 Shader",
	}

-------------  MultiQuad VBO  -------------------
-- A 4x4 rectangle VBO

local maxrects = 16
local rectVBO -- Contains the Vertex Array 
local rectIndexVBO -- Contains the index array for the rectangles
local numIndices = 2 * 3 * 9

local function initRectVBO(numrects)

	local vertexData = {}
	for i=1, numrects do
		local r = math.random()
		vertexData[#vertexData +1] = 0		
		vertexData[#vertexData +1] = 0 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r		
		
		vertexData[#vertexData +1] = 1		
		vertexData[#vertexData +1] = 0 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r		
		
		vertexData[#vertexData +1] = 1		
		vertexData[#vertexData +1] = 1 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r
		
		vertexData[#vertexData +1] = 0		
		vertexData[#vertexData +1] = 1 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r		
	end
	
	rectVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	rectVBO:Define(numrects * 4, { -- see how this matches per vertex attributes in vertex shader
		{id = 0, name = "xy_idx_rand", size = 4},
		})
	rectVBO:Upload(vertexData)
	
	local indexData = {}
	for i=1, numrects do 
		indexData[#indexData] = 4*(i-1) + 0
		indexData[#indexData] = 4*(i-1) + 1
		indexData[#indexData] = 4*(i-1) + 2
		indexData[#indexData] = 4*(i-1) + 2
		indexData[#indexData] = 4*(i-1) + 3
		indexData[#indexData] = 4*(i-1) + 0
  end

	rectIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	rectIndexVBO:Define(6 * numrects)
	rectIndexVBO:Upload(indexData)
	if rectVBO == nil or rectIndexVBO == nil then 
		Spring.Echo("Failed to create rect VBO", rectVBO, rectIndexVBO)
	end
end

---------------------- Instance VBOs --------------------------
--- Each widget should (or could) have its own instance VBO, which will make layering easier, and one can transfer elements from one vbo to the other
--- An instance VBO is just a set of instances
--- An instance VBO Table is a lua table that wraps an instance VBO to allow for easy and fast addition and removal of elements

VFS.Include(luaShaderDir.."instancevbotable.lua")

local particleSmokeInstanceVBO = nil

local function goodbye(reason)
  Spring.Echo("particleSmoke GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local particleSmokeInstanceVBOLayout = { -- see how this matches per instance attributes in vertex shader
	{id = 2, name = 'screenpos', size = 4},
	{id = 3, name = 'tiling', size = 4},
	{id = 4, name = 'color1', size = 4},
	{id = 5, name = 'color2', size = 4},
	{id = 6, name = 'uv1', size = 4},
	{id = 7, name = 'uv2', size = 4},
	{id = 8, name = 'animinfo', size = 4},
	{id = 9, name = 'otherparams', size = 4},
}

local function CreateInstanceVBOTable()
	local defaultMaxElements
	particleSmokeInstanceVBO = makeInstanceVBOTable(particleSmokeInstanceVBOLayout, defaultMaxElements, "particleSmokeVBO")
	
	particleSmokeInstanceVBO.vertexVBO = rectVBO
	particleSmokeInstanceVBO.indexVBO  = rectIndexVBO
	particleSmokeInstanceVBO.VAO = makeVAOandAttach(
		particleSmokeInstanceVBO.vertexVBO,
		particleSmokeInstanceVBO.instanceVBO,
		particleSmokeInstanceVBO.indexVBO
	)
	
	return particleSmokeInstanceVBO
end

local defaultUV = {0,1,0,1} -- xXyY
local defaultColor = {1,1,1,1}
local defaultTiling = {0,0,0,0}

local function AddInstance( instanceID, screenpos, tiling, color1, color2, tex1name, tex2name, animinfo, otherparams)

	tiling = tiling or defaultTiling
	color1 = color1 or defaultColor
	color2 = color2 or defaultColor
	uv1 = atlassedImagesUVs[tex1name] or defaultUV
	uv2 = atlassedImagesUVs[tex2name] or defaultUV
	animinfo = animinfo or defaultTiling
	otherparams = animinfo or defaultTiling

	return pushElementInstance(
		particleSmokeInstanceVBO, -- push into this Instance VBO Table
			{
				screenpos[1], screenpos[2], screenpos[3], screenpos[4],  -- screenpos; // screen pixel coords
				tiling[1], tiling[2], tiling[3], tiling[4],  -- tiling; // skLeft, skbottom, skRight, sktop
				color1[1], color1[2], color1[3], color1[4],  
				color2[1], color2[2], color2[3],  color2[4],  
				uv1[1], uv1[2], uv1[3], uv1[4], 
				uv2[1], uv2[2], uv2[3], uv2[4], 
				animinfo[1], animinfo[2], animinfo[3], animinfo[4],  -- unused so far
				otherparams[1], otherparams[2], otherparams[3],otherparams[4], -- unused so far
			},
		instanceID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
end

function widget:DrawWorld()
	if particleSmokeShader == nil then return end
	gl.Culling(false)
	--gl.DepthTest(GL_LEQUAL)
	--gl.DepthTest(false)
	--gl.DepthMask(false)
	glTexture(0, atlas_alphaplusxyz)
	glTexture(1, atlas_emissiveminusxyz)
	particleSmokeShader:Activate()
	particleSmokeShader:SetUniform("atlasSize",atlasX,atlasY)
	particleSmokeShader:SetUniform("myFloat",1.23456)
	if particleSmokeInstanceVBO.usedElements > 0 then 
		particleSmokeInstanceVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, widgetInstanceVBO.usedElements, 0)
	end
	particleSmokeShader:Deactivate()
	glTexture(0, false)
end

local function RemoveElement( instanceID) 
	-- this is NOT order preserving, if you wish to preserve order, use instanceTable:compact()
	if particleSmokeInstanceVBO and 
		particleSmokeInstanceVBO[instanceID] then 
		popElementInstance(widgetInstanceVBOs, instanceID)
	end
end

local function randtablechoice (t)
	local i = 0
	for _ in pairs(t) do i = i+1 end 
	local randi = math.floor(math.random()*i)
	local j = 0
	for k,v in pairs(t) do 
		if j > randi then return k,v end
		j = j+1
	end
	return next(t)
end

function widget:Initialize()
	makeAtlas()
	particleSmokeShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	initRectVBO()
	CreateInstanceVBOTable() 
	
	if true then -- debug mode
		math.randomseed(1)
		local grid = 32
		local gs = 64
		local vsx, vsy = Spring.GetViewGeometry()
		for i= 0, grid * grid -1 do 
			local tex1 = randtablechoice(atlassedImagesUVs)
			local tex2 = randtablechoice(atlassedImagesUVs)
			local tiling = math.floor(math.random() * 8 + 4)
			local x = (i % grid)* gs + 16
			local y = math.floor(i/grid) * gs + 16
			local w = x + math.random() * gs + 16
			local h = y + math.random() * gs + 16
			AddInstance('default', nil, {x,y,w,h}, {tiling,tiling,tiling,tiling}, {math.random(), math.random(), math.random(), math.random()}, nil, tex1, tex2)
		end
	end
end

function widget:ShutDown()
end
