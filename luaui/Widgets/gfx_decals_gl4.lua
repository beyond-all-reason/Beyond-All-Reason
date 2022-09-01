function widget:GetInfo()
	return {
		name = "Decals GL4",
		desc = "Try to draw some nice normalmapped decals",
		author = "Beherith",
		date = "2021.11.02",
		license = "Lua code: GNU GPL, v2 or later, Shader GLSL code: (c) Beherith (mysterme@gmail.com)",
		layer = 999,
		enabled = false,
	}
end



-- Notes and TODO
-- yes these are geoshader decals
-- we are gonna try to smaple heightmap
-- atlasColor is diffuse + alpha
-- atlasNormals is normals + emission

-- advanced geoshader tricount for quads
-- 4x4 - 40
-- KNOWN BUG:
	-- the pop-back can change the render order of decals to be a tad annoying.... maybe a better method of managing this is needed? 


local atlasColorAlpha = nil
local atlasNormals = nil
local atlasHeights = nil
local atlasORM = nil 

local atlasSize = 4096
local atlasType = 1 -- 0 is legacy, 1 is quadtree type with no padding
-- ATLASTYPE 0 HAS WIIIIIIERD MINIFICATION ARTIFACTS!
-- atlastype 1 is da bomb
-- atlastype 2 seems oddly slow?
local atlassedImages = {}
local unitDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas

local function addDirToAtlas(atlas, path, key)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	--Spring.Echo("Adding",#files, "images to atlas from", path, key)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] and string.find(files[i], key, nil, true) then
			--Spring.Echo(files[i])
			gl.AddAtlasTexture(atlas,files[i])
			atlassedImages[files[i]] = atlas
		end
	end
end

local function makeAtlases()
	local success
	atlasColorAlpha = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
	addDirToAtlas(atlasColorAlpha, "luaui/images/decals_gl4/groundScars", '_a.png')
	success = gl.FinalizeTextureAtlas(atlasColorAlpha)
	if success == false then return false end
	
	atlasNormals = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
	addDirToAtlas(atlasNormals, "luaui/images/decals_gl4/groundScars", '_n.png')
	success = gl.FinalizeTextureAtlas(atlasNormals)
	if success == false then return false end
	
	atlasHeights = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
	addDirToAtlas(atlasHeights, "luaui/images/decals_gl4/groundScars", '_h.png')
	success = gl.FinalizeTextureAtlas(atlasHeights)
	if success == false then return false end
	
	atlasORM = gl.CreateTextureAtlas(atlasSize,atlasSize,atlasType)
	addDirToAtlas(atlasORM, "luaui/images/decals_gl4/groundScars", '_orm.png')
	success = gl.FinalizeTextureAtlas(atlasORM)
	if success == false then return false end
	return true
end

local decalVBO = nil
local decalLargeVBO = nil
local decalExtraLargeVBO = nil

local decalShader = nil
local decalLargeShader = nil

local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local spValidUnitID = Spring.ValidUnitID

local spec, fullview = Spring.GetSpectatingState()

local shaderConfig = {
	TRANSPARENCY = 0.2, -- transparency of the stuff drawn
	HEIGHTOFFSET = 1, -- Additional height added to everything
	ANIMATION = 1, -- set to 0 if you dont want animation
	INITIALSIZE = 0.66, -- What size the stuff starts off at when spawned
	GROWTHRATE = 4, -- How fast it grows to full size
	BREATHERATE = 30.0, -- how fast it periodicly grows
	BREATHESIZE = 0.05, -- how much it periodicly grows
	TEAMCOLORIZATION = 1.0, -- not used yet
	CLIPTOLERANCE = 1.1, -- At 1.0 it wont draw at units just outside of view (may pop in), 1.1 is a good safe amount
	USETEXTURE = 1, -- 1 if you want to use textures (atlasses too!) , 0 if not
	BILLBOARD = 0, -- 1 if you want camera facing billboards, 0 is flat on ground
	POST_ANIM = " ", -- what you want to do in the animation post function (glsl snippet, see shader source)
	POST_VERTEX = "v_color = v_color;", -- noop
	POST_GEOMETRY = "gl_Position.z = (gl_Position.z) - 256.0 / (gl_Position.w);",	--"g_uv.zw = dataIn[0].v_parameters.xy;", -- noop
	POST_SHADING = "fragColor.rgba = fragColor.rgba;", -- noop
	MAXVERTICES = 64, -- The max number of vertices we can emit, make sure this is consistent with what you are trying to draw (tris 3, quads 4, corneredrect 8, circle 64
	USE_CIRCLES = 1, -- set to nil if you dont want circles
	USE_CORNERRECT = 1, -- set to nil if you dont want cornerrect
	FULL_ROTATION = 0, -- the primitive is fully rotated in the units plane
	LOSDARKNESS = 0.7	,
}

---- GL4 Backend Stuff----

local luaShaderDir = "LuaUI/Widgets/Include/"
local LuaShader = VFS.Include(luaShaderDir.."LuaShader.lua")
VFS.Include(luaShaderDir.."instancevbotable.lua")

local vsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.vert.glsl"
local fsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.frag.glsl"
local gsSrcPath = "LuaUI/Widgets/Shaders/decals_gl4.geom.glsl"

local vsSrcLargePath = "LuaUI/Widgets/Shaders/decals_large_gl4.vert.glsl"
-- large decal resolution:
local resolution = 32 -- 32 is 2k tris, a tad pricey...
local largesizethreshold  = 128 -- if min(width,height)> than this, then we use the large version!
local extralargesizeThreshold = 768 -- if min(width,height)> than this, then we use the extra large version!

local lastshaderupdate = nil
local shaderSourceCache = {
	vssrcpath = vsSrcPath,
	fssrcpath = fsSrcPath,
	gssrcpath = gsSrcPath,
	}
	
local shaderLargeSourceCache = {
	vssrcpath = vsSrcLargePath,
	fssrcpath = fsSrcPath,
	}

local function checkShaderUpdates(shadersourcecache, shadername, delaytime)
	-- todo: extract shaderconfig
	if shadersourcecache.lastshaderupdate == nil or 
		Spring.DiffTimers(Spring.GetTimer(), shadersourcecache.lastshaderupdate) > (delaytime or 0.5) then 
		shadersourcecache.lastshaderupdate = Spring.GetTimer()
		local vsSrcNew = shadersourcecache.vssrcpath and VFS.LoadFile(shadersourcecache.vssrcpath)
		local fsSrcNew = shadersourcecache.fssrcpath and VFS.LoadFile(shadersourcecache.fssrcpath)
		local gsSrcNew = shadersourcecache.gssrcpath and VFS.LoadFile(shadersourcecache.gssrcpath)
		if  vsSrcNew == shadersourcecache.vsSrc and 
			fsSrcNew == shadersourcecache.fsSrc and 
			gsSrcNew == shadersourcecache.gsSrc then 
			--Spring.Echo("No change in shaders")
			return nil
		else
			local compilestarttime = Spring.GetTimer()
			shadersourcecache.vsSrc = vsSrcNew
			shadersourcecache.fsSrc = fsSrcNew
			shadersourcecache.gsSrc = gsSrcNew
			
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
					heightmapTex = 0,
					miniMapTex = 1,
					infoTex = 2,
					shadowtex = 3,
					mapNormalsTex = 4,
					atlasColorAlpha = 5, 
					atlasHeights = 6, 
					atlasNormals = 7, 
					atlasORM = 8, 
					--mapDeferredDepths = 9,
					--mapDeferredDiffuse = 10,
					--mapDeferredNormal = 11,
					},
				uniformFloat = {
					fadeDistance = 3000,
				  },
				},
				shadername
			)
			local shaderCompiled = reinitshader:Initialize()
			
			Spring.Echo(shadername, " recompiled in ", Spring.DiffTimers(Spring.GetTimer(), compilestarttime, true), "ms at", Spring.GetGameFrame(), "success", shaderCompiled or false)
			if shaderCompiled then 
				return reinitshader
			else
				return nil
			end
		end
	end
	return nil
end

function widget:Update()
	decalShader = checkShaderUpdates(shaderSourceCache, "Decals GL4", 0.5) or decalShader
	lastshaderupdate = nil
	decalLargeShader = checkShaderUpdates(shaderLargeSourceCache, "Large Decals GL4", 0.5) or decalLargeShader
end

local function goodbye(reason)
  Spring.Echo("DrawPrimitiveAtUnits GL4 widget exiting with reason: "..reason)
  widgetHandler:RemoveWidget()
end

local function initGL4( DPATname)
	decalShader = checkShaderUpdates(shaderSourceCache,  "Decals GL4")
	decalLargeShader = checkShaderUpdates(shaderLargeSourceCache, "Large Decals GL4", 0.5)
	
	if not decalShader or not decalLargeShader then goodbye("Failed to compile ".. DPATname .." GL4 ") end

	decalVBO = makeInstanceVBOTable(
		{
			{id = 0, name = 'lengthwidthrotation', size = 4},
			{id = 1, name = 'uv_atlaspos', size = 4},
			{id = 2, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 3, name = 'worldPos', size = 4},
		},
		64, -- maxelements
		DPATname .. "VBO" -- name
	)
	if decalVBO == nil then goodbye("Failed to create decalVBO") end

	local smallDecalVAO = gl.GetVAO()
	smallDecalVAO:AttachVertexBuffer(decalVBO.instanceVBO)
	decalVBO.VAO = smallDecalVAO
	
	local planeVBO, numVertices = makePlaneVBO(1,1,resolution,resolution)
	local planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution,resolution, true)
	
	decalLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
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
	planeIndexVBO, numIndices =  makePlaneIndexVBO(resolution*4,resolution*4, true)
	
	decalExtraLargeVBO = makeInstanceVBOTable(
		{
			{id = 1, name = 'lengthwidthrotation', size = 4},
			{id = 2, name = 'uv_atlaspos', size = 4},
			{id = 3, name = 'alphastart_alphadecay_heatstart_heatdecay', size = 4},
			{id = 4, name = 'worldPos', size = 4},
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

-----------------------------------------------------------------------------------------------
-- This part is kinda useless for now, but we could prevent or control excessive decal spam right here!
local areaResolution = 256 -- elmos per square, for a 64x map this is 
local decalToArea = {} -- maps instanceID to a position key on the map 
local areaDecals = {} -- {positionkey = {decallist, totalarea},}
local saturationThreshold = 1 * areaResolution
local floor = math.floor

local function hashPos(mapx, mapz) -- packs XZ into 1000*x + z
	return floor(mapx / areaResolution) * 1000 + floor(mapz/areaResolution)
end

local function initAreas() 
	for x= areaResolution /2, Game.mapSizeX, areaResolution do 
		for z= areaResolution /2, Game.mapSizeZ, areaResolution do 
			areaDecals[hashPos(x,z)] = {instanceIDsToArea = {}, totalarea = 0}
		end
	end
end

local function AddDecalToArea(instanceID, posx, posz, width, length)
	local hash = hashPos(posx,posz)
	local maparea = areaDecals[hash]
	local area = width * length
	maparea.instanceIDs[instanceID] =  area
	maparea.totalarea = maparea.totalarea + area
	decalToArea[instanceID] = hash
end

local function RemoveDecalFromArea(instanceID) 
	local hashpos = decalToArea[instanceID]
	if hashpos then 
		local maparea = areaDecals[hashPos(posx,posz)]
		if maparea.instanceIDs[instanceID] then 
			maparea.totalarea = math.max(0,maparea.totalarea - maparea.instanceIDs[instanceID])
			maparea.instanceIDs[instanceID] = nil
		end
		decalToArea[instanceID] = nil
	end
end

local function CheckDecalAreaSaturation(posx, posz, width, lenght)
	return (math.sqrt(areaDecals[hashPos(posx,posz)].totalarea) > saturationThreshold)
end
-----------------------------------------------------------------------------------------------

local function AddDecal(decaltexturename, posx, posz, rotation, width, length, heatstart, heatdecay, alphastart, alphadecay, maxalpha, spawnframe)
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
	
	if CheckDecalAreaSaturation(posx, posz, width, length) then 
		Spring.Echo("Map area is oversaturated with decals!", posx, posz, width, length)
		return nil 
	else
	
	end
	
	spawnframe = spawnframe or Spring.GetGameFrame()
	--Spring.Echo(decaltexturename, atlassedImages[decaltexturename], atlasColorAlpha)
	local p,q,s,t = gl.GetAtlasTexture(atlasColorAlpha, decaltexturename)
	--Spring.Echo(gl.GetAtlasTexture(atlasColorAlpha, decaltexturename))
	--Spring.Echo(gl.GetAtlasTexture(atlasNormals, string.gsub(decaltexturename, "_a.png","_n.png")))
	--	rotation = 0
	local posy = Spring.GetGroundHeight(posx, posz)
	--Spring.Echo (unitDefID,decalInfo.texfile, width, length, alpha)
	local lifetime = math.floor(alphastart/alphadecay)
	decalIndex = decalIndex + 1
	local targetVBO = decalVBO
	
	if math.min(width,length) > extralargesizeThreshold then 
		targetVBO = decalExtraLargeVBO
	elseif math.min(width,length) > largesizethreshold then 
		targetVBO = decalLargeVBO
	end
	
	pushElementInstance(
		targetVBO, -- push into this Instance VBO Table
			{length, width, rotation, maxalpha ,  -- lengthwidthrotation maxalpha
			p,q,s,t, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			alphastart, alphadecay, heatstart, heatdecay, -- alphastart_alphadecay_heatstart_heatdecay
			posx, posy, posz, spawnframe },
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

function widget:DrawWorldPreUnit()
	if decalVBO.usedElements > 0 or decalLargeVBO.usedElements > 0 or decalExtraLargeVBO.usedElements > 0 then
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(decalVBO.usedElements,decalLargeVBO.usedElements)
		glCulling(GL.BACK) 
		glDepthTest(GL_LEQUAL)
		gl.DepthMask(false)
		glTexture(0, '$heightmap')
		glTexture(1, '$minimap')
		glTexture(2, '$info')
		glTexture(3, '$shadow')
		glTexture(4, '$normals')
		glTexture(5, atlasColorAlpha)
		glTexture(6, atlasHeights)
		glTexture(7, atlasNormals)
		glTexture(8, atlasORM)
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
		
		for i = 0, 8 do glTexture(i, false) end
		glCulling(GL.BACK) -- This is the correct default mode! 
		glDepthTest(GL_LEQUAL)
		gl.DepthMask(false)
		
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

function widget:GameFrame(n)
	if decalRemoveQueue[n] then 
		for i=1, #decalRemoveQueue[n] do
			RemoveDecal(decalRemoveQueue[n][i])
		end
		decalRemoveQueue[n] = nil
	end
end

function widget:Initialize()
	if makeAtlases() == false then 
		goodbye("Failed to init texture atlas for DecalsGL4")
		return
	end
	local initsuccess = initGL4( "DecalsGL4")
	if initsuccess == nil then 
		widgetHandler:RemoveWidget()
		return
	end
	
	math.randomseed(1)
	if true then 
		for i= 1, 100 do 
			local w = math.random() * 32 + 2
			w = w * w
			local j = math.floor(math.random()*10 + 1)
			local idx = string.format("luaui/images/decals_gl4/groundScars/t_groundcrack_%02d_a.png", j)
			--Spring.Echo(idx)
			AddDecal(idx, 
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
	widgetHandler:RegisterGlobal('AddDecalGL4', WG['decalsgl4'].AddDecalGL4)
	widgetHandler:RegisterGlobal('RemoveDecalGL4', WG['decalsgl4'].RemoveDecalGL4)
	
end


function widget:ShutDown()
	if atlasColorAlpha ~= nil then
		gl.DeleteTextureAtlas(atlasColorAlpha)
	end
	if atlasHeights ~= nil then
		gl.DeleteTextureAtlas(atlasHeights)
	end
	if atlasNormals ~= nil then
		gl.DeleteTextureAtlas(atlasNormals)
	end
	if atlasORM ~= nil then
		gl.DeleteTextureAtlas(atlasORM)
	end
	
	WG['decalsgl4'] = nil
	widgetHandler:DeregisterGlobal('AddDecalGL4')
	widgetHandler:DeregisterGlobal('RemoveDecalGL4')
end
