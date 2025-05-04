local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Decals GL4",
		desc = "Try to draw some nice normalmapped decals",
		author = "Beherith",
		date = "2021.11.02",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = 999,
		enabled = true,
		depends = {'gl4'},
	}
end

-- Notes and TODO
-- yes these are geometry shader decals
-- we are gonna try to smaple heightmap
-- atlasColor is diffuse + alpha
	-- The color is expected to blend up to 0.5,
-- atlasNormals is normals + emission

-- advanced geoshader tricount for quads
-- 4x4 - 40
-- KNOWN BUG:
	-- the pop-back can change the render order of decals to be a tad annoying.... maybe a better method of managing this is needed?
	-- possibly solvable via batched decal removal, a good amount of time after they become transparent?
-- TODO:
	-- use global sun params for lighting calcs
	-- DONE disable parallax
	-- DONE enable support for old-style decals
	-- paint emission
	-- soften and make large decal creation above saturation threshold more probabilistic
	-- always allow the creation of small decals
	-- DONE control parallax via config
	-- SKIP fix parallax to work
	-- DONE Validate normals
	-- DONE decal fade-in?
	-- DONE cache decal UV's
	-- Add team/clan/etc sprays
		-- determine clan from first [] of playername
		-- which can be done on initialize?
		-- cursor
	-- DONE: SHADOWS SUPPORT!
	-- FOG SUPPORT?
	-- Better LOS SUPPORT
	-- DONE: BWfactor
	-- DONE: glowsustain
	-- DONE: glowadd
	-- Fix unused decals having 1.0 alpha in normal resulting in heavy glow on zoomed out small decals bleeding
------------------------ CONFIGURABLES -----------------------------------------------

local shaderConfig = {
	HEIGHTOFFSET = 0.5, -- Additional height added to everything
	LOSDARKNESS = 0.7, -- additional LOS darken factor
	PARALLAX = 0, -- 1 for on, kinda broken, do not use
	AMBIENTOCCLUSION = 0, -- 1 for on, do not use
	USEGLOW = 1, -- 1 for on, kinda wierd at the moment
	GLOWTHRESHOLD = 0.99,
	FADEINTIME = 20, -- number of frames to fade in over
	SPECULAREXPONENT = 5.0, -- how shiny decal surface is?
	SPECULARSTRENGTH = 0.3, -- how strong specular highlights are
	--BLACKANDWHITEFACTOR = 0.5, -- set to between [0,1] to set how strong the black and white conversion should be, 0 = original color, 1 = full black and white, deprecated, now controllable per-decal
	MINIMAPCOLORBLENDFACTOR = 1, -- How much minimap color should affect decal color
	SINGLEQUADDECALSIZETHRESHOLD = 24, -- if length and width of decal is less than this, then only spawn 1 quad instead of 16
}

local groundscarsPath = "luaui/images/decals_gl4/groundscars/"	-- old: "luaui/images/decals_gl4/oldscars/"
local footprintsPath = "luaui/images/decals_gl4/footprints/"	-- old: "luaui/images/decals_gl4/oldscars/"


-- large decal resolution, 16x16 grid is ok
local resolution = 16 -- 32 is 2k tris, a tad pricey...
local largesizethreshold  = 512 -- if min(width,height)> than this, then we use the large version!
local extralargesizeThreshold = 1024 -- if min(width,height)> than this, then we use the extra large version!
local lifeTimeMult = 1.0 -- A global lifetime multiplier for configurability

local autoupdate = false -- auto update shader, for debugging only!


-- for automatic oversaturation prevention, not sure if it even works, but hey!
local areaResolution = 256 -- elmos per square, for a 64x map this is uh, big? for 32x32 its 4k
local saturationThreshold = 16 * areaResolution

------------------------ GL4 BACKEND -----------------------------------

local atlasHeights = nil

local atlas = VFS.Include("luaui/images/decals_gl4/decalsgl4_atlas_diffuse.lua")
local upperkeys = {}
for k,v in pairs(atlas) do
	if type(v) == "table" then
		if string.lower(k) ~= k then
			upperkeys[k] = true
		end
	end
end
for k,_ in pairs(upperkeys) do
	atlas[string.lower(k)] = atlas[k]
	atlas[k] = nil
end
upperkeys = nil
-- re-pad the atlas a little bit to avoid mip bleed:
--function(t,p) for k,v in pairs(t) do if type(v) == "table" then p = p or 0.5; local px,py = p/t.width, p/t.height; v[1], v[2], v[3], v[4] = v[1] + px, v[2]-px, v[3] + py, v[4] - py end end end ,

-- FIXME: Actually fix the unused scars having full white alpha (all emissive) in normal texture!
for k,v in pairs(atlas) do
	if type(v) =='table' then -- do 8/512 padding
		local px = (8/512) * v[5]/ atlas.width
		local py = (8/512) * v[6]/ atlas.height
		v[1], v[2], v[3], v[4] = v[1] + px, v[2]-px, v[3] + py, v[4] - py
	end
end

atlas.flip(atlas)

local decalVBO = nil
local decalLargeVBO = nil
local decalExtraLargeVBO = nil

local decalShader = nil
local decalLargeShader = nil


local hasBadCulling = false -- AMD+Linux combo

--------------------------- Localization for faster access -------------------

local spGetGroundHeight = Spring.GetGroundHeight
local abs = math.abs

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_LEQUAL = GL.LEQUAL



---- GL4 Backend Stuff----

local luaShaderDir = "LuaUI/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrcPath = "LuaUI/Shaders/decals_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Shaders/decals_gl4.frag.glsl"
local gsSrcPath = "LuaUI/Shaders/decals_gl4.geom.glsl"

local vsSrcLargePath = "LuaUI/Shaders/decals_large_gl4.vert.glsl"

local uniformInts =  {

	heightmapTex = 0,
	miniMapTex = 1,
	infoTex = 2,
	shadowTex = 3,
	mapNormalsTex = 4,
	atlasColorAlpha = 5,
	atlasNormals = 6,
	atlasHeights = ((shaderConfig.PARALLAX == 1) and 7 ) or nil,
	atlasORM = ((shaderConfig.AMBIENTOCCLUSION == 1) and 8 ) or nil,
	atlasRG = ((shaderConfig.USEGLOW == 1) and 9 ) or nil,
}

local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	gssrcpath = gsSrcPath,
	shaderConfig = shaderConfig,
	uniformInt = uniformInts,
	uniformFloat = {
		fadeDistance = 3000,
	},
	shaderName = "Decals Gl4 Shader",
}

local shaderLargeSourceCache = {
	vssrcpath = vsSrcLargePath,
	fssrcpath = fsSrcPath,
	shaderConfig = shaderConfig,
	uniformInt = uniformInts,
	uniformFloat = {
		fadeDistance = 3000,
	},
	shaderName = "Decals Large Gl4 Shader",
}

local function goodbye(reason)
  Spring.Echo("DrawPrimitiveAtUnits GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initGL4( DPATname)
	hasBadCulling = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == true)
	if hasBadCulling then Spring.Echo("Decals GL4 detected AMD + Linux platform, attempting to fix culling") end
	decalShader = LuaShader.CheckShaderUpdates(shaderSourceCache)
	decalLargeShader = LuaShader.CheckShaderUpdates(shaderLargeSourceCache)

	if (not decalShader) or (not decalLargeShader) then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	decalVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthrotation', size = 4},
			{id = 1, name = 'uv_atlaspos', size = 4},
			{id = 2, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 3, name = 'worldPos', size = 4},
			{id = 4, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if decalVBO == nil then goodbye("Failed to create decalVBO") end

	local smallDecalVAO = gl.GetVAO()
	smallDecalVAO:AttachVertexBuffer(decalVBO.instanceVBO)
	decalVBO.VAO = smallDecalVAO

	local planeVBO, numVertices = makePlaneVBO(1,1,resolution,resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution,resolution) --, true) -- add true to cull into a circle

	decalLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
			{id = 5, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "Large VBO" -- name
	)
	if decalLargeVBO == nil then goodbye("Failed to create decalLargeVBO") end

	decalLargeVBO.vertexVBO = planeVBO
	decalLargeVBO.indexVBO = planeIndexVBO
	decalLargeVBO.VAO = makeVAOandAttach(
		decalLargeVBO.vertexVBO,
		decalLargeVBO.instanceVBO,
		decalLargeVBO.indexVBO
	)

	planeVBO, numVertices = makePlaneVBO(1,1,resolution*4,resolution*4)
	planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution*4,resolution*4) --, true) -- add true to cull into a circle

	decalExtraLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
			{id = 5, name = 'parameters', size = 4},
		},
		64, -- maxelements
		DPATname .. "Extra Large VBO" -- name
	)
	if decalExtraLargeVBO == nil then goodbye("Failed to create decalExtraLargeVBO") end

	decalExtraLargeVBO.vertexVBO = planeVBO
	decalExtraLargeVBO.indexVBO = planeIndexVBO
	decalExtraLargeVBO.VAO = makeVAOandAttach(
		decalExtraLargeVBO.vertexVBO,
		decalExtraLargeVBO.instanceVBO,
		decalExtraLargeVBO.indexVBO
	)
	return decalLargeVBO ~= nil and decalVBO ~= nil and decalExtraLargeVBO ~= nil
end

local decalIndex = 0
local decalTimes = {} -- maps instanceID to expected fadeout timeInfo
local decalRemoveQueue = {} -- maps gameframes to list of decals that will be removed
local decalRemoveList = {} -- maps instanceID's of decals that need to be batch removed to preserve order

-----------------------------------------------------------------------------------------------
-- This part is kinda useless for now, but we could prevent or control excessive decal spam right here!

local decalToArea = {} -- maps instanceID to a position key on the map
local areaDecals = {} -- {positionkey = {decallist, totalarea},}
local floor = math.floor

local function hashPos(mapx, mapz) -- packs XZ into 1000*x + z
	if mapx == nil or mapz == nil then
		Spring.Debug.TraceFullEcho()
	end

	return floor(mapx / areaResolution) * 1000 + floor(mapz/areaResolution)
end

local function initAreas()
	for x= areaResolution /2, Game.mapSizeX, areaResolution do
		for z= areaResolution /2, Game.mapSizeZ, areaResolution do
			local gh = spGetGroundHeight(x,z)
			areaDecals[hashPos(x,z)] = {instanceIDs = {}, totalarea = 0, x = x, y = gh, z = z, smoothness = 0}
		end
	end
end

local function AddDecalToArea(instanceID, posx, posz, width, length)
	local hash = hashPos(posx,posz)
	local maparea = areaDecals[hash]
	if maparea == nil then return end
	local area = width * length
	maparea.instanceIDs[instanceID] =  area
	maparea.totalarea = maparea.totalarea + area
	decalToArea[instanceID] = hash
end

local function RemoveDecalFromArea(instanceID)
	local hashpos = decalToArea[instanceID]
	if hashpos then
		local maparea = areaDecals[hashpos]
		if maparea and maparea.instanceIDs[instanceID] then
			maparea.totalarea = math.max(0,maparea.totalarea - maparea.instanceIDs[instanceID])
			maparea.instanceIDs[instanceID] = nil
		end
		decalToArea[instanceID] = nil
	end
end

local function CheckDecalAreaSaturation(posx, posz, width, length)
	local hash = hashPos(posx,posz)
	--Spring.Echo(hash,posx,posz, next(areaDecals))
	if not hash then
		return false
	else
		local areaD = areaDecals[hashPos(posx,posz)]
		if not areaD then
			return false
		else
			return (math.sqrt(areaD.totalarea) > saturationThreshold)
		end
	end
end

local updatePositionX = 0
local updatePositionZ = 0
function widget:Update() -- this is pointlessly expensive!
	if autoupdate then
		decalShader = LuaShader.CheckShaderUpdates(shaderSourceCache) or decalShader
		decalLargeShader = LuaShader.CheckShaderUpdates(shaderLargeSourceCache) or		decalLargeShader
	end

	if true then return end
	-- run over the map, one area per frame, and calc its smoothness
	updatePositionX = updatePositionX + areaResolution
	if updatePositionX >= Game.mapSizeX then
		updatePositionX = 0
		updatePositionZ = updatePositionZ + areaResolution
		if updatePositionZ >= Game.mapSizeZ then
			updatePositionZ = 0
		end
	end
	if updatePositionX == nil or updatePositionZ == nil then
		Spring.Echo("updatePositionX == nil or updatePositionZ == nil")
		return
	end
	local hash = hashPos(updatePositionX, updatePositionZ)
	--Spring.Echo("Updateing smoothness at",updatePositionX, updatePositionZ)
	local step = areaResolution/ 16
	local totalsmoothness = 0
	local prevHeight = spGetGroundHeight(updatePositionX, updatePositionZ)
	local prevX = prevHeight
	for x = updatePositionX, updatePositionX + areaResolution, step do
		for z = updatePositionZ, updatePositionZ + areaResolution, step do
			local h = spGetGroundHeight(x,z)
			totalsmoothness = totalsmoothness + abs(h-prevHeight)
			prevHeight = h
		end
		prevX = prevHeight
	end
	areaDecals[hash].smoothness = totalsmoothness
end

local function DrawSmoothness()
	gl.Color(1,1,1,1)
	for areaHash, areaInfo in pairs(areaDecals) do
		--Spring.Echo(areaHash, areaInfo.x, areaInfo.y, areaInfo.z)
		if Spring.IsSphereInView(areaInfo.x, areaInfo.y, areaInfo.z, 128) then
			gl.PushMatrix()
			local text = string.format("Smoothness = %d",areaInfo.smoothness)
			local w = gl.GetTextWidth(text) * 16.0
			gl.Translate(areaInfo.x - w, areaInfo.y + 64, areaInfo.z)
			gl.Text( text,0,0,16,'n')
			gl.PopMatrix()
		end
	end
end

-----------------------------------------------------------------------------------------------

local dCT = {} -- decalCacheTable


local function AddDecal(decaltexturename, posx, posz, rotation,
	width, length,
	heatstart, heatdecay, alphastart, alphadecay,
	maxalpha,
	bwfactor, glowsustain, glowadd, fadeintime, spawnframe)
	-- Documentation
	-- decaltexturename, full path to the decal texture name, it must have been added to the atlasses, e.g. 'bitmaps/scars/scar1.bmp'
	-- posx, posz, world pos to place center of decal
	-- rotation: rotation around y in radians
	-- width, length in elmos
	-- TODO: heatstart: the initial temperature, in kelvins of the emissive parts (alpha channel of normal texture)
	-- TODO: heatdecay: the exponential rate at which the hot parts are cooled down each frame
	-- alphastart: The initial transparency amount, can be > 1 too
	-- alphadecay: How much alpha is reduced each frame, when alphastart/alphadecay goes below 0, the decal will get automatically removed.
	-- maxalpha: The highest amount of transparency this decal can have
	-- bwfactor: the mix factor of the diffuse texture to black and whiteness, 0 is original cololr, 1 is black and white
	-- glowsustain: how many frames to elapse before glow starts to recede
	-- glowadd: how much additional, non-transparency controlled heat glow should the decal get
	-- fadeintime: how many frames it takes for a decal to reach its max alpha after spawning
	-- spawnframe: really shouldnt be touched (pass nil) unless you want to modify the params of an existing decal, then specify the frame that decal was spawned on.
	heatstart = heatstart or 0
	heatdecay = heatdecay or 1
	alphastart = alphastart or 1
	alphadecay = (alphadecay or 0) / lifeTimeMult

	bwfactor = bwfactor or 1 -- default force to black and white
	glowsustain = glowsustain or 1 -- how many frames to keep max heat for
	glowadd = glowadd or 0 -- how much additional additive glow to add
	fadeintime = fadeintime or shaderConfig.FADEINTIME

	if CheckDecalAreaSaturation(posx, posz, width, length) then
		if autoupdate then
			Spring.Echo("Map area is oversaturated with decals!", posx, posz, width, length)
		end
		return nil
	else

	end

	spawnframe = spawnframe or Spring.GetGameFrame()
	--Spring.Echo(decaltexturename, atlassedImages[decaltexturename], atlasColorAlpha)
	local p,q,s,t = 0,1,0,1

	--Spring.Echo(decaltexturename) --used for displaying which decal texture is spawned
	if atlas[decaltexturename] == nil then
		Spring.Echo("Tried to spawn a decal gl4 with a texture not present in the atlas:",decaltexturename)
	else
		local uvs = atlas[decaltexturename]
		p,q,s,t = uvs[1], uvs[2], uvs[3], uvs[4]
	end

	local posy = Spring.GetGroundHeight(posx, posz)
	--Spring.Echo (unitDefID,decalInfo.texfile, width, length, alpha)
	-- match the vertex shader on lifetime:
	-- 	float currentAlpha = min(1.0, (lifetonow / FADEINTIME))  * alphastart - lifetonow* alphadecay;
	--  currentAlpha = min(currentAlpha, lengthwidthrotation.w);
	local lifetime = math.floor(alphastart/alphadecay)
	decalIndex = decalIndex + 1
	local targetVBO = decalVBO

	if math.min(width,length) > extralargesizeThreshold then
		targetVBO = decalExtraLargeVBO
	elseif math.min(width,length) > largesizethreshold then
		targetVBO = decalLargeVBO
	end

	dCT[1],  dCT[2],  dCT[3],  dCT[4]  = length, width, rotation, maxalpha   -- lengthwidthrotation maxalpha
	dCT[5],  dCT[6],  dCT[7],  dCT[8]  = p,q,s,t -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
	dCT[9],  dCT[10], dCT[11], dCT[12] = alphastart, alphadecay, heatstart, heatdecay -- alphastart_alphadecay_heatstart_heatdecay
	dCT[13], dCT[14], dCT[15], dCT[16] = posx, posy, posz, spawnframe
	dCT[17], dCT[18], dCT[19], dCT[20] = bwfactor, glowsustain, glowadd, fadeintime -- params

	pushElementInstance(
		targetVBO, -- push into this Instance VBO Table
			dCT,-- decalCacheTable
		decalIndex, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		false) -- noupload, dont use unless you know what you want to batch push/pop
	local deathtime = spawnframe + lifetime
	decalTimes[decalIndex] = deathtime
	if decalRemoveQueue[deathtime] == nil then
		decalRemoveQueue[deathtime] = {decalIndex}
	else
		decalRemoveQueue[deathtime][#decalRemoveQueue[deathtime] + 1 ] = decalIndex
	end

	AddDecalToArea(decalIndex, posx, posz, width, length)
	return decalIndex, lifetime
end


local skipdraw = false
local firstRun = true

local function DrawDecals()
	if firstRun then
		glTexture(0, "luaui/images/decals_gl4/decalsgl4_atlas_diffuse.dds")
		glTexture(0, false)
		glTexture(0, "luaui/images/decals_gl4/decalsgl4_atlas_normal.dds")
		glTexture(0, false)
	end

	if skipdraw then return end
	--local alt, ctrl = Spring.GetModKeyState()
	if decalVBO.usedElements > 0 or decalLargeVBO.usedElements > 0 or decalExtraLargeVBO.usedElements > 0 then

		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- the default mode
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(decalVBO.usedElements,decalLargeVBO.usedElements)
		if hasBadCulling then
			glCulling(false)
		else
			glCulling(GL.BACK)
		end
		glDepthTest(GL_LEQUAL)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		glTexture(0, '$heightmap')
		glTexture(1, '$minimap')
		glTexture(2, '$info')
		glTexture(3, '$shadow')
		glTexture(4, '$normals')
		glTexture(5, "luaui/images/decals_gl4/decalsgl4_atlas_diffuse.dds")
		glTexture(6, "luaui/images/decals_gl4/decalsgl4_atlas_normal.dds")
		if shaderConfig.PARALLAX == 1 then glTexture(7, atlasHeights) end
		--glTexture(9, '$map_gbuffer_zvaltex')
		--glTexture(10, '$map_gbuffer_difftex')
		--glTexture(11, '$map_gbuffer_normtex')


		if decalVBO.usedElements > 0  then
			decalShader:Activate()
			decalShader:SetUniform("fadeDistance",disticon * 1000)
			decalVBO.VAO:DrawArrays(GL.POINTS, decalVBO.usedElements)
			decalShader:Deactivate()
		end

		if decalLargeVBO.usedElements > 0 or decalExtraLargeVBO.usedElements > 0 then
			--Spring.Echo("large elements:", decalLargeVBO.usedElements)
			decalLargeShader:Activate()
			--decalLargeShader:SetUniform("fadeDistance",disticon * 1000)
			if decalLargeVBO.usedElements > 0 then
				decalLargeVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, decalLargeVBO.usedElements, 0)
			end
			if decalExtraLargeVBO.usedElements > 0 then
				decalExtraLargeVBO.VAO:DrawElements(GL.TRIANGLES, nil, 0, decalExtraLargeVBO.usedElements, 0)
			end
			decalLargeShader:Deactivate()
		end

		-- Restore the GL state
		for i = 0, 8 do glTexture(i, false) end
		glCulling(false) -- This is the correct default mode!
		gl.Blending(GL.SRC_ALPHA, GL.ONE_MINUS_SRC_ALPHA) -- the default mode
	end
end

function widget:TextCommand(command)
	if string.find(command, "decalsgl4stats", nil, true) then
		local tricount = 4*4*2 * decalVBO.usedElements + resolution*resolution*2*decalLargeVBO.usedElements + 4*4*resolution*resolution*2*decalExtraLargeVBO.usedElements
		Spring.Echo(string.format("Small decal = %d, Medium decal = %d, Large decal = %d, tris = %d",
			decalVBO.usedElements,
			decalLargeVBO.usedElements,
			decalExtraLargeVBO.usedElements,
			tricount))
		return true
	end
	if string.find(command, "decalsgl4skipdraw", nil, true) then
		skipdraw = not skipdraw
		Spring.Echo("Decals GL4 skipdraw set to", skipdraw)
		return true
	end
	return false
end

if Script.IsEngineMinVersion(105, 0, 1422) then
	function widget:DrawPreDecals()
		DrawDecals()
	end
else
	function widget:DrawWorldPreUnit()
		DrawDecals()
	end
end


local function RemoveDecal(instanceID)
	RemoveDecalFromArea(instanceID)
	if decalVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalVBO, instanceID)
	elseif decalLargeVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalLargeVBO, instanceID)
	elseif decalExtraLargeVBO.instanceIDtoIndex[instanceID] then
		popElementInstance(decalExtraLargeVBO, instanceID)
	end
	decalTimes[instanceID] = nil
end

local numDecalsToRemove = 0

function widget:GameFrame(n)
	if decalRemoveQueue[n] then
		for i=1, #decalRemoveQueue[n] do
			local decalID = decalRemoveQueue[n][i]
			decalRemoveList[decalID] = true
			numDecalsToRemove = numDecalsToRemove + 1
			--RemoveDecal(decalID)
		end
		decalRemoveQueue[n] = nil
	end

	if n % 67 == 0 then -- About every 2 seconds
		local totalDecalCount = decalVBO.usedElements + decalLargeVBO.usedElements +  decalExtraLargeVBO.usedElements

		-- Perform a compacting step if about half of our decals should be removed
		if totalDecalCount == 0 or (numDecalsToRemove/totalDecalCount < 0.5) then return end

		numDecalsToRemove = 0
		local removed = 0
		removed = removed + compactInstanceVBO(decalVBO, decalRemoveList)
		removed = removed + compactInstanceVBO(decalLargeVBO, decalRemoveList)
		removed = removed + compactInstanceVBO(decalExtraLargeVBO, decalRemoveList)
		decalRemoveList = {}

		if autoupdate and removed > 0 then
			Spring.Echo("Removed",removed,"decals from decal instance tables: s=",decalVBO.usedElements,' l=', decalLargeVBO.usedElements,'xl=', decalExtraLargeVBO.usedElements, "Tot=", totalDecalCount, "Rem=",numDecalsToRemove)
		end
		if decalVBO.dirty then 	uploadAllElements(	decalVBO) end
		if decalLargeVBO.dirty then 	uploadAllElements(	decalLargeVBO) end
		if decalExtraLargeVBO.dirty then 	uploadAllElements(	decalExtraLargeVBO) end

	end
end

local function randtablechoice (t)
	local i = 0
	for k,v in pairs(t) do
		if type(v) == "table" then
			i = i+1
		end
	end
	local randi = math.floor(math.random()*i)
	local j = 0
	for k,v in pairs(t) do
		if type(v) == "table" and j > randi then return k,v end
		j = j+1
	end
	return next(t)
end

-- Solars, nanos, wind, advsolars, metal makers,
local buildingExplosionPositionVariation = {
	nanoboom = 1,
	nanoselfd = 1,
	--smallBuildingExplosionGeneric = 1, --armadvsol
	--smallBuildingExplosionGenericSelfd = 1, -- armadvsol
	metalmaker = 1,
	metalmakerSelfd = 1,
	advmetalmaker = 1,
	advmetalmakerSelfd = 1,
	windboom = 1,
	--mediumBuildingexplosiongeneric = 1, -- coradvsol
	--mediumBuildingExplosionGenericSelfd = 1, --coradvsol
	}
local globalDamageMult = Spring.GetModOptions().multiplier_weapondamage or 1
local weaponConfig = {}
for weaponDefID=1, #WeaponDefs do
	local weaponDef = WeaponDefs[weaponDefID]
	local nodecal = (weaponDef.customParams and weaponDef.customParams.nodecal)
	if (not nodecal) and (not string.find(weaponDef.cegTag, 'aa')) then
		local radius = weaponDef.damageAreaOfEffect * 1.4

		local damage = 100
		for cat=0, #weaponDef.damages do
			if Game.armorTypes[cat] and Game.armorTypes[cat] == 'default' then
				damage = weaponDef.damages[cat]
				break
			end
		end

		-- correct damage multiplier modoption to more sane value
		damage = (damage / globalDamageMult) + ((damage * (globalDamageMult-1))*0.25)

		--local damageEffectiveness = weaponDef.edgeEffectiveness

		local bwfactor = 0.5 --the mix factor of the diffuse texture to black and whiteness, 0 is original cololr, 1 is black and white
		local radiusVariation = 0.3	-- 0.3 -> 30% larger or smaller radius
		local alpha
		local alphadecay
		local heatstart
		local heatdecay
		local glowsustain
		local glowadd
		local fadeintime
		local positionVariation = 0


		local textures = { "t_groundcrack_17_a.tga", "t_groundcrack_21_a.tga", "t_groundcrack_10_a.tga" }
		if weaponDef.paralyzer then
			textures = { "t_groundcrack_17_a.tga", "t_groundcrack_10_a.tga", "t_groundcrack_10_a.tga" }
			heatstart = 0
			glowadd = 0
			if weaponDef.type == 'AircraftBomb' then
				textures = {"t_groundcrack_16_a.tga" }
				alpha = 0.44
				alphadecay = 0.00015
				radius = radius * 0.75
				radiusVariation = 1.45
				heatstart = 100
				heatdecay = 2.5
				--glowsustain = 35
				glowadd = 4
			end

		elseif weaponDef.type == 'Cannon' then
			if string.find(weaponDef.name, 'old_armsnipe_weapon') then
				textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga" }
				radius = 50
				heatstart = 6000
				heatdecay = 2.0
				glowsustain = 35
				glowadd = 4
			end
			if weaponDef.highTrajectory == 1 then
				textures = { "t_groundcrack_21_a.tga", "t_groundcrack_22_a.tga", "t_groundcrack_10_a.tga" }
				alphadecay = 0.0024

			elseif string.find(weaponDef.name, 'lrpc') then
				textures = { "t_groundcrack_09_a.tga", "t_groundcrack_05_a.tga" }
				radius = radius * 1.3
				radiusVariation = 0.7
				heatstart = 6000
				heatdecay = 0.78
				glowadd = 2

			elseif string.find(weaponDef.name, 'tremor') then
				textures = { "t_groundcrack_17_a.tga", "t_groundcrack_21_a.tga", "t_groundcrack_10_a.tga", "t_groundcrack_09_a.tga" }
				radius = radius * 0.96
				radiusVariation = 0.85
				alphadecay = 0.0026
				heatstart = 6000
				heatdecay = 1.5
				glowadd = 2

			elseif string.find(weaponDef.name, 'crawl_blastsmlscavboss') then
				textures = { "t_groundcrack_21_a.tga" }
				radius = radius * 1.7
				--radiusVariation = 0.7
				heatstart = 6000
				heatdecay = 0.78
				glowadd = 2
			end

		elseif weaponDef.type == 'Flame' then
			-- FLAME does not work - probably does not apply a decal on engine level
			-- textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga" }
			-- if string.find(weaponDef.name, 'flamethrower') then
			-- 	radius = radius * 5.8
			-- 	heatstart = 6000
			-- 	heatdecay = 0.78
			-- 	alpha = 6
			-- 	alphadecay = 0.0024
			-- 	glowadd = 2
			-- end

		elseif weaponDef.type == 'LightningCannon' then
			heatstart = 4000
			heatdecay = 1.0
			glowsustain = 10
			alpha = 0.5
			--glowadd = 2
			fadeintime = 15
			bwfactor = 0.8

		elseif weaponDef.type == 'BeamLaser' then

		elseif weaponDef.type == 'LaserCannon' then

		elseif weaponDef.type == 'StarburstLauncher' then

		elseif weaponDef.type == 'AircraftBomb' then
			if string.find(weaponDef.name, '.advbomb') then
				alpha = 1.1
				radius = radius * 1.5
				heatstart = 5500
				heatdecay = 2.0
				alphadecay = 0.0006
				radiusVariation = 0.6
				glowsustain = 35
				glowadd = 4
			else
				radius = radius * 0.8
				heatstart = 3500
				heatdecay = 2.7
				alphadecay = 0.0030
				radiusVariation = 0.45
				glowsustain = 20
				glowadd = 1.2
			end
			bwfactor = 0.01

		elseif weaponDef.type == 'DGun' then
			textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga" }
			if string.find(weaponDef.name, 'juggernaut_fire') then
				radius = radius * 2.4
				heatdecay = 0.65
				glowsustain = 40
				glowadd = 1.3
				bwfactor = 0.1
			elseif string.find(weaponDef.name, 'disintegratorxl') then
				textures = { "t_groundcrack_21_a.tga", "t_groundcrack_16_a.tga" }
				alphadecay = 0.004
				radius = radius * 1.7 --* (math.random() * 20 + 0.2)
				radiusVariation = 1.65
				heatdecay = 0.75
				glowsustain = 30
				glowadd = 1.8
				bwfactor = 0.1
			else
				radius = radius * 2.5
				heatdecay = 0.7
				glowsustain = 40
				glowadd = 2.5
				bwfactor = 0
			end
		end

		if radius > 500 then
			textures = { "t_groundcrack_21_a.tga" }
			heatstart = 5500
			heatdecay = 0.5
			glowsustain = 150
			glowadd = 1.5
			bwfactor = 0.1
		end

		if string.find(weaponDef.name, 'juno') then
			textures = { "t_groundcrack_10_a.tga" }
			radius = 700
			alpha = 0.4
			heatstart = 700
			heatdecay = 0.5
			alphadecay = 0.00005
			--glowadd = 2.5
			bwfactor = 0.05

		elseif string.find(weaponDef.name, 'acid') then
			textures = { "t_groundcrack_26_a.tga" }
			radius = (radius * 5)-- * (math.random() * 0.15 + 0.85)
			alpha = 6
			heatstart = 500
			heatdecay = 10
			alphadecay = 0.012
			--glowadd = 2.5
			--glowsustain = 0
			fadeintime = 200
			bwfactor = 0.17

		elseif string.find(weaponDef.name, 'vipersabot') then -- viper has very tiny AoE
			radius = (radius * 4)

		elseif string.find(weaponDef.name, 'armmav_weapon') then -- armmav has very tiny AoE
			radius = (radius * 6)

		elseif string.find(weaponDef.name, 'corkorg_fire') then -- Juggernaut has lots of decals on shotgun
			alphadecay = 0.004

		elseif string.find(weaponDef.name, 'exp_heavyrocket') then -- Catapult has lower AoE but big explo
			textures = { "t_groundcrack_17_a.tga", "t_groundcrack_21_a.tga", "t_groundcrack_10_a.tga", "t_groundcrack_09_a.tga" }
			radius = radius * 2.1
			radiusVariation = 0.8
			alphadecay = 0.0026
			heatstart = 6500
			heatdecay = 0.8
			glowadd = 2

		elseif string.find(weaponDef.name, 'napalm') then
			textures = { "t_groundcrack_16_a.tga" }
			radius = radius * 1.6
			heatstart = 4000
			heatdecay = 0.33
			alpha = 0.4
			alphadecay = 0.0002
			glowsustain = 225
			glowadd = 4.5

			--armliche
		elseif string.find(weaponDef.name, 'arm_pidr') then
			textures = { "t_groundcrack_21_a.tga" }
			radius = radius * 1.8
			heatstart = 5500
			heatdecay = 0.66
			glowsustain = 100
			glowadd = 1.5
			bwfactor = 0.1

		elseif string.find(weaponDef.name, 'death_acid') then
			textures = { "t_groundcrack_26_a.tga" }
			radius = (radius * 5.5)-- * (math.random() * 0.25 + 0.75)
			alpha = 6
			heatstart = 550
			heatdecay = 0.1
			alphadecay = 0.012
			glowadd = 2.5
			fadeintime = 200
			bwfactor = 0.17

		elseif string.find(weaponDef.name, 'flamebug') then
			textures = { "t_groundcrack_23_a.tga", "t_groundcrack_24_a.tga", "t_groundcrack_25_a.tga", "t_groundcrack_27_a.tga" }
			radius = (radius * 5)-- * (math.random() * 0.7 + 0.52)
			alpha = 15
			heatstart = 500
			heatdecay = 0.12
			alphadecay = 0.002
			glowsustain = 15
			glowadd = 2.5
			fadeintime = 150
			bwfactor = 0.6

		elseif string.find(weaponDef.name, 'bug') then
			textures = { "t_groundcrack_23_a.tga", "t_groundcrack_24_a.tga", "t_groundcrack_25_a.tga", "t_groundcrack_27_a.tga" }
			if string.find(weaponDef.name, 'flamebug') then
				radius = (radius * 5)
			else
				radius = (radius * 10)-- * (math.random() * 0.7 + 0.52)
				alpha = 15
				heatstart = 500
				heatdecay = 0.12
				alphadecay = 0.002
				glowsustain = 15
				glowadd = 2.5
				fadeintime = 75
				bwfactor = 0.6
			end

		elseif string.find(weaponDef.name, 'bloodyeggs') then
			textures = { "t_groundcrack_23_a.tga" }
			radius = (radius * 1.5)-- * (math.random() * 1.2 + 0.25)
			alpha = 10
			heatstart = 490
			heatdecay = 0.1
			alphadecay = 0.005
			glowadd = 2.5
			fadeintime = 75
			bwfactor = 0.6

		elseif string.find(weaponDef.name, 'dodo') then
			textures = { "t_groundcrack_23_a.tga", "t_groundcrack_24_a.tga" }
			radius = (radius * 1.2)-- * (math.random() * 0.15 + 0.85)
			alpha = 10
			heatstart = 490
			heatdecay = 0.1
			alphadecay = 0.002
			glowadd = 2.5
			bwfactor = 0.7

		elseif string.find(weaponDef.name, 'armagmheat') then
			textures = { "t_groundcrack_10_a.tga" }
			radius = (radius * 1.6)-- * (math.random() * 0.15 + 0.85)
			alpha = 1
			heatstart = 6500
			heatdecay = 0.5
			alphadecay = 0.002
			glowadd = 2.5
			--bwfactor = 0.15

		elseif string.find(weaponDef.name, 'corkorg_laser') then
			textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga", "t_groundcrack_10_a.tga" }
			alphadecay = 0.004
			radius = radius * 1.1 --* (math.random() * 20 + 0.2)
			radiusVariation = 0.3
			heatstart = 6800
			heatdecay = 0.75
			glowsustain = 45
			glowadd = 1.8
			bwfactor = 0.1

		elseif string.find(weaponDef.name, 'pineappleofdoom') or string.find(weaponDef.name, 'heatraylarge') or string.find(weaponDef.name, 'skybeam') or string.find(weaponDef.name, 'heat_ray') then --legbastion leginc legphoenix legaheattank
			textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga", "t_groundcrack_05_a.tga" }
			--textures = { "t_groundcrack_16_a.tga", "t_groundcrack_17_a.tga", "t_groundcrack_10_a.tga" }
			alphadecay = 0.004
			radius = radius * 0.8
			--radiusVariation = 0.3
			heatstart = 8000
			heatdecay = 3.95
			glowsustain = 20
			glowadd = 2.8
			bwfactor = 0.1

		elseif string.find(weaponDef.name, 'starfire') then
			textures = { "t_groundcrack_16_a.tga", "t_groundcrack_09_a.tga", "t_groundcrack_10_a.tga" }
			alphadecay = 0.003
			radius = radius * 1.2 --* (math.random() * 20 + 0.2)
			radiusVariation = 0.6
			heatstart = 9000
			heatdecay = 2.5
			glowsustain = 0
			glowadd = 2.5
			bwfactor = 0.3

		elseif string.find(weaponDef.name, 'footstep') then
			--textures = { "f_corkorg_a.tga" }
			textures = { "t_groundcrack_10_a.tga" }
			--radius = 70
			radius = (radius * 0.7)
			radiusVariation = 0.5 --0.03
			alpha = 0.5
			heatstart = 100
			heatdecay = 0.7
			alphadecay = 0.00055 --0.00055
			--glowadd = 2.5
			bwfactor = 0.4

		end
		if buildingExplosionPositionVariation[weaponDef.name] then
			positionVariation = buildingExplosionPositionVariation[weaponDef.name]
		end

		weaponConfig[weaponDefID] = {
			textures,
			radius,
			radiusVariation,
			heatstart, -- 4
			heatdecay, -- 5
			alpha, -- 6
			alphadecay, -- 7
			bwfactor,	-- 8
			glowsustain, --9
			glowadd, -- 10
			weaponDef.damageAreaOfEffect,	-- 11
			damage,	-- 12
			fadeintime, -- 13
			positionVariation, --14
		}

	end
end

function widget:VisibleExplosion(px, py, pz, weaponID, ownerID)
	local random = math.random
	local params = weaponConfig[weaponID]
	if not params then
		return
	end

	local radius = params[2] + ((params[2] * (random()-0.5)) * params[3])
	local exploHeight = py - spGetGroundHeight(px,pz)
	if exploHeight >= radius then
		return
	end

	local texture = params[1][ random(1,#params[1]) ]

	-- reduce severity when explosion is above ground
	local heightMult = 1 - (exploHeight / radius)

	local heatstart = params[4] or ((random() * 0.2 + 0.9) * 4900)
	local heatdecay = params[5] or ((random() * 0.4 + 2.0) - (params[11]/2250))

	local alpha = params[6] or ((random() * 1.0 + 1.5) * (1.0 - exploHeight/radius) * heightMult)
	local alphadecay = params[7] or (params[7] or ((random() * 0.3 + 0.2) / (4 * radius)))

	local bwfactor = params[8] or 0.5 --the mix factor of the diffuse texture to black and whiteness, 0 is original cololr, 1 is black and white
	local glowsustain = params[9] or (random() * 20) -- how many frames to elapse before glow starts to recede
	local glowadd = params[10] or (random() * 2) -- how much additional, non-transparency controlled heat glow should the decal get
	local fadeintime = params[13]

	if params[14] > 0 then --positionVariation
		px = px + (random() - 0.5 ) * radius * 0.2
		pz = pz + (random() - 0.5 ) * radius * 0.2
	end


	AddDecal(
		groundscarsPath..texture,
		px, --posx
		pz, --posz
		random() * 6.28, -- rotation
		radius, -- width
		radius, -- height
		heatstart * heightMult, -- heatstart
		heatdecay * (1+(1-heightMult)), -- heatdecay
		(random() * 0.38 + 0.72) * alpha, -- alphastart
		alphadecay, -- alphadecay
		random() * 0.2 + 0.8, -- maxalpha
		bwfactor,
		glowsustain,
		glowadd,
		fadeintime
	)
end

local UnitScriptDecalsNames = {
	['corkorg'] = {
		[1] = {
			texture = footprintsPath..'f_corkorg_a.png',
			offsetx = 2, --offset from what the UnitScriptDecal returns
			offsetz = -25, --
			offsetrot = 0, -- in radians
			width = 64,
			height = 32,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1.0,
			alphadecay = 0.0002,
			maxalpha = 1.0,
			bwfactor = 0.0,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},

	['armfboy'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armfboy_a.png',
			offsetx = -1, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0, -- in radians
			width = 60,
			height = 30,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0008,
			maxalpha = 1.0,
			bwfactor = 0.0,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		[2] = { -- RFOOT
			texture = footprintsPath..'f_armfboy_a.png',
			offsetx = 1, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0, -- in radians
			width = 60,
			height = 30,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.8,
			alphadecay = 0.0008,
			maxalpha = 1.0,
			bwfactor = 0.0,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},
	['armwar'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armwar_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.2, -- in radians
			width = 18,
			height = 18,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		[2] = { -- RFOOT
			texture = footprintsPath..'f_armwar_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = -0.2, -- in radians
			width = 18,
			height = 18,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armck'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armck_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 7, --
			offsetrot = 0.0, -- in radians
			width = 20,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armrock'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armrock_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = -3, --
			offsetrot = 0.0, -- in radians
			width = 20,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},
	['armham'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armham_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = -1, --
			offsetrot = 0.0, -- in radians
			width = 20,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armack'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armack_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 1, --
			offsetrot = 0.0, -- in radians
			width = 28,
			height = 28,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.5,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armzeus'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armzeus_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 12,
			height = 12,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.6,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armmav'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armmav_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 20,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.6,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armmar'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armmar_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 40,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1.0,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armraz'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_armraz_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 54,
			height = 26,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.9,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armvang'] = {
		[1] = { -- FOOT
			texture = footprintsPath..'f_armvang_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.8, -- in radians
			width = 24,
			height = 24,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1.4,
			alphadecay = 0.0016,
			maxalpha = 1.2,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},

		[2] = { -- ankle
			texture = footprintsPath..'f_armvang_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 3.14, -- in radians
			width = 24,
			height = 24,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1.2,
			alphadecay = 0.0022,
			maxalpha = 1.2,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['armbanth'] = {
		[1] = {
			texture = footprintsPath..'f_armbanth_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = -7, --
			offsetrot = 0, -- in radians
			width = 48,
			height = 24,
			heatstart = 1000,
			heatdecay = 0.0005,
			alphastart = 0.8,
			alphadecay = 0.0009,
			maxalpha = 1.0,
			bwfactor = 0.3,
			glowsustain = 10,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},

	['corck'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corck_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 20,
			height = 20,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.5,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['corstorm'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corstorm_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 26,
			height = 13,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.6,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['corthud'] = {
		[1] = {
			texture = footprintsPath..'f_corthud_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = -2, --
			offsetrot = 0, -- in radians
			width = 19,
			height = 19,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},

	['corack'] = {
		[1] = {
			texture = footprintsPath..'f_corthud_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = -2, --
			offsetrot = 0, -- in radians
			width = 19,
			height = 19,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},


	['cormando'] = {
		[1] = { --lfoot
			texture = footprintsPath..'f_cormando_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.15, -- in radians
			width = 19,
			height = 19,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		[2] = { --rfoot
			texture = footprintsPath..'f_cormando_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = -0.15, -- in radians
			width = 19,
			height = 19,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			}
		},


	['corpyro'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corpyro_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 22,
			height = 11,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},
	['corhrk'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corhrk_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 34,
			height = 17,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},
	['corcan'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corcan_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 3.14, -- in radians
			width = 24,
			height = 11,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.9,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		[2] = { -- RFOOT
			texture = footprintsPath..'f_corcan_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 24,
			height = 12,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.9,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},

	['corsumo'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corsumo_a.png',
			offsetx = -1, --offset from what the UnitScriptDecal returns
			offsetz = -1, --
			offsetrot = 0.0, -- in radians
			width = 26,
			height = 30,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.80,
			alphadecay = 0.0010,
			maxalpha = 0.9,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},
	['coramph'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_coramph_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 3, --
			offsetrot = 0.0, -- in radians
			width = 28,
			height = 14,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.6,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},
	['corcat'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corcat_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 3, --
			offsetrot = 0.0, -- in radians
			width = 36,
			height = 36,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},
	['corshiva'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corshiva_a.png',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 30,
			height = 30,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.7,
			alphadecay = 0.0022,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 2,
			},
		},
	['corjugg'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_corjugg_a.png',
			offsetx = -1, --offset from what the UnitScriptDecal returns
			offsetz = -3, --
			offsetrot = 0.0, -- in radians
			width = 64,
			height = 34,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 0.8,
			alphadecay = 0.0003,
			maxalpha = 1.0,
			bwfactor = 0.1,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

	['raptor_land_swarmer_basic_t1_v1'] = {
		[1] = { -- LFOOT
			texture = footprintsPath..'f_raptor_a.tga',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 26,
			height = 26,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1,
			alphadecay = 0.0032,
			maxalpha = 1.0,
			bwfactor = 0.3,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		[2] = { -- RFOOT
			texture = footprintsPath..'f_raptor_a.tga',
			offsetx = 0, --offset from what the UnitScriptDecal returns
			offsetz = 0, --
			offsetrot = 0.0, -- in radians
			width = 26,
			height = 26,
			flipvertical = true,
			heatstart = 0,
			heatdecay = 0,
			alphastart = 1,
			alphadecay = 0.0032,
			maxalpha = 1.0,
			bwfactor = 0.3,
			glowsustain = 0.0,
			glowadd = 0.0,
			fadeintime = 5,
			},
		},

}
-- convert unitname -> unitDefID
local UnitScriptDecals = {}
for unitName, decals in pairs(UnitScriptDecalsNames) do
	if UnitDefNames[unitName] then
		UnitScriptDecals[UnitDefNames[unitName].id] = decals
	end
end
UnitScriptDecalsNames = nil


--[[
Shit needed in the cob script:

lua_UnitScriptDecal(lightIndex, xpos,zpos, heading)
{
	return 0;
}

call-script lua_UnitScriptDecal(1, (get PIECE_XZ(lfoot) & 0xffff0000) / 0x00010000 , (get PIECE_XZ(lfoot) & 0x0000ffff),   get HEADING(0));
]]--
local function UnitScriptDecal(unitID, unitDefID, whichDecal, posx, posz, heading)
	--Spring.Echo("Widgetside UnitScriptDecal", unitID, unitDefID, whichDecal, posx,posz, heading)
	if Spring.ValidUnitID(unitID) and Spring.GetUnitIsDead(unitID) == false and UnitScriptDecals[unitDefID] and UnitScriptDecals[unitDefID][whichDecal] then
		local decalTable =  UnitScriptDecals[unitDefID][whichDecal]

		-- So order of transformations is, get heading, rotate that into world space , heading 0 is +Z direction
		-- Then place at worldpos
		-- Then place at offset (rotated)
		-- Then apply additional offset rotation

		local rotationradians = (0.75 + heading / 65536) * 2 * math.pi
		local sinrot = math.sin(-rotationradians)
		local cosrot = math.cos(-rotationradians)
		local offsetx = decalTable.offsetz
		local offsetz = decalTable.offsetx
		--local worldposx = posx + cosrot * decalTable.offsetx - sinrot * decalTable.offsetz
		local worldposx = posx + cosrot * offsetx - sinrot * offsetz

		local worldposz = posz + sinrot * offsetx + cosrot * offsetz
		if false then -- old reliable method
			AddDecal(
				decalTable.texture,
				worldposx, --posx
				worldposz, --posx
				decalTable.offsetrot + rotationradians, --rotation
				decalTable.width, -- width
				decalTable.height, -- height
				decalTable.heatstart, -- heatstart
				decalTable.heatdecay, -- heatdecay
				decalTable.alphastart, -- alphastart
				decalTable.alphadecay, -- alphadecay
				decalTable.maxalpha, -- maxalpha
				decalTable.bwfactor,
				decalTable.glowsustain,
				decalTable.glowadd,
				decalTable.fadeintime
			)
		else -- new fast but unmaintainable method
			local decalCache = decalTable.cacheTable

			decalCache[3] = decalTable.offsetrot + rotationradians
			decalCache[13] = worldposx
			decalCache[14] = Spring.GetGroundHeight(posx, posz)
			decalCache[15] = worldposz

			decalCache[10] = decalTable.alphadecay / lifeTimeMult

			local spawnframe = Spring.GetGameFrame()
			decalCache[16] = spawnframe

			local lifetime = math.floor(decalTable.alphastart/decalCache[10])
			decalIndex = decalIndex + 1
			--Spring.Echo(decalIndex)
			pushElementInstance(
				decalVBO, -- push into this Instance VBO Table
				decalCache, -- params
				decalIndex, -- this is the key inside the VBO Table, should be unique per unit
				true, -- update existing element
				false) -- noupload, dont use unless you know what you want to batch push/pop
			local deathtime = spawnframe + lifetime
			decalTimes[decalIndex] = deathtime
			if decalRemoveQueue[deathtime] == nil then
				decalRemoveQueue[deathtime] = {decalIndex}
			else
				decalRemoveQueue[deathtime][#decalRemoveQueue[deathtime] + 1 ] = decalIndex
			end

			AddDecalToArea(decalIndex, worldposx, worldposz, decalTable.width, decalTable.height)
		end
	end
end

function widget:Initialize()
	--if makeAtlases() == false then
	--	goodbye("Failed to init texture atlas for DecalsGL4")
	--	return
	--end
	local initsuccess = initGL4("DecalsGL4")
	if initsuccess == nil then
		widgetHandler:RemoveWidget()
		return
	end
	initAreas()
	if autoupdate then
		math.randomseed(1)
		for i= 1, 100 do
			local w = math.random() * 15 + 7
			w = w * w
			local texture =  randtablechoice(atlas)
			--Spring.Echo(texture)
			AddDecal(
				texture,
				Game.mapSizeX * math.random() * 1.0, --posx
				Game.mapSizeZ * math.random() * 1.0, --posz
				math.random() * 6.28, -- rotation
				w, -- width
				w, --height
				math.random() * 10000, -- heatstart
				math.random() * 1, -- heatdecay
				math.random() * 1.0 + 1.0, -- alphastart
				math.random() * 0.001, -- alphadecay
				math.random() * 0.3 + 0.7 -- maxalpha
			)
		end
	end

	WG['decalsgl4'] = {}
	WG['decalsgl4'].AddDecalGL4 = AddDecal
	WG['decalsgl4'].RemoveDecalGL4 = RemoveDecal
	WG['decalsgl4'].SetLifeTimeMult = function(value)
		lifeTimeMult = value
	end

	widgetHandler:RegisterGlobal('AddDecalGL4', WG['decalsgl4'].AddDecalGL4)
	widgetHandler:RegisterGlobal('RemoveDecalGL4', WG['decalsgl4'].RemoveDecalGL4)
	widgetHandler:RegisterGlobal('UnitScriptDecal', UnitScriptDecal)
	--Spring.Echo(string.format("Decals GL4 loaded %d textures in %.3fs",numFiles, Spring.DiffTimers(Spring.GetTimer(), t0)))
	--Spring.Echo("Trying to access _G[NightModeParams]", _G["NightModeParams"])

	--pre-optimize UnitScriptDecals:
	for unitDefID, UnitScriptDecalSet in pairs(UnitScriptDecals) do
		for i, decalTable in ipairs(UnitScriptDecalSet) do
			local p,q,s,t = 0,1,0,1

			if atlas[decalTable.texture] == nil then
				Spring.Echo("Tried to spawn a decal gl4 with a texture not present in the atlas:",decalTable.texture)
			else
				local uvs = atlas[decalTable.texture]
				p,q,s,t = uvs[1], uvs[2], uvs[3], uvs[4]
				if decalTable.fliphorizontal then
					p, q = q, p
				end
				if decalTable.flipvertical then
					s, t = t, s
				end
			end

			decalTable.cacheTable = {
				decalTable.width, decalTable.height, 0,	decalTable.maxalpha,
				p,q,s,t,
				decalTable.alphastart or 1,
				(decalTable.alphadecay) or 0 / lifeTimeMult,
				decalTable.heatstart or 0,
				decalTable.heatdecay or 1,
				0,0,0,0,
				decalTable.bwfactor or 1,
				decalTable.glowsustain or 1,
				decalTable.glowadd or 1,
				decalTable.fadeintime or shaderConfig.FADEINTIME or 1
			}
		end
	end


end

function widget:SunChanged()
	--local nmp = _G["NightModeParams"]
	--Spring.Echo("widget:SunChanged()",nmp)
end

function widget:ShutDown()

	WG['decalsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddDecalGL4')
	widgetHandler:DeregisterGlobal('RemoveDecalGL4')
	widgetHandler:DeregisterGlobal('UnitScriptDecal')
end

function widget:GetConfigData(_) -- Called by RemoveWidget
	local savedTable = {
		lifeTimeMult = lifeTimeMult,
	}
	return savedTable
end

function widget:SetConfigData(data) -- Called on load (and config change), just before Initialize!
	if data.lifeTimeMult ~= nil then
		lifeTimeMult = data.lifeTimeMult
	end
end
