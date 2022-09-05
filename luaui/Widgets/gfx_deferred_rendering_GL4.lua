--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Deferred rendering GL4",
		version = 3,
		desc = "Collects and renders cone, point and beam lights",
		author = "Beherith",
		date = "2022.06.10",
		license = "Lua code is GPL V2, GLSL is (c) Beherith (mysterme@gmail.com)",
		layer = -99999990,
		enabled = false
	}
end

-------------------------------- Notes, TODO ----------------------------------
do
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
		-- TODO: beamttl needs to be fixes, as we are way over spamming these, with up to 3 lights per beam
	-- lightning
		-- TODO: see if the multi-spawn
	-- plasma balls
		-- these are actually easy to sim, but might not be worth it, not simmed
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

-- Features are not light-attachable at the moment, and shouldnt be as they are immobile, use global lights 

-- preliminary perf:
	-- yeah raymarch is expensive!

--TODO:
	-- XX Reload config
	-- XX Fix initialize
	-- XX convert config to dicts
	-- XX load config to tale on init
	-- XX noupload pass
	-- reload shaderconfig
	--cursorlight
	-- XX light types should know their vbo?
		-- this one is much harder than expected
	-- XX initialize config dicts -- DONE
	-- XX rework dicts -- DONE
	-- XX unitdefidpiecemapcache -- DONE
	-- Draw pre-water?
	-- optimizations:
		-- XX only upload dirty VBOs
		-- Smaller, single channel noise texture
		
end

----------------------------- Localize for optmization ------------------------------------

local glBlending = gl.Blending
local glDepthMask = gl.DepthMask
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local spEcho = Spring.Echo


-- Strong: 
local spIsSphereInView = Spring.IsSphereInView
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileType = Spring.GetProjectileType
local spGetPieceProjectileParams = Spring.GetPieceProjectileParams
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGroundHeight = Spring.GetGroundHeight


-- Weak:
local spIsGUIHidden = Spring.IsGUIHidden
local spGetUnitHeight = Spring.GetUnitHeight -- weak

local math_min = math.min
local math_max = math.max
local math_ceil = math.ceil

local gameFrame = 0
local chobbyInterface

--------------------------------------------------------------------------------
--Light falloff functions: http://gamedev.stackexchange.com/questions/56897/glsl-light-attenuation-color-and-intensity-formula
------------------------------ Debug switches ------------------------------
local autoupdate = true

------------------------------ Light and Shader configurations ------------------

local unitDefLight  -- Table of lights per unitDefID
local unitEventLights -- Table of lights per unitDefID
local muzzleFlashLights  -- one light per weaponDefID
local projectileDefLights  -- one light per weaponDefID
local explosionLights  -- one light per weaponDefID
local gibLight  -- one light for all pieceprojectiles


local deferredLightGL4Config = {globalLightMult = 1, globalRadiusMult = 1, globalLifeMult = 1} 

local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1, -- The ratio of Rayleigh scattering to Mie scattering
	RAYMARCHSTEPS = 4, -- must be at least one, this one one of the main quality parameters
	USE3DNOISE = 1, -- dont touch this
	SURFACECOLORMODULATION = 0.5, -- This specifies how much the lit surfaces color affects direct light blending, 0 is does not effect it, 1.0 is full effect
	BLEEDFACTOR = 0.5, -- How much oversaturated color channels will bleed into other color channels. 
}

-- the 3d noise texture used for this shader
local noisetex3dcube =  "LuaUI/images/noise64_cube_3.dds"

--[[
local examplePointLight = {
	lightType = 'point', 
	pieceName = nil,
	alwaysVisible = true,
	posx = 0, posy = 0, posz = 0, radius = 0, 
	r = 1, g = 1, b = 1, a = 1, 
	color2r = 1, color2g = 1, color2b = 1, colortime = 15, -- point lights only, colortime in seconds for unit-attached
	dirx = 0, diry = 0, dirz = 1, theta = 0.5,  -- cone lights only, specify direction and half-angle in radians
	pos2x = 100, pos2y = 100, pos2z = 100, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 1, specular = 1, scattering = 1, lensflare = 1, 
	lifetime = 0, sustain = 1, 	aninmtype = 0 -- unused
}
]]--


------------------------------ Data structures and management variables ------------

-- These will contain 'global' type lights, ones that dont get updated every frame
local coneLightVBO = {}
local beamLightVBO = {}
local pointLightVBO = {}
local lightVBOMap -- a table of the above 3, keyed by light type

-- These contain cob-controlled lights
local unitConeLightVBO = {}
local unitPointLightVBO = {}
local unitBeamLightVBO = {}
local unitLightVBOMap -- a table of the above 3, keyed by light type

-- these will be separate, as they need per-frame updates!
local projectilePointLightVBO = {}  -- for plasma balls
local projectileBeamLightVBO = {}  -- for lasers
local projectileConeLightVBO = {} -- for rockets
local projectileLightVBOMap -- a table of the above 3, keyed by light type

local cursorPointLightVBO = {} -- this will contain ally and player cursor lights

local lightRemoveQueue = {} -- stores lights that have expired life {gameframe = {lightIDs ... }}

local unitDefPeiceMapCache = {} -- maps unitDefID to piecemap

local lightParamTableSize = 29
local lightCacheTable = {} -- this is a reusable table cache for saving memory later on
for i = 1, lightParamTableSize do lightCacheTable[i] = 0 end 
local pieceIndexPos = 25
local spawnFramePos = 17
lightCacheTable[13] = 1 --modelfactor_specular_scattering_lensflare
lightCacheTable[14] = 1
lightCacheTable[15] = 1
lightCacheTable[16] = 1

local lightParamKeyOrder = {
	posx = 1, posy = 2, posz = 3, radius = 4, 
	r = 9, g = 10, b = 11, a = 12, 
	color2r = 5, color2g = 6, color2b = 7, colortime = 8, -- point lights only, colortime in seconds for unit-attached
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- cone lights only, specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 13, specular = 14, scattering = 15, lensflare = 16, 
	lifetime = 18, sustain = 19, animtype = 20 -- unused
}

local autoLightInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local deferredLightShader = nil

local vsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/deferred_lights_gl4.frag.glsl"

local lastshaderupdate = nil
local shaderSourceCache = {}

local chobbyInterface = false
---------------------- INITIALIZATION FUNCTIONS ----------------------------------

local function goodbye(reason) 
	Spring.Echo('Exiting', reason)
	widgetHandler:RemoveWidget()
end

local function checkShaderUpdates(vssrcpath, fssrcpath, gssrcpath, shadername, delaytime)
	if lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), lastshaderupdate) > (delaytime or 2.25) then 
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
					--mapExtra = 4, 
					--modelExtra = 5,
					mapDiffuse = 6,
					modelDiffuse = 7,
					noise3DCube = 8,
					--heightmapTex = 9,
					--mapnormalsTex = 10,
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

function widget:ViewResize()
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
	deferredLightShader =  checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4")
	if not deferredLightShader then 
		goodbye("Failed to compile Deferred Lights GL4 shader") 
		return false
	end 
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
	
	projectileLightVBOMap = { point = projectilePointLightVBO,  beam = projectileBeamLightVBO,  cone = projectileConeLightVBO, }
	unitLightVBOMap = { point = unitPointLightVBO,  beam = unitBeamLightVBO,  cone = unitConeLightVBO, }
	lightVBOMap = { point = pointLightVBO,  beam = beamLightVBO,  cone = coneLightVBO, }
	return pointLightVBO and unitPointLightVBO and coneLightVBO and beamLightVBO
end


---InitializeLight
---Takes a light definition table, and tries to check wether its already been initialized, if not, it inits it in-place
---@param lightTable table
---@param unitID number 
local function InitializeLight(lightTable, unitID)
	if not lightTable.initComplete then  -- late init
		-- do the table to flattable conversion, if it doesnt exist yet
		if not lightTable.lightParamTable then -- perform correct init
			local lightparams = {}
			for i = 1, lightParamTableSize do lightparams[i] = 0 end 
			for paramname, tablepos in pairs(lightParamKeyOrder) do 
				lightparams[tablepos] = lightTable.lightConfig[paramname] or lightparams[tablepos]
			end
			lightparams[lightParamKeyOrder.radius] = deferredLightGL4Config.globalRadiusMult * lightparams[lightParamKeyOrder.radius]
			lightparams[lightParamKeyOrder.a] = deferredLightGL4Config.globalLightMult * lightparams[lightParamKeyOrder.a]
			lightparams[lightParamKeyOrder.lifetime] = math.floor(deferredLightGL4Config.globalLifeMult * lightparams[lightParamKeyOrder.lifetime] )
			--lightparams[lightParamKeyOrder.sustain] = math.floor(deferredLightGL4Config.globalLifeMult * lightparams[lightParamKeyOrder.sustain] ) -- not needed yet
			lightTable.lightParamTable = lightparams
		end

		if unitID then 
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and not unitDefPeiceMapCache[unitDefID] then 
				unitDefPeiceMapCache[unitDefID] = Spring.GetUnitPieceMap(unitID)
			end
			local pieceMap = unitDefPeiceMapCache[unitDefID]
			if pieceMap[lightTable.pieceName] then -- if its not a real piece, it will default to the model worldpos!
				lightTable.pieceIndex = pieceMap[lightTable.pieceName] 
				lightTable.lightParamTable[pieceIndexPos] = lightTable.pieceIndex
			end
				--Spring.Echo(lightname, lightParams.pieceName, pieceMap[lightParams.pieceName])
		end

		lightTable.initComplete = true
	end
end


--------------------------------------------------------------------------------

local function calcLightExpiry(targetVBO, lightParamTable, instanceID)
	if lightParamTable[18] <= 0 then -- LifeTime less than 0 means never expires
		return nil 
	end
	local deathtime = math_ceil(lightParamTable[17] + lightParamTable[18])
	if lightRemoveQueue[deathtime] == nil then
		lightRemoveQueue[deathtime] = {}
	end
	lightRemoveQueue[deathtime][instanceID] = targetVBO
	return deathtime
end

---AddLight
---Note that instanceID can be nil if an auto-generated one is OK.
---If the light is not attached to a unit, and its lifetime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing light, 
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex number if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param targetVBO table specify which one you want it to
---@param lightparams table a valid table of light parameters
---@param noUpload bool true if it shouldnt be uploaded to gpu yet
---@return instanceID for future reuse
local function AddLight(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
	if instanceID == nil then 
		autoLightInstanceID = autoLightInstanceID + 1 
		instanceID = autoLightInstanceID
	end
	lightparams[spawnFramePos] = gameFrame -- this might be problematic, as we will be modifying a table 
	lightparams[pieceIndexPos] = pieceIndex or 0
	instanceID = pushElementInstance(targetVBO, lightparams, instanceID, true, noUpload, unitID)
	if lightparams[18] > 0 then 
		calcLightExpiry(targetVBO, lightparams, instanceID) -- This will add lights that have >0 lifetime to the removal queue
	end
	return instanceID
end

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
	instanceIndex = (instanceIndex - 1 ) * lightVBO.instanceStep
	local instData = lightVBO.instanceData
	if posx then 
		instData[instanceIndex + 1] = posx 
		instData[instanceIndex + 2] = posy 
		instData[instanceIndex + 3] = posz 
	end
	if radius then instData[instanceIndex + 4] = radius end
	
	if p2x then 
		instData[instanceIndex + 5] = p2x 
		instData[instanceIndex + 6] = p2y 
		instData[instanceIndex + 7] = p2z 
	end
	if theta then instData[instanceIndex + 8] = theta end
	lightVBO.dirty = true
	return instanceIndex 
end

-- multiple lights per unitdef/piece are possible, as the lights are keyed by lightname

local function AddStaticLightsForUnit(unitID, unitDefID, noUpload)
	if unitDefLights[unitDefID] then
		local unitDefLight = unitDefLights[unitDefID]
		if unitDefLight.initComplete ~= true then  -- late init
			for lightname, lightParams in pairs(unitDefLight) do
				InitializeLight(lightParams, unitID)
			end
			unitDefLight.initComplete = true
		end
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				--Spring.Debug.TraceFullEcho(nil,nil,nil,"AddStaticLightsForUnit")
				--Spring.Debug.TableEcho(lightParams)
				if lightParams.lightType == 'point' then
					AddPointLight( tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable)
				elseif lightParams.lightType == 'cone' then 
					AddConeLight(tostring(unitID) ..  lightname, unitID, nil, nil, lightParams.lightParamTable) 
				elseif lightParams.lightType == 'beam' then 
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
				if lightParams.lightType == 'point' then
					popElementInstance(unitPointLightVBO, tostring(unitID) ..  lightname) 
				elseif lightParams.lightType == 'cone' then 
					popElementInstance(unitConeLightVBO, tostring(unitID) ..  lightname)
				elseif lightParams.lightType == 'beam' then 
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
local function RemoveLight(lightshape, instanceID, unitID, noUpload)
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

local function RemoveProjectileLight(lightshape, instanceID, unitID, noUpload)
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

local function InterpolateBeam(x, y, z, dx, dy, dz)
	local finalDx, finalDy, finalDz = 0, 0, 0
	for i = 1, 10 do
		local h = spGetGroundHeight(x + dx + finalDx, z + dz + finalDz)
		local mult
		dx, dy, dz = dx*0.5, dy*0.5, dz*0.5
		if h < y + dy + finalDy then
			finalDx, finalDy, finalDz = finalDx + dx, finalDy + dy, finalDz + dz
		end
	end
	return finalDx, finalDy, finalDz
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
	local success, result =	pcall(VFS.Include, 'luaui/configs/DeferredLightsGL4config.lua')
	--Spring.Echo("Loading GL4 light config", success, result)
	if success then
		--Spring.Echo("Loaded GL4 light config")
		unitDefLights = result.unitDefLights
		unitEventLights = result.unitEventLights
		--projectileDefLights = result.projectileDefLights

	else
		Spring.Echo("Failed to load GL4 Unit light config", success, result)
	end
	
	local success2, result2 =	pcall(VFS.Include, 'luaui/configs/DeferredLightsGL4WeaponsConfig.lua')
	--Spring.Echo("Loading GL4 weapon light config", success2, result2)
	if success2 then
		gibLight = result2.gibLight
		InitializeLight(gibLight)		
		
		muzzleFlashLights = result2.muzzleFlashLights
		for weaponID, lightTable in pairs(muzzleFlashLights) do 
			InitializeLight(lightTable)
		end
		
		explosionLights = result2.explosionLights
		for weaponID, lightTable in pairs(explosionLights) do 
			InitializeLight(lightTable)
		end
		
		projectileDefLights = result2.projectileDefLights
		for weaponID, lightTable in pairs(projectileDefLights) do 
			InitializeLight(lightTable)
		end
	else
		Spring.Echo("Failed to load GL4 weapon light config", success2, result2)
	end
	--deferredLightGL4Config = nil -- clean up our global after load is done
	return success and success2
end

local mapinfo = nil
local nightFactor = 1 --0.33
local unitNightFactor = 1 -- applied above nightFactor default 1.2
local adjustfornight = {'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor','groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor' }
 
local function GadgetWeaponExplosion(px, py, pz, weaponID, ownerID)
	if explosionLights[weaponID] then
		local lightParamTable = explosionLights[weaponID].lightParamTable
		if explosionLights[weaponID].alwaysVisible or spIsSphereInView(px,py,pz, lightParamTable[4]) then
			local groundHeight = spGetGroundHeight(px,pz) or 1
			py = math_max(groundHeight + (explosionLights[weaponID].yOffset or 0), py)
			lightParamTable[1] = px
			lightParamTable[2] = py
			lightParamTable[3] = pz
			--Spring.Echo("GadgetWeaponExplosion added:",  explosionLights[weaponID].lightClassName, px, py, pz)
			AddLight(nil, nil, nil, pointLightVBO, lightParamTable) --(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
		end
	end
end

local function GadgetWeaponBarrelfire(px, py, pz, weaponID, ownerID)
	if muzzleFlashLights[weaponID] then 
		local lightParamTable = muzzleFlashLights[weaponID].lightParamTable
		if muzzleFlashLights[weaponID].alwaysVisible or spIsSphereInView(px,py,pz, lightParamTable[4]) then
			local groundHeight = spGetGroundHeight(px,pz) or 1
			lightParamTable[1] = px
			lightParamTable[2] = py
			lightParamTable[3] = pz
			--Spring.Echo("GadgetWeaponBarrelfire added:",  muzzleFlashLights[weaponID].lightClassName, px, py, pz)
			AddLight(nil, nil, nil, pointLightVBO, lightParamTable) --(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
		end
	end
end

local function UnitScriptLight(unitID, unitDefID, lightIndex, param)
	Spring.Echo("Widgetside UnitScriptLight", unitID, unitDefID, lightIndex, param)
	if unitEventLights.UnitScriptLights[unitDefID] and unitEventLights.UnitScriptLights[unitDefID][lightIndex] then 
		local lightTable = unitEventLights.UnitScriptLights[unitDefID][lightIndex]
		if lightTable.initComplete == nil then InitializeLight(lightTable) end 
		local instanceID = tostring(unitID) .. "UnitScriptLight" .. tostring(lightIndex) .. "_" .. tostring(param)
		AddLight(instanceID, unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightTable.lightParamTable)
	end
end
 
function widget:Initialize()

	Spring.Debug.TraceEcho("Initialize DLGL4")
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Deferred Rendering (gfx_deferred_rendering.lua) requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	if not LoadLightConfig() then
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
	--for i=1, 1 do AddRandomLight(	math.random()) end   
	
	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	
	WG['lightsgl4'] = {}
	WG['lightsgl4'].AddPointLight = AddPointLight
	WG['lightsgl4'].AddBeamLight  = AddBeamLight
	WG['lightsgl4'].AddConeLight  = AddConeLight
	WG['lightsgl4'].AddLight  = AddLight
	WG['lightsgl4'].RemoveLight  = RemoveLight
	widgetHandler:RegisterGlobal('AddPointLight', WG['lightsgl4'].AddPointLight)
	widgetHandler:RegisterGlobal('AddBeamLight', WG['lightsgl4'].AddBeamLight)
	widgetHandler:RegisterGlobal('AddConeLight', WG['lightsgl4'].AddConeLight)
	widgetHandler:RegisterGlobal('AddLight', WG['lightsgl4'].AddLight)
	widgetHandler:RegisterGlobal('RemoveLight', WG['lightsgl4'].RemoveLight)
	
	widgetHandler:RegisterGlobal('UnitScriptLight', UnitScriptLight)
	
	widgetHandler:RegisterGlobal('GadgetWeaponExplosion', GadgetWeaponExplosion)
	widgetHandler:RegisterGlobal('GadgetWeaponBarrelfire', GadgetWeaponBarrelfire)
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
	widgetHandler:DeregisterGlobal('AddLight')
	
	widgetHandler:DeregisterGlobal('GadgetWeaponExplosion')
	widgetHandler:DeregisterGlobal('GadgetWeaponBarrelfire')
	
	widgetHandler:DeregisterGlobal('UnitScriptLight')
end

local windX = 0
local windZ = 0

function widget:GameFrame(n)
	if n % 100 == 0 then 
		--AddRandomDecayingPointLight()
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
	if unitEventLights['UnitIdle'] then 
		if unitEventLights['UnitIdle'][unitDefID] then 
			local unitEventLight = unitEventLights['UnitIdle'][unitDefID]
			--InitializeLight(lightTable, unitID)
			for lightname, lightTable in pairs(unitEventLight) do
				if lightname ~= 'initComplete' then
					if not lightTable.initComplete then InitializeLight(lightTable, unitID) end
					AddLight(tostring(unitID) ..  lightname, unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightTable.lightParamTable)
				end
			end
		end
	end
end

function widget:UnitFinished(unitID, unitDefID, teamID)
	if unitEventLights['UnitFinished'] then 
		local lightTable = unitEventLights['UnitFinished']['default']
		if unitEventLights['UnitFinished'][unitDefID] then 
			lightTable = unitEventLights['UnitFinished'][unitDefID]
		end
		if not lightTable.initComplete then InitializeLight(lightTable, unitID) end
		--Spring.Echo("Unitfinished",  unitEventLights['UnitFinished'], lightTable.lightType )
		lightTable.lightParamTable[2] = spGetUnitHeight(unitID) + 64
		AddLight(tostring(unitID) ..  "UnitFinished", unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightTable.lightParamTable)
	end
end

function widget:UnitCreated(unitID, unitDefID, teamID)
	if unitEventLights['UnitCreated'] then 
		local lightTable = unitEventLights['UnitCreated']['default']
		if unitEventLights['UnitCreated'][unitDefID] then 
			lightTable = unitEventLights['UnitCreated'][unitDefID]
		end
		if not lightTable.initComplete then InitializeLight(lightTable, unitID) end
		--Spring.Echo("Unitfinished",  unitEventLights['UnitFinished'], lightTable.lightType )
		lightTable.lightParamTable[2] = spGetUnitHeight(unitID) + 64
		AddLight(tostring(unitID) ..  "UnitCreated", unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightTable.lightParamTable)
	end
end


local updateCount = 0
local trackedProjectiles = {}
local trackedProjectileTypes = {}
local lastgf = -2

local testprojlighttable = {0,16,0,200, --pos + radius
								0.25, 0.25,0.125, 5, -- color2, colortime
								1.0,1.0,0.5,0.5, -- RGBA
								0.1,1,0.25,1, -- modelfactor_specular_scattering_lensflare
								0,0,200,0, -- spawnframe, lifetime (frames), sustain (frames), animtype
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								}


-- Beam type projectiles are indeed an oddball, as they live for exactly 3 frames, no?

local function PrintProjectileInfo(projectileID)
	local px, py, pz = spGetProjectilePosition(projectileID)
	local weapon, piece = Spring.GetProjectileType(projectileID)
	local weaponDefID = weapon and Spring.GetProjectileDefID ( projectileID ) 
	Spring.Debug.TraceFullEcho()
end

local function updateProjectileLights(newgameframe)
	local debugproj = false
	local nowprojectiles = Spring.GetVisibleProjectiles()
	gameFrame = Spring.GetGameFrame()
	local newgameframe = true
	if gameFrame == lastgf then newgameframe = false end 
	--Spring.Echo(gameFrame, lastgf, newgameframe)
	lastgf = gameFrame
	-- turn off uploading vbo
	-- BUG: having a lifetime associated with each projectile kind of bugs out updates
	local numadded = 0
	local noUpload = true
	for i= 1, #nowprojectiles do
		local projectileID = nowprojectiles[i]
		local px, py, pz = spGetProjectilePosition(projectileID)
		if px then -- we are somehow getting projectiles with no position?	
			local lightType = 'point' -- default
			if trackedProjectiles[projectileID] then 
				if newgameframe then
					--update proj pos
					lightType = trackedProjectileTypes[projectileID] 
					if lightType == 'point' then 
						local instanceIndex = updateLightPosition(projectilePointLightVBO, projectileID, px,py,pz)
					elseif lightType == 'cone' then 
						local dx,dy,dz = spGetProjectileVelocity(projectileID)
						updateLightPosition(projectileConeLightVBO, projectileID, px,py,pz, nil, dx,dy,dz)
					end -- NOTE: WE DONT UPDATE BEAM POS!
					if debugproj then Spring.Echo("Updated", instanceIndex, projectileID, px, py, pz) end
				end
			else
				-- add projectile		
				local weapon, piece = spGetProjectileType(projectileID)
				if piece then 
					local explosionflags = spGetPieceProjectileParams(projectileID)
					if explosionflags and explosionflags%32 > 15 then 
						local gib = gibLight.lightParamTable
						gib[1] = px
						gib[2] = py
						gib[3] = pz
						AddLight(projectileID, nil, nil, projectilePointLightVBO, gib, noUpload)
						--Spring.Echo("added gib")
						--Spring.Debug.TableEcho(gib)
					end
				else
					local weaponDefID = spGetProjectileDefID ( projectileID ) 
					if projectileDefLights[weaponDefID] then 
						local lightParamTable = projectileDefLights[weaponDefID].lightParamTable
						lightType = projectileDefLights[weaponDefID].lightType
						lightParamTable[1] = px
						lightParamTable[2] = py
						lightParamTable[3] = pz
						if debugproj then Spring.Echo(lightType, projectileDefLights[weaponDefID].lightClassName) end
						
						if lightType == 'beam' then 
							local dx,dy,dz = spGetProjectileVelocity(projectileID)
							--dx, dy, dz = InterpolateBeam(px,py,pz, dx, dy,dz)
							lightParamTable[5] = px + dx
							lightParamTable[6] = py + dy
							lightParamTable[7] = pz + dz
						elseif lightType == 'cone' then 
						
							local dx,dy,dz = spGetProjectileVelocity(projectileID)						lightParamTable[5] = dx
							lightParamTable[6] = dy
							lightParamTable[7] = dz
						end 
						if debugproj then Spring.Echo(lightType, px,py,pz, dx, dy,dz) end
						
						AddLight(projectileID, nil, nil, projectileLightVBOMap[lightType], lightParamTable,noUpload)
						--AddLight(projectileID, nil, nil, projectilePointLightVBO, lightParamTable)
					else 
						Spring.Echo("No projectile light defined for", projectileID, weaponDefID, px, pz)
						testprojlighttable[1] = px
						testprojlighttable[2] = py
						testprojlighttable[3] = pz
						AddPointLight(projectileID, nil, nil, projectilePointLightVBO, testprojlighttable)
					end
				end
				numadded = numadded + 1
				if debugproj then Spring.Echo("Adding projlight", projectileID, Spring.GetProjectileName(projectileID)) end
				--trackedProjectiles[]
				trackedProjectileTypes[projectileID] = lightType
			end
			trackedProjectiles[projectileID] = gameFrame
		end
	end
	-- remove theones that werent updated 
	local numremoved = 0
	for projectileID, gf in pairs(trackedProjectiles) do
		if gf < gameFrame then
			-- SO says we can modify or remove elements while iterating, we just cant add
			-- a possible hack to keep projectiles visible, is trying to keep getting their pos
			local px, py, pz = spGetProjectilePosition(projectileID)
			if px then
				if newgameframe then 
					updateLightPosition(projectilePointLightVBO, projectileID, px,py,pz)
				end
			else
				numremoved = numremoved + 1 
				trackedProjectiles[projectileID] = nil
				local lightType = trackedProjectileTypes[projectileID] 
				--RemoveLight('point', projectileID, nil)
				if projectileLightVBOMap[lightType].instanceIDtoIndex[projectileID] then -- god the indirections here ... 
					local success = popElementInstance(projectileLightVBOMap[lightType], projectileID, noUpload) 
					if success == nil then PrintProjectileInfo(projectileID) end 
				end
				trackedProjectileTypes[projectileID] = nil
			end
		end
	end
	-- upload all changed elements in one go
	for vboname, targetVBO in pairs(projectileLightVBOMap) do 
		if targetVBO.dirty then 
			uploadAllElements(targetVBO)
		end
	end
	if debugproj then 
		--Spring.Echo("#points", projectilePointLightVBO.usedElements, '#projs', #nowprojectiles ) 
	end
end

local configCache = {lastUpdate = Spring.GetTimer()}
local function checkConfigUpdates()
	if Spring.DiffTimers(Spring.GetTimer(), configCache.lastUpdate) > 0.5 then 
		local newconfa = VFS.LoadFile('luaui/configs/DeferredLightsGL4config.lua')
		local newconfb = VFS.LoadFile('luaui/configs/DeferredLightsGL4WeaponsConfig.lua')
		if newconfa ~= configCache.confa or newconfb ~= configCache.confb then 
			LoadLightConfig()
			configCache.confa = newconfa
			configCache.confb = newconfb
		end
		configCache.lastUpdate = Spring.GetTimer()
	end
end

function widget:Update()
	if autoupdate then checkConfigUpdates() end
	updateProjectileLights()
end

------------------------------- Drawing all the lights ---------------------------------


local tf = Spring.GetTimerMicros()
function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	if chobbyInterface then return end
	local t0 = Spring.GetTimerMicros()
	--if true then return end
	if autoupdate then deferredLightShader = checkShaderUpdates(vsSrcPath, fsSrcPath, nil, "Deferred Lights GL4") or deferredLightShader end
	
	if pointLightVBO.usedElements > 0 or 
		unitPointLightVBO.usedElements > 0 or 
		beamLightVBO.usedElements > 0 or 
		unitConeLightVBO.usedElements > 0 or
		coneLightVBO.usedElements > 0 then 

		local alt, ctrl, meta, shft = Spring.GetModKeyState()

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
		--glTexture(4, "$map_gbuffer_spectex")
		--glTexture(5, "$model_gbuffer_spectex")
		glTexture(6, "$map_gbuffer_difftex")
		glTexture(7, "$model_gbuffer_difftex")
		glTexture(8, noisetex3dcube)
		
		deferredLightShader:Activate()
		deferredLightShader:SetUniformFloat("nightFactor", nightFactor)
		deferredLightShader:SetUniformFloat("windX", windX)
		deferredLightShader:SetUniformFloat("windZ", windZ)
		--Spring.Echo(windX, windZ)
		

		-- Fixed worldpos lights, cursors, projectiles, world lights
		deferredLightShader:SetUniformFloat("attachedtounitID", 0) -- worldpos stuff
		deferredLightShader:SetUniformFloat("pointbeamcone", 0)
		
		if not spIsGUIHidden() then
			cursorPointLightVBO:draw()
		end
		
		pointLightVBO:draw()
		projectilePointLightVBO:draw()
		
		
		deferredLightShader:SetUniformFloat("pointbeamcone", 1)
		beamLightVBO:draw()
		projectileBeamLightVBO:draw()

		deferredLightShader:SetUniformFloat("pointbeamcone", 2)
		coneLightVBO:draw()
		projectileConeLightVBO:draw()

		-- Unit Attached Lights
		deferredLightShader:SetUniformFloat("attachedtounitID", 1)		
		
		deferredLightShader:SetUniformFloat("pointbeamcone", 0)
		unitPointLightVBO:draw()
		
		deferredLightShader:SetUniformFloat("pointbeamcone", 1)
		unitBeamLightVBO:draw()

		deferredLightShader:SetUniformFloat("pointbeamcone", 2)
		unitConeLightVBO:draw()
			
		deferredLightShader:Deactivate()
		
		for i = 0, 8 do glTexture(i, false) end 
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		gl.DepthMask(true)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	local t1 = 	Spring.GetTimerMicros()
	if (Spring.GetDrawFrame() % 50 == 0 ) then 
		local dt =  Spring.DiffTimers(t1,t0)
		Spring.Echo("Deltat is ", dt,'us, so total load should be', dt * Spring.GetFPS() / 10 ,'%') 
		Spring.Echo("epoch is ", Spring.DiffTimers(t1,tf)) 
	end 
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end
--------------------------- Ingame Configurables -------------------

function widget:GetConfigData(data) -- Called by RemoveWidget
	--Spring.Debug.TraceEcho("GetConfigData DLGL4")
	local savedTable = {
		globalLightMult = deferredLightGL4Config.globalLightMult,
		globalRadiusMult = deferredLightGL4Config.globalRadiusMult,
		globalLifeMult = deferredLightGL4Config.globalLifeMult,
		resetted = 1.65,
	}
	return savedTable
end

function widget:SetConfigData(data) -- Called on load (and config change), just before Initialize!
	--Spring.Debug.TraceEcho("SetConfigData DLGL4")
	if data.globalLifeMult ~= nil and data.resetted ~= nil and data.resetted == 1.65 then
		if data.globalLightMult ~= nil then
			deferredLightGL4Config.globalLightMult =  data.globalLightMult
		end
		if data.globalRadiusMult ~= nil then
			deferredLightGL4Config.globalRadiusMult =  data.globalRadiusMult
		end
		if data.globalLifeMult ~= nil then
			deferredLightGL4Config.globalLifeMult =  data.globalLifeMult
		end
	end
	--Spring.Debug.TableEcho(deferredLightGL4Config)
	--deferredLightGL4Config = data
end
