--------------------------------------------------------------------------------

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Deferred rendering GL4",
		version = 3,
		desc = "Collects and renders cone, point and beam lights",
		author = "Beherith",
		date = "2022.06.10",
		license = "Lua code is GPL V2, GLSL is (c) Beherith (mysterme@gmail.com)",
		layer = -99999990,
		enabled = true,
		depends = {'gl4'},
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
	-- cursorlight
		-- ally and own, click sensitive!
	-- XX light types should know their vbo?
		-- this one is much harder than expected
	-- XX initialize config dicts -- DONE
	-- XX rework dicts -- DONE
	-- XX unitdefidpiecemapcache -- DONE
	-- Draw pre-water?
	-- optimizations:
		-- XX only upload dirty VBOs
		-- Smaller, single channel noise texture
	-- XX Beam lights double length for projectiles!
	-- Some falloff issues result in a bit of overdraw
	-- allow for customizable attenuation
	-- XX list type configs for events
	-- Handle playerchanged -- hasnt crashed yet :P
		-- clear every goddamned unit light and buffer
	-- FIX SSAO widget for day-night cycle changes - done!

end


local cursorLights
local cursorLightHeight = 35
local cursorLightParams = {
	lightType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	lightConfig = {
		posx = 0, posy = 0, posz = 0, radius = 350,	-- (radius is set elsewhere)
		r = 1, g = 1, b = 1, a = 0.1,	-- (alpha is set elsewhere)
		color2r = 0, color2g = 0, color2b = 0, colortime = 0, -- point lights only, colortime in seconds for unit-attache
		modelfactor = 0.3, specular = 0.7, scattering = 0, lensflare = 0,
		lifetime = 0, sustain = 0, selfshadowing = 0
	}
}

local cursorLightAlpha = 0.5
local cursorLightRadius = 0.85
local cursorLightSelfShadowing = false

-- This is for the player himself!
local showPlayerCursorLight = false

local playerCursorLightRadius = 1
local playerCursorLightBrightness = 1
local playerCursorLightParams = {
	lightType = 'point', -- or cone or beam
	pieceName = nil, -- optional
	lightConfig = {
		posx = 0, posy = 0, posz = 0, radius = 250,
		r = 1, g = 0.8, b = 0.6, a = 0.1,	-- (alpha is set elsewhere)
		color2r = 0, color2g = 0, color2b = 0, colortime = 0, -- point lights only, colortime in seconds for unit-attache
		modelfactor = 0.3, specular = 0.4, scattering = 0, lensflare = 0,
		lifetime = 0, sustain = 0, selfshadowing = 8
	}
}


local teamColors = {}
local function loadTeamColors()
	local playerList = Spring.GetPlayerList()
	for _, playerID in ipairs(playerList) do
		local teamID = select(4, Spring.GetPlayerInfo(playerID, false))
		local r, g, b = Spring.GetTeamColor(teamID)
		teamColors[playerID] = {r, g, b}
	end
end
loadTeamColors()

----------------------------- Localize for optmization ------------------------------------

local glBlending = gl.Blending
local glTexture = gl.Texture


-- Strong:
local spGetProjectilePosition = Spring.GetProjectilePosition
local spGetProjectileVelocity = Spring.GetProjectileVelocity
local spGetProjectileType = Spring.GetProjectileType
local spGetPieceProjectileParams = Spring.GetPieceProjectileParams
local spGetProjectileDefID = Spring.GetProjectileDefID
local spGetGroundHeight = Spring.GetGroundHeight
local spIsSphereInView  = Spring.IsSphereInView
local spGetUnitPosition  = Spring.GetUnitPosition
local spGetUnitIsDead = Spring.GetUnitIsDead
local spValidUnitID = Spring.ValidUnitID


-- Weak:
local spIsGUIHidden = Spring.IsGUIHidden

local math_max = math.max
local math_ceil = math.ceil

local unitName = {}
for udid, ud in pairs(UnitDefs) do
	unitName[udid] = ud.name
end

---------------------------------------------------------------------------------
--Light falloff functions: http://gamedev.stackexchange.com/questions/56897/glsl-light-attenuation-color-and-intensity-formula

------------------------------ Light and Shader configurations ------------------

local unitDefLights
local featureDefLights
local unitEventLights -- Table of lights per unitDefID
local muzzleFlashLights  -- one light per weaponDefID
local projectileDefLights  -- one light per weaponDefID
local explosionLights  -- one light per weaponDefID
local gibLight  -- one light for all pieceprojectiles

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local shaderConfig = {
	MIERAYLEIGHRATIO = 0.1, -- The ratio of Rayleigh scattering to Mie scattering
	RAYMARCHSTEPS = 4, -- must be at least one, this one one of the main quality parameters
	USE3DNOISE = 1, -- dont touch this
	SURFACECOLORMODULATION = 0.05, -- This specifies how much the lit surfaces color affects direct light blending, 0 is does not effect it, 1.0 is full effect
	BLEEDFACTOR = 0.15, -- How much oversaturated color channels will bleed into other color channels.
	VOIDWATER = gl.GetMapRendering("voidWater") and 1 or 0,
	SCREENSPACESHADOWS = 1, -- set to nil to disable completely
	USEQUATERNIONS = Engine.FeatureSupport.transformsInGL4 and "1" or "0",
}

local radiusMultiplier = 1.0
local intensityMultiplier = 1.0
local screenSpaceShadows = 2

local isPotatoGpu = false
local gpuMem = (Platform.gpuMemorySize and Platform.gpuMemorySize or 1000) / 1000
if Platform ~= nil and Platform.gpuVendor == 'Intel' then
	isPotatoGpu = true
end
if gpuMem and gpuMem > 0 and gpuMem < 1800 then
	isPotatoGpu = true
end
if isPotatoGpu then
	screenSpaceShadows = 0
elseif gpuMem and gpuMem > 0 and gpuMem < 5000 then
	screenSpaceShadows = 1
end

-- the 3d noise texture used for this shader
local noisetex3dcube =  "LuaUI/images/noisetextures/noise64_cube_3.dds"
local blueNoise2D =  "LuaUI/images/noisetextures/blue_noise_64.tga"

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
	lifetime = 0, sustain = 1, 	selfshadowing = 0
}
]]--

------------------------------ Debug switches ------------------------------
local autoupdate = false
local debugproj = false
local addrandomlights = false
local skipdraw = false
------------------------------ Data structures and management variables ------------

-- These will contain 'global' type lights, ones that dont get updated every frame
local pointLightVBO = {} -- an instanceVBOTable
local coneLightVBO = {} -- an instanceVBOTable
local beamLightVBO = {} -- an instanceVBOTable
local lightVBOMap -- a table of the above 3, keyed by light type, {point = pointLightVBO, ...}

-- These contain the unitdef defined, cob-instanced and unit event based lights
local unitPointLightVBO = {} -- an instanceVBOTable, with unit-attachment
local unitConeLightVBO = {} -- an instanceVBOTable
local unitBeamLightVBO = {} -- an instanceVBOTable
local unitLightVBOMap -- a table of the above 3, keyed by light type,  {point = unitPointLightVBO, ...}

local unitAttachedLights = {} -- this is a table mapping unitID's to all their attached instanceIDs and vbos
	--{unitID = { instanceID = targetVBO, ... }}
local visibleUnits = {} -- this is a proxy for the widget callins, used to ensure we dont add unitscriptlights to units that are not visible

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

local lightParamKeyOrder = { -- This table is a 'quick-ish' way of building the lua array from human-readable light parameters
	posx = 1, posy = 2, posz = 3, radius = 4,
	r = 9, g = 10, b = 11, a = 12,
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam lights only, specifies the endpoint of the beam
	modelfactor = 13, specular = 14, scattering = 15, lensflare = 16,
	lifetime = 18, sustain = 19, selfshadowing = 20, -- selfshadowing unused

	-- NOTE THERE ARE 4 MORE UNUSED SLOTS HERE RESERVED FOR FUTURE USE! -- Nope, beherith ate these like a greedy boy
	color2r = 21, color2g = 22, color2b = 23, colortime = 24, -- point lights only, colortime in seconds for unit-attached
}

local autoLightInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones


local gameFrame = 0

local trackedProjectiles = {} -- used for finding out which projectiles can be culled {projectileID = updateFrame, ...}
local trackedProjectileTypes = {} -- we have to track the types [point, light, cone] of projectile lights for efficient updates
local lastGameFrame = -2

local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local uploadAllElements = InstanceVBOTable.uploadAllElements
local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local deferredLightShader = nil

local shaderSourceCache = {
	shaderName = 'Deferred Lights GL4',
	vssrcpath = "LuaUI/Shaders/deferred_lights_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/deferred_lights_gl4.frag.glsl",
	shaderConfig = shaderConfig,
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
		blueNoise = 9,
		--heightmapTex = 9,
		--mapnormalsTex = 10,
		screenSpaceShadows = 16,
		},
	uniformFloat = {
		pointbeamcone = 0,
		--fadeDistance = 3000,
		attachedtounitID = 0,
		nightFactor = 1.0,
		windX = 0.0,
		windZ = 0.0,
		radiusMultiplier = 1.0,
		intensityMultiplier = 1.0,
	  },
}
local testprojlighttable = {0,16,0,200, --pos + radius
								0.25, 0.25,0.125, 5, -- color2, colortime
								1.0,1.0,0.5,0.5, -- RGBA
								0.1,1,0.25,1, -- modelfactor_specular_scattering_lensflare
								0,0,200,0, -- spawnframe, lifetime (frames), sustain (frames), selfshadowing
								0,0,0,0, -- color2
								0, -- pieceIndex
								0,0,0,0 -- instData always 0!
								}
local numAddLights = 0 -- how many times AddLight was called

local spec = Spring.GetSpectatingState()

---------------------- INITIALIZATION FUNCTIONS ----------------------------------



local function goodbye(reason)
	Spring.Echo('Deferred Lights GL4 exiting:', reason)
	widgetHandler:RemoveWidget()
end

local function createLightInstanceVBO(vboLayout, vertexVBO, numVertices, indexVBO, VBOname, unitIDattribID)
	local targetLightVBO = InstanceVBOTable.makeInstanceVBOTable( vboLayout, 16, VBOname, unitIDattribID)
	if vertexVBO == nil or targetLightVBO == nil then goodbye("Failed to make "..VBOname) end
	targetLightVBO.vertexVBO = vertexVBO
	targetLightVBO.numVertices = numVertices
	targetLightVBO.indexVBO = indexVBO
	targetLightVBO.VAO = InstanceVBOTable.makeVAOandAttach(targetLightVBO.vertexVBO, targetLightVBO.instanceVBO, targetLightVBO.indexVBO)
	return targetLightVBO
end

local function initGL4()
	deferredLightShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0)
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
				-- for spot, this is direction.xyz for unitattached, or world anim params
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

	local pointVBO, _, pointIndexVBO, _ = InstanceVBOTable.makeSphereVBO(8, 4, 1)
	pointLightVBO 			= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Point Light VBO")
	unitPointLightVBO 		= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Unit Point Light VBO", 10)
	cursorPointLightVBO 	= createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Cursor Point Light VBO")
	projectilePointLightVBO = createLightInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Projectile Point Light VBO")

	local coneVBO, numConeVertices = InstanceVBOTable.makeConeVBO(12, 1, 1)
	coneLightVBO 			= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Cone Light VBO")
	unitConeLightVBO 		= createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Unit Cone Light VBO", 10)
	projectileConeLightVBO  = createLightInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Projectile Cone Light VBO")

	local beamVBO, numBeamVertices = InstanceVBOTable.makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamLightVBO 			= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Beam Light VBO")
	unitBeamLightVBO 		= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Unit Beam Light VBO", 10)
	projectileBeamLightVBO 	= createLightInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Projectile Beam Light VBO")

	projectileLightVBOMap = { point = projectilePointLightVBO,  beam = projectileBeamLightVBO,  cone = projectileConeLightVBO, }
	unitLightVBOMap = { point = unitPointLightVBO,  beam = unitBeamLightVBO,  cone = unitConeLightVBO, }
	lightVBOMap = { point = pointLightVBO,  beam = beamLightVBO,  cone = coneLightVBO, }
	return pointLightVBO and unitPointLightVBO and coneLightVBO and beamLightVBO
end


---InitializeLight(lightTable, unitID)
---Takes a light definition table, and tries to check wether its already been initialized, if not, it inits it in-place
---@param lightTable table
---@param unitID number
local function InitializeLight(lightTable, unitID)
	if not lightTable.initComplete then  -- late init
		-- do the table to flattable conversion, if it doesnt exist yet
		if not lightTable.lightParamTable then -- perform correct init
			local lightparams = {}
			for i = 1, lightParamTableSize do lightparams[i] = 0 end
			if lightTable.lightConfig == nil then Spring.Debug.TraceFullEcho() end
			for paramname, tablepos in pairs(lightParamKeyOrder) do
				lightparams[tablepos] = lightTable.lightConfig[paramname] or lightparams[tablepos]
			end
			lightparams[lightParamKeyOrder.radius] = lightparams[lightParamKeyOrder.radius]
			lightparams[lightParamKeyOrder.a] =  lightparams[lightParamKeyOrder.a]
			lightparams[lightParamKeyOrder.lifetime] = math.floor( lightparams[lightParamKeyOrder.lifetime] )
			lightTable.lightParamTable = lightparams
			lightTable.lightConfig = nil -- never used again after initialization
		end

		if unitID then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and not unitDefPeiceMapCache[unitDefID] then
				unitDefPeiceMapCache[unitDefID] = Spring.GetUnitPieceMap(unitID)
			end
			local pieceMap = unitDefPeiceMapCache[unitDefID]

			if pieceMap == nil or unitDefID == nil then
				return false
				--Spring.Debug.TraceFullEcho(nil,nil,nil,"InitializeLight, pieceMap == nil")
			end

			if pieceMap[lightTable.pieceName] then -- if its not a real piece, it will default to the model worldpos!
				lightTable.pieceIndex = pieceMap[lightTable.pieceName]
				lightTable.lightParamTable[pieceIndexPos] = lightTable.pieceIndex
			end
				--Spring.Echo(lightname, lightParams.pieceName, pieceMap[lightParams.pieceName])
		end

		lightTable.initComplete = true
	end
	return true
end
InitializeLight(cursorLightParams)
InitializeLight(playerCursorLightParams)

--------------------------------------------------------------------------------

---calcLightExpiry(targetVBO, lightParamTable, instanceID)
---Calculates the gameframe that a light might expire at, and if it will, then it places it into the removal queue
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

---AddLight(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
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
	--tracy.ZoneBeginN("pushElementInstance")
	instanceID = pushElementInstance(targetVBO, lightparams, instanceID, true, noUpload, unitID)
	--tracy.ZoneEnd()
	if lightparams[18] > 0 then
		calcLightExpiry(targetVBO, lightparams, instanceID) -- This will add lights that have >0 lifetime to the removal queue
	end
	if unitID then
		if unitAttachedLights[unitID] == nil then
			unitAttachedLights[unitID] = {[instanceID] = targetVBO}
		else
			unitAttachedLights[unitID][instanceID] = targetVBO
		end
	end
	numAddLights = numAddLights + 1
	return instanceID
end

---AddPointLight
---DEPRECTATED Note that instanceID can be nil if an auto-generated one is OK.
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
---@param selfshadowing int what further type of animation will be used (0 is default 1 is for screen space shadow)
---@return instanceID for future reuse
local function AddPointLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, r2,g2,b2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, selfshadowing)

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
		lightparams[20] = selfshadowing or 0
		lightparams[21] = r2 or 0
		lightparams[22] = g2 or 0
		lightparams[23] = b2 or 0
		lightparams[24] = colortime or 0
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
	AddPointLight(nil,nil,nil, nil,
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5,
		250,
		1,0,0,1,
		0,1,0,60,
		1,1,1,1,
		gameFrame, 100, 20, 1)
	--Spring.Echo("AddRandomDecayingPointLight", instanceID)

	AddPointLight(nil,nil,nil,nil,
		Game.mapSizeX * 0.5 + math.random()*2000,
		Spring.GetGroundHeight(Game.mapSizeX * 0.5,Game.mapSizeZ * 0.5) + 50,
		Game.mapSizeZ * 0.5 + 400,
		250,
		1,1,1,1,
		1,0.5,0.2,5,
		1,1,1,1,
		gameFrame, 30, 0.2, 1)
	--Spring.Echo("AddRandomExplosionPointLight", instanceID)

	AddPointLight(nil,nil,nil,nil,
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
---DEPRECTATED Note that instanceID can be nil if an auto-generated one is OK.
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
---@param selfshadowing int what further type of animation will be used
---@return instanceID for future reuse
local function AddBeamLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, sx, sy, sz, r2, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, selfshadowing)

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
		lightparams[20] = selfshadowing or 0
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
---DEPRECATED! Note that instanceID can be nil if an auto-generated one is OK.
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
---@param selfshadowing int what further type of animation will be used
---@return instanceID for future reuse
local function AddConeLight(instanceID, unitID, pieceIndex, targetVBO, px_or_table, py, pz, radius, r,g,b,a, dx,dy,dz,theta, colortime,
	modelfactor, specular, scattering, lensflare, spawnframe, lifetime, sustain, selfshadowing)

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
		lightparams[20] = selfshadowing or 0
		lightparams[21] = 0 -- RESERVED
		lightparams[22] = 0 --RESERVED
		lightparams[23] = 0 --RESERVED
		lightparams[24] = 0 --RESERVED
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

---updateLightPosition(lightVBO, instanceID, posx, posy, posz, radius, p2x, p2y, p2z, theta)
---This function is for internal use only, to update the position of a light.
---Only use if you know the consequences of updating a VBO in-place!
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

local function AddStaticLightsForUnit(unitID, unitDefID, noUpload, reason)
	if unitDefLights[unitDefID] then
		if Spring.GetUnitIsBeingBuilt(unitID) then return end
		local unitDefLight = unitDefLights[unitDefID]
		if unitDefLight.initComplete ~= true then  -- late init
			for lightname, lightParams in pairs(unitDefLight) do
				if not InitializeLight(lightParams, unitID) then return end
			end
			unitDefLight.initComplete = true
		end
		for lightname, lightParams in pairs(unitDefLight) do
			if lightname ~= 'initComplete' then
				local targetVBO = unitLightVBOMap[lightParams.lightType]

				if (not spec) and lightParams.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then return end
				AddLight(tostring(unitID) ..  lightname, unitID, lightParams.pieceIndex, targetVBO, lightParams.lightParamTable, noUpload)
			end
		end
	end
end

---RemoveUnitAttachedLights(unitID, instanceID)
---Removes all or 1 light attached to a unit
---@param unitID the unit to remove lights from
---@param instanceID which light to remove, if nil, then all lights will be removed
---@returns the number of lights that got removed
local function RemoveUnitAttachedLights(unitID, instanceID)
	local numremoved = 0
	if unitAttachedLights[unitID] then
		if instanceID and unitAttachedLights[unitID][instanceID] then
			popElementInstance(unitAttachedLights[unitID][instanceID],instanceID)
			numremoved = numremoved + 1
			unitAttachedLights[unitID][instanceID] = nil
		else
			for instanceID, targetVBO in pairs(unitAttachedLights[unitID]) do
				if targetVBO.instanceIDtoIndex[instanceID] then
					numremoved = numremoved + 1
					popElementInstance(targetVBO,instanceID)
				else
					--Spring.Echo("Light attached to unit no longer is in targetVBO", unitID, instanceID, targetVBO.myName)
				end
			end
			--Spring.Echo("Removed lights from unitID", unitID, numremoved, successes)
			unitAttachedLights[unitID] = nil
		end
	else
		--Spring.Echo("RemoveUnitAttachedLights: No lights attached to", unitID)
	end
	return numremoved
end

---RemoveLight(lightshape, instanceID, unitID)
---Remove a light
---@param lightshape string 'point'|'beam'|'cone'
---@param instanceID any the ID of the light to remove
---@param unitID number make this non-nil to remove it from a unit
---@returns the same instanceID on success, nil if the light was not found
local function RemoveLight(lightshape, instanceID, unitID, noUpload)
	if unitID then
		if unitAttachedLights[unitID] and unitAttachedLights[unitID][instanceID] then
			local targetVBO = unitAttachedLights[unitID][instanceID]
			unitAttachedLights[unitID][instanceID] = nil
			return popElementInstance(targetVBO, instanceID)
		else
			Spring.Echo("RemoveLight tried to remove a non-existing unitlight", lightshape, instanceID, unitID)
		end
	elseif lightshape then
		if lightVBOMap[lightshape].instanceIDtoIndex[instanceID] then
			return popElementInstance(lightVBOMap[lightshape], instanceID)
		else
			if not noUpload then
				if type(instanceID) == "string" and (not string.find(instanceID, "FeatureCreated", nil, true)) then
					Spring.Echo("RemoveLight tried to remove a non-existing light", lightshape, instanceID, unitID)
				end
			end
		end
	else
		Spring.Echo("RemoveLight tried to remove a non-existing light", lightshape, instanceID, unitID)
	end
	return nil
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
		featureDefLights = result.featureDefLights
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
	return success and success2
end

local nightFactor = 1 --0.33
local unitNightFactor = 1 -- applied above nightFactor default 1.2
local adjustfornight = {'unitAmbientColor', 'unitDiffuseColor', 'unitSpecularColor','groundAmbientColor', 'groundDiffuseColor', 'groundSpecularColor' }


local targetable = {}
for wdid, wd in pairs(WeaponDefs) do
	if wd.targetable then
		targetable[wdid] = true
	end
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	if targetable[weaponID] and py-300 > Spring.GetGroundHeight(px, pz) then	-- dont add light to (likely) intercepted explosions (mainly to curb nuke flashes)
		return
	end
	if explosionLights[weaponID] then
		local lightParamTable = explosionLights[weaponID].lightParamTable
		if explosionLights[weaponID].alwaysVisible or spIsSphereInView(px,py,pz, lightParamTable[4]) then
			local groundHeight = spGetGroundHeight(px,pz) or 1
			py = math_max(groundHeight + (explosionLights[weaponID].yOffset or 0), py)
			lightParamTable[1] = px
			lightParamTable[2] = py
			lightParamTable[3] = pz
			AddLight(nil, nil, nil, pointLightVBO, lightParamTable) --(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
		end
	end
end

function widget:Barrelfire(px, py, pz, weaponID, ownerID)
	if muzzleFlashLights[weaponID] then
		local lightParamTable = muzzleFlashLights[weaponID].lightParamTable
		if muzzleFlashLights[weaponID].alwaysVisible or spIsSphereInView(px,py,pz, lightParamTable[4]) then
			lightParamTable[1] = px
			lightParamTable[2] = py
			lightParamTable[3] = pz
			AddLight(nil, nil, nil, pointLightVBO, lightParamTable) --(instanceID, unitID, pieceIndex, targetVBO, lightparams, noUpload)
		end
	end
end

local function UnitScriptLight(unitID, unitDefID, lightIndex, param)
	if spValidUnitID(unitID) and spGetUnitIsDead(unitID) == false and visibleUnits[unitID] and unitEventLights.UnitScriptLights[unitDefID] and unitEventLights.UnitScriptLights[unitDefID][lightIndex] then
		local lightTable = unitEventLights.UnitScriptLights[unitDefID][lightIndex]
		if not lightTable.alwaysVisible then
			local px,py,pz = spGetUnitPosition(unitID)
			if px == nil or spIsSphereInView(px,py,pz, lightTable[4]) == false then return end
		end
		if (not spec) and lightTable.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then return end
		if lightTable.initComplete == nil then InitializeLight(lightTable, unitID) end
		local instanceID = tostring(unitID) .. "_" .. tostring(unitName[unitDefID]) .. "UnitScriptLight" .. tostring(lightIndex) .. "_" .. tostring(param)
		AddLight(instanceID, unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightTable.lightParamTable)
	end
end

local function GetLightVBO(vboName)
	if vboName == 'cursorPointLightVBO' then return cursorPointLightVBO end
	return nil
end

function widget:PlayerChanged(playerID)
	spec = Spring.GetSpectatingState()

	local _, _, isSpec, teamID = Spring.GetPlayerInfo(playerID, false)
	local r, g, b = Spring.GetTeamColor(teamID)
	if isSpec then
		teamColors[playerID] = { 1, 1, 1 }
	elseif r and g and b then
		teamColors[playerID] = { r, g, b }
	end
	if cursorLights and cursorLights[playerID] and cursorPointLightVBO.instanceIDtoIndex["PLAYERCURSOR"] then
		popElementInstance(cursorPointLightVBO, cursorLights[playerID])
		cursorLights[playerID] = nil
	end
end


function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	visibleUnits[unitID] = unitDefID
	AddStaticLightsForUnit(unitID, unitDefID, false, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(unitPointLightVBO) -- clear all instances
	InstanceVBOTable.clearInstanceTable(unitBeamLightVBO) -- clear all instances
	InstanceVBOTable.clearInstanceTable(unitConeLightVBO) -- clear all instances
	visibleUnits = {}

	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
		AddStaticLightsForUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(unitPointLightVBO) -- upload them all
	uploadAllElements(unitBeamLightVBO) -- upload them all
	uploadAllElements(unitConeLightVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove all the lights for this unit
	--if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	RemoveUnitAttachedLights(unitID)
	visibleUnits[unitID] = nil
end

function widget:Shutdown()
	-- TODO: delete the VBOs and shaders like a good boy
	WG['lightsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddPointLight')
	widgetHandler:DeregisterGlobal('AddBeamLight')
	widgetHandler:DeregisterGlobal('AddConeLight')
	widgetHandler:DeregisterGlobal('AddLight')
	widgetHandler:DeregisterGlobal('RemoveLight')
	widgetHandler:DeregisterGlobal('GetLightVBO')

	widgetHandler:DeregisterGlobal('UnitScriptLight')

	deferredLightShader:Delete()
	local ram = 0
	for lighttype, vbo in pairs(unitLightVBOMap) do ram = ram + vbo:Delete() end
	for lighttype, vbo in pairs(projectileLightVBOMap) do ram = ram + vbo:Delete() end
	for lighttype, vbo in pairs(lightVBOMap) do ram = ram + vbo:Delete() end
	ram = ram + cursorPointLightVBO:Delete()

	--Spring.Echo("DLGL4 ram usage MB = ", ram / 1000000)
	--Spring.Echo("featureDefLights", table.countMem(featureDefLights))
	--Spring.Echo("unitEventLights", table.countMem(unitEventLights))
	--Spring.Echo("unitDefLights", table.countMem(unitDefLights))
	--Spring.Echo("projectileDefLights", table.countMem(projectileDefLights))
	--Spring.Echo("explosionLights", table.countMem(explosionLights))

	-- Note, these must be nil'ed manually, because
	-- tables included from VFS.Include dont get GC'd unless specifically nil'ed
	unitDefLights = nil
	featureDefLights = nil
	unitEventLights = nil
	muzzleFlashLights = nil
	projectileDefLights = nil
	explosionLights  = nil
	gibLight = nil

	--collectgarbage("collect")
	--collectgarbage("collect")

end

local windX = 0
local windZ = 0

function widget:GameFrame(n)
	if addrandomlights and (n % 100 == 0) then
		AddRandomDecayingPointLight()
	end
	gameFrame = n
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	--windStrength = math.min(20, math.max(3, windStrength))
	--Spring.Echo(windDirX,windDirZ,windStrength)
	windX = windX + windDirX * 0.016
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

-- This should simplify adding all kinds of events
-- You are permitted to define as many lights as you wish, but its probably stupid to do so.
local function eventLightSpawner(eventName, unitID, unitDefID, teamID)
	if spValidUnitID(unitID) and spGetUnitIsDead(unitID) == false and unitEventLights[eventName] then
		if unitEventLights[eventName] then
			-- get the default event if it is defined
			local lightList =  unitEventLights[eventName][unitDefID] or unitEventLights[eventName]['default']
			if lightList then
				for lightname, lightTable in pairs(lightList) do
					local visible = lightTable.alwaysVisible
					local px,py,pz = spGetUnitPosition(unitID)
					if not visible then
						if px and spIsSphereInView(px,py,pz, lightTable[4]) then visible = true end
					end

					-- bail if only for allies
					if (not spec) and lightTable.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then
						visible = false
					end

					-- bail if unable to initialize light
					if not lightTable.initComplete then
						if not InitializeLight(lightTable, unitID) then
							visible = false
						end
					end

					-- bail if invalid unitID wants a unit-attached light
					if lightTable.pieceName and (visibleUnits[unitID] == nil) then
						visible = false
					end

					if visible then
						--if lightTable.aboveUnit then lightTable.lightParamTable end
						local lightParamTable = lightTable.lightParamTable
						if lightTable.pieceName then
							if lightTable.aboveUnit then -- if its above the unit, then add the aboveunit offset to the units height too!
								-- this is done via a quick copy of the table
								for i=1, lightParamTableSize do lightCacheTable[i] = lightParamTable[i] end
								local unitHeight = Spring.GetUnitHeight(unitID)
								if unitHeight == nil then
									local losstate = Spring.GetUnitLosState(unitID)
									Spring.Echo("Unitheight is nil for unitID", unitID, "unitDefName", unitName[unitDefID], eventName, lightname, 'losstate', losstate and losstate.los)
								end

								lightCacheTable[2] = lightCacheTable[2] + lightTable.aboveUnit + (unitHeight or 0)
								lightParamTable = lightCacheTable
							end
							AddLight(eventName .. tostring(unitID) ..  lightname, unitID, lightTable.pieceIndex, unitLightVBOMap[lightTable.lightType], lightParamTable)
						else
							for i=1, lightParamTableSize do lightCacheTable[i] = lightParamTable[i] end
							lightCacheTable[1] = lightCacheTable[1] + px
							lightCacheTable[2] = lightParamTable[2] + py + ((lightTable.aboveUnit and Spring.GetUnitHeight(unitID)) or 0)
							lightCacheTable[3] = lightCacheTable[3] + pz
							AddLight(eventName .. tostring(unitID) ..  lightname, nil, lightTable.pieceIndex, lightVBOMap[lightTable.lightType], lightCacheTable)
						end
					end

				end
			end
		end
	end
end

-- Below are the registered spawners for events
function widget:UnitIdle(unitID, unitDefID, teamID) -- oh man we need a sane way to handle height :D
	eventLightSpawner("UnitIdle", unitID, unitDefID, teamID)
end
function widget:UnitFinished(unitID, unitDefID, teamID)
	eventLightSpawner("UnitFinished", unitID, unitDefID, teamID)
end
function widget:UnitCreated(unitID, unitDefID, teamID)
	eventLightSpawner("UnitCreated", unitID, unitDefID, teamID)
end
function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	eventLightSpawner("UnitFromFactory", unitID, unitDefID, teamID)  -- i have no idea of the differences here
	eventLightSpawner("UnitFromFactoryBuilder", factID, factDefID, teamID)
end
function widget:UnitDestroyed(unitID, unitDefID, teamID) -- dont do piece-attached lights here!
	eventLightSpawner("UnitDestroyed", unitID, unitDefID, teamID)
end
function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemoveUnitAttachedLights(unitID)
end

-- THIS ONE DOESNT WORK, some shit is being pulled and i cant get the unit height of the unit being taken here!
--function widget:UnitTaken(unitID, unitDefID, teamID)
	--eventLightSpawner("UnitTaken", unitID, unitDefID, teamID)
--end
function widget:UnitGiven(unitID, unitDefID, teamID)
	eventLightSpawner("UnitGiven", unitID, unitDefID, teamID)
end
function widget:UnitCloaked(unitID, unitDefID, teamID)
	eventLightSpawner("UnitCloaked", unitID, unitDefID, teamID)
end
function widget:UnitDecloaked(unitID, unitDefID, teamID)
	eventLightSpawner("UnitDecloaked", unitID, unitDefID, teamID)
end
function widget:UnitMoveFailed(unitID, unitDefID, teamID)
	eventLightSpawner("UnitMoveFailed", unitID, unitDefID, teamID)
end

function widget:StockpileChanged(unitID, unitDefID, teamID, weaponNum, oldCount, newCount)
	if newCount > oldCount then
		eventLightSpawner("StockpileChanged", unitID, unitDefID, teamID)
	end
end

function widget:FeatureCreated(featureID, noUpload)
	if type(noUpload) ~= 'boolean' then noUpload = nil end
	-- TODO: Allow team-colored feature lights by getting teamcolor and putting it into lightCacheTable
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefLights[featureDefID] then
		for lightname, lightTable in pairs(featureDefLights[featureDefID]) do
			if not lightTable.initComplete then InitializeLight(lightTable) end
			local px, py, pz = Spring.GetFeaturePosition(featureID)
			if px and featureID%(lightTable.fraction or 1 ) == 0 then

				local lightParamTable = lightTable.lightParamTable
				for i=1, lightParamTableSize do lightCacheTable[i] = lightParamTable[i] end
				lightCacheTable[1] = lightParamTable[1] + px
				lightCacheTable[2] = lightParamTable[2] + py
				lightCacheTable[3] = lightParamTable[3] + pz
				AddLight(tostring(featureID) ..  lightname, nil, nil, lightVBOMap[lightTable.lightType], lightCacheTable, noUpload)
			end
		end
	end
end

function widget:FeatureDestroyed(featureID, noUpload)
	if type(noUpload) ~= 'boolean' then noUpload = nil end
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefLights[featureDefID] then
		for lightname, lightTable in pairs(featureDefLights[featureDefID]) do
			if featureID % (lightTable.fraction or 1 ) == 0 then
				RemoveLight(lightTable.lightType, tostring(featureID) ..  lightname, nil, noUpload)
			end
		end
	end
end

-- Beam type projectiles are indeed an oddball, as they live for exactly 3 frames, no?

local function PrintProjectileInfo(projectileID)
	local px, py, pz = spGetProjectilePosition(projectileID)
	local weapon, piece = Spring.GetProjectileType(projectileID)
	local weaponDefID = weapon and Spring.GetProjectileDefID ( projectileID )
	Spring.Debug.TraceFullEcho()
end


local function updateProjectileLights(newgameframe)
	local nowprojectiles = Spring.GetVisibleProjectiles()
	gameFrame = Spring.GetGameFrame()
	local newgameframe = true
	if gameFrame == lastGameFrame then newgameframe = false end
	--Spring.Echo(gameFrame, lastGameFrame, newgameframe)
	lastGameFrame = gameFrame
	-- turn off uploading vbo
	-- one known issue regarding to every gameframe respawning lights is to actually get them to update existing dead light candidates, this is very very hard to do sanely
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
					if lightType ~= 'beam' then
						local dx,dy,dz = spGetProjectileVelocity(projectileID)
						local instanceIndex = updateLightPosition(projectileLightVBOMap[lightType],
							projectileID, px,py,pz, nil, dx,dy,dz)
						if debugproj then Spring.Echo("Updated", instanceIndex, projectileID, px, py, pz,dx,dy,dz) end
					end

				end
			else
				-- add projectile
				local weapon, piece = spGetProjectileType(projectileID)
				if piece then
					local gib = gibLight.lightParamTable
					gib[1] = px
					gib[2] = py
					gib[3] = pz
					AddLight(projectileID, nil, nil, projectilePointLightVBO, gib, noUpload)
				else
					local weaponDefID = spGetProjectileDefID ( projectileID )
					if projectileDefLights[weaponDefID] and ( projectileID % (projectileDefLights[weaponDefID].fraction or 1) == 0 ) then
						local lightParamTable = projectileDefLights[weaponDefID].lightParamTable
						lightType = projectileDefLights[weaponDefID].lightType


						lightParamTable[1] = px
						lightParamTable[2] = py
						lightParamTable[3] = pz
						if debugproj then Spring.Echo(lightType, projectileDefLights[weaponDefID].lightClassName) end

						local dx,dy,dz = spGetProjectileVelocity(projectileID)

						if lightType == 'beam' then
							lightParamTable[5] = px + dx
							lightParamTable[6] = py + dy
							lightParamTable[7] = pz + dz
						else
							-- for points and cones, velocity gives the pointing dir, and for cones it gives the pos super well.
							lightParamTable[5] = dx
							lightParamTable[6] = dy
							lightParamTable[7] = dz
						end
						if debugproj then Spring.Echo(lightType, px,py,pz, dx, dy,dz) end

						AddLight(projectileID, nil, nil, projectileLightVBOMap[lightType], lightParamTable,noUpload)
						--AddLight(projectileID, nil, nil, projectilePointLightVBO, lightParamTable)
					else
						--Spring.Echo("No projectile light defined for", projectileID, weaponDefID, px, pz)
						--testprojlighttable[1] = px
						--testprojlighttable[2] = py
						--testprojlighttable[3] = pz
						--AddPointLight(projectileID, nil, nil, projectilePointLightVBO, testprojlighttable)
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
			if px then -- this means that this projectile
				local lightType = trackedProjectileTypes[projectileID]
				if newgameframe and lightType ~= 'beam' then
					local dx,dy,dz = spGetProjectileVelocity(projectileID)
					updateLightPosition(projectileLightVBOMap[lightType],
						projectileID, px,py,pz, nil, dx,dy,dz )
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
	for _, targetVBO in pairs(projectileLightVBOMap) do
		if targetVBO.dirty then
			uploadAllElements(targetVBO)
		end
	end
	--if debugproj then
	--	Spring.Echo("#points", projectilePointLightVBO.usedElements, '#projs', #nowprojectiles )
	--end
end

local configCache = {lastUpdate = Spring.GetTimer()}
local function checkConfigUpdates()
	if Spring.DiffTimers(Spring.GetTimer(), configCache.lastUpdate) > 0.5 then
		local newconfa = VFS.LoadFile('luaui/configs/DeferredLightsGL4config.lua')
		local newconfb = VFS.LoadFile('luaui/configs/DeferredLightsGL4WeaponsConfig.lua')
		if newconfa ~= configCache.confa or newconfb ~= configCache.confb then
			LoadLightConfig()
			if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
				widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
			end
			for i, featureID in pairs(Spring.GetAllFeatures()) do
				widget:FeatureDestroyed(featureID, true)
			end
			for i, featureID in pairs(Spring.GetAllFeatures()) do
				widget:FeatureCreated(featureID, true)
			end
			if pointLightVBO.dirty then uploadAllElements(pointLightVBO) end
			configCache.confa = newconfa
			configCache.confb = newconfb
		end
		configCache.lastUpdate = Spring.GetTimer()
	end
end

local expavg = 0
local sec = 1
function widget:Update(dt)
	if autoupdate then checkConfigUpdates() end
	local tus = Spring.GetTimerMicros()

	-- update/handle Cursor Lights!
	if WG['allycursors'] and WG['allycursors'].getLights() then
		sec = sec + dt
		if sec >= 0.25 then
			if cursorLightAlpha ~= WG['allycursors'].getLightStrength() or cursorLightRadius ~= WG['allycursors'].getLightRadius() or cursorLightSelfShadowing ~= WG['allycursors'].getLightSelfShadowing() then
				cursorLightAlpha = WG['allycursors'].getLightStrength()
				cursorLightRadius = WG['allycursors'].getLightRadius()
				cursorLightSelfShadowing = WG['allycursors'].getLightSelfShadowing()
				InstanceVBOTable.clearInstanceTable(cursorPointLightVBO)
				cursorLights = nil
			end
		end
		if not cursorLights then
			cursorLights = {}
		end
		local cursors, notIdle = WG['allycursors'].getCursors()
		for playerID, cursor in pairs(cursors) do
			if teamColors[playerID] and not cursor[8] and notIdle[playerID] then
				if not cursorLights[playerID] then
					local params = cursorLightParams.lightParamTable	-- see lightParamKeyOrder for which key contains what
					params[1], params[2], params[3] = cursor[1], cursor[2] + cursorLightHeight, cursor[3]
					params[4] = cursorLightRadius * 250
					params[9], params[10], params[11] = teamColors[playerID][1], teamColors[playerID][2], teamColors[playerID][3]
					params[12] = cursorLightAlpha * 0.2
					params[20] = cursorLightSelfShadowing and 8 or 0
					cursorLights[playerID] = AddLight(nil, nil, nil, cursorPointLightVBO, params)	--pointLightVBO
				else
					updateLightPosition(cursorPointLightVBO, cursorLights[playerID], cursor[1], cursor[2]+cursorLightHeight, cursor[3])
				end
			end
		end
		uploadAllElements(cursorPointLightVBO)
	else
		if cursorLights then
			InstanceVBOTable.clearInstanceTable(cursorPointLightVBO)
			cursorLights = nil
		end
	end

	-- This is the player cursor!
	if showPlayerCursorLight then
		local mx,my,m1,m2,m3, _ , camPanning = Spring.GetMouseState()
		local traceType, tracedScreenRay = Spring.TraceScreenRay(mx, my, true)
		if not camPanning and tracedScreenRay ~= nil then
			local params = playerCursorLightParams.lightParamTable
			params[1], params[2], params[3] = tracedScreenRay[1],tracedScreenRay[2] + cursorLightHeight,tracedScreenRay[3]
			params[4] = playerCursorLightRadius * 250
			params[12] = playerCursorLightBrightness * 0.1
			AddLight("PLAYERCURSOR", nil, nil, cursorPointLightVBO, params)
		else
			if cursorPointLightVBO.instanceIDtoIndex["PLAYERCURSOR"] then
				popElementInstance(cursorPointLightVBO, "PLAYERCURSOR")
			end
		end
	end

	updateProjectileLights()
	expavg = expavg * 0.98 + 0.02 * Spring.DiffTimers(Spring.GetTimerMicros(),tus)
	--if Spring.GetGameFrame() % 120 ==0 then Spring.Echo("Update is on average", expavg,'ms') end
end

------------------------------- Drawing all the lights ---------------------------------


-- local tf = Spring.GetTimerMicros()
function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	--local t0 = Spring.GetTimerMicros()
	--if true then return end
	if skipdraw then return end
	if autoupdate then
		deferredLightShader = LuaShader.CheckShaderUpdates(shaderSourceCache, 0) or deferredLightShader
	end

	if pointLightVBO.usedElements > 0 or
		unitPointLightVBO.usedElements > 0 or
		beamLightVBO.usedElements > 0 or
		unitConeLightVBO.usedElements > 0 or
		coneLightVBO.usedElements > 0 or
		cursorPointLightVBO.usedElements > 0
		then

		local alt, ctrl = Spring.GetModKeyState()
		local devui = (Spring.GetConfigInt('DevUI', 0) == 1)

		if autoupdate and alt and ctrl and (isSinglePlayer or spec) and devui then
			-- draw a full-screen black quad first!
			local camX, camY, camZ = Spring.GetCameraPosition()
			local camDirX,camDirY,camDirZ = Spring.GetCameraDirection()
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
			gl.Culling(GL.BACK)
			gl.DepthTest(false)
			gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
			gl.Color(0,0,0,1)
			gl.PushMatrix()
			gl.Color(0,0,0,1.0)
			gl.Translate(camX+(camDirX*360),camY+(camDirY*360),camZ+(camDirZ*360))
			gl.Billboard()
			gl.Rect(-5000, -5000, 5000, 5000)
			gl.PopMatrix()
		end

		if autoupdate and ctrl and (not alt) and (isSinglePlayer or spec) and devui then
			glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		else
			glBlending(GL.SRC_ALPHA, GL.ONE)
		end
		--if autoupdate and alt and (not ctrl) and (isSinglePlayer or spec) and devui then return end

		gl.Culling(GL.BACK)
		gl.DepthTest(false)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, "$map_gbuffer_zvaltex")
		glTexture(1, "$model_gbuffer_zvaltex")
		glTexture(2, "$map_gbuffer_normtex")
		glTexture(3, "$model_gbuffer_normtex")
		--glTexture(4, "$map_gbuffer_spectex")
		--glTexture(5, "$model_gbuffer_spectex")
		glTexture(6, "$map_gbuffer_difftex")
		glTexture(7, "$model_gbuffer_difftex")
		glTexture(8, noisetex3dcube)
		glTexture(9, blueNoise2D)

		deferredLightShader:Activate()
		deferredLightShader:SetUniformFloat("nightFactor", nightFactor)

		deferredLightShader:SetUniformFloat("intensityMultiplier", intensityMultiplier)
		deferredLightShader:SetUniformFloat("radiusMultiplier", radiusMultiplier)

		-- As the setting goes from 0 to 4, map to 0,8,16,32,64
		local screenSpaceShadowSampleCount = 0
		if screenSpaceShadows > 0 then
			screenSpaceShadowSampleCount = math.min(64, math.floor( math.pow(2, screenSpaceShadows) * 4) )
		end
		deferredLightShader:SetUniformInt("screenSpaceShadows",  screenSpaceShadowSampleCount)
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
		--gl.DepthMask(true) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	end
	--local t1 = 	Spring.GetTimerMicros()
	--if (Spring.GetDrawFrame() % 50 == 0 ) then
	--	local dt =  Spring.DiffTimers(t1,t0)
	--	Spring.Echo("Deltat is ", dt,'us, so total load should be', dt * Spring.GetFPS() / 10 ,'%')
	--	Spring.Echo("epoch is ", Spring.DiffTimers(t1,tf))
	--end
end

-- Register /luaui dlgl4stats to dump light statistics
function widget:TextCommand(command)
	if string.find(command, "dlgl4stats", nil, true) then
		Spring.Echo(string.format("DLGLStats Total = %d , (PBC=%d,%d,%d), (unitPBC=%d,%d,%d), (projPBC=%d,%d,%d), Cursor = %d",
				numAddLights,
				pointLightVBO.usedElements, beamLightVBO.usedElements, coneLightVBO.usedElements,
				unitPointLightVBO.usedElements, unitBeamLightVBO.usedElements, unitConeLightVBO.usedElements,
				projectilePointLightVBO.usedElements, projectileBeamLightVBO.usedElements, projectileConeLightVBO.usedElements,
				cursorPointLightVBO.usedElements))
		return true
	end
	if string.find(command, "dlgl4skipdraw", nil, true) then
		skipdraw = not skipdraw
		Spring.Echo("Deferred Rendering GL4 skipdraw set to", skipdraw)
		return true
	end
	return false
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
		local nightLightingParams = {}
		for _,v in ipairs(adjustfornight) do
			nightLightingParams[v] = mapinfo.lighting[string.lower(v)]
			if nightLightingParams[v] ~= nil then
				for k2, v2 in pairs(nightLightingParams[v]) do
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

	if addrandomlights then
		math.randomseed(1)
		for i=1, 1 do AddRandomLight(	math.random()) end
	end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end

	WG['lightsgl4'] = {}
	WG['lightsgl4'].AddPointLight = AddPointLight
	WG['lightsgl4'].AddBeamLight  = AddBeamLight
	WG['lightsgl4'].AddConeLight  = AddConeLight
	WG['lightsgl4'].AddLight  = AddLight
	WG['lightsgl4'].RemoveLight  = RemoveLight
	WG['lightsgl4'].GetLightVBO  = GetLightVBO

	WG['lightsgl4'].IntensityMultiplier = function(value)
		intensityMultiplier = value
	end
	WG['lightsgl4'].RadiusMultiplier = function(value)
		radiusMultiplier = value
	end
	WG['lightsgl4'].ScreenSpaceShadows = function(value)
		screenSpaceShadows = value
	end

	WG['lightsgl4'].ShowPlayerCursorLight = function(value)
		showPlayerCursorLight = value
		-- Remove the player's cursor light on disabling this feature
		if not showPlayerCursorLight and cursorPointLightVBO.instanceIDtoIndex["PLAYERCURSOR"] then
			popElementInstance(cursorPointLightVBO, "PLAYERCURSOR")
		end
	end
	WG['lightsgl4'].PlayerCursorLightRadius = function(value)
		playerCursorLightRadius = value
	end
	WG['lightsgl4'].PlayerCursorLightBrightness = function(value)
		playerCursorLightBrightness = value
	end

	widgetHandler:RegisterGlobal('AddPointLight', WG['lightsgl4'].AddPointLight)
	widgetHandler:RegisterGlobal('AddBeamLight', WG['lightsgl4'].AddBeamLight)
	widgetHandler:RegisterGlobal('AddConeLight', WG['lightsgl4'].AddConeLight)
	widgetHandler:RegisterGlobal('AddLight', WG['lightsgl4'].AddLight)
	widgetHandler:RegisterGlobal('RemoveLight', WG['lightsgl4'].RemoveLight)
	widgetHandler:RegisterGlobal('GetLightVBO', WG['lightsgl4'].GetLightVBO)

	widgetHandler:RegisterGlobal('UnitScriptLight', UnitScriptLight)
end

if autoupdate then
	function widget:DrawScreen()
		if deferredLightShader.DrawPrintf then deferredLightShader.DrawPrintf() end
	end
end
--------------------------- Ingame Configurables -------------------

function widget:GetConfigData(_) -- Called by RemoveWidget
	local savedTable = {
		intensityMultiplier = intensityMultiplier,
		radiusMultiplier = radiusMultiplier,
		screenSpaceShadows = screenSpaceShadows,
		showPlayerCursorLight = showPlayerCursorLight,
		playerCursorLightRadius = playerCursorLightRadius,
		playerCursorLightBrightness = playerCursorLightBrightness,
	}
	return savedTable
end

function widget:SetConfigData(data) -- Called on load (and config change), just before Initialize!
	if data.intensityMultiplier ~= nil then
		intensityMultiplier = data.intensityMultiplier
	end
	if data.radiusMultiplier ~= nil then
		radiusMultiplier = data.radiusMultiplier
	end
	if data.screenSpaceShadows ~= nil then
		screenSpaceShadows = data.screenSpaceShadows
	end
	if data.showPlayerCursorLight ~= nil then
		showPlayerCursorLight = data.showPlayerCursorLight
	end
	if data.playerCursorLightRadius ~= nil then
		playerCursorLightRadius = data.playerCursorLightRadius
	end
	if data.playerCursorLightBrightness ~= nil then
		playerCursorLightBrightness = data.playerCursorLightBrightness
	end
end
