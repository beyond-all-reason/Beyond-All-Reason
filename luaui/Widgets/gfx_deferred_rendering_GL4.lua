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

local glBlending = gl.Blending
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glGetViewSizes = gl.GetViewSizes
local glTexture = gl.Texture
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


local unitDefLight
local unitEventLights
local projectileDefLights 
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

--TODO:
	--Reload config
	--Fix initialize
	--convert config to dicts
	--load config to tale on init
	--noupload pass
	--reload shaderconfig
	--cursorlight
	--light types should know their vbo?
		-- this one is much harder than expected
	-- initialize config dicts
	-- unitdefidpiecemapcache

local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1,
	RAYMARCHSTEPS = 4, -- must be at least one
	USE3DNOISE = 1,
}

local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"

-- These will contain 'global' type lights, ones that dont get updated every frame
local coneLightVBO = {}
local beamLightVBO = {}
local pointLightVBO = {}
local autoLightInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones

-- These contain cob-controlled lights
local unitConeLightVBO = {}
local unitPointLightVBO = {}
local unitBeamLightVBO = {}

local cursorPointLightVBO = {} -- this will contain ally and player cursor lights

-- these will be separate, as they need per-frame updates!
local projectilePointLightVBO = {}  -- for plasma balls
local projectileBeamLightVBO = {}  -- for lasers
local projectileConeLightVBO = {} -- for rockets


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
	return nils
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
	pointLightVBO 			= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Point Light VBO")
	unitPointLightVBO 		= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Unit Point Light VBO", 10)
	cursorPointLightVBO 	= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Cursor Point Light VBO")
	projectilePointLightVBO = createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Projectile Point Light VBO")

	local coneVBO, numConeVertices = makeConeVBO(12, 1, 1)
	coneLightVBO 			= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Cone Light VBO")
	unitConeLightVBO 		= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Unit Cone Light VBO", 10)
	projectileConeLightVBO  = createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Projectile Cone Light VBO")

	local beamVBO, numBeamVertices = makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamLightVBO 			= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Beam Light VBO")
	unitBeamLightVBO 		= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Unit Beam Light VBO", 10)
	projectileBeamLightVBO 	= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Projectile Beam Light VBO")
	
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
---@param targetVBO nil if you want to automatically add it to pointlightvbo/unitPointLightVBO, specify other if you do not
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
local function AddPointLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, r2,g2,b2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	--Spring.Echo("AddPointLight",instanceID)
	local noUpload
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
		lightparams[spawnFramePos] = gameFrame -- this might be problematic, as we will be modifying a table passed by reference!
		noUpload = py
	end
	if targetVBO == nil then targetVBO = pointLightVBO end 
	if unitID then targetVBO = unitPointLightVBO end
	instanceID = pushElementInstance(targetVBO, lightparams, instanceID, true, noUpload, unitID)
	calcLightExpiry(targetVBO, lightparams, instanceID) -- This will add lights that have >0 lifetime to the removal queue
	return instanceID
end

local function AddRandomDecayingPointLight()
	local instanceID = AddPointLight(nil,nil,nil, nil,
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5,
		250,
		1,0,0,1,
		0,1,0,60,
		1,1,1,1,
		gameFrame, 100, 20, 1)
	--Spring.Echo("AddRandomDecayingPointLight", instanceID)	
	
	instanceID = AddPointLight(nil,nil,nil,nil,
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5 + 400,
		250,
		1,1,1,1,
		1,0.5,0.2,5,
		1,1,1,1,
		gameFrame, 30, 0.2, 1)
	--Spring.Echo("AddRandomExplosionPointLight", instanceID)
	
	instanceID = AddPointLight(nil,nil,nil,nil,
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
---@param targetVBO nil if you want to automatically add it to pointlightvbo/unitPointLightVBO, specify other if you do not
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
local function AddBeamLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, sx, sy, sz, r2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	
	local noUpload
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
		noUpload = py 
	end
	
	if targetVBO == nil then targetVBO = beamLightVBO end 
	if unitID then targetVBO = unitBeamLightVBO end
	instanceID = pushElementInstance(targetVBO, lightparams, instanceID, true, noUpload, unitID)
	calcLightExpiry(targetVBO, lightparams, instanceID) -- This will add lights that have >0 lifetime to the removal queue
	return instanceID
end

---AddConeLight
---Note that instanceID can be nil if an auto-generated one is OK.
---If the light is not attached to a unit, and its lifetime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing light, 
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex nil if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param targetVBO nil if you want to automatically add it to pointlightvbo/unitPointLightVBO, specify other if you do not
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
local function AddConeLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, dx,dy,dz,theta, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, animtype)
	
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	local noUpload
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
		noUpload = py
	end
	
	if targetVBO == nil then targetVBO = coneLightVBO end 
	if unitID then targetVBO = unitConeLightVBO end
	instanceID = pushElementInstance(targetVBO, lightparams, instanceID, true, noUpload, unitID)
	calcLightExpiry(targetVBO, lightparams, instanceID) -- This will add lights that have >0 lifetime to the removal queue
	return instanceID
end

local function updateLightPosition(lightVBO, instanceID, posx, posy, posz, radius, p2x, p2y, p2z, theta)
	local instanceIndex = lightVBO.instanceIDtoIndex[instanceID]
	if instanceIndex == nil then return nil end
	instanceIndex = instanceIndex * iT.instanceStep
	local instData = lightVBO.instanceData
	if posx then instData[instanceIndex + 1] = posx end
	if posy then instData[instanceIndex + 2] = posy end
	if posz then instData[instanceIndex + 3] = posz end
	if radius then instData[instanceIndex + 4] = radius end
	if p2x then instData[instanceIndex + 5] = p2x end
	if p2y then instData[instanceIndex + 6] = p2y end
	if p2z then instData[instanceIndex + 7] = p2z end
	if theta then instData[instanceIndex + 8] = theta end
	return instanceIndex
end

-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

local unitDefPieceMapCache = {} -- maps unitDefID to piecemap

local examplePointLight = {
	lighttype = 'point', 
	pieceName = nil,
	posx = 0, posy = 0, posz = 0, radius = 0, 
	r = 1, g = 1, b = 1, a = 1, 
	color2r = 1, color2g = 1, color2b = 1, colortime = 15, -- point lights only, colortime specifies transition time in seconds for unit-attached lights, and transition period 
	dirx = 0, diry = 0, dirz = 1, theta = 0.5,  -- cone lights only, specify direction and half-angle in radians
	pos2x = 100, pos2y = 100, pos2z = 100, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 1, specular = 1, scattering = 1, lensflare = 1, 
	lifetime = 0, 
	sustain = 1, 
	aninmtype = 0 -- unused
}

local function InitializeLight(lightTable, unitID)
	if lightTable.initComplete ~= true then  -- late init
		-- do the table to flattable conversion
		lightParams.lightParamTable = 
		
		
		if unitID then 
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and not unitDefPieceMapCache[unitDefID] then 
				unitDefPieceMapCache[unitDefID] = Spring.GetUnitPieceMap(unitID)
			end
			local pieceMap = unitDefPieceMapCache[unitDefID]
			for lightname, lightParams in pairs(lightTable) do
				if pieceMap[lightParams.pieceName] then -- if its not a real piece, it will default to the model!
					lightParams.pieceIndex = pieceMap[lightParams.pieceName] 
					lightParams.lightParamTable[pieceIndexPos] = lightParams.pieceIndex
				end
				--Spring.Echo(lightname, lightParams.pieceName, pieceMap[lightParams.pieceName])
			end
		end
		
		
		
		lightTable.initComplete = true
	end
end

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
					AddPointLight( tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable)
				end
				if lightParams.lighttype == 'cone' then 
					AddConeLight(tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable) 
				end
				if lightParams.lighttype == 'beam' then 
					AddBeamLight(tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable) 
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
local function RemoveLight(lightshape, instanceID, unitID, noUplooad)
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

local function RemoveProjectileLight(lightshape, instanceID, unitID, noUplooad)
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
		AddPointLight(nil, nil, nil, nil, posx, posy, posz, radius, r,g,b,a)
	elseif which < 0.66 then -- beam
		local s =  (math.random() - 0.5) * 500
		local t =  (math.random() + 0.5) * 100
		local u =  (math.random() - 0.5) * 500
		AddBeamLight(nil,nil,nil,nil, posx, posy , posz, radius, r,g,b,a, posx + s, posy + t, posz + u)
	else -- cone
		local s =  (math.random() - 0.5) * 2
		local t =  (math.random() + 0.0) * -1
		local u =  (math.random() - 0.5) * 2
		local lenstu = 1.0 / math.sqrt(s*s + t*t + u*u)
		local theta = math.random() * 0.9 
		AddConeLight(nil,nil,nil,nil, posx, posy + radius, posz, 3* radius, r,g,b,a,s * lenstu, t * lenstu, u * lenstu, theta)
	end
	
end

local function LoadLightConfig()
	local success, result =	VFS.Include('luaui/config/DeferredLightsGL4config.lua')
	if success then
		unitDefLights = result.unitDefLights
		unitEventLights = result.unitEventLights
		projectileDefLights = result.projectileDefLights
	end
end

local mapinfo = nil
local nightFactor = 0.33
local unitNightFactor = 1.2 -- applied above nightFactor
local adjustfornight = {'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor','groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor' }

function widget:Initialize()
	LoadLightConfig()

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

function widget:UnitIdle(unitID, unitDefID, teamID)
	if unitEventLights[unitDefID] then 
		local lightTable = unitEventLights[unitDefID]
		InitializeLight(lightTable, unitID)
		for lightname, lightParams in pairs(lightTable) do
			if lightname ~= 'initComplete' then
				if lightParams.lighttype == 'point' then
					AddPointLight( tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable)
				end
				if lightParams.lighttype == 'cone' then 
					AddConeLight(tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable) 
				end
				if lightParams.lighttype == 'beam' then 
					AddBeamLight(tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable) 
				end
			end
		end
	end
end


local updateCount = 0
local trackedprojectiles = {}
local lastgf = -2
local removalqueue = {}

local testprojlighttable = {0,16,0,420, --pos + radius
								1,1,1, 15, -- color2
								-1,1,1,1, -- RGBA
								0.2,1,1,1, -- modelfactor_specular_scattering_lensflare
								0,1500,2000,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								}


function widget:Update()
	local nowprojectiles = Spring.GetVisibleProjectiles()
	local newgameframe = lastgf == gameFrame
	lastgf = gameFrame

	-- turn off uploading vbo

	for i= 1, #nowprojectiles do
		local projid = nowprojectiles[i]
		local px, py, pz = Spring.GetProjectilePosition(projid)
		trackedprojectiles[projid] = gameFrame

		if trackedprojectiles[projid] then 
			if newgameframe then
				--update proj pos
				updateLightPosition(pointLightVBO, projid, px,py,pz)
			end
		else
			-- add projectile
			testprojlighttable[1] = px
			testprojlighttable[2] = py
			testprojlighttable[3] = pz
			AddPointLight(projid, nil, nil, pointLightVBO, testprojlighttable)

			--trackedprojectiles[]
		end
	end
	-- remove theones that werent updated 
	for projid, gf in pairs(trackedprojectiles) do
		if gf < gameFrame then
			--SO says we can modify or remove elements while iterating, we just cant add

			trackedprojectiles[projid] = nil
			RemoveLight('point', projid, nil)
		end
	end
	-- upload all changed elements in one go
	uploadAllElements(pointLightVBO)

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


local chobbyInterface = false
function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

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
	end


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
		
		-- Projectile lights
		if projectilePointLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 0)
			projectilePointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, projectilePointLightVBO.usedElements, 0)
		end
		if projectileBeamLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 1)
			projectileBeamLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, projectileBeamLightVBO.usedElements, 0)
		end
		if projectileConeLightVBO.usedElements > 0 then
			deferredLightShader:SetUniformFloat("pointbeamcone", 2)
			projectileConeLightVBO.VAO:DrawArrays(GL.TRIANGLES, nil, 0, projectileConeLightVBO.usedElements, 0)
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

		-- World space cursor lights 
		deferredLightShader:SetUniformFloat("attachedtounitID", 0)		
	
		if not Spring.IsGUIHidden() and not chobbyInterface then
			if cursorPointLightVBO.usedElements > 0 then
				deferredLightShader:SetUniformFloat("pointbeamcone", 0)
				cursorPointLightVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, cursorPointLightVBO.usedElements, 0)
			end
		end 
		
		deferredLightShader:Deactivate()
		
		for i = 0, 10 do glTexture(i, false) end 
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		gl.DepthMask(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
end