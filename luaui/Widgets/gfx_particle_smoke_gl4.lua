function widget:GetInfo()
	return {
		name = "Particle Smoke API",
		desc = "Draws smoke animated billboards", 
		author = "Beherith",
		license = "Lua: GNU GPL, v2 or later, GLSL: Apache 2.0 by Beherith (mysterme@gmail.com)",
		layer = -1,
		enabled = true,
	}
end

-------------------------- TODO AND NOTES ----------------------------------
-- 2024.07.08
-- [ ] Draw newest first
	-- This is actually interesting, and should maybe just be a relatively easy tweak to instanceVBOTables
	-- Literature recommends drawing newest particles first, so that older ones occlude over them
-- [ ] Also add horizontal and vertical billboards, not just camera facing ones
-- [ ] Figure out normal mapping and lighting
-- [ ] Color gradient for emissivity controls (maybe needs a color2?)
-- [ ] Sample depth buffers for smoothness (at the very least in the vertex shader)
-- [ ] figure out blending mode
-- [ ] figure out atmospheric absorbtion



-- localized speedup stuff ---------------------------------
local testing = false

local glTexture = gl.Texture

local atlas_alphaplusxyz = "LuaUI/Images/particles_GL4/particlesgl4_plus.dds"
local atlas_emissiveminusxyz = "LuaUI/Images/particles_GL4/particlesgl4_minus.dds"

local particlesmokeatlasinfo = VFS.Include("LuaUI/Images/particles_GL4/particlesgl4_tiles.lua")
particlesmokeatlasinfo.flip(particlesmokeatlasinfo)

if testing then
	atlas_alphaplusxyz = "LuaUI/Images/particles_GL4/test_cube_normal.dds"
	atlas_emissiveminusxyz = "LuaUI/Images/particles_GL4/test_cube_normal.dds"

	particlesmokeatlasinfo = VFS.Include("LuaUI/Images/particles_GL4/particlesgl4_tiles_test.lua")
particlesmokeatlasinfo.flip(particlesmokeatlasinfo)

end


------------- SHADERS ----------------------------------------------
local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
local particleSmokeShader = nil

local autoupdate = true -- auto update shader, for debugging only!

local shaderConfig = { -- these will get #defined in shader headers
	HEIGHTOFFSET = 0.5, -- Additional height added to everything
}

-- TODO use this instead
local vsSrcPath = "LuaUI/Widgets/Shaders/particle_smoke_6way_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/particle_smoke_6way_gl4.frag.glsl"

local particleSmokeInstanceVBOLayout = { -- see how this matches per instance attributes in vertex shader
	{id = 1, name = 'startpos_scale', size = 4},
	{id = 2, name = 'motionvector', size = 4},
	{id = 3, name = 'atlasuv', size = 4},
	{id = 4, name = 'numTiles_lifestart_animspeed', size = 4},
	{id = 5, name = 'emissivecolor', size = 4},
}

local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	--vsSrc = vsSrc,
	--fsSrc = fsSrc,
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
		vertexData[#vertexData +1] = 1 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r		
		
		vertexData[#vertexData +1] = 1		
		vertexData[#vertexData +1] = 1 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r		
		
		vertexData[#vertexData +1] = 1		
		vertexData[#vertexData +1] = 0 
		vertexData[#vertexData +1] = i 
		vertexData[#vertexData +1] = r
		
		vertexData[#vertexData +1] = 0		
		vertexData[#vertexData +1] = 0 
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
		indexData[#indexData+1] = 4*(i-1) + 0
		indexData[#indexData+1] = 4*(i-1) + 1
		indexData[#indexData+1] = 4*(i-1) + 2
		indexData[#indexData+1] = 4*(i-1) + 2
		indexData[#indexData+1] = 4*(i-1) + 3
		indexData[#indexData+1] = 4*(i-1) + 0
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

local function AddInstance( instanceID, startpos_scale, motionvector, atlasuv, numTiles_lifestart_animspeed, emissivecolor)
	--	{id = 1, name = 'startpos_scale', size = 4},
	-- {id = 2, name = 'motionvector', size = 4},
	-- {id = 3, name = 'atlasuv', size = 4},
	-- {id = 4, name = 'numTiles_lifestart_animspeed', size = 4},
	-- {id = 5, name = 'emissivecolor', size = 4},
	

	return pushElementInstance(
		particleSmokeInstanceVBO, -- push into this Instance VBO Table
			{
				startpos_scale[1], startpos_scale[2], startpos_scale[3], startpos_scale[4],  -- 
				motionvector[1], motionvector[2], motionvector[3], motionvector[4],  -- 
				atlasuv[1], atlasuv[2], atlasuv[3], atlasuv[4],  
				numTiles_lifestart_animspeed[1], numTiles_lifestart_animspeed[2], numTiles_lifestart_animspeed[3],  numTiles_lifestart_animspeed[4],  
				emissivecolor[1], emissivecolor[2], emissivecolor[3], emissivecolor[4], 
			},
		instanceID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
end

local function GetPixelAtMousePos(drawvector)
	-- get it one above the cursors hot point
	local mx, my, lmb = Spring.GetMouseState()
	
	local pixels 
	if lmb then  
		pixels = gl.ReadPixels(mx, my +1, 2,2)
	else
		local r,g,b,a = gl.ReadPixels(mx, my+1,1,1)
		pixels = {{{r,g,b,a}}}
	end
	if pixels then
		pixels["mx"] = mx
		pixels["my"] = my
		pixels["lmb"] = lmb
	else
		Spring.Echo(mx,my, pixels)
	end
	
	local x,y,z = pixels[1][1][1], pixels[1][1][2], pixels[1][1][3]
	x,y,z = x * 2.0 - 1.0, y * 2.0 - 1.0, z * 2.0 - 1.0
	if math.abs(math.diag(x,y,z) - 1.0 ) < 0.1 then -- almost a normal vector
		-- We need to draw the normal vector space then.
		pixels['normal'] = true
	end
	return pixels
end



local function DrawPixelAtMousePos(pixels, fraction)
	for x, lr in ipairs({'','r'}) do -- left, right (1,2)
		for y, tb in ipairs({'t', 'b'}) do -- top, bottom, 1,2
			if pixels[x] and pixels[x][y] then
				local p = pixels[x][y]
				local text 
				fraction = math.abs(math.diag(p[1]*2-1, p[2]*2-1, p[3]*2-1))
				if math.abs(fraction - 1.0) < 0.01 then 
					p[1], p[2], p[3] = p[1]*2-1, p[2]*2-1, p[3]*2-1
				else
					fraction = false
				end
				
				if fraction then 
					-- numbers are argb
					text = string.format('(\255\255\50\50%.02f \255\50\255\50%.02f \255\50\50\255%.02f \255\255\255\255%.02f [%.03f])', p[1],p[2],p[3],p[4], fraction)
				else
					text = string.format('[\255\255\50\50%03d \255\50\255\50%03d \255\50\50\255%03d \255\255\255\255%03d]', p[1] * 255,p[2]* 255,p[3]* 255,p[4]* 255)
				end
				
				local opts = string.format('%s%so',lr,tb)
				gl.Text(text, pixels['mx'] - (x*32) + 48 , pixels['my'] - y *32 + 48,16,opts)
				--Spring.Echo(Spring.GetDrawFrame(), pixels['mx'], pixels['my'],text)
			end
		end
	end		
end
local pxstore

function widget:DrawWorld()
	if autoupdate then
		particleSmokeShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or particleSmokeShader
	end
	
	if particleSmokeShader == nil then return end
	gl.Culling(GL.BACK)
	gl.DepthTest(GL.LEQUAL)
	--gl.DepthTest(true)
	gl.DepthMask(false)
	glTexture(0, atlas_alphaplusxyz)
	glTexture(1, atlas_emissiveminusxyz)
	particleSmokeShader:Activate()
	particleSmokeShader:SetUniform("atlasSize",atlasX,atlasY)
	particleSmokeShader:SetUniform("myFloat",1.23456)
	if particleSmokeInstanceVBO.usedElements > 0 then 
		particleSmokeInstanceVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, particleSmokeInstanceVBO.usedElements, 0)
	end
	particleSmokeShader:Deactivate()
	glTexture(0, false)
	pxstore = GetPixelAtMousePos()
end

function widget:DrawScreenPost()
	DrawPixelAtMousePos(pxstore)
end

local function RemoveElement( instanceID) 
	-- this is NOT order preserving, if you wish to preserve order, use instanceTable:compact()
	if particleSmokeInstanceVBO and 
		particleSmokeInstanceVBO[instanceID] then 
		popElementInstance(particleSmokeInstanceVBO, instanceID)
	end
end

local function randtablechoice(t)
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

local idx = 0

local particles = {}
for k,v in pairs(particlesmokeatlasinfo) do
	if type(k) == "string" and type(v) == "table" then 
		Spring.Echo(k)
		particles[#particles+1] = k
	end
end


local function AddSomeSmoke()
	idx = idx + 1
	local r = math.random
	
	local particledata = particlesmokeatlasinfo[particles[math.random(1, #particles)]]
	
	
	--Spring.Echo("Added some smoke", idx)
	AddInstance(
		idx,
		{1024 * r(),1024 * r(),1024 * r(),32 * r() +32,},
		{1 * r(),1 * r(),1 * r(), 0.1 * r() ,},
		{particledata[1],particledata[2],particledata[3],particledata[4]},
		{particledata[7],particledata[8], Spring.GetGameFrame(),0.85 * r() + 0.25 ,},
		{r(), r(), r(),particledata[9] ,}
		
		)
end


function widget:Initialize()
	particleSmokeShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	initRectVBO(1)
	CreateInstanceVBOTable() 
	
	if false then -- debug mode
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


function widget:GameFrame(n) 
	AddSomeSmoke()
	if n%900 ==0  then
		clearInstanceTable(particleSmokeInstanceVBO)
	
	end
	
end


function widget:ShutDown()
end














































