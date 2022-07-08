--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Deferred rendering GL4",
		version = 3,
		desc = "Collects and renders cone, point and beam lights",
		author = "Beherith",
		date = "2022.06.10",
		license = "Lua code is GPL V2, GLSL is (c) Beherith",
		layer = -99999990,
		enabled = false
	}
end


--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glBeginEnd = gl.BeginEnd
local glBillboard = gl.Billboard
local glBlending = gl.Blending
local glCallList = gl.CallList
local glClear = gl.Clear
local glColor = gl.Color
local glCreateList = gl.CreateList
local glCreateShader = gl.CreateShader
local glCreateTexture = gl.CreateTexture
local glDeleteShader = gl.DeleteShader
local glDeleteTexture = gl.DeleteTexture
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glGetShaderLog = gl.GetShaderLog
local glGetUniformLocation = gl.GetUniformLocation
local glGetViewSizes = gl.GetViewSizes
local glPopMatrix = gl.PopMatrix
local glPushMatrix = gl.PushMatrix
local glTexCoord = gl.TexCoord
local glTexture = gl.Texture
local glTexRect = gl.TexRect
local glRect = gl.Rect
local glRenderToTexture = gl.RenderToTexture
local glUniform = gl.Uniform
local glUniformInt = gl.UniformInt
local glUniformMatrix = gl.UniformMatrix
local glUseShader = gl.UseShader
local glVertex = gl.Vertex
local glTranslate = gl.Translate
local spEcho = Spring.Echo
local spGetCameraPosition = Spring.GetCameraPosition
local spWorldToScreenCoords = Spring.WorldToScreenCoords
local spGetGroundHeight = Spring.GetGroundHeight
local gameFrame = 0

local math_sqrt = math.sqrt
local math_min = math.min
local math_max = math.max

local glowImg = "LuaUI/Images/glow2.dds"
local beamGlowImg = ":n:LuaUI/Images/barglow-center.png"
local beamGlowEndImg = ":n:LuaUI/Images/barglow-edge.png"

local GLSLRenderer = true

local vsx, vsy, chobbyInterface, forceNonGLSL
local ivsx = 1.0
local ivsy = 1.0
local screenratio = 1.0

-- dynamic light shaders
local depthPointShader = nil
local depthBeamShader = nil

-- shader uniforms
local lightposlocPoint = nil
local lightcolorlocPoint = nil
local lightparamslocPoint = nil
local uniformEyePosPoint
local uniformViewPrjInvPoint

local lightposlocBeam = nil
local lightpos2locBeam = nil
local lightcolorlocBeam = nil
local lightparamslocBeam = nil
local uniformEyePosBeam
local uniformViewPrjInvBeam

--------------------------------------------------------------------------------
--Light falloff functions: http://gamedev.stackexchange.com/questions/56897/glsl-light-attenuation-color-and-intensity-formula
--------------------------------------------------------------------------------

local verbose = false
local function VerboseEcho(...)
	if verbose then
		Spring.Echo(...)
	end
end

local collectionFunctions = {}
local collectionFunctionCount = 0

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------


function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:ViewResize()
	vsx, vsy = gl.GetViewSizes()
	ivsx = 1.0 / vsx --we can do /n here!
	ivsy = 1.0 / vsy
	if Spring.GetMiniMapDualScreen() == 'left' then
		vsx = vsx / 2
	end
	if Spring.GetMiniMapDualScreen() == 'right' then
		vsx = vsx / 2
	end
	screenratio = vsy / vsx --so we dont overdraw and only always draw a square
end

widget:ViewResize()

-- GL4 notes:
-- A spot light is a sphere?
-- A cone light is a cone
-- A beam light is a box
-- all prims should be back-face only rendered!

-- Full documentation:
-- https://docs.google.com/document/d/16mvYJX8WJ8cNjGe_3zhrymTOzPoSkFprr78i_vpH7yA/edit#

-- Separate VBO's for spheres, cones, beams
-- no geometry shader for now, its kinda pointless, might change my mind later

-- Sources of light
-- Projectiles
	-- beamlasers
		-- might get away with not updating their pos each frame?
		-- probably not, due to continuous lasers like beamer turret (though that one may be spawned every frame...)
	-- lightning
		-- these move too?
	-- plasma balls
		-- these are actually easy to sim, but might not be worth it
	-- missiles
		-- unsimable, must be queried
	-- rockets
		-- hard to sim
	-- gibs
		-- hard to sim
-- Explosions
	-- actually spawn once, reasonably easy (separate vbotable for them?) 
	-- always spherical, should be able to override a param with them
	-- 
-- mapdefined lights
	-- animating them might be a challenge
-- headlights
	-- would rock, needs their own vbo for position maybe?
	-- or just extend
-- piecelights
	-- for thrusters, would be truly epic!
	-- fusion lights
	
-- Notes on self-point lights:
	-- these are probably best billboarded, then depth tested!

-- would be nice to have:
	-- full map-level dense atmosphere
	-- explosions should kick up dust
	-- simulate wind and other movements
	-- at a rez of 32 elmos, dsd would need:
	-- 256*256*16 voxels (1 million?) yeesh

-- Features are not light-attachable at the moment, and shouldnt be, use global lights 

-- preliminary perf:
	-- yeah raymarch is expensive!

local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1,
	RAYMARCHSTEPS = 4, -- must be at least one
	USE3DNOISE = 1,
}

local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"

local coneLightVBO = {}
local beamLightVBO = {}
local pointLightVBO = {}
local autoLightInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones

local unitConeLightVBO = {}
local unitPointLightVBO = {}
local unitBeamLightVBO = {}

--local featureConeLightVBO = {}
--local featurePointLightVBO = {}

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local deferredLightShader = nil

local function goodbye(reason) 
	Spring.Echo('Exiting', reason)
	widgetHandler:RemoveWidget()
end

local vsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.frag.glsl"

local lastshaderupdate = nil
local shaderSourceCache = {}
local function checkShaderUpdates(vssrcpath, fssrcpath, gssrcpath, shadername, delaytime)
	if lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), lastshaderupdate) > (delaytime or 0.25) then 
		lastshaderupdate = Spring.GetTimer()
		local vsSrcNew = vssrcpath and VFS.LoadFile(vssrcpath)
		local fsSrcNew = fssrcpath and VFS.LoadFile(fssrcpath)
		local gsSrcNew = gssrcpath and VFS.LoadFile(gssrcpath)
		if  vsSrcNew == shaderSourceCache.vsSrc and 
			fsSrcNew == shaderSourceCache.fsSrc and 
			gsSrcNew == shaderSourceCache.gsSrc then 
			--Spring.Echo("No change in shaders")
			return nil
		else
			local compilestarttime = Spring.GetTimer()
			shaderSourceCache.vsSrc = vsSrcNew
			shaderSourceCache.fsSrc = fsSrcNew
			shaderSourceCache.gsSrc = gsSrcNew
			
			local engineUniformBufferDefs = LuaShader.GetEngineUniformBufferDefs()
			if vsSrcNew then 
				vsSrcNew = vsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				vsSrcNew = vsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			if fsSrcNew then 
				fsSrcNew = fsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				fsSrcNew = fsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			if gsSrcNew then 
				gsSrcNew = gsSrcNew:gsub("//__ENGINEUNIFORMBUFFERDEFS__", engineUniformBufferDefs)
				gsSrcNew = gsSrcNew:gsub("//__DEFINES__", LuaShader.CreateShaderDefinesString(shaderConfig))
			end
			local reinitshader =  LuaShader(
				{
				vertex = vsSrcNew,
				fragment = fsSrcNew,
				geometry = gsSrcNew,
				uniformInt = {
					mapDepths = 0,
					modelDepths = 1,
					mapNormals = 2,
					modelNormals = 3,
					mapExtra = 4, 
					modelExtra = 5,
					mapDiffuse = 6,
					modelDiffuse = 7,
					noise3DCube = 8,
					heightmapTex = 9,
					mapnormalsTex = 10,
					},
				uniformFloat = {
					pointbeamcone = 0,
					--fadeDistance = 3000,
					attachedtounitID = 0,
					nightFactor = 1.0,
					windX = 0.0,
					windZ = 0.0, 
				  },
				},
				shadername
			)
			local shaderCompiled = reinitshader:Initialize()
			
			Spring.Echo(shadername, " recompiled in ", Spring.DiffTimers(Spring.GetTimer(), compilestarttime, true), "ms at", gameFrame, "success", shaderCompiled or false)
			if shaderCompiled then 
				return reinitshader
			else
				return nil
			end
		end
	end
	return nil
end

local function createLightInstanceVBO(vboLayout, vertexVBO, numVertices, indexVBO, VBOname, unitIDattribID)
	local targetLightVBO = makeInstanceVBOTable( vboLayout, 64, VBOname, unitIDattribID)
	if vertexVBO == nil or targetLightVBO == nil then goodbye("Failed to make "..VBOname) end 
	targetLightVBO.vertexVBO = vertexVBO
	targetLightVBO.numVertices = numVertices
	targetLightVBO.indexVBO = indexVBO
	targetLightVBO.VAO = makeVAOandAttach(targetLightVBO.vertexVBO, targetLightVBO.instanceVBO, targetLightVBO.indexVBO)
	return targetLightVBO
end
 
local function initGL4()
	-- init the VBO
	local vboLayout = {
			{id = 3, name = 'worldposrad', size = 4}, 
				-- for spot, this is center.xyz and radius
				-- for cone, this is center.xyz and height
				-- for beam this is center.xyz and radiusleft
			{id = 4, name = 'worldposrad2', size = 4},
				-- for spot, this is 0
				-- for cone, this is direction.xyz and angle in radians
				-- for beam this is end.xyz and radiusright
			{id = 5, name = 'lightcolor', size = 4},
				-- this is light color rgba for all
			{id = 6, name = 'modelfactor_specular_scattering_lensflare', size = 4},
			{id = 7, name = 'otherparams', size = 4},
				-- Otherparams must be spawnframe, dieframe
			{id = 8, name = 'color2', size = 4},
			{id = 9, name = 'pieceIndex', size = 1, type = GL.UNSIGNED_INT},
			{id = 10, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
	}

	local pointVBO, numPointVertices, pointIndexVBO, numIndices = makeSphereVBO(8, 4, 1) 
	pointLightVBO 		= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Point Light VBO")
	unitPointLightVBO 	= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Unit Point Light VBO", 10)
	--featurePointLightVBO = createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Feature Point Light VBO", 10)
	
	local coneVBO, numConeVertices = makeConeVBO(12, 1, 1)
	coneLightVBO 		= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Cone Light VBO")
	unitConeLightVBO 	= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Unit Cone Light VBO", 10)
	--featureConeLightVBO = createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Feature Cone Light VBO", 10)
	
	local beamVBO, numBeamVertices = makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamLightVBO 		= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Beam Light VBO")
	unitBeamLightVBO 	= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Unit Beam Light VBO", 10)
	
	deferredLightShader =  checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4")
	if not deferredLightShader then goodbye("Failed to compile Deferred Lights GL4 shader") end 
end


--------------------------------------------------------------------------------
------
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
--[[
local function DeferredLighting_RegisterFunction(func)
	collectionFunctionCount = collectionFunctionCount + 1
	collectionFunctions[collectionFunctionCount] = func
	return collectionFunctionCount
end

local function DeferredLighting_UnRegisterFunction(functionID)
	collectionFunctions[functionID] = nil
end
]]--
local lightRemoveQueue = {}
local function calcLightExpiry(targetVBO, lightParamsTable, instanceID)
	if lightParamsTable[18] <= 0 then -- LifeTime less than 0 means never expires
		return nil 
	end
	local deathtime = math.ceil(lightParamsTable[17] + lightParamsTable[18])
	if lightRemoveQueue[deathtime] == nil then
		lightRemoveQueue[deathtime] = {}
	end
	lightRemoveQueue[deathtime][instanceID] = targetVBO
	return deathtime
end

local lightCacheTable = {}
for i = 1, 29 do lightCacheTable[i] = 0 end 
local pieceIndexPos = 25
local spawnFramePos = 17
lightCacheTable[13] = 1 --modelfactor_specular_scattering_lensflare
lightCacheTable[14] = 1
lightCacheTable[15] = 1
lightCacheTable[16] = 1

---AddPointLight
---Note that instanceID can be nil if an auto-generated one is OK.
---If the light is not attached to a unit, and its lifetime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing light, 
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex nil if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param px_or_table float position X or a valid table of parameters
---@param py float Y position of the light
---@param pz float Z position of the light
---@param radius float radius position of the light
---@param r float red color of the light (0-1), but can go higher
---@param g float green color of the light (0-1), but can go higher
---@param b float blue color of the light (0-1), but can go higher
---@param a float global brightness modifier of the light (0-1), but can go higher
---@param r2 float red secondary color of the light (0-1), but can go higher
---@param g2 float green secondary color of the light (0-1), but can go higher
---@param b2 float blue secondary color of the light (0-1), but can go higher
---@param colortime float time in seconds for the light to transition to secondary color. For unitlights, specify in frames the period you want
---@param modelfactor float how much more light gets applied to models vs terrain (default 1)
---@param specular float how strong specular highlights of this light are (default 1)
---@param scattering float how strong the atmospheric scattering effect is (default 1)
---@param lensflare float intensity of the lens flare effect( default 1)
---@param spawnframe float the gameframe the light was spawned in (for anims, in frames, default current game frame)
---@param lifetime float how many frames the light will live, with decreasing brightness
---@param sustain float how much sustain time the light will have at its original brightness (in game frames) 
---@param animtype int what further type of animation will be used
---@return instanceID for future reuse
local function AddPointLight(instanceID, unitID, pieceIndex, px_or_table, py, pz, radius, r,g,b,a, r2,g2,b2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	--Spring.Echo("AddPointLight",instanceID)
	local lightparams
	if type(px_or_table) ~= "table" then 
		lightparams = lightCacheTable
		lightparams[1] = px_or_table or 0
		lightparams[2] = py or 0 
		lightparams[3] = pz or 0 
		lightparams[4] = radius or 100
		lightparams[5] = r2 or 0
		lightparams[6] = g2 or 0
		lightparams[7] = b2 or 0
		lightparams[8] = colortime or 0
		
		lightparams[9] = r or 1
		lightparams[10] = g or 1
		lightparams[11] = b or 1
		lightparams[12] = a or 1
		
		lightparams[13] = modelfactor or 1
		lightparams[14] = specular or 1
		lightparams[15] = scattering or 1
		lightparams[16] = lensflare or 1
		
		lightparams[spawnFramePos] = spawnframe or gameFrame
		lightparams[18] = lifetime or 0
		lightparams[19] = sustain or 1
		lightparams[20] = animtype or 0
		lightparams[21] = 0 -- unused
		lightparams[22] = 0 --unused
		lightparams[23] = 0 --unused
		lightparams[24] = 0 --unused
		lightparams[pieceIndexPos] = pieceIndex or 0
	else
		lightparams = px_or_table
		lightparams[spawnFramePos] = gameFrame
	end
	if unitID then 
		instanceID = pushElementInstance(unitPointLightVBO, lightparams, instanceID, true, nil, unitID)
	else
		instanceID = pushElementInstance(pointLightVBO, lightparams, instanceID, true)
		calcLightExpiry(pointLightVBO, lightparams, instanceID)
	end
	return instanceID
end

local function AddRandomDecayingPointLight()
	local instanceID = AddPointLight(nil,nil,nil, 
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5,
		250,
		1,0,0,1,
		0,1,0,60,
		1,1,1,1,
		gameFrame, 100, 20, 1)
	--Spring.Echo("AddRandomDecayingPointLight", instanceID)	
	
	instanceID = AddPointLight(nil,nil,nil, 
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5 + 400,
		250,
		1,1,1,1,
		1,0.5,0.2,5,
		1,1,1,1,
		gameFrame, 30, 0.2, 1)
	--Spring.Echo("AddRandomExplosionPointLight", instanceID)
	
	instanceID = AddPointLight(nil,nil,nil, 
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5 + 800,
		250,
		0,0,0,1, -- start from black
		1,0.5,0.25,3, -- go to yellow in 3 frames
		1,1,1,1,
		gameFrame, 100, 20, 1) -- Sustain peak brightness for 20 frames, and go down to 0 brightness by 100 frames.
	--Spring.Echo("AddRandomDecayingPointLight", instanceID)
end

---AddBeamLight
---Note that instanceID can be nil if an auto-generated one is OK.
---If the light is not attached to a unit, and its lifetime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing light, 
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex nil if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param px_or_table float position X or a valid table of parameters
---@param py float Y position of the light
---@param pz float Z position of the light
---@param radius float radius position of the light
---@param r float red color of the light (0-1), but can go higher
---@param g float green color of the light (0-1), but can go higher
---@param b float blue color of the light (0-1), but can go higher
---@param a float global brightness modifier of the light (0-1), but can go higher
---@param sx float pos of the endpoint of the beam
---@param sy float pos of the endpoint of the beam
---@param sz float pos of the endpoint of the beam
---@param r2 float radius2 is unused at the moment
---@param modelfactor float how much more light gets applied to models vs terrain (default 1)
---@param specular float how strong specular highlights of this light are (default 1)
---@param scattering float how strong the atmospheric scattering effect is (default 1)
---@param lensflare float intensity of the lens flare effect( default 1)
---@param spawnframe float the gameframe the light was spawned in (for anims, in frames, default current game frame)
---@param lifetime float how many frames the light will live, with decreasing brightness
---@param sustain float how much sustain time the light will have at its original brightness (in game frames) 
---@param animtype int what further type of animation will be used
---@return instanceID for future reuse
local function AddBeamLight(instanceID, unitID, pieceIndex, px_or_table, py, pz, radius, r,g,b,a, sx, sy, sz, r2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	
	local lightparams
	if type(px_or_table) ~= "table" then 
		lightparams = lightCacheTable
		lightparams[1] = px_or_table or 0
		lightparams[2] = py or 0 
		lightparams[3] = pz or 0 
		lightparams[4] = radius or 100
		lightparams[5] = sx or 0
		lightparams[6] = sy or 0
		lightparams[7] = sz or 0
		lightparams[8] = radius or 100
		
		lightparams[9] = r or 1
		lightparams[10] = g or 1
		lightparams[11] = b or 1
		lightparams[12] = a or 1
		
		lightparams[13] = modelfactor or 1
		lightparams[14] = specular or 1
		lightparams[15] = scattering or 1
		lightparams[16] = lensflare or 1
		
		lightparams[spawnFramePos] = spawnframe or gameFrame
		lightparams[18] = lifetime or 0
		lightparams[19] = sustain or 1
		lightparams[20] = animtype or 0
		lightparams[21] = 0 --unused
		lightparams[22] = 0 --unused
		lightparams[23] = 0 --unused
		lightparams[24] = 0 --unused
		lightparams[pieceIndexPos] = pieceIndex or 0
	else
		lightparams = px_or_table
		lightparams[spawnFramePos] = gameFrame
	end
	if unitID then 
		instanceID = pushElementInstance(unitBeamLightVBO, lightparams, instanceID, true, nil, unitID)
	else
		instanceID = pushElementInstance(beamLightVBO, lightparams, instanceID, true)
		calcLightExpiry(beamLightVBO, lightparams, instanceID)
	end
	return instanceID
end

---AddConeLight
---Note that instanceID can be nil if an auto-generated one is OK.
---If the light is not attached to a unit, and its lifetime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing light, 
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex nil if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param px_or_table float position X or a valid table of parameters
---@param py float Y position of the light
---@param pz float Z position of the light
---@param radius float height of the cone
---@param r float red color of the light (0-1), but can go higher
---@param g float green color of the light (0-1), but can go higher
---@param b float blue color of the light (0-1), but can go higher
---@param a float global brightness modifier of the light (0-1), but can go higher
---@param dx float dirx of the cone
---@param dy float diry of the cone
---@param dz float dirz of the cone
---@param theta float half-angle of the cone in radians
---@param modelfactor float how much more light gets applied to models vs terrain (default 1)
---@param specular float how strong specular highlights of this light are (default 1)
---@param scattering float how strong the atmospheric scattering effect is (default 1)
---@param lensflare float intensity of the lens flare effect( default 1)
---@param spawnframe float the gameframe the light was spawned in (for anims, in frames, default current game frame)
---@param lifetime float how many frames the light will live, with decreasing brightness
---@param sustain float how much sustain time the light will have at its original brightness (in game frames) 
---@param animtype int what further type of animation will be used
---@return instanceID for future reuse
local function AddConeLight(instanceID, unitID, pieceIndex, px_or_table, py, pz, radius, r,g,b,a, dx,dy,dz,theta, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	
	local lightparams
	if type(px_or_table) ~= "table" then 
		lightparams = lightCacheTable
		lightparams[1] = px_or_table or 0
		lightparams[2] = py or 0 
		lightparams[3] = pz or 0 
		lightparams[4] = radius or 100
		lightparams[5] = dx or 0
		lightparams[6] = dy or 0
		lightparams[7] = dz or 0
		lightparams[8] = theta or 0.5
		
		lightparams[9] = r or 1
		lightparams[10] = g or 1
		lightparams[11] = b or 1
		lightparams[12] = a or 1
		
		lightparams[13] = modelfactor or 1
		lightparams[14] = specular or 1
		lightparams[15] = scattering or 1
		lightparams[16] = lensflare or 1
		
		lightparams[spawnFramePos] = spawnframe or gameFrame
		lightparams[18] = lifetime or 0
		lightparams[19] = sustain or 1
		lightparams[20] = animtype or 0
		lightparams[21] = 0 -- unused
		lightparams[22] = 0 --unused
		lightparams[23] = 0 --unused
		lightparams[24] = 0 --unused
		lightparams[pieceIndexPos] = pieceIndex or 0
	else
		lightparams = px_or_table
		lightparams[spawnFramePos] = gameFrame
	end
	if unitID then 
		instanceID = pushElementInstance(unitConeLightVBO, lightparams, instanceID, true, nil, unitID)
	else
		instanceID = pushElementInstance(coneLightVBO, lightparams, instanceID, true)
		calcLightExpiry(coneLightVBO, lightparams, instanceID)
	end
	return instanceID
end

local function updateLightPosition(lightVBO, instanceID, posx, posy, posz, p2x, p2y, p2z)
	local instanceIndex = lightVBO.instanceIDtoIndex[instanceID]
	if instanceIndex == nil then return nil end
	instanceIndex = instanceIndex * iT.instanceStep
	local instData = lightVBO.instanceData
	instData[instanceIndex + 1] = posx
	instData[instanceIndex + 2] = posy
	instData[instanceIndex + 3] = posz
	if p2x then
		instData[instanceIndex + 5] = p2x
		instData[instanceIndex + 6] = p2y
		instData[instanceIndex + 7] = p2z
	end
	return instanceIndex
end

-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

local unitDefLights = {
	[UnitDefNames['armpw'].id] = {
		headlightpw = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'justattachtobase', -- invalid ones will attack to the worldpos of the unit
			lightParamTable = {0,23,7,150, --pos + height
								0,-0.07,1, 0.30, -- dir + angle
								1,1,0.9,0.6, -- RGBA
								-0.33,1,1.5,0.6, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- dicklight = {
		-- 	lighttype = 'point',
		-- 	pieceName = 'pelvis',
		-- 	lightParamTable = {50,10,4,100, --pos + radius
		-- 						0,0,0, 0, -- color2
		-- 						1,1,1,0, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		-- gunlight = {
		-- 	lighttype = 'beam',
		-- 	pieceName = 'lthigh',
		-- 	lightParamTable = {0,0,0,150, --pos + radius
		-- 						150,150,150, 0, -- endpos
		-- 						1,1,1,1, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['armrad'].id] = {
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,0,70, --pos + radius
		-- 						0,0,-1, 0.2, -- dir + angle
		-- 						0.5,3,0.5,1, -- RGBA
		-- 						0.5,1,2,0, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		greenblob = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,72,0,20, --pos + radius
								0,0,0,0, -- color2
								0,1,0,0.6, -- RGBA
								0.8,0.9,1.0,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corrad'].id] = {
		greenblob = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,82,0,20, --pos + radius
								0,0,0,0, -- color2
								0,1,0,0.6, -- RGBA
								0.8,0.9,1.0,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},

	[UnitDefNames['armllt'].id] = {
		searchlightllt = {
			lighttype = 'cone',
			pieceName = 'sleeve',
			lightParamTable = {0,5,5.8,450, --pos + radius
								0,0,1,0.25, -- dir + angle
								1,1,1,0.5, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corllt'].id] = {
		searchlightllt = {
			lighttype = 'cone',
			pieceName = 'turret',
			lightParamTable = {0,5,5.8,450, --pos + radius
								0,0,1,0.25, -- dir + angle
								1,1,1,0.5, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armrl'].id] = {
		searchlightrl = {
			lighttype = 'cone',
			pieceName = 'sleeve',
			lightParamTable = {0,0,7,450, --pos + radius
								0,0,1,0.20, -- dir + angle
								1,1,1,1, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armjamt'].id] = {
		-- searchlight = {
		-- 	lighttype = 'cone',
		-- 	pieceName = 'turret',
		-- 	lightParamTable = {0,0,3,65, --pos + radius
		-- 						0,-0.4,1, 1, -- dir + angle
		-- 						1.2,0.1,0.1,1.2, -- RGBA
		-- 						1,1,1,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
		cloaklightred = {
				lighttype = 'point',
				pieceName = 'turret',
				lightParamTable = {0,30,0,35, --pos + radius
								0,0,1,0, -- unused
								1,0,0,0.5, -- RGBA
								0.5,0.5,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armack'].id] = {
		beacon1 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'beacon1',
			lightParamTable = {0,0,0,21, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		beacon2 = {
			lighttype = 'cone',
			pieceName = 'beacon2',
			lightParamTable = {0,0,0,21, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armstump'].id] = {
		searchlightstump = {
			lighttype = 'cone',
			pieceName = 'base',
			lightParamTable = {0,0,10,100, --pos + radius
								0,-0.08,1, 0.26, -- dir + angle
								1,1,1,1.2, -- RGBA
								1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armbanth'].id] = {
		searchlightbanth = {
			lighttype = 'cone',
			pieceName = 'turret',
			lightParamTable = {0,2,18,520, --pos + radius
								0,-0.12,1, 0.26, -- dir + angle
								1,1,1,1, -- RGBA
								0.1,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},	
	[UnitDefNames['armcom'].id] = {
		headlightarmcom = {
			lighttype = 'cone',
			pieceName = 'head',
			lightParamTable = {0,0,10,420, --pos + radius
								0,-0.25,1, 0.26, -- dir + angle
								-1,1,1,1, -- RGBA
								0.2,2,3,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		-- lightsaber = {
		-- 	lighttype = 'beam',
		-- 	pieceName = 'dish',
		-- 	lightParamTable = {0,0,4,80, --pos + radius
		-- 						0,0, 300 , 40, -- pos2
		-- 						1,0,0,1, -- RGBA
		-- 						1,1,0.3,1, -- modelfactor_specular_scattering_lensflare
		-- 						0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
		--						0,0,0,0, -- color2
		-- 						0, -- pieceIndex
		-- 						0,0,0,0 -- instData always 0!
		-- 						},
		-- 	--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		-- },
	},
	[UnitDefNames['corcom'].id] = {
		headlightarmcom = {
			lighttype = 'cone',
			pieceName = 'head',
			lightParamTable = {0,1,9,420, --pos + radius
								0,-0.17,1, 0.26, -- dir + angle
								-1,1,1,1, -- RGBA
								1,2,3,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armcv'].id] = {
		nanolightarmcv = {
			lighttype = 'cone',
			pieceName = 'nano1',
			lightParamTable = {3,0,-4,120, --pos + radius
								0,0,1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armca'].id] = {
		nanolightarmca = {
			lighttype = 'cone',
			pieceName = 'nano',
			lightParamTable = {0,0,0,120, --pos + radius
								0,0,-1, 0.3, -- pos2
								-1,0,0,1, -- RGBA
								0,1,3,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armamd'].id] = {
		readylightamd = {
				lighttype = 'point',
				pieceName = 'antenna',
				lightParamTable = {0,1,0,21, --pos + radius
								0,0.5,0,15, -- color2
								0,2,0,1, -- RGBA
								1,1,1,6, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armaap'].id] = {
		blinkaap = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {-86,91,3,75, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.5, -- RGBA
								0.2,0.5,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armatlas'].id] = {
		jetr = {
			lighttype = 'cone',
			pieceName = 'thrustr',
			lightParamTable = {-2,0,-2,140, --pos + radius
								0,0,-1, 0.8, -- pos2
								1,0.98,0.85,0.4, -- RGBA
								0,1,0.5,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		jetl = {
				lighttype = 'cone',
			pieceName = 'thrustl',
			lightParamTable = {2,0,-2,140, --pos + radius
								0,0,-1, 0.8, -- pos2
								1,0.98,0.85,0.4, -- RGBA
								0,1,0.5,1, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armeyes'].id] = {
		eyeglow = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {0,10,0,300, --pos + radius
								0,0,0,0, -- unused
								1,1,1,0.3, -- RGBA
								0.1,0.5,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armanni'].id] = {
		annilight = {
			lighttype = 'cone',
			pieceName = 'light',
			lightParamTable = {0,0,0,950, --pos + radius
								0,0,1, 0.07, -- pos2
								1,1,1,0.5, -- RGBA
								0,1,2,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armafus'].id] = {
		controllight = {
			lighttype = 'cone',
			pieceName = 'collar1',
			lightParamTable = {-25,38,-25,100, --pos + radius
								1,0,1, 0.5, -- pos2
								-1,1,1,5, -- RGBA
								0.1,1,2,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		fusionglow = {
				lighttype = 'point',
				pieceName = 'base',
				lightParamTable = {0,45,0,90, --pos + radius
								0,0,0,0, -- color2 + colortime
								-1,1,1,0.9, -- RGBA
								0.1,0.5,1,5, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armzeus'].id] = {
		weaponglow = {
			lighttype = 'point',
			pieceName = 'gunhand',
			lightParamTable = {0,-9.5,8.5,10, --pos + radius
							0.4,0.7,1.2,30, -- color2 + colortime
							0.2,0.5,1.0,0.8, -- RGBA
							0.1,0.75,2,7, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		weaponspark = {
			lighttype = 'point',
			pieceName = 'emit_spark',
			lightParamTable = {0,1,0,55, --pos + radius
							0,0,0,2, -- color2
							1,1,1,0.85, -- RGBA
							0.1,0.75,0.2,7, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		backpackglow = {
			lighttype = 'point',
			pieceName = 'gunstatic',
			lightParamTable = {0,8,0,10, --pos + radius
							0.4,0.7,1.2,30, -- color2 + colortime
							0.2,0.5,1.0,0.8, -- RGBA
							0.1,0.75,2,10, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corpyro'].id] = {
		flamelight = {
			lighttype = 'point',
			pieceName = 'lloarm',
			lightParamTable = {0,-1.4,15,24, --pos + radius
							0.9,0.5,0.05,10, -- unused
							0.95,0.66,0.07,0.56, -- RGBA
							0.1,1.5,0.35,0, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armsnipe'].id] = {
		sniperreddot = {
			lighttype = 'cone',
			pieceName = 'laser',
			lightParamTable = {0,0,0,700, --pos + radius
								0,1,0.0001, 0.006, -- pos2
								2,0,0,0.85, -- RGBA
								0.1,4,2,4, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['cormakr'].id] = {
		flamelight = {
			lighttype = 'point',
			pieceName = 'light',
			lightParamTable = {0,10,0,50, --pos + radius
							0,0,0,0, -- color2 + colortime
							0.9,0.7,0.45,0.58, -- RGBA
							0.1,1.5,0.35,0, -- modelfactor_specular_scattering_lensflare
							0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
							0,0,0,0, -- color2
							0, -- pieceIndex
							0,0,0,0 -- instData always 0!
							},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['lootboxbronze'].id] = {
		blinka = {
				lighttype = 'point',
				pieceName = 'blinka',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								1,120,0,1, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkb = {
				lighttype = 'point',
				pieceName = 'blinkb',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkc = {
				lighttype = 'point',
				pieceName = 'blinkc',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkd = {
				lighttype = 'point',
				pieceName = 'blinkd',
				lightParamTable = {0,1,0,25, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,0.85, -- RGBA
								1,1,1,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['armaap'].id] = {
		blinka = {
				lighttype = 'point',
				pieceName = 'blinka',
				lightParamTable = {0,1,0,20, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		dishlight = {
				lighttype = 'point',
				pieceName = 'dish',
				lightParamTable = {0,8,0,20, --pos + radius
								-1,-1,-1,30, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		blinkb = {
				lighttype = 'point',
				pieceName = 'blinkb',
				lightParamTable = {0,1,0,20, --pos + radius
								0,0,0,0, -- color2
								-1,1,1,1, -- RGBA
								0.2,0.5,2,7, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corsilo'].id] = {
		launchlight1 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit1',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit2',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight3 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit3',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		launchlight4 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit4',
			lightParamTable = {0,0,0,30, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.1,0,2, -- RGBA
								0.1,0.2,1,2, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corint'].id] = {
		hotbarrel1 = {
				lighttype = 'point',
				pieceName = 'light',
				lightParamTable = {-7,8,5,30, --pos + radius
								0,0,1,0, -- unused
								1,0.2,0,0.7, -- RGBA
								2,1,0,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		hotbarrel2 = {
				lighttype = 'point',
				pieceName = 'light',
				lightParamTable = {7,8,5,30, --pos + radius
								0,0,1,0, -- unused
								1,0.2,0,0.7, -- RGBA
								2,1,0,0, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corlab'].id] = {
		buildlight = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		buildlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,1.5,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
	[UnitDefNames['corck'].id] = {
		buildlight = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,2,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
		buildlight2 = { -- this is the lightname
			lighttype = 'cone',
			pieceName = 'cagelight_emit',
			lightParamTable = {0,0,0,17, --pos + radius
								-1,0,0, 0.99, -- dir + angle
								1.3,0.9,0.1,2, -- RGBA
								0.1,0.2,2,10, -- modelfactor_specular_scattering_lensflare
								0,0,0,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								},
			--pieceIndex will be nil, because this can only be determined once a unit of this type is spawned
		},
	},
}

local function AddStaticLightsForUnit(unitID, unitDefID, noupload)
	if unitDefLights[unitDefID] then
		local unitDefLight = unitDefLights[unitDefID]
		if unitDefLight.initComplete ~= true then  -- late init
			local pieceMap = Spring.GetUnitPieceMap(unitID)
			for lightname, lightParams in pairs(unitDefLight) do
				if pieceMap[lightParams.pieceName] then -- if its not a real piece, it will default to the model!
					lightParams.pieceIndex = pieceMap[lightParams.pieceName] 
					lightParams.lightParamTable[pieceIndexPos] = lightParams.pieceIndex
				end
				--Spring.Echo(lightname, lightParams.pieceName, pieceMap[lightParams.pieceName])
			end
			unitDefLight.initComplete = true
		end
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				if lightParams.lighttype == 'point' then
					AddPointLight( tostring(unitID) ..  lightname, unitID, nil, lightParams.lightParamTable)
				end
				if lightParams.lighttype == 'cone' then 
					AddConeLight(tostring(unitID) ..  lightname, unitID, nil, lightParams.lightParamTable) 
				end
				if lightParams.lighttype == 'beam' then 
					AddBeamLight(tostring(unitID) ..  lightname, unitID, nil, lightParams.lightParamTable) 
				end
			end
		end
	end
end

local function RemoveStaticLightsFromUnit(unitID, unitDefID)
	if unitDefLights[unitDefID] then 
		local unitDefLight = unitDefLights[unitDefID]
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				if lightParams.lighttype == 'point' then
					popElementInstance(unitPointLightVBO, tostring(unitID) ..  lightname) 
				end
				if lightParams.lighttype == 'cone' then 
					popElementInstance(unitConeLightVBO, tostring(unitID) ..  lightname)
				end
				if lightParams.lighttype == 'beam' then 
					popElementInstance(unitBeamLightVBO, tostring(unitID) ..  lightname)
				end
			end
		end
	end
end

---RemoveLight(lightshape, instanceID, unitID)
---Remove a light
---@param lightshape string 'point'|'beam'|'cone'
---@param instanceID any the ID of the light to remove
---@param unitID number make this non-nil to remove it from a unit
---@returns the same instanceID on success, nil if the light was not found
local function RemoveLight(lightshape, instanceID, unitID)
	if lightshape == 'point' then 
		if unitID then return popElementInstance(unitPointLightVBO, instanceID) 
		else return popElementInstance(pointLightVBO, instanceID) end
	elseif lightshape =='beam' then 
		if unitID then return popElementInstance(unitBeamLightVBO, instanceID) 
		else return popElementInstance(beamLightVBO, instanceID) end
	elseif lightshape =='cone' then 
		if unitID then return popElementInstance(unitConeLightVBO, instanceID) 
		else return popElementInstance(coneLightVBO, instanceID) end
	else return nil end
end


function AddRandomLight(which)
	local gf = gameFrame
	local radius = math.random() * 150 + 50
	local posx = Game.mapSizeX * math.random() * 1.0
	local posz = Game.mapSizeZ * math.random() * 1.0
	local posy = Spring.GetGroundHeight(posx, posz) + math.random() * 0.5 * radius
	-- randomize color
	local r  = math.random() + 0.1 --r
	local g = math.random() + 0.1 --g 
	local b = math.random() + 0.1 --b
	local a = math.random() * 1.0 + 0.5 -- intensity or alpha
	
	lightCacheTable[13] = 1 -- modelfactor
	lightCacheTable[14] = 1 -- specular
	lightCacheTable[15] = 1 -- rayleigh-mie
	lightCacheTable[16] = 1 -- lensflare
	
	
	if which < 0.33 then -- point
		AddPointLight(nil, nil, nil, posx, posy, posz, radius, r,g,b,a)
	elseif which < 0.66 then -- beam
		local s =  (math.random() - 0.5) * 500
		local t =  (math.random() + 0.5) * 100
		local u =  (math.random() - 0.5) * 500
		AddBeamLight(nil,nil,nil,posx, posy , posz, radius, r,g,b,a, posx + s, posy + t, posz + u)
	else -- cone
		local s =  (math.random() - 0.5) * 2
		local t =  (math.random() + 0.0) * -1
		local u =  (math.random() - 0.5) * 2
		local lenstu = 1.0 / math.sqrt(s*s + t*t + u*u)
		local theta = math.random() * 0.9 
		AddConeLight(nil,nil,nil,posx, posy + radius, posz, 3* radius, r,g,b,a,s * lenstu, t * lenstu, u * lenstu, theta)
	end
	
end

local mapinfo = nil
local nightFactor = 0.33
local unitNightFactor = 1.2 -- applied above nightFactor
local adjustfornight = {'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor','groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor' }

function widget:Initialize()
	
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	
	if initGL4() == false then return end
	
	local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs
	
	if nightFactor ~= 1 then 
		--Spring.Debug.TableEcho(mapinfo)
		local nightLightingParams = {}
		for _,v in ipairs(adjustfornight) do 
			nightLightingParams[v] = mapinfo.lighting[string.lower(v)]
			if nightLightingParams[v] ~= nil then 
				for k2, v2 in pairs(nightLightingParams[v]) do
					--Spring.Echo(v,k2,v2)
					if tonumber(v2) then 
						if string.find(v, 'unit', nil, true) then 
							nightLightingParams[v][k2] = v2 * nightFactor * unitNightFactor
						else
							nightLightingParams[v][k2] = v2 * nightFactor 
						end
					end
				end
			else
				Spring.Echo("Deferred Lights GL4: Warning: This map does not specify ",v, "in mapinfo.lua!")
			end
		end
		Spring.SetSunLighting(nightLightingParams)
	end 
	
	math.randomseed(1)
	for i=1, 50 do AddRandomLight(	math.random()) end   
	
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	
	WG['lightsgl4'] = {}
	WG['lightsgl4'].AddPointLight = AddPointLight
	WG['lightsgl4'].AddBeamLight  = AddBeamLight
	WG['lightsgl4'].AddConeLight  = AddConeLight
	WG['lightsgl4'].RemoveLight  = RemoveLight
	widgetHandler:RegisterGlobal('AddPointLight', WG['lightsgl4'].AddPointLight)
	widgetHandler:RegisterGlobal('AddBeamLight', WG['lightsgl4'].AddBeamLight)
	widgetHandler:RegisterGlobal('AddConeLight', WG['lightsgl4'].AddConeLight)
	widgetHandler:RegisterGlobal('RemoveLight', WG['lightsgl4'].RemoveLight)
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddStaticLightsForUnit(unitID, unitDefID, false, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(unitPointLightVBO) -- clear all instances
	clearInstanceTable(unitBeamLightVBO) -- clear all instances
	clearInstanceTable(unitConeLightVBO) -- clear all instances
	
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddStaticLightsForUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(unitPointLightVBO) -- upload them all
	uploadAllElements(unitBeamLightVBO) -- upload them all
	uploadAllElements(unitConeLightVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	--if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	RemoveStaticLightsFromUnit(unitID, Spring.GetUnitDefID(unitID))
end

function widget:Shutdown()
	-- TODO: delete the VBOs and shaders like a good boy 
	WG['lightsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddPointLight')
	widgetHandler:DeregisterGlobal('AddBeamLight')
	widgetHandler:DeregisterGlobal('AddConeLight')
	widgetHandler:DeregisterGlobal('RemoveLight')
end

local function DrawLightType(lights, lightsCount, lighttype)
	-- point = 0 beam = 1
	--Spring.Echo('Camera FOV = ', Spring.GetCameraFOV()) -- default TA cam fov = 45
	--set uniforms:
	local cpx, cpy, cpz = spGetCameraPosition()
	if lighttype == 0 then
		--point
		glUseShader(depthPointShader)
		glUniform(uniformEyePosPoint, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvPoint, "viewprojectioninverse")
	else
		--beam
		glUseShader(depthBeamShader)
		glUniform(uniformEyePosBeam, cpx, cpy, cpz)
		glUniformMatrix(uniformViewPrjInvBeam, "viewprojectioninverse")
	end

	glTexture(0, "$model_gbuffer_normtex")
	glTexture(1, "$model_gbuffer_zvaltex")
	glTexture(2, "$map_gbuffer_normtex")
	glTexture(3, "$map_gbuffer_zvaltex")
	glTexture(4, "$model_gbuffer_spectex")

	local cx, cy, cz = spGetCameraPosition()
	for i = 1, lightsCount do
		local light = lights[i]
		local param = light.param
		if verbose then
			VerboseEcho('gfx_deferred_rendering.lua: Light being drawn:', i)
			Spring.Debug.TableEcho(light)
		end
		if lighttype == 0 then
			-- point
			local lightradius = param.radius
			local falloffsquared = param.falloffsquared or 1.0
			--Spring.Echo("Drawlighttype position = ", light.px, light.py, light.pz)
			local groundheight = math_max(0, spGetGroundHeight(light.px, light.pz))
			local sx, sy, sz = spWorldToScreenCoords(light.px, groundheight, light.pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx / vsx
			sy = sy / vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			--local dist_sq = (light.px-cx)^2 + (groundheight-cy)^2 + (light.pz-cz)^2
			local dist_sq = (light.px - cx) ^ 2 + (groundheight - cy) ^ 2 + (light.pz - cz) ^ 2
			local ratio = lightradius / math_sqrt(dist_sq) * 1.5
			glUniform(lightposlocPoint, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightcolorlocPoint, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, falloffsquared)
			local tx1 = (sx - 0.5) * 2 - ratio * screenratio
			local ty1 = (sy - 0.5) * 2 - ratio
			local tx2 = (sx - 0.5) * 2 + ratio * screenratio
			local ty2 = (sy - 0.5) * 2 + ratio
			--PtaQ uncomment this if you want to debug:
			--Spring.Echo(string.format("sx=%.4f sy = %.4f dist_sq=%.1f ratio = %.4f, {%.4f : %.4f}-{%.4f :  %.4f}",sx,sy,dist_sq,ratio,tx1,ty1,tx2,ty2))

			glTexRect(
				math_max(-1, tx1),
				math_max(-1, ty1),
				math_min(1, tx2),
				math_min(1, ty2),
				math_max(0, sx - 0.5 * ratio * screenratio),
				math_max(0, sy - 0.5 * ratio),
				math_min(1, sx + 0.5 * ratio * screenratio),
				math_min(1, sy + 0.5 * ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1

		end
		if lighttype == 1 then
			-- beam
			local lightradius = 0

			local falloffsquared = param.falloffsquared or 1.0
			local px = light.px + light.dx * 0.5
			local py = light.py + light.dy * 0.5
			local pz = light.pz + light.dz * 0.5
			local lightradius = param.radius + math_sqrt(light.dx * light.dx + light.dy * light.dy + light.dz * light.dz) * 0.5
			VerboseEcho("Drawlighttype position = ", light.px, light.py, light.pz)
			local sx, sy, sz = spWorldToScreenCoords(px, py, pz) -- returns x, y, z, where x and y are screen pixels, and z is z buffer depth.
			sx = sx / vsx
			sy = sy / vsy --since FOV is static in the Y direction, the Y ratio is the correct one
			local dist_sq = (px - cx) ^ 2 + (py - cy) ^ 2 + (pz - cz) ^ 2
			local ratio = lightradius / math_sqrt(dist_sq)
			ratio = ratio * 2

			glUniform(lightposlocBeam, light.px, light.py, light.pz, param.radius) --in world space
			glUniform(lightpos2locBeam, light.px + light.dx, light.py + light.dy + 24, light.pz + light.dz, param.radius) --in world space, the magic constant of +24 in the Y pos is needed because of our beam distance calculator function in GLSL
			glUniform(lightcolorlocBeam, param.r * light.colMult, param.g * light.colMult, param.b * light.colMult, falloffsquared)
			--TODO: use gl.Shape instead, to avoid overdraw
			glTexRect(
				math_max(-1, (sx - 0.5) * 2 - ratio * screenratio),
				math_max(-1, (sy - 0.5) * 2 - ratio),
				math_min(1, (sx - 0.5) * 2 + ratio * screenratio),
				math_min(1, (sy - 0.5) * 2 + ratio),
				math_max(0, sx - 0.5 * ratio * screenratio),
				math_max(0, sy - 0.5 * ratio),
				math_min(1, sx + 0.5 * ratio * screenratio),
				math_min(1, sy + 0.5 * ratio)
			) -- screen size goes from -1, -1 to 1, 1; uvs go from 0, 0 to 1, 1
		end
	end
	glUseShader(0)
	glTexture(0, false)
	glTexture(1, false)
	glTexture(2, false)
	glTexture(3, false)
	glTexture(4, false)
end

local function renderToTextureFunc(tex, s, t)
	glTexture(tex)
	glTexRect(-1 * s, -1 * t, 1 * s, 1 * t)
	glTexture(false)
end

local function mglRenderToTexture(FBOTex, tex, s, t)
	glRenderToTexture(FBOTex, renderToTextureFunc, tex, s, t)
end

local beamLights = {}
local beamLightCount = 0
local pointLights = {}
local pointLightCount = 0


local windX = 0
local windZ = 0



function widget:GameFrame(n)
	if n % 100 == 0 then 
		AddRandomDecayingPointLight()
	end
	gameFrame = n
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	--windStrength = math.min(20, math.max(3, windStrength))	
	--Spring.Echo(windDirX,windDirZ,windStrength)
	windX = windX + windDirX *  0.016
	windZ = windZ + windDirZ * 0.016	
	if lightRemoveQueue[n] then 
		for instanceID, targetVBO in pairs(lightRemoveQueue[n]) do
			if targetVBO.instanceIDtoIndex[instanceID] then 
				--Spring.Echo("removing dead light", targetVBO.usedElements, 'id:', instanceID)
				popElementInstance(targetVBO, instanceID)
			end
		end
		lightRemoveQueue[n] = nil
	end
end

function widget:Update()
	

	--[[
	beamLights = {}
	beamLightCount = 0
	pointLights = {}
	pointLightCount = 0
	for i = 1, collectionFunctionCount do
		if collectionFunctions[i] then
			beamLights, beamLightCount, pointLights, pointLightCount = collectionFunctions[i](beamLights, beamLightCount, pointLights, pointLightCount)
		end
	end
	]]--
end

-- adding a glow to Cannon projectiles
--function widget:DrawWorld()
	--[[
	local lights = pointLights
	gl.DepthMask(false)
	glBlending(GL.SRC_ALPHA, GL.ONE)
	gl.Texture(glowImg)
	local size = 1
	for i = 1, pointLightCount do
		local light = lights[i]
		local param = light.param
		if param.gib == nil and param.type == "Cannon" then
			size = param.glowradius * 0.44
			gl.PushMatrix()
			local colorMultiplier = 1 / math_max(param.r, param.g, param.b)
			gl.Color(param.r * colorMultiplier, param.g * colorMultiplier, param.b * colorMultiplier, 0.015 + (size / 4000))
			gl.Translate(light.px, light.py, light.pz)
			gl.Billboard(true)
			gl.TexRect(-(size / 2), -(size / 2), (size / 2), (size / 2))
			gl.PopMatrix()
		end
	end
	gl.Billboard(false)
	gl.Texture(false)
	gl.DepthMask(true)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	]]--
--end


function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	--glBlending(GL.DST_COLOR, GL.ONE) -- Set add blending mode
	deferredLightShader = checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4") or deferredLightShader
	
	
	if pointLightVBO.usedElements > 0 or 
		unitPointLightVBO.usedElements > 0 or 
		beamLightVBO.usedElements > 0 or 
		unitConeLightVBO.usedElements > 0 or
		coneLightVBO.usedElements > 0 then 
	
	
		local alt, ctrl, meta, shft = Spring.GetModKeyState()
				
		local screenCopyTex = nil
		if WG['screencopymanager'] and WG['screencopymanager'].GetScreenCopy then
			--screenCopyTex = WG['screencopymanager'].GetScreenCopy() -- TODO DOESNT WORK? CRASHES THE GL PIPE
		end
		if screenCopyTex == nil then
			--glTexture(6, false)
		else 
			--glTexture(6, screenCopyTex)
		end
		if ctrl then
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		else
			glBlending(GL.SRC_ALPHA, GL.ONE)
		end
		
		gl.Culling(GL.BACK)
		gl.DepthTest(false)
		gl.DepthMask(false)
		glTexture(0, "$map_gbuffer_zvaltex")
		glTexture(1, "$model_gbuffer_zvaltex")
		glTexture(2, "$map_gbuffer_normtex")
		glTexture(3, "$model_gbuffer_normtex")
		glTexture(4, "$map_gbuffer_spectex")
		glTexture(5, "$model_gbuffer_spectex")
		glTexture(6, "$map_gbuffer_difftex")
		glTexture(7, "$model_gbuffer_difftex")
		glTexture(8, noisetex3dcube)
		glTexture(9, "$heightmap")
		glTexture(10,"$normals")

		--Spring.Echo(screenCopyTex)
		
		deferredLightShader:Activate()
		deferredLightShader:SetUniformFloat("nightFactor", nightFactor)
		deferredLightShader:SetUniformFloat("attachedtounitID", 0)
		deferredLightShader:SetUniformFloat("windX", windX)
		deferredLightShader:SetUniformFloat("windZ", windZ)
		--Spring.Echo(windX, windZ)
		
		-- Fixed worldpos lights
		if pointLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 0)
			pointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, pointLightVBO.usedElements, 0)
		end
		if beamLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 1)
			beamLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, beamLightVBO.usedElements, 0)
		end
		if coneLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 2)
			coneLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, coneLightVBO.usedElements, 0)
		end
		
		
		
		-- Unit Attached Lights
		deferredLightShader:SetUniformFloat("attachedtounitID", 1)		
		
		if unitPointLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 0)
			unitPointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, unitPointLightVBO.usedElements, 0)
		end
		
		if unitBeamLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 1)
			unitBeamLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, unitBeamLightVBO.usedElements, 0)
		end
		
		if unitConeLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 2)
			unitConeLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, unitConeLightVBO.usedElements, 0)
		end
	
		
		deferredLightShader:Deactivate()
		
		for i = 0, 10 do glTexture(i, false) end 
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		gl.DepthMask(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end
