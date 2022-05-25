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

local worley3d128 = "LuaUI/images/worley_rgbnorm_01_asum_128_v1.dds"
--local worley3d128 = "LuaUI/images/worley_128_single_norm_v1.dds"
local worley3d3level = "LuaUI/images/worley_rsum_bgaind_128_v1.dds"

--local noisetex3dcube =  "LuaUI/images/lavadistortion.png"
--local noisetex3d64 =  "LuaUI/images/grid3d64rgb.bmp"

--local distortiontex = "LuaUI/images/lavadistortion.png"
local distortiontex = "LuaUI/images/fractal_voronoi_tiled_1024_1.png"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local GL_RGBA16F_ARB = 0x881A
local GL_RGBA32F_ARB = 0x8814

local GL_FUNC_ADD = 0x8006
local GL_FUNC_REVERSE_SUBTRACT = 0x800B
local GL_GREATER = GL.GREATER
local GL_ONE     = GL.ONE
local GL_SRC_ALPHA = GL.SRC_ALPHA
local GL_ONE_MINUS_SRC_ALPHA = GL.ONE_MINUS_SRC_ALPHA

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	HEIGHTOFFSET = 1, -- Additional height added to everything
	SPHERESEGMENTS = 16,
	RESOLUTION = 2,
	MOTION = 0,
	USEDEFERREDBUFFERS = 0,
	USESHADOWS = 0,
}

---- GL4 Backend Stuff----
-- omg all possible object-object intersection tests: http://www.realtimerendering.com/intersections.html

-- TODO: 
	-- Try to z-sort the stupid spheres!

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local fogSphereInstanceVBO = nil 

local fogTexture
local vsx, vsy
local combineShader

local vsSrc = VFS.LoadFile("LuaUI/Widgets/Shaders/fog_volumes.vert.glsl")
local fsSrc = VFS.LoadFile("LuaUI/Widgets/Shaders/fog_volumes.frag.glsl")

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
		format = GL_RGBA32F_ARB,
		})
end

local function compileFogVolumeShader()
	local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
		local lvsSrc = vsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		local lfsSrc = fsSrc:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
		fogSphereShader =  LuaShader(
			{
			vertex = lvsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
			fragment = lfsSrc:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig)),
			uniformInt = {
				mapDepths = 0,
				modelDepths = 1,
				heightmapTex = 2,
				infoTex = 3,
				shadowTex = 4,
				noise64cube = 5,
				dithernoise2d = 6,
				worley3D = 7,
				worley3d3level = 8,
				},
			uniformFloat = {
				fadeDistance = 300000,
				},
			},
			"fogvolumesShader"
		  )
		  
end

local lastupdate = Spring.GetTimer()
function widget:Update()
	if Spring.DiffTimers(Spring.GetTimer(), lastupdate) > 0.25 then 
		lastupdate = Spring.GetTimer()
		-- load the vs and fs
		local vsSrcNew = VFS.LoadFile("LuaUI/Widgets/Shaders/fog_volumes.vert.glsl")
		local fsSrcNew = VFS.LoadFile("LuaUI/Widgets/Shaders/fog_volumes.frag.glsl")
		if vsSrcNew == vsSrc and fsSrcNew == fsSrc then 
			--Spring.Echo("No change in shaders")
		else
			Spring.Echo("Shaders changed, recompiling", Spring.GetGameFrame())
			vsSrc = vsSrcNew
			fsSrc = fsSrcNew
			compileFogVolumeShader()
			local shaderCompiled = fogSphereShader:Initialize()
		end
	end
end

local function initFogGL4(shaderConfig, DPATname)
	compileFogVolumeShader()
	local shaderCompiled = fogSphereShader:Initialize()
	if not shaderCompiled then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	local sphereVBO, numVertices, sphereIndexVBO, numIndices = makeSphereVBO(shaderConfig.SPHERESEGMENTS, shaderConfig.SPHERESEGMENTS/2, 1)
	--Spring.Echo(sphereVBO, numVertices, sphereIndexVBO, numIndices)

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
	
	combineShader = LuaShader({
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
			uniform sampler2D fogbase;
			uniform sampler2D distortion;
			uniform float gameframe;
			uniform float distortionlevel;
			void main(void) {
				vec2 distUV = gl_TexCoord[0].st * 4 + vec2(0, - gameframe*4);
				vec4 dist = (texture2D(distortion, distUV) * 2.0 - 1.0) * distortionlevel;
				gl_FragColor = texture2D(fogbase, gl_TexCoord[0].st + dist.xy);
			}
		]],
		uniformInt = { fogbase = 0, distortion = 1},
		uniformFloat = { gameframe = 0, distortionlevel = 0},
	})
	
	shaderCompiled = combineShader:Initialize()

	if (shaderCompiled == nil) then
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

	gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)	
	
	--gl.Blending(true);
	--gl.BlendFuncSeparate(GL.SRC_ALPHA, GL.DST_ALPHA, GL.SRC_ALPHA, GL.ONE);
	--gl.BlendEquation(GL_FUNC_ADD);
	
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
	if fogSphereShader.shaderObj == nil then return end
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
		gl.Texture(7, worley3d128)
		gl.Texture(8, worley3d3level)
		
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
		glTexture(7, false)
		glTexture(8, false)
		--glCulling(false)
		glDepthTest(false)
		
		
		
		if toTexture then
			
			gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			combineShader:Activate()
			combineShader:SetUniformFloat("gameframe", Spring.GetGameFrame()/1000)
			combineShader:SetUniformFloat("distortionlevel", 0.00001) -- 0.001
			gl.Texture(0, fogTexture)
			gl.Texture(1, distortiontex)
			gl.TexRect(-1, -1, 1, 1, 0, 0, 1, 1)
			combineShader:Deactivate()
			--gl.TexRect(0, 0, 10000, 10000, 0, 0, 1, 1) -- dis is for debuggin!
			gl.Texture(0, false)
			gl.Texture(1, false)
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
			math.random()* 0.5 + 0.5, math.random() * 0.5 + 0.5, math.random()*0.5 + 0.5, math.random()*0.1 + 0.9 ,
			math.random() - 0.5, math.random() - 0.5, math.random() - 0.5, math.random() -0.5,
			gf, math.random() * 0.1, gf + math.random() * 1000, math.random() * 0.01,
			gf, math.random() + 0.5, math.random()*2, math.random()*0.02
			)
end

function widget:GameFrame(n)
	if shaderConfig.MOTION == 1 then 
		if fogSphereRemoveQueue[n] then 
			for i=1, #fogSphereRemoveQueue[n] do
				RemovefogSphere(fogSphereRemoveQueue[n][i])
				AddRandomFogSphere()
			end
			fogSphereRemoveQueue[n] = nil
		end
	end
end

function widget:Initialize()

	if Spring.HaveShadows() then shaderConfig.USESHADOWS = 1 end 
	local advmap, advmodel = Spring.HaveAdvShading()
	if advmap and advmodel then shaderConfig.USEDEFERREDBUFFERS = 1 end
	--shaderConfig.MAXVERTICES = 4
	fogSphereVBO, fogSphereShader = initFogGL4(shaderConfig, "fogSpheres")
	math.randomseed(1)
	if true then 
		for i= 1, 10 do 
			AddRandomFogSphere()
		end
	end
	
	Spring.Echo(Spring.HaveShadows(),"advshad",Spring.HaveAdvShading())
end
