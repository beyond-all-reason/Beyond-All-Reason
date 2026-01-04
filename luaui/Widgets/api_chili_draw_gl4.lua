local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Chili Draw GL4 API",
		desc = "Draw a button (instanced)",
		author = "Beherith",
		date = "2022.02.07 - 2022.12.08", -- damn that took a while
		license = "Lua: GNU GPL, v2 or later, GLSL: (c) Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = false,
	}
end

-- Localized functions for performance
local mathFloor = math.floor
local mathRandom = math.random

-- Localized Spring API for performance
local spEcho = Spring.Echo

-- Notes and TODO
-- what parts should be atlassed? the correct answer is all parts should be atlassed
-- pick up images from atlas:
-- VBO params:
	-- background vertices
	--

-- localized speedup stuff ---------------------------------
local glTexture = gl.Texture

--- ATLAS STUFF --------------------------------------------
local atlasTexture = nil
local atlassedImagesUVs = {}
local atlasSize = 4096
local atlasX = 4000
local atlasY = 4000

local function addDirToAtlas(atlas, path, key, filelist)
	if filelist == nil then filelist = {} end
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	--files = table.sort(files)
	--spEcho("Adding",#files, "images to atlas from", path, key)
	for i=1, #files do
		spEcho(files[i])
		local lowerfile = string.lower(files[i])
		if imgExts[string.sub(lowerfile,-3,-1)] and (key and string.find(lowerfile, key, nil, true)) then
			spEcho(lowerfile)
			gl.AddAtlasTexture(atlas,lowerfile)
			atlassedImagesUVs[lowerfile] = true
			filelist[lowerfile] = true
		end
	end
	return filelist
end

local function makeAtlas()
	atlasTexture = gl.CreateTextureAtlas(atlasSize,atlasSize,1)
	addDirToAtlas(atlasTexture, "luaui/images/chiliskin_gl4", "tech")
	gl.FinalizeTextureAtlas(atlasTexture)	
	local texInfo = gl.TextureInfo(atlasTexture ) 

	atlasX = texInfo.xsize -- cool this works
	atlasY = texInfo.ysize
	for filepath,_ in pairs(atlassedImagesUVs) do
		local p,q,s,t = gl.GetAtlasTexture(atlasTexture, filepath) -- this returns xXyY 
		atlassedImagesUVs[filepath] = {p,q,s,t}
		spEcho(string.format("%dx%d %s at xXyY %d %d %d %d", atlasX, atlasY, filepath,
			p *atlasX, q * atlasX, s * atlasY, t * atlasY)) 
	end

end

------------- SHADERS ----------------------------------------------
local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

local chiliShader = nil

local autoupdate = false -- auto update shader, for debugging only!

local shaderConfig = { -- these will get #defined in shader headers
	HEIGHTOFFSET = 0.5, -- Additional height added to everything
}

-- TODO use this instead
local vsSrcPath = "LuaUI/Shaders/chiligl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/chiligl4.frag.glsl"

-- the vertex shader maps to screen space
local vsSrc =  [[
#version 420
#extension GL_ARB_uniform_buffer_object : require
#extension GL_ARB_shader_storage_buffer_object : require
#extension GL_ARB_shading_language_420pack: require

#line 5000

// per vertex attributes
layout (location = 0) in vec4 xyuv; // each vertex of the rectVBO, range [0,1]
layout (location = 1) in vec4 tilingvector; // TODO: binary vector of tiling factors?

// per instance attributes, hmm, 32 floats per instance....
layout (location = 2) in vec4 screenpos; // screen pixel coords
layout (location = 3) in vec4 tiling; // skLeft, skbottom, skRight, sktop
layout (location = 4) in vec4 color1;
layout (location = 5) in vec4 color2;
layout (location = 6) in vec4 uv1;
layout (location = 7) in vec4 uv2;
layout (location = 8) in vec4 animinfo;
layout (location = 9) in vec4 otherparams;

//__ENGINEUNIFORMBUFFERDEFS__
//__DEFINES__

#line 10000

uniform float myFloat;
uniform float myZDepth;
uniform vec2 atlasSize;
uniform sampler2D atlasTex;

out DataVS {
	vec4 v_screenpos; // needed later for mouse magic
	vec2 v_uv1; //
	vec2 v_uv2;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_animinfo;
	vec4 v_otherparams;
};


#line 11000
void main()
{
	// we have to start by transforming the vertices by tiling them:
	// todo this is just maffs googlefrog im sure you can solve this
	// for now we juke it:
	
	// Calculate the screen pixel coords of this vertex
	vec2 pixelpos = mix(screenpos.xy, screenpos.zw, xyuv.xy);
	//vec2 pixelpos = mix(screenpos.xz, screenpos.yw, xyuv.xy);


	// Clamp tiling if element rectangle is smaller than our tiling:
	vec2 elementWidthHeight = screenpos.zw - screenpos.xy;
	vec4 clampedTiling = clamp(tiling, vec4(0.0), elementWidthHeight.xyxy * 0.5);
	
	// Horizontal Tiling	
	vec4 tilingPixels = tilingvector * clampedTiling;
	pixelpos.x += tilingPixels.x + tilingPixels.z;
	pixelpos.y += tilingPixels.y + tilingPixels.w;
	
	

	// Tiling the UV's
	v_uv1 = mix(uv1.xz, uv1.yw, xyuv.xy);
	v_uv1.x += (tilingPixels.x + tilingPixels.z)/atlasSize.x;
	v_uv1.y += (tilingPixels.y + tilingPixels.w)/atlasSize.y;
	
	v_uv2 = mix(uv2.xz, uv2.yw, xyuv.xy);
	v_uv2.x += (tilingPixels.x + tilingPixels.z)/atlasSize.x;
	v_uv2.y += (tilingPixels.y + tilingPixels.w)/atlasSize.y;

	
	// optional flooring to make them integers?
	pixelpos = floor(pixelpos);
	
	// Dump everything to fragment shader
	v_color1 = color1;
	v_color2 = color2;
	v_animinfo = animinfo;
	v_otherparams = otherparams;
	
	v_otherparams.xy = (v_uv1 - uv1.xz)/(uv1.yw - uv1.xz);
	v_otherparams.z = dot(abs(tilingvector), vec4(0.48));
	//screenpos.xy + xyuv.xy * screenpos.xy + xyuv.xy
	
	// is the mouse, v_color1 will be increased if mouse is inside, even more if its clicked
	bvec2 leftbottommouse = lessThan(screenpos.xy, mouseScreenPos.xy);
	bvec2 righttopmouse =   lessThan(mouseScreenPos.xy,screenpos.zw);
	bool isinmouse = all(bvec4(righttopmouse, leftbottommouse));
	if (isinmouse) {
		v_otherparams.w += 0.5;
		v_color1 *= 2;
		// uint mouseStatus; // bits 0th to 32th: LMB, MMB, RMB, offscreen, mmbScroll, locked
		if ((mouseStatus & 1u) > 0u){
			v_color1 *= 2;
			v_otherparams.w += 0.5;
		}
	}
	
	vec2 viewportpos = (pixelpos.xy / viewGeometry.xy)* 2.0 - 1.0; // viewGeometry.xy contains view size in pixels
	
	gl_Position = vec4(viewportpos.x, viewportpos.y, myZDepth, 1.0);
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

uniform float myFloat;
uniform float myZDepth;
uniform vec2 atlasSize;
uniform sampler2D atlasTex;

in DataVS {
	vec4 v_screenpos; // needed later for mouse magic
	vec2 v_uv1; //
	vec2 v_uv2;
	vec4 v_color1;
	vec4 v_color2;
	vec4 v_animinfo;
	vec4 v_otherparams;
};

out vec4 fragColor;

#line 31000
void main(void)
{
	vec4 tex1color = texture(atlasTex, v_uv1);
	vec4 tex2color = texture(atlasTex, v_uv2);
	
	fragColor.rgba = tex1color.rgba;
	fragColor.rgba += tex2color * v_color2 * v_otherparams.w;
	
	//fragColor.a = 1.0; // no alpha for testing
	//fragColor.rgb = fract(v_otherparams.xyx);
	//fragColor.rgba = v_color1.rgba;
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
		atlasTex = 0,
	},
	uniformFloat = { -- specify uniform floats here
		myFloat = 3000,
		myZDepth = 0.7,
		atlasSize = {atlasX, atlasY},
		myFloat4 = {0,1,2,3},
		},
	shaderName = "Chili Gl4 Shader",
	}


-------------  Rectangle VBO  -------------------
-- A 4x4 rectangle VBO

local rectVBO -- Contains the Vertex Array for the tiled 4x4 rectangle
local rectIndexVBO -- Contains the index array for the rectangle
local numIndices = 2 * 3 * 9

local function initRectVBO()
	-- made of 9 quadrants
	-- Each 8 values is position, uv and tileweight
	-- mimic skinutils function _DrawTiledTexture(x, y, w, h, skLeft, skbottom, skRight, sktop, texw, texh, texIndex, disableTiling)
	-- 0----1----2----4
	-- | TL | TC | TR |
	-- 4----5----6----7
	-- | CL | CC | CR |
	-- 8----9----10--11
	-- | BL | BC | BR |
	-- 12---13---14--15 
	--
	--o------------------------> X
	
	local vertexData = {
		--Starting from TL to TR, then BL to BR, 
		-- x, y, u, v, skLeft, skbottom, skRight, sktop,
		-- interleaved as
		-- vec4 xyuv    tilingvector
		-- tilingvector must match screenpos order of LBRT
		0,1,0,1,    0,0,0,0, --0
		0,1,0,1,    1,0,0,0,
		1,1,1,1,    0,0,-1,0,
		1,1,1,1,    0,0,0,0,
		
		0,1,0,1,    0,0,0,-1, --4
		0,1,0,1,    1,0,0,-1,
		1,1,1,1,    0,0,-1,-1,
		1,1,1,1,    0,0,0,-1,
		
		0,0,0,0,    0,1,0,0, -- 8
		0,0,0,0,    1,1,0,0,
		1,0,1,0,    0,1,-1,0,
		1,0,1,0,    0,1,0,0,
		
		0,0,0,0,    0,0,0,0, --12
		0,0,0,0,    1,0,0,0,
		1,0,1,0,    0,0,-1,0,
		1,0,1,0,    0,0,0,0, --15
	}
	rectVBO = gl.GetVBO(GL.ARRAY_BUFFER,false)
	rectVBO:Define(16, { -- see how this matches per vertex attributes in vertex shader
		{id = 0, name = "xyuv", size = 4},
		{id = 1, name = "tilingvector", size = 4},
		})
	rectVBO:Upload(vertexData)
	
	local indexData = { -- This indexes vertexData
		0,4,5, 0,5,1, -- TL
		1,5,6, 1,6,2, -- TC
		2,6,7, 2,7,3, -- TR
		4,8,9, 4,9,5, -- CL
		5,9,10, 5,10,6,  -- CC
		6,10,11, 6,11,7, -- CR
		8,12,13, 8,13,9, -- BL
		9,13,14, 9, 14, 10, -- BC
		10,14,15, 10,15,11, -- BR
	}

	rectIndexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER,false)
	rectIndexVBO:Define(numIndices)
	rectIndexVBO:Upload(indexData)
	if rectVBO == nil or rectIndexVBO == nil then 
		spEcho("Failed to create rect VBO", rectVBO, rectIndexVBO)
	end
end

---------------------- Instance VBOs --------------------------
--- Each widget should (or could) have its own instance VBO, which will make layering easier, and one can transfer elements from one vbo to the other
--- An instance VBO is just a set of instances
--- An instance VBO Table is a lua table that wraps an instance VBO to allow for easy and fast addition and removal of elements

local widgetInstanceVBOs = {} -- this will be a list of _named_ instance VBOs, so you can separate per-pass (or per widget or whatever)

local function goodbye(reason)
  spEcho("Chili GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local chiliInstanceVBOLayout = { -- see how this matches per instance attributes in vertex shader
	{id = 2, name = 'screenpos', size = 4},
	{id = 3, name = 'tiling', size = 4},
	{id = 4, name = 'color1', size = 4},
	{id = 5, name = 'color2', size = 4},
	{id = 6, name = 'uv1', size = 4},
	{id = 7, name = 'uv2', size = 4},
	{id = 8, name = 'animinfo', size = 4},
	{id = 9, name = 'otherparams', size = 4},
}

local function CreateInstanceVBOTable(tableName)
	local defaultMaxElements
	local newInstanceVBO = InstanceVBOTable.makeInstanceVBOTable(chiliInstanceVBOLayout, defaultMaxElements, tableName .. "_ChiliVBO")
	
	newInstanceVBO.vertexVBO = rectVBO
	newInstanceVBO.indexVBO  = rectIndexVBO
	newInstanceVBO.VAO = InstanceVBOTable.makeVAOandAttach(
		newInstanceVBO.vertexVBO,
		newInstanceVBO.instanceVBO,
		newInstanceVBO.indexVBO
	)
	
	widgetInstanceVBOs[tableName] = newInstanceVBO
	return newInstanceVBO
end

local defaultUV = {0,1,0,1} -- xXyY
local defaultColor = {1,1,1,1}
local defaultTiling = {0,0,0,0}

local function AddInstance(tableName, instanceID, screenpos, tiling, color1, color2, tex1name, tex2name, animinfo, otherparams)

	tiling = tiling or defaultTiling
	color1 = color1 or defaultColor
	color2 = color2 or defaultColor
	uv1 = atlassedImagesUVs[tex1name] or defaultUV
	uv2 = atlassedImagesUVs[tex2name] or defaultUV
	animinfo = animinfo or defaultTiling
	otherparams = animinfo or defaultTiling

	return pushElementInstance(
		widgetInstanceVBOs[tableName], -- push into this Instance VBO Table
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

function widget:DrawScreen()
	if chiliShader == nil then return end
	--gl.Culling(false)
	--gl.DepthTest(GL_LEQUAL)
	--gl.DepthTest(false)
	--gl.DepthMask(false)
	glTexture(0, atlasTexture)
	chiliShader:Activate()
	chiliShader:SetUniform("atlasSize",atlasX,atlasY)
	
	chiliShader:SetUniform("myFloat",1.23456)
	for name, widgetInstanceVBO in pairs(widgetInstanceVBOs) do 
		if widgetInstanceVBO.usedElements > 0 then 
			widgetInstanceVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, widgetInstanceVBO.usedElements, 0)
		end
	end
	chiliShader:Deactivate()
	glTexture(0, false)
end

local function RemoveElement(tableName, instanceID) 
	-- this is NOT order preserving, if you wish to preserve order, use instanceTable:compact()
	if widgetInstanceVBOs[tableName] and 
		widgetInstanceVBOs[tableName][instanceID] then 
		popElementInstance(widgetInstanceVBOs[tableName], instanceID)
	end
end

local function randtablechoice (t)
	local i = 0
	for _ in pairs(t) do i = i+1 end 
	local randi = mathFloor(mathRandom()*i)
	local j = 0
	for k,v in pairs(t) do 
		if j > randi then return k,v end
		j = j+1
	end
	return next(t)
end

function widget:Initialize()
	makeAtlas()
	chiliShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	initRectVBO()
	CreateInstanceVBOTable("default") 
	
	if true then -- debug mode
		math.randomseed(1)
		local grid = 32
		local gs = 64
		local vsx, vsy = Spring.GetViewGeometry()
		for i= 0, grid * grid -1 do 
			local tex1 = randtablechoice(atlassedImagesUVs)
			local tex2 = randtablechoice(atlassedImagesUVs)
			local tiling = mathFloor(mathRandom() * 8 + 4)
			local x = (i % grid)* gs + 16
			local y = mathFloor(i/grid) * gs + 16
			local w = x + mathRandom() * gs + 16
			local h = y + mathRandom() * gs + 16
			AddInstance('default', nil, {x,y,w,h}, {tiling,tiling,tiling,tiling}, {mathRandom(), mathRandom(), mathRandom(), mathRandom()}, nil, tex1, tex2)
		end
	end
end

function widget:ShutDown()
	if atlasTexture ~= nil then
		gl.DeleteTextureAtlas(atlasTexture)
	end
end
