--------------------------------------------------------------------------------

function widget:GetInfo()
	return {
		name = "Distortion GL4",
		version = 3,
		desc = "Renders screen-space distortion effects",
		author = "Beherith",
		date = "2022.06.10",
		license = "Lua code is GPL V2, GLSL is (c) Beherith (mysterme@gmail.com)",
		layer = -999999999, -- should be the last call of DrawWorld
		enabled = true
	}
end

-------------------------------- Notes, TODO ----------------------------------
do
--
-- Rendering passes:
-- 1. Render all distortion effects to a screen-sized buffer, DistortionTexture
-- 	1.1 Call widget:DrawDistortion(textureset)
--  
-- 2. Perform the distortion pass, 
	-- inputs are DistortionTexture, Depth Buffers, ScreenCopy
	-- Output is the final screen
-- Perform a compression pass on distortionParams, culling idents
end

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
------------------------------ Debug switches ------------------------------
local autoupdate = false
local debugproj = false
local skipdraw = false

------------------------------ Distortion and Shader configurations ------------------
local unitDefDistortions
local featureDefDistortions
local unitEventDistortions -- Table of distortions per unitDefID
local muzzleFlashDistortions  -- one distortion per weaponDefID
local projectileDefDistortions  -- one distortion per weaponDefID
local explosionDistortions  -- one distortion per weaponDefID
local gibDistortion  -- one distortion for all pieceprojectiles

local isSinglePlayer = Spring.Utilities.Gametype.IsSinglePlayer()

local shaderConfig = {
	VOIDWATER = gl.GetMapRendering("voidWater") and 1 or 0,
	CHROMATIC_ABERRATION = 1.02, -- How much chromatic aberration to apply to the distortion, set to nil to disable
	DEBUGCOMBINER = autoupdate and 1 or 0, -- 1 is debug mode, 0 is normal mode
	UNIFORMSBUFFERCOPY = nil, -- enable this for experimental unit uniforms buffer copy
}

local radiusMultiplier = 1.0
local intensityMultiplier = 1.0

-- the 3d noise texture used for this shader
local noisetex3dcube =  "LuaUI/images/noisetextures/noise64_cube_3.dds"

------------------------------ Data structures and management variables ------------

-- These will contain 'global' type distortions, ones that dont get updated every frame
local pointDistortionVBO = {} -- an instanceVBOTable
local coneDistortionVBO = {} -- an instanceVBOTable
local beamDistortionVBO = {} -- an instanceVBOTable
local distortionVBOMap -- a table of the above 3, keyed by distortion type, {point = pointDistortionVBO, ...}

-- These contain the unitdef defined, cob-instanced and unit event based distortions
local unitPointDistortionVBO = {} -- an instanceVBOTable, with unit-attachment
local unitConeDistortionVBO = {} -- an instanceVBOTable
local unitBeamDistortionVBO = {} -- an instanceVBOTable
local unitDistortionVBOMap -- a table of the above 3, keyed by distortion type,  {point = unitPointDistortionVBO, ...}

local unitAttachedDistortions = {} -- this is a table mapping unitID's to all their attached instanceIDs and vbos
	--{unitID = { instanceID = targetVBO, ... }}
local visibleUnits = {} -- this is a proxy for the widget callins, used to ensure we dont add unitscriptdistortions to units that are not visible

-- these will be separate, as they need per-frame updates!
local projectilePointDistortionVBO = {}  -- for plasma balls
local projectileBeamDistortionVBO = {}  -- for lasers
local projectileConeDistortionVBO = {} -- for rockets
local projectileDistortionVBOMap -- a table of the above 3, keyed by distortion type

local distortionRemoveQueue = {} -- stores distortions that have expired life {gameframe = {distortionIDs ... }}

local unitDefPeiceMapCache = {} -- maps unitDefID to piecemap

local distortionParamTableSize = 29
local distortionCacheTable = {} -- this is a reusable table cache for saving memory later on
for i = 1, distortionParamTableSize do distortionCacheTable[i] = 0 end
local pieceIndexPos = 25
local spawnFramePos = 17
distortionCacheTable[13] = 1 --modelfactor_specular_scattering_lensflare
distortionCacheTable[14] = 1
distortionCacheTable[15] = 1
distortionCacheTable[16] = 1

local distortionEffectTypes = {
	heatDistortion = 0,
	airShockwave = 1,
	groundShockwave = 2,
	airJet = 3,
	gravityLens = 4,
	fusionSphere = 5, 
	cloakDistortion = 6, 
	shieldSphere = 7, 
	magnifier = 8,
	twirl = 10,
	motionBlur = 11,
	tachyonBeam = 12,
	distortionCircleGround = 13,

}

local distortionParamKeyOrder = { -- This table is a 'quick-ish' way of building the lua array from human-readable distortion parameters
	-- worldposrad:
	posx = 1, posy = 2, posz = 3, radius = 4,

	-- worldposrad2:
	dirx = 5, diry = 6, dirz = 7, theta = 8,  -- cones: specify direction and half-angle in radians
	pos2x = 5, pos2y = 6, pos2z = 7, -- beam distortions only, specifies the endpoint of the beam


	-- baseparams
	yoffset = 9, -- the offset along the y axis for this effect
	effectStrength = 10, -- Default 1, multiply with any effect's final strength
	startRadius = 11, -- Defaults to match radius, multiply with any effect's final radius
	unused = 12,
	
	-- universalParams
	noiseStrength = 13, noiseScaleSpace = 14, distanceFalloff = 15, onlyModelMap = 16, 

	-- lifeParams:
	--spawnFrame = 17, is reserved! 
	lifeTime = 18, rampUp = 19, decay = 20,
	
	-- effectParams
	effectParam1 = 21, 
	riseRate = 21, -- note how riseRate is identical to effectParam1 for clarity
	shockWidth = 21,    -- note how width is identical to effectParam1 for clarity
	magnificationRate = 21,

	effectParam2 = 22,  --note how refractiveIndex is identical to effectParam2 for clarity
	refractiveIndex = 22,
	
	windAffected = 23,  effectType = 24, 
	--color2r = 21, color2g = 22, color2b = 23, colortime = 24, -- point distortions only, colortime in seconds for unit-attached
}

local autoDistortionInstanceID = 128000 -- as MAX_PROJECTILES = 128000, so they get unique ones


local gameFrame = 0

local trackedProjectiles = {} -- used or finding out which projectiles can be culled {projectileID = updateFrame, ...}
local trackedProjectileTypes = {} -- we have to track the types [point, distortion, cone] of projectile distortions for efficient updates
local lastGameFrame = -2


local LuaShader = gl.LuaShader
local InstanceVBOTable = gl.InstanceVBOTable

local uploadAllElements   = InstanceVBOTable.uploadAllElements
local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local deferredDistortionShader = nil

local distortionShaderSourceCache = {
	shaderName = 'Deferred Distortions GL4',
	vssrcpath = "LuaUI/Shaders/distortion_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/distortion_gl4.frag.glsl",
	shaderConfig = shaderConfig,
	uniformInt = {
		mapDepths = 0,
		modelDepths = 1,
		mapNormals = 2,
		modelNormals = 3,
		mapDiffuse = 4,
		modelDiffuse = 5,
		noise3DCube = 6,
		},
	uniformFloat = {
		pointbeamcone = 0,
		--fadeDistance = 3000,
		attachedtounitID = 0,
		nightFactor = 1.0,
		windXZ = {0,0},
		radiusMultiplier = 1.0,
		intensityMultiplier = 1.0,
	  },
}


local numAddDistortions = 0 -- how many times AddDistortion was called

local spec = Spring.GetSpectatingState()

local vsx, vsy, vpx, vpy
local DistortionTexture -- RGBA 8bit
local ScreenCopy -- RGBA 8bit

local screenDistortionShader = nil
local screenDistortionShaderSourceCache = {	
	shaderName = 'ScreenDistortionShader GL4',
	vssrcpath = "LuaUI/Shaders/screen_distortion_combine_gl4.vert.glsl",
	fssrcpath = "LuaUI/Shaders/screen_distortion_combine_gl4.frag.glsl",
	shaderConfig = shaderConfig,
	uniformInt = {
		mapDepths = 0,
		modelDepths = 1,
		screenCopyTexture = 2,
		distortionTexture = 3,
		},
	uniformFloat = {
		distortionStrength = 1.0,
		},
}

local fullScreenQuadVAO = nil
---------------------- INITIALIZATION FUNCTIONS ----------------------------------


local function goodbye(reason)
	Spring.Echo('Deferred Distortions GL4 exiting:', reason)
	widgetHandler:RemoveWidget()
end

local function createDistortionInstanceVBO(vboLayout, vertexVBO, numVertices, indexVBO, VBOname, unitIDattribID)
	local targetDistortionVBO = InstanceVBOTable.makeInstanceVBOTable( vboLayout, 16, VBOname, unitIDattribID)
	if vertexVBO == nil or targetDistortionVBO == nil then goodbye("Failed to make "..VBOname) end
	targetDistortionVBO.vertexVBO = vertexVBO
	targetDistortionVBO.numVertices = numVertices
	targetDistortionVBO.indexVBO = indexVBO
	targetDistortionVBO.VAO = InstanceVBOTable.makeVAOandAttach(targetDistortionVBO.vertexVBO, targetDistortionVBO.instanceVBO, targetDistortionVBO.indexVBO)
	return targetDistortionVBO
end

function widget:ViewResize()
	vsx, vsy, vpx, vpy = Spring.GetViewGeometry()
	if ScreenCopy then gl.DeleteTexture(ScreenCopy) end
	ScreenCopy = gl.CreateTexture(vsx  , vsy, {
		border = false,
		min_filter = GL.LINEAR,
		mag_filter = GL.LINEAR,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
	})
	local GL_RGBA16F_ARB = 0x881A
	--local GL_DEPTH_COMPONENT32 = 0x81A7
	if DistortionTexture then gl.DeleteTexture(DistortionTexture) end
	DistortionTexture = gl.CreateTexture(vsx , vsy, {
		border = false,
		format = GL_RGBA16F_ARB,
		min_filter = GL.NEAREST,
		mag_filter = GL.NEAREST,
		wrap_s = GL.CLAMP,
		wrap_t = GL.CLAMP,
		fbo = true,
	})
	if not ScreenCopy then Spring.Echo("Distortions GL4 Manager failed to create a ScreenCopy") return false end 
	if not DistortionTexture then Spring.Echo("ScreenCopy Manager failed to create a DistortionTexture") return false end 
	return true
end

local function initGL4()
	if not widget:ViewResize() then 
		goodbye("Failed to CreateTexture for Distortions GL4")
		return false
	end

	deferredDistortionShader = LuaShader.CheckShaderUpdates(distortionShaderSourceCache, 0)
	if not deferredDistortionShader then
		goodbye("Failed to compile Deferred Distortions GL4 shader")
		return false
	end

	screenDistortionShader = LuaShader.CheckShaderUpdates(screenDistortionShaderSourceCache, 0)
	if not screenDistortionShader then
		goodbye("Failed to compile Screen Distortion GL4 shader")
		return false
	end
	
	fullScreenQuadVAO = InstanceVBOTable.MakeTexRectVAO()--  -1, -1, 1, 0,   0,0,1, 0.5)
	-- init the VBO
	local vboLayout = {
			{id = 3, name = 'worldposrad', 			size = 4},
				-- for spot, this is center.xyz and radius
				-- for cone, this is center.xyz and height
				-- for beam this is center.xyz and radiusleft
			{id = 4, name = 'worldposrad2', 		size = 4},
				-- for spot, this is direction.xyz for unitattached, or world anim params
				-- for cone, this is direction.xyz and angle in radians
				-- for beam this is end.xyz and radiusright
			{id = 5, name = 'baseparams', 		size = 4}, -- yoffset, effectStrength, startRadius,  unused 
			{id = 6, name = 'universalParams', 		size = 4}, -- noiseStrength, noiseScaleSpace, distanceFalloff, onlyModelMap
			{id = 7, name = 'lifeParams', 			size = 4},	-- spawnFrame, lifeTime, rampUp, decay
			{id = 8, name = 'effectParams', size = 4}, -- effectParam1, effectParam2, windAffectd, effectType
			{id = 9, name = 'pieceIndex', size = 1, type = GL.UNSIGNED_INT},
			{id = 10, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
	}

	local pointVBO, numVerts, pointIndexVBO, numIndices = InstanceVBOTable.makeSphereVBO(8, 4, 1) -- could use an icosahedron (v12/i60/f20) maybe?
	--Spring.Echo('numVerts', numVerts, numIndices) -- (v45, i144, f45) for a sphere
	pointDistortionVBO 			= createDistortionInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Point Distortion VBO")
	unitPointDistortionVBO 		= createDistortionInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Unit Point Distortion VBO", 10)
	projectilePointDistortionVBO = createDistortionInstanceVBO(vboLayout, pointVBO, nil, pointIndexVBO, "Projectile Point Distortion VBO")

	local coneVBO, numConeVertices = InstanceVBOTable.makeConeVBO(12, 1, 1)
	coneDistortionVBO 			= createDistortionInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Cone Distortion VBO")
	unitConeDistortionVBO 		= createDistortionInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Unit Cone Distortion VBO", 10)
	projectileConeDistortionVBO  = createDistortionInstanceVBO(vboLayout, coneVBO, numConeVertices, nil, "Projectile Cone Distortion VBO")

	local beamVBO, numBeamVertices = InstanceVBOTable.makeBoxVBO(-1, -1, -1, 1, 1, 1)
	beamDistortionVBO 			= createDistortionInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Beam Distortion VBO")
	unitBeamDistortionVBO 		= createDistortionInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Unit Beam Distortion VBO", 10)
	projectileBeamDistortionVBO 	= createDistortionInstanceVBO(vboLayout, beamVBO, numBeamVertices, nil, "Projectile Beam Distortion VBO")

	projectileDistortionVBOMap = { point = projectilePointDistortionVBO,  beam = projectileBeamDistortionVBO,  cone = projectileConeDistortionVBO, }
	unitDistortionVBOMap = { point = unitPointDistortionVBO,  beam = unitBeamDistortionVBO,  cone = unitConeDistortionVBO, }
	distortionVBOMap = { point = pointDistortionVBO,  beam = beamDistortionVBO,  cone = coneDistortionVBO, }
	return pointDistortionVBO and unitPointDistortionVBO and coneDistortionVBO and beamDistortionVBO
end


---InitializeDistortion(distortionTable, unitID)
---Takes a distortion definition table, and tries to check wether its already been initialized, if not, it inits it in-place
---@param distortionTable table
---@param unitID number
local function InitializeDistortion(distortionTable, unitID)
	if not distortionTable.initComplete then  -- late init
		-- do the table to flattable conversion, if it doesnt exist yet
		if not distortionTable.distortionParamTable then -- perform correct init
			local distortionparams = {}
			for i = 1, distortionParamTableSize do distortionparams[i] = 0 end
			if distortionTable.distortionConfig == nil then Spring.Debug.TraceFullEcho() end
			for paramname, tablepos in pairs(distortionParamKeyOrder) do
				if paramname == "effectType" and type(distortionTable.distortionConfig[paramname]) == 'string' then
					distortionparams[tablepos] = distortionEffectTypes[distortionTable.distortionConfig[paramname]] or distortionparams[tablepos]
				else
					distortionparams[tablepos] = distortionTable.distortionConfig[paramname] or distortionparams[tablepos]
				end
			end
			--distortionparams[distortionParamKeyOrder.radius] = distortionparams[distortionParamKeyOrder.radius]
			--distortionparams[distortionParamKeyOrder.a] =  distortionparams[distortionParamKeyOrder.a] or 1
			distortionparams[distortionParamKeyOrder.lifeTime] = math.floor( distortionparams[distortionParamKeyOrder.lifeTime] ) or 0
			distortionparams[distortionParamKeyOrder.noiseStrength] = distortionTable.distortionConfig.noiseStrength or 1
			distortionparams[distortionParamKeyOrder.noiseScaleSpace] = distortionTable.distortionConfig.noiseScaleSpace or 1
			distortionparams[distortionParamKeyOrder.distanceFalloff] = distortionTable.distortionConfig.distanceFalloff or 1
			distortionparams[distortionParamKeyOrder.effectStrength] = distortionTable.distortionConfig.effectStrength or 1
			local startRadius = distortionTable.distortionConfig.startRadius
			if startRadius then
				if (startRadius > 0) and (startRadius < 1 ) then
					startRadius = startRadius * (distortionTable.distortionConfig.radius or 100)
				end
				distortionparams[distortionParamKeyOrder.startRadius] = startRadius
			else
				distortionparams[distortionParamKeyOrder.startRadius] = distortionTable.distortionConfig.radius or 100
			end
			
			--distortionparams[distortionParamKeyOrder.startRadius] = startRadius

			distortionTable.distortionParamTable = distortionparams
			--distortionTable.distortionConfig = nil -- never used again after initialization
			local cnt = 0
			for k,v in pairs(distortionTable.distortionParamTable) do
				cnt = cnt +1 
			end
			if cnt ~= distortionParamTableSize then
					
				for k,v in pairs(distortionTable.distortionParamTable) do
					Spring.Echo(k,v) 
				end
				Spring.Echo("DistortionTable size mismatch", cnt, distortionParamTableSize)
				Spring.Echo(distortionTable)
			end

		end
		if unitID then
			local unitDefID = Spring.GetUnitDefID(unitID)
			if unitDefID and not unitDefPeiceMapCache[unitDefID] then
				unitDefPeiceMapCache[unitDefID] = Spring.GetUnitPieceMap(unitID)
			end
			local pieceMap = unitDefPeiceMapCache[unitDefID]

			if pieceMap == nil or unitDefID == nil then
				return false
				--Spring.Debug.TraceFullEcho(nil,nil,nil,"InitializeDistortion, pieceMap == nil")
			end

			if pieceMap[distortionTable.pieceName] then -- if its not a real piece, it will default to the model worldpos!
				distortionTable.pieceIndex = pieceMap[distortionTable.pieceName]
				distortionTable.distortionParamTable[pieceIndexPos] = distortionTable.pieceIndex
			end
				--Spring.Echo(distortionname, distortionParams.pieceName, pieceMap[distortionParams.pieceName])
		end

		distortionTable.initComplete = true
	end
	return true
end

--------------------------------------------------------------------------------

---calcDistortionExpiry(targetVBO, distortionParamTable, instanceID)
---Calculates the gameframe that a distortion might expire at, and if it will, then it places it into the removal queue
local function calcDistortionExpiry(targetVBO, distortionParamTable, instanceID)
	if distortionParamTable[18] <= 0 then -- lifeTime less than 0 means never expires
		return nil
	end
	local deathtime = math_ceil(distortionParamTable[17] + distortionParamTable[18])
	if distortionRemoveQueue[deathtime] == nil then
		distortionRemoveQueue[deathtime] = {}
	end
	distortionRemoveQueue[deathtime][instanceID] = targetVBO
	return deathtime
end

---AddDistortion(instanceID, unitID, pieceIndex, targetVBO, distortionparams, noUpload)
---Note that instanceID can be nil if an auto-generated one is OK.
---If the distortion is not attached to a unit, and its lifeTime is > 0, then it will be automatically added to the removal queue
---TODO: is spawnframe even a good idea here, as it might fuck with updates, and is the only thing that doesnt have to be changed
---@param instanceID any usually nil, supply an existing instance ID if you want to update an existing distortion,
---@param unitID nil if worldpos, supply valid unitID if you want to attach it to something
---@param pieceIndex number if worldpos, supply valid piece index  if you want to attach it to something, 0 attaches to world offset
---@param targetVBO table specify which one you want it to
---@param distortionparams table a valid table of distortion parameters
---@param noUpload bool true if it shouldnt be uploaded to gpu yet
---@return instanceID for future reuse
local function AddDistortion(instanceID, unitID, pieceIndex, targetVBO, distortionparams, noUpload)
	if instanceID == nil then
		autoDistortionInstanceID = autoDistortionInstanceID + 1
		instanceID = autoDistortionInstanceID
	end
	distortionparams[spawnFramePos] = gameFrame -- this might be problematic, as we will be modifying a table
	distortionparams[pieceIndexPos] = pieceIndex or 0
	--tracy.ZoneBeginN("pushElementInstance")
	instanceID = pushElementInstance(targetVBO, distortionparams, instanceID, true, noUpload, unitID)
	--tracy.ZoneEnd()
	if distortionparams[18] > 0 then
		calcDistortionExpiry(targetVBO, distortionparams, instanceID) -- This will add distortions that have >0 lifeTime to the removal queue
	end
	if unitID then
		if unitAttachedDistortions[unitID] == nil then
			unitAttachedDistortions[unitID] = {[instanceID] = targetVBO}
		else
			unitAttachedDistortions[unitID][instanceID] = targetVBO
		end
	end
	numAddDistortions = numAddDistortions + 1
	return instanceID
end

---updateDistortionPosition(distortionVBO, instanceID, posx, posy, posz, radius, p2x, p2y, p2z, theta)
---This function is for internal use only, to update the position of a distortion.
---Only use if you know the consequences of updating a VBO in-place!
local function updateDistortionPosition(distortionVBO, instanceID, posx, posy, posz, radius, p2x, p2y, p2z, theta)
	local instanceIndex = distortionVBO.instanceIDtoIndex[instanceID]
	if instanceIndex == nil then return nil end
	instanceIndex = (instanceIndex - 1 ) * distortionVBO.instanceStep
	local instData = distortionVBO.instanceData
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
	distortionVBO.dirty = true
	return instanceIndex
end

-- multiple distortions per unitdef/piece are possible, as the distortions are keyed by distortionname

local function AddStaticDistortionsForUnit(unitID, unitDefID, noUpload, reason)
	if unitDefDistortions[unitDefID] then
		if Spring.GetUnitIsBeingBuilt(unitID) then return end
		local unitDefDistortion = unitDefDistortions[unitDefID]
		if unitDefDistortion.initComplete ~= true then  -- late init
			for distortionname, distortionParams in pairs(unitDefDistortion) do
				if not InitializeDistortion(distortionParams, unitID) then return end
			end
			unitDefDistortion.initComplete = true
		end
		for distortionname, distortionParams in pairs(unitDefDistortion) do
			if distortionname ~= 'initComplete' then
				local targetVBO = unitDistortionVBOMap[distortionParams.distortionType]

				if (not spec) and distortionParams.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then return end
				AddDistortion(tostring(unitID) ..  distortionname, unitID, distortionParams.pieceIndex, targetVBO, distortionParams.distortionParamTable, noUpload)
			end
		end
	end
end

---RemoveUnitAttachedDistortions(unitID, instanceID)
---Removes all or 1 distortion attached to a unit
---@param unitID the unit to remove distortions from
---@param instanceID which distortion to remove, if nil, then all distortions will be removed
---@returns the number of distortions that got removed
local function RemoveUnitAttachedDistortions(unitID, instanceID)
	local numremoved = 0
	if unitAttachedDistortions[unitID] then
		if instanceID and unitAttachedDistortions[unitID][instanceID] then
			popElementInstance(unitAttachedDistortions[unitID][instanceID],instanceID)
			numremoved = numremoved + 1
			unitAttachedDistortions[unitID][instanceID] = nil
		else
			for instanceID, targetVBO in pairs(unitAttachedDistortions[unitID]) do
				if targetVBO.instanceIDtoIndex[instanceID] then
					numremoved = numremoved + 1
					popElementInstance(targetVBO,instanceID)
				else
					--Spring.Echo("Distortion attached to unit no longer is in targetVBO", unitID, instanceID, targetVBO.myName)
				end
			end
			--Spring.Echo("Removed distortions from unitID", unitID, numremoved, successes)
			unitAttachedDistortions[unitID] = nil
		end
	else
		--Spring.Echo("RemoveUnitAttachedDistortions: No distortions attached to", unitID)
	end
	return numremoved
end

---RemoveDistortion(distortionshape, instanceID, unitID)
---Remove a distortion
---@param distortionshape string 'point'|'beam'|'cone'
---@param instanceID any the ID of the distortion to remove
---@param unitID number make this non-nil to remove it from a unit
---@returns the same instanceID on success, nil if the distortion was not found
local function RemoveDistortion(distortionshape, instanceID, unitID, noUpload)
	if unitID then
		if unitAttachedDistortions[unitID] and unitAttachedDistortions[unitID][instanceID] then
			local targetVBO = unitAttachedDistortions[unitID][instanceID]
			unitAttachedDistortions[unitID][instanceID] = nil
			return popElementInstance(targetVBO, instanceID)
		else
			Spring.Echo("RemoveDistortion tried to remove a non-existing unitdistortion", distortionshape, instanceID, unitID)
		end
	elseif distortionshape then
		return popElementInstance(distortionVBOMap[distortionshape], instanceID)
	else
		Spring.Echo("RemoveDistortion tried to remove a non-existing distortion", distortionshape, instanceID, unitID)
	end
	return nil
end


local function LoadDistortionConfig()
	local effectTypes = {}
	local function findeffecttypes(t, res)
		if not autoupdate then return end
		for k, v in pairs(t) do 
			if type(v) == 'table' then
				findeffecttypes(v, res)
			elseif k == 'effectType' then
				res[v] = (res[v] or 0) + 1
			end
		end
		return res
	end
	local success, result =	pcall(VFS.Include, 'luaui/configs/DistortionGL4Config.lua')
	--Spring.Echo("Loading GL4 distortion config", success, result)
	if success then
		--Spring.Echo("Loaded GL4 distortion config")
		unitDefDistortions = result.unitDefDistortions
		unitEventDistortions = result.unitEventDistortions
		featureDefDistortions = result.featureDefDistortions
		--projectileDefDistortions = result.projectileDefDistortions
		findeffecttypes(unitDefDistortions, effectTypes)
		findeffecttypes(unitEventDistortions, effectTypes)
		findeffecttypes(featureDefDistortions, effectTypes)

	else
		Spring.Echo("Failed to load GL4 Unit distortion config", success, result)
	end

	local success2, result2 =	pcall(VFS.Include, 'luaui/configs/DistortionGL4WeaponsConfig.lua')
	--Spring.Echo("Loading GL4 weapon distortion config", success2, result2)
	if success2 then
		gibDistortion = result2.gibDistortion
		InitializeDistortion(gibDistortion)

		muzzleFlashDistortions = result2.muzzleFlashDistortions
		for weaponID, distortionList in pairs(muzzleFlashDistortions) do
			for i, distortionTable in pairs(distortionList) do
				InitializeDistortion(distortionTable)
			end
		end

		explosionDistortions = result2.explosionDistortions
		for weaponID, distortionList in pairs(explosionDistortions) do
			for i, distortionTable in pairs(distortionList) do
				InitializeDistortion(distortionTable)
			end
		end

		projectileDefDistortions = result2.projectileDefDistortions
		for weaponID, distortionTable in pairs(projectileDefDistortions) do
			InitializeDistortion(distortionTable)
		end
		
		findeffecttypes(gibDistortion, effectTypes)
		findeffecttypes(muzzleFlashDistortions, effectTypes)
		findeffecttypes(explosionDistortions, effectTypes)
		findeffecttypes(projectileDefDistortions, effectTypes)
	else
		Spring.Echo("Failed to load GL4 weapon distortion config", success2, result2)
	end
	if autoupdate and false then 
		Spring.Echo("GL4 Distortion effect types found:")
		for k,v in pairs(effectTypes) do
			Spring.Echo(k,v)
		end
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
	if targetable[weaponID] and py-7300 > Spring.GetGroundHeight(px, pz) then	-- dont add distortion to (likely) intercepted explosions (mainly to curb nuke flashes)
		return
	end
	if explosionDistortions[weaponID] then
		for i, distortion in pairs(explosionDistortions[weaponID]) do
			local distortionParamTable = distortion.distortionParamTable
			if distortion.alwaysVisible or spIsSphereInView(px,py,pz, distortionParamTable[4]) then
				local groundHeight = spGetGroundHeight(px,pz) or 1
				py = math_max(groundHeight + (distortion.yOffset or 0), py)
				distortionParamTable[1] = px
				distortionParamTable[2] = py
				distortionParamTable[3] = pz
				AddDistortion(nil, nil, nil, pointDistortionVBO, distortionParamTable) --(instanceID, unitID, pieceIndex, targetVBO, distortionparams, noUpload)
			end
		end
	end
end

function widget:Barrelfire(px, py, pz, weaponID, ownerID)
	if muzzleFlashDistortions[weaponID] then
		for i, distortion in pairs(muzzleFlashDistortions[weaponID]) do
			local distortionParamTable = distortion.distortionParamTable
			if distortion.alwaysVisible or spIsSphereInView(px,py,pz, distortionParamTable[4]) then
				local groundHeight = spGetGroundHeight(px,pz) or 1
				distortionParamTable[1] = px
				distortionParamTable[2] = py
				distortionParamTable[3] = pz
				AddDistortion(nil, nil, nil, pointDistortionVBO, distortionParamTable) --(instanceID, unitID, pieceIndex, targetVBO, distortionparams, noUpload)
			end
		end
	end
end

local function UnitScriptDistortion(unitID, unitDefID, distortionIndex, param)
	--Spring.Echo("UnitSCriptDistortion", unitID, unitDefID, distortionIndex, param, visibleUnits[unitID] )
	if spValidUnitID(unitID) and spGetUnitIsDead(unitID) == false and visibleUnits[unitID] and unitEventDistortions.UnitScriptDistortions[unitDefID] and unitEventDistortions.UnitScriptDistortions[unitDefID][distortionIndex] then
		local distortionTable = unitEventDistortions.UnitScriptDistortions[unitDefID][distortionIndex]
		if not distortionTable.alwaysVisible then
			local px,py,pz = spGetUnitPosition(unitID)
			if px == nil or spIsSphereInView(px,py,pz, distortionTable[4]) == false then return end
		end
		if (not spec) and distortionTable.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then return end
		if distortionTable.initComplete == nil then InitializeDistortion(distortionTable, unitID) end
		local instanceID = tostring(unitID) .. "_" .. tostring(unitName[unitDefID]) .. "UnitScriptDistortion" .. tostring(distortionIndex) .. "_" .. tostring(param)
		AddDistortion(instanceID, unitID, distortionTable.pieceIndex, unitDistortionVBOMap[distortionTable.distortionType], distortionTable.distortionParamTable)
	end
end

local function GetDistortionVBO(vboName)
	return nil
end



function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	visibleUnits[unitID] = unitDefID
	AddStaticDistortionsForUnit(unitID, unitDefID, false, "VisibleUnitAdded")
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(unitPointDistortionVBO) -- clear all instances
	InstanceVBOTable.clearInstanceTable(unitBeamDistortionVBO) -- clear all instances
	InstanceVBOTable.clearInstanceTable(unitConeDistortionVBO) -- clear all instances
	visibleUnits = {}

	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
		AddStaticDistortionsForUnit(unitID, unitDefID, true, "VisibleUnitsChanged") -- add them with noUpload = true
	end
	uploadAllElements(unitPointDistortionVBO) -- upload them all
	uploadAllElements(unitBeamDistortionVBO) -- upload them all
	uploadAllElements(unitConeDistortionVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove all the distortions for this unit
	--if debugmode then Spring.Debug.TraceEcho("remove",unitID,reason) end
	RemoveUnitAttachedDistortions(unitID)
	visibleUnits[unitID] = nil
end

function widget:Shutdown()
	-- TODO: delete the VBOs and shaders like a good boy
	WG['distortionsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddDistortion')
	widgetHandler:DeregisterGlobal('RemoveDistortion')

	widgetHandler:DeregisterGlobal('UnitScriptDistortion')

	deferredDistortionShader:Delete()
	local ram = 0
	for distortiontype, vbo in pairs(unitDistortionVBOMap) do ram = ram + vbo:Delete() end
	for distortiontype, vbo in pairs(projectileDistortionVBOMap) do ram = ram + vbo:Delete() end
	for distortiontype, vbo in pairs(distortionVBOMap) do ram = ram + vbo:Delete() end

	--Spring.Echo("distortionGL4 ram usage MB = ", ram / 1000000)
	--Spring.Echo("featureDefDistortions", table.countMem(featureDefDistortions))
	--Spring.Echo("unitEventDistortions", table.countMem(unitEventDistortions))
	--Spring.Echo("unitDefDistortions", table.countMem(unitDefDistortions))
	--Spring.Echo("projectileDefDistortions", table.countMem(projectileDefDistortions))
	--Spring.Echo("explosionDistortions", table.countMem(explosionDistortions))

	-- Note, these must be nil'ed manually, because
	-- tables included from VFS.Include dont get GC'd unless specifically nil'ed
	unitDefDistortions = nil
	featureDefDistortions = nil
	unitEventDistortions = nil
	muzzleFlashDistortions = nil
	projectileDefDistortions = nil
	explosionDistortions  = nil
	gibDistortion = nil

	--collectgarbage("collect")
	--collectgarbage("collect")

end

local windX = 0
local windZ = 0

function widget:GameFrame(n)
	gameFrame = n
	local windDirX, _, windDirZ, windStrength = Spring.GetWind()
	--windStrength = math.min(20, math.max(3, windStrength))
	--Spring.Echo(windDirX,windDirZ,windStrength)
	windX = windX + windDirX * 0.016 -- this is not smooth, should be smoothed on update with timeOffset!
	windZ = windZ + windDirZ * 0.016
	if distortionRemoveQueue[n] then
		for instanceID, targetVBO in pairs(distortionRemoveQueue[n]) do
			if targetVBO.instanceIDtoIndex[instanceID] then
				--Spring.Echo("removing dead distortion", targetVBO.usedElements, 'id:', instanceID)
				popElementInstance(targetVBO, instanceID)
			end
		end
		distortionRemoveQueue[n] = nil
	end
end

-- This should simplify adding all kinds of events
-- You are permitted to define as many distortions as you wish, but its probably stupid to do so.
local function eventDistortionSpawner(eventName, unitID, unitDefID, teamID)
	if spValidUnitID(unitID) and spGetUnitIsDead(unitID) == false and unitEventDistortions[eventName] then
		if unitEventDistortions[eventName] then
			-- get the default event if it is defined
			local distortionList =  unitEventDistortions[eventName][unitDefID] or unitEventDistortions[eventName]['default']
			if distortionList then
				for distortionname, distortionTable in pairs(distortionList) do
					local visible = distortionTable.alwaysVisible
					local px,py,pz = spGetUnitPosition(unitID)
					if not visible then
						if px and spIsSphereInView(px,py,pz, distortionTable[4]) then visible = true end
					end

					-- bail if only for allies
					if (not spec) and distortionTable.alliedOnly == true and Spring.IsUnitAllied(unitID) == false then
						visible = false
					end

					-- bail if unable to initialize distortion
					if not distortionTable.initComplete then
						if not InitializeDistortion(distortionTable, unitID) then
							visible = false
						end
					end

					-- bail if invalid unitID wants a unit-attached distortion
					if distortionTable.pieceName and (visibleUnits[unitID] == nil) then
						visible = false
					end

					if visible then
						--if distortionTable.aboveUnit then distortionTable.distortionParamTable end
						local distortionParamTable = distortionTable.distortionParamTable
						if distortionTable.pieceName then
							if distortionTable.aboveUnit then -- if its above the unit, then add the aboveunit offset to the units height too!
								-- this is done via a quick copy of the table
								for i=1, distortionParamTableSize do distortionCacheTable[i] = distortionParamTable[i] end
								local unitHeight = Spring.GetUnitHeight(unitID)
								if unitHeight == nil then
									local losstate = Spring.GetUnitLosState(unitID)
									Spring.Echo("Unitheight is nil for unitID", unitID, "unitDefName", unitName[unitDefID], eventName, distortionname, 'losstate', losstate and losstate.los)
								end

								distortionCacheTable[2] = distortionCacheTable[2] + distortionTable.aboveUnit + (unitHeight or 0)
								distortionParamTable = distortionCacheTable
							end
							AddDistortion(eventName .. tostring(unitID) ..  distortionname, unitID, distortionTable.pieceIndex, unitDistortionVBOMap[distortionTable.distortionType], distortionParamTable)
						else
							for i=1, distortionParamTableSize do distortionCacheTable[i] = distortionParamTable[i] end
							distortionCacheTable[1] = distortionCacheTable[1] + px
							distortionCacheTable[2] = distortionParamTable[2] + py + ((distortionTable.aboveUnit and Spring.GetUnitHeight(unitID)) or 0)
							distortionCacheTable[3] = distortionCacheTable[3] + pz
							AddDistortion(eventName .. tostring(unitID) ..  distortionname, nil, distortionTable.pieceIndex, distortionVBOMap[distortionTable.distortionType], distortionCacheTable)
						end
					end

				end
			end
		end
	end
end

-- Below are the registered spawners for events
function widget:UnitIdle(unitID, unitDefID, teamID) -- oh man we need a sane way to handle height :D
	eventDistortionSpawner("UnitIdle", unitID, unitDefID, teamID)
end
function widget:UnitFinished(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitFinished", unitID, unitDefID, teamID)
end
function widget:UnitCreated(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitCreated", unitID, unitDefID, teamID)
end
function widget:UnitFromFactory(unitID, unitDefID, unitTeam, factID, factDefID, userOrders)
	eventDistortionSpawner("UnitFromFactory", unitID, unitDefID, teamID)  -- i have no idea of the differences here
	eventDistortionSpawner("UnitFromFactoryBuilder", factID, factDefID, teamID)
end
function widget:UnitDestroyed(unitID, unitDefID, teamID) -- dont do piece-attached distortions here!
	eventDistortionSpawner("UnitDestroyed", unitID, unitDefID, teamID)
end
function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemoveUnitAttachedDistortions(unitID)
end

-- THIS ONE DOESNT WORK, some shit is being pulled and i cant get the unit height of the unit being taken here!
--function widget:UnitTaken(unitID, unitDefID, teamID)
	--eventDistortionSpawner("UnitTaken", unitID, unitDefID, teamID)
--end
function widget:UnitGiven(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitGiven", unitID, unitDefID, teamID)
end
function widget:UnitCloaked(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitCloaked", unitID, unitDefID, teamID)
end
function widget:UnitDecloaked(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitDecloaked", unitID, unitDefID, teamID)
end
function widget:UnitMoveFailed(unitID, unitDefID, teamID)
	eventDistortionSpawner("UnitMoveFailed", unitID, unitDefID, teamID)
end

function widget:StockpileChanged(unitID, unitDefID, teamID, weaponNum, oldCount, newCount)
	if newCount > oldCount then
		eventDistortionSpawner("StockpileChanged", unitID, unitDefID, teamID)
	end
end

function widget:FeatureCreated(featureID,allyteam)
	-- TODO: Allow team-colored feature distortions by getting teamcolor and putting it into distortionCacheTable
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefDistortions[featureDefID] then
		for distortionname, distortionTable in pairs(featureDefDistortions[featureDefID]) do
			if not distortionTable.initComplete then InitializeDistortion(distortionTable) end
			local px, py, pz = Spring.GetFeaturePosition(featureID)
			if px then

				local distortionParamTable = distortionTable.distortionParamTable
				for i=1, distortionParamTableSize do distortionCacheTable[i] = distortionParamTable[i] end
				distortionCacheTable[1] = distortionCacheTable[1] + px
				distortionCacheTable[2] = distortionCacheTable[2] + py
				distortionCacheTable[3] = distortionCacheTable[3] + pz
				AddDistortion(tostring(featureID) ..  distortionname, nil, nil, distortionVBOMap[distortionTable.distortionType], distortionCacheTable)
			end
		end
	end
end

function widget:FeatureDestroyed(featureID)
	local featureDefID = Spring.GetFeatureDefID(featureID)
	if featureDefDistortions[featureDefID] then
		for distortionname, distortionTable in pairs(featureDefDistortions[featureDefID]) do
			RemoveDistortion(distortionTable.distortionType, tostring(featureID) ..  distortionname)
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


local function updateProjectileDistortions(newgameframe)
	local nowprojectiles = Spring.GetVisibleProjectiles()
	gameFrame = Spring.GetGameFrame()
	local newgameframe = true
	if gameFrame == lastGameFrame then newgameframe = false end
	--Spring.Echo(gameFrame, lastGameFrame, newgameframe)
	lastGameFrame = gameFrame
	-- turn off uploading vbo
	-- one known issue regarding to every gameframe respawning distortions is to actually get them to update existing dead distortion candidates, this is very very hard to do sanely
	-- BUG: having a lifeTime associated with each projectile kind of bugs out updates
	local numadded = 0
	local noUpload = true
	for i= 1, #nowprojectiles do
		local projectileID = nowprojectiles[i]
		local px, py, pz = spGetProjectilePosition(projectileID)
		if px then -- we are somehow getting projectiles with no position?
			local distortionType = 'point' -- default
			if trackedProjectiles[projectileID] then
				if newgameframe then
					--update proj pos
					distortionType = trackedProjectileTypes[projectileID]
					if distortionType ~= 'beam' then
						local dx,dy,dz = spGetProjectileVelocity(projectileID)
						local instanceIndex = updateDistortionPosition(projectileDistortionVBOMap[distortionType],
							projectileID, px,py,pz, nil, dx,dy,dz)
						if debugproj then Spring.Echo("Updated", instanceIndex, projectileID, px, py, pz,dx,dy,dz) end
					end

				end
			else
				-- add projectile
				local weapon, piece = spGetProjectileType(projectileID)
				if piece then
					local explosionflags = spGetPieceProjectileParams(projectileID)
					local gib = gibDistortion.distortionParamTable
					gib[1] = px
					gib[2] = py
					gib[3] = pz
					AddDistortion(projectileID, nil, nil, projectilePointDistortionVBO, gib, noUpload)
				else
					local weaponDefID = spGetProjectileDefID ( projectileID )
					if projectileDefDistortions[weaponDefID] and ( projectileID % (projectileDefDistortions[weaponDefID].fraction or 1) == 0 ) then
						local distortionParamTable = projectileDefDistortions[weaponDefID].distortionParamTable
						distortionType = projectileDefDistortions[weaponDefID].distortionType


						distortionParamTable[1] = px
						distortionParamTable[2] = py
						distortionParamTable[3] = pz
						if debugproj then Spring.Echo(distortionType, projectileDefDistortions[weaponDefID].distortionClassName) end

						local dx,dy,dz = spGetProjectileVelocity(projectileID)

						if distortionType == 'beam' then
							distortionParamTable[5] = px + dx
							distortionParamTable[6] = py + dy
							distortionParamTable[7] = pz + dz
						else
							-- for points and cones, velocity gives the pointing dir, and for cones it gives the pos super well.
							distortionParamTable[5] = dx
							distortionParamTable[6] = dy
							distortionParamTable[7] = dz
						end
						if debugproj then Spring.Echo(distortionType, px,py,pz, dx, dy,dz) end

						AddDistortion(projectileID, nil, nil, projectileDistortionVBOMap[distortionType], distortionParamTable,noUpload)
						--AddDistortion(projectileID, nil, nil, projectilePointDistortionVBO, distortionParamTable)
					else
						--Spring.Echo("No projectile distortion defined for", projectileID, weaponDefID, px, pz)
					end
				end
				numadded = numadded + 1
				if debugproj then Spring.Echo("Adding projdistortion", projectileID, Spring.GetProjectileName(projectileID)) end
				--trackedProjectiles[]
				trackedProjectileTypes[projectileID] = distortionType
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
				local distortionType = trackedProjectileTypes[projectileID]
				if newgameframe and distortionType ~= 'beam' then
					local dx,dy,dz = spGetProjectileVelocity(projectileID)
					updateDistortionPosition(projectileDistortionVBOMap[distortionType],
						projectileID, px,py,pz, nil, dx,dy,dz )
				end
			else
				numremoved = numremoved + 1
				trackedProjectiles[projectileID] = nil
				local distortionType = trackedProjectileTypes[projectileID]
				--RemoveDistortion('point', projectileID, nil)
				if projectileDistortionVBOMap[distortionType].instanceIDtoIndex[projectileID] then -- god the indirections here ...
					local success = popElementInstance(projectileDistortionVBOMap[distortionType], projectileID, noUpload)
					if success == nil then PrintProjectileInfo(projectileID) end
				end
				trackedProjectileTypes[projectileID] = nil
			end
		end
	end
	-- upload all changed elements in one go
	for _, targetVBO in pairs(projectileDistortionVBOMap) do
		if targetVBO.dirty then
			uploadAllElements(targetVBO)
		end
	end
	--if debugproj then
	--	Spring.Echo("#points", projectilePointDistortionVBO.usedElements, '#projs', #nowprojectiles )
	--end
end

local configCache = {lastUpdate = Spring.GetTimer()}
local function checkConfigUpdates()
	if Spring.DiffTimers(Spring.GetTimer(), configCache.lastUpdate) > 0.5 then
		local newconfa = VFS.LoadFile('luaui/configs/DistortionGL4Config.lua')
		local newconfb = VFS.LoadFile('luaui/configs/DistortionGL4WeaponsConfig.lua')
		if newconfa ~= configCache.confa or newconfb ~= configCache.confb then
			LoadDistortionConfig()
			if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
				widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
			end
			configCache.confa = newconfa
			configCache.confb = newconfb
			Spring.Echo("DistortionGL4: Config updated")
		end
		configCache.lastUpdate = Spring.GetTimer()
	end
end

function widget:Update(dt)
	if autoupdate then checkConfigUpdates() end
	local tus = Spring.GetTimerMicros()

	updateProjectileDistortions()
end

------------------------------- Drawing all the distortions ---------------------------------


local function DrawDistortionFunction2(gf) -- For render-to-texture
		-- Set is as black with zero alpha
		gl.Clear(GL.COLOR_BUFFER_BIT, 0.0, 0.0, 0.0, 0.0)

		local alt, ctrl = Spring.GetModKeyState()

		--if autoupdate and ctrl and (isSinglePlayer or spec) and (Spring.GetConfigInt('DevUI', 0) == 1) then
		--	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
		--else
		--end
		-- So we are gonna multiply each effect with its own alpha, and then add them together on the destination
		-- This means we also will be ignoring the destination alpha channel. 
		-- The default blending function is GL_FUNC_ADD
		glBlending(GL.SRC_ALPHA, GL.ONE)
		--if autoupdate and alt and (isSinglePlayer or spec) and devui then return end

		gl.Culling(false)
		gl.DepthTest(false)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, "$map_gbuffer_zvaltex")
		glTexture(1, "$model_gbuffer_zvaltex")
		glTexture(2, "$map_gbuffer_normtex")
		glTexture(3, "$model_gbuffer_normtex")
		glTexture(4, "$map_gbuffer_difftex")
		glTexture(5, "$model_gbuffer_difftex")
		glTexture(6, noisetex3dcube)
		if shaderConfig.UNIFORMSBUFFERCOPY then 
			local UniformsBufferCopy = WG['api_unitbufferuniform_copy'].GetUnitUniformBufferCopy()
			if not UniformsBufferCopy then
				Spring.Echo("DistortionGL4: UniformsBufferCopy not found")
				return
			end
			
			UniformsBufferCopy:BindBufferRange(4)
		end

		deferredDistortionShader:Activate()
		deferredDistortionShader:SetUniformFloat("nightFactor", nightFactor)

		deferredDistortionShader:SetUniformFloat("intensityMultiplier", intensityMultiplier)
		deferredDistortionShader:SetUniformFloat("radiusMultiplier", radiusMultiplier)
		deferredDistortionShader:SetUniformFloat("windXZ", windX, windZ)
	

		-- Fixed worldpos distortions, cursors, projectiles, world distortions
		deferredDistortionShader:SetUniformFloat("attachedtounitID", 0) -- worldpos stuff
		deferredDistortionShader:SetUniformFloat("pointbeamcone", 0)

		pointDistortionVBO:draw()
		projectilePointDistortionVBO:draw()


		deferredDistortionShader:SetUniformFloat("pointbeamcone", 1)
		beamDistortionVBO:draw()
		projectileBeamDistortionVBO:draw()

		deferredDistortionShader:SetUniformFloat("pointbeamcone", 2)
		coneDistortionVBO:draw()
		projectileConeDistortionVBO:draw()

		-- Unit Attached Distortions
		deferredDistortionShader:SetUniformFloat("attachedtounitID", 1)

		deferredDistortionShader:SetUniformFloat("pointbeamcone", 0)
		unitPointDistortionVBO:draw()

		deferredDistortionShader:SetUniformFloat("pointbeamcone", 1)
		unitBeamDistortionVBO:draw()

		deferredDistortionShader:SetUniformFloat("pointbeamcone", 2)
		unitConeDistortionVBO:draw()

		deferredDistortionShader:Deactivate()

		for i = 0, 6 do glTexture(i, false) end
		gl.Culling(GL.BACK)
		gl.DepthTest(true)
		--gl.DepthMask(true) --"BK OpenGL state resets", was true but now commented out (redundant set of false states)
		glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
end

-- local tf = Spring.GetTimerMicros()
function widget:DrawWorld() -- We are drawing in world space, probably a bad idea but hey
	--local t0 = Spring.GetTimerMicros()
	--if true then return end
	if skipdraw then return end
	if autoupdate then
		deferredDistortionShader = LuaShader.CheckShaderUpdates(distortionShaderSourceCache, 0) or deferredDistortionShader
	end

	local hasAtLeastOneDistortion = 
		pointDistortionVBO.usedElements > 0 or
		beamDistortionVBO.usedElements > 0 or
		coneDistortionVBO.usedElements > 0 or
		unitPointDistortionVBO.usedElements > 0 or
		unitBeamDistortionVBO.usedElements > 0 or
		unitConeDistortionVBO.usedElements > 0 or
		projectilePointDistortionVBO.usedElements > 0 or 
		projectileBeamDistortionVBO.usedElements > 0 or 
		projectileConeDistortionVBO.usedElements > 0

	if (not hasAtLeastOneDistortion) then return end
	
	tracy.ZoneBeginN("CopyToTexture")
	-- Blend the distortion:
	gl.CopyToTexture(ScreenCopy, 0, 0, vpx, vpy, vsx, vsy)
	tracy.ZoneEnd() 



	gl.RenderToTexture(DistortionTexture, DrawDistortionFunction2, Spring.GetGameFrame())
	--tracy.ZoneEnd()
	tracy.ZoneBeginN("CombineDistortion")
	-- Combine the distortion with the scene:
	if autoupdate then
		screenDistortionShader = LuaShader.CheckShaderUpdates(screenDistortionShaderSourceCache, 0) or screenDistortionShader
	end

	gl.Texture(0, "$map_gbuffer_zvaltex")
	gl.Texture(1, "$model_gbuffer_zvaltex")
	gl.Texture(2, ScreenCopy)
	gl.Texture(3, DistortionTexture)
	glBlending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA)
	gl.Culling(false) -- ffs
	gl.DepthTest(false)
	gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
	--Spring.Echo("Drawing Distortion")
	screenDistortionShader:Activate()
	
	screenDistortionShader:SetUniformFloat("inverseScreenResolution", 1/vsx, 1/vsy)
	screenDistortionShader:SetUniformFloat("distortionOverallStrength", 1)
	fullScreenQuadVAO:DrawArrays(GL.TRIANGLES)
	screenDistortionShader:Deactivate()
	
	for i = 0,3 do gl.Texture(i, false) end
	tracy.ZoneEnd()

	
	gl.DepthTest(true)
	--local t1 = 	Spring.GetTimerMicros()
	--if (Spring.GetDrawFrame() % 50 == 0 ) then
	--	local dt =  Spring.DiffTimers(t1,t0)
	--	Spring.Echo("Deltat is ", dt,'us, so total load should be', dt * Spring.GetFPS() / 10 ,'%')
	--	Spring.Echo("epoch is ", Spring.DiffTimers(t1,tf))
	--end
end

if autoupdate then
	function widget:DrawScreen()
		--Spring.Echo("DrawScreen", deferredDistortionShader.DrawPrintf)
		if deferredDistortionShader.DrawPrintf then deferredDistortionShader.DrawPrintf(0) end
	end
end

-- Register /luaui distortionGL4stats to dump distortion statistics
function widget:TextCommand(command)
	if string.find(command, "distortionGL4stats", nil, true) then
		Spring.Echo(string.format("distortionGL4Stats Total = %d , (PBC=%d,%d,%d), (unitPBC=%d,%d,%d), (projPBC=%d,%d,%d)",
				numAddDistortions,
				pointDistortionVBO.usedElements, beamDistortionVBO.usedElements, coneDistortionVBO.usedElements,
				unitPointDistortionVBO.usedElements, unitBeamDistortionVBO.usedElements, unitConeDistortionVBO.usedElements,
				projectilePointDistortionVBO.usedElements, projectileBeamDistortionVBO.usedElements, projectileConeDistortionVBO.usedElements)
	)
		return true
	end
	if string.find(command, "distortionGL4skipdraw", nil, true) then
		skipdraw = not skipdraw
		Spring.Echo("Deferred Rendering GL4 skipdraw set to", skipdraw)
		return true
	end
	return false
end

function widget:Initialize()

	Spring.Debug.TraceEcho("Initialize distortionGL4")
	if Spring.GetConfigString("AllowDeferredMapRendering") == '0' or Spring.GetConfigString("AllowDeferredModelRendering") == '0' then
		Spring.Echo('Distortion GL4  requires  AllowDeferredMapRendering and AllowDeferredModelRendering to be enabled in springsettings.cfg!')
		widgetHandler:RemoveWidget()
		return
	end
	if not LoadDistortionConfig() then
		widgetHandler:RemoveWidget()
		return
	end

	if initGL4() == false then return end

	local success, mapinfo = pcall(VFS.Include,"mapinfo.lua") -- load mapinfo.lua confs

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end

	for _, featureID in ipairs(Spring.GetAllFeatures()) do
		widget:FeatureCreated(featureID)
	end

	WG['distortionsgl4'] = {}
	WG['distortionsgl4'].AddDistortion  = AddDistortion
	WG['distortionsgl4'].RemoveDistortion  = RemoveDistortion
	WG['distortionsgl4'].GetDistortionVBO  = GetDistortionVBO

	WG['distortionsgl4'].IntensityMultiplier = function(value)
		intensityMultiplier = value
	end
	WG['distortionsgl4'].RadiusMultiplier = function(value)
		radiusMultiplier = value
	end

	widgetHandler:RegisterGlobal('AddDistortion', WG['distortionsgl4'].AddDistortion)
	widgetHandler:RegisterGlobal('RemoveDistortion', WG['distortionsgl4'].RemoveDistortion)
	widgetHandler:RegisterGlobal('GetDistortionVBO', WG['distortionsgl4'].GetDistortionVBO)

	widgetHandler:RegisterGlobal('UnitScriptDistortion', UnitScriptDistortion)
end
--------------------------- Ingame Configurables -------------------

function widget:GetConfigData(_) -- Called by RemoveWidget
	local savedTable = {
		intensityMultiplier = intensityMultiplier,
		radiusMultiplier = radiusMultiplier,
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
end
