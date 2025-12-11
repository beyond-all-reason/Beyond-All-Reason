local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Ground AO Plates Features GL4",
		desc = "Draw ground ao plates under features",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end


-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetSpectatingState = Spring.GetSpectatingState

--------------- Configurables -------------------
local decalAlpha = 0.66

--------------- Atlas textures ----------------


local atlas = VFS.Include("unittextures/decals_features/featureaoplates_atlas.lua")
local getUVCoords = atlas.getUVCoords
atlas.flip(atlas)
local atlassedImages = {}

local featureDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas

local function basepath(s,pattern)
	while string.find(s, pattern, 1, true ) do
		s = string.sub(s, string.find(s, pattern, 1, true) + 1 ) 
	end
	return s
end

local function addDirToAtlas(atlas, path)

	--spEcho("Adding",#files, "images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			local s3oname = basepath(files[i],'/')
			if string.find(s3oname, "_dead", 1 , true) then 
				--spEcho('s3oname',s3oname)
				s3oname = string.sub(s3oname, 1,	string.find(s3oname, "_dead", 1 , true) + 4)
				atlassedImages[s3oname] = files[i]
			elseif string.find(s3oname, "arm.x.._._", 1) or string.find(s3oname, "cor.x.._._", 1) then 
				s3oname = string.sub(s3oname, 1,7)
				
				--spEcho('s3oname',s3oname)
				atlassedImages[s3oname] = files[i]
			else
				--spEcho('Custom Feature AO plate:',s3oname, files[i])
				atlassedImages[s3oname] = files[i]
			end
		end
	end
end

local function makeAtlas()
	for filename, uvs in pairs(atlas) do
		if type(uvs) == "table" then 

			local s3oname = basepath(filename,'/')
			if string.find(s3oname, "_dead", 1 , true) then 
				--spEcho('s3oname',s3oname)
				s3oname = string.sub(s3oname, 1,	string.find(s3oname, "_dead", 1 , true) + 4)
				atlassedImages[s3oname] = filename
			elseif string.find(s3oname, "arm.x.._._", 1) or string.find(s3oname, "cor.x.._._", 1) then 
				s3oname = string.sub(s3oname, 1,7)
				
				--spEcho('s3oname',s3oname)
				atlassedImages[s3oname] = filename
			else
				--spEcho('Custom Feature AO plate:',s3oname, filename)])
				atlassedImages[s3oname] = filename
			end
		end
	end
end

---- GL4 Backend Stuff----
local groundPlateVBO = nil
local groundPlateShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local function AddPrimitiveAtUnit(featureID, featureDefID, noUpload)
	local gf = Spring.GetGameFrame()
	featureDefID = featureDefID or Spring.GetFeatureDefID(featureID)

	if featureDefID == nil or featureDefIDtoDecalInfo[featureDefID] == nil then return end -- these cant have plates
	local decalInfo = featureDefIDtoDecalInfo[featureDefID]
	
	--local texname = "unittextures/decals/".. UnitDefs[featureDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds

	local numVertices = 4 -- default to circle
	local additionalheight = 0
	
	local p,q,s,t = getUVCoords(atlas, decalInfo.texfile)
	--spEcho (featureDefID,featureID,decalInfo.texfile, decalInfo.sizez, decalInfo.sizex , decalInfo.alpha, p, q, s,t)
	
	pushElementInstance(
		groundPlateVBO, -- push into this Instance VBO Table
			{decalInfo.sizez, decalInfo.sizex, 0, additionalheight,	-- lengthwidthcornerheight
			0, --Spring.GetUnitTeam(featureID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, decalInfo.alpha * decalAlpha, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			q,p,t,s, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		featureID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		featureID) -- last one should be featureID!
end

local function ProcessAllFeatures()
	InstanceVBOTable.clearInstanceTable(groundPlateVBO)
	local features = Spring.GetAllFeatures()
	--spEcho("Refreshing Ground Plates", #features)
	for _, featureID in ipairs(features) do
		AddPrimitiveAtUnit(featureID, nil, true)
	end
	InstanceVBOTable.uploadAllElements(groundPlateVBO)
end
local firstRun = true
function widget:DrawWorldPreUnit()
	if firstRun then 
		glTexture(0, atlas.atlasimage)
		glTexture(0, false)
		firstRun = false
	end
		
	if groundPlateVBO.usedElements > 0 then 
		local disticon = Spring.GetConfigInt("FeatureFadeDistance", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		glCulling(GL_BACK)
		glDepthTest(GL_LEQUAL)
		gl.DepthMask(false) --"BK OpenGL state resets", default is already false, could remove
		--glDepthTest(false)
		glTexture(0, atlas.atlasimage)
		groundPlateShader:Activate()
		groundPlateShader:SetUniform("iconDistance",disticon) 
		groundPlateShader:SetUniform("addRadius",0) 
		groundPlateVBO.VAO:DrawArrays(GL.POINTS,groundPlateVBO.usedElements)
		groundPlateShader:Deactivate()
		glTexture(0, false)
		glCulling(false)
		gl.DepthTest(GL.ALWAYS)
		gl.DepthTest(false)
		gl.DepthMask(false) --"BK OpenGL state resets", already set as false
	end
end

local function RemovePrimitive(featureID)
	if groundPlateVBO.instanceIDtoIndex[featureID] then
		popElementInstance(groundPlateVBO, featureID)
	end
end

function widget:FeatureCreated(featureID)
	--spEcho("FeatureCreated", featureID)
	AddPrimitiveAtUnit(featureID)
end

function widget:FeatureDestroyed(featureID)
	--spEcho("FeatureDestroyed", featureID)
	RemovePrimitive(featureID)
end


function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	makeAtlas()
	--if true then return end
	local knownheaps3os = {['arm3x3'] = 1}
	for id , featureDefID in pairs(FeatureDefs) do
		local FD = FeatureDefs[id]
		if FD.modelname and (string.find(FD.modelname:lower(), "_dead", nil, true) or string.find(FD.name, "_heap", nil, true) ) then -- todo TREES!
			-- lets see if we can find an image for this one!
			local modelnamenos3o = string.gsub(string.lower(FD.modelname), ".s3o","")
			modelnamenos3o = basepath(modelnamenos3o,'/')

			--spEcho(FD.name, modelnamenos3o, atlassedImages[modelnamenos3o] )
			if atlassedImages[modelnamenos3o] then
				--spEcho(modelnamenos3o,atlassedImages[modelnamenos3o])
				local atlasname = basepath(atlassedImages[modelnamenos3o],'/')
				local sizestr = ""
				if string.find(atlasname, "_dead", nil, true) then -- regular wrecks
					sizestr = string.sub(atlasname,
						(string.find(atlasname, "_dead", nil, true) or 0) + 6, 
						string.find(atlasname, "_aoplane.dds", nil, true)-1)
				else -- heaps override
					sizestr = string.sub(atlasname,9,11)
				end
				
					--spEcho(atlasname, modelnamenos3o, sizestr)
				local sizex = string.sub(sizestr, 1, string.find(sizestr, "_", nil, true)-1)
				local sizez = string.sub(sizestr, string.find(sizestr, "_", nil, true)+1 )
				--spEcho(sizex, sizez)
				featureDefIDtoDecalInfo[id] = {
					texfile = atlassedImages[modelnamenos3o],
					sizex = (sizex or 8) *16,
					sizez = (sizez or 8) *16,
					alpha = 1.0,
				}
			end
			
		elseif FD.customParams then 
			if  FD.customParams.decalinfo_texfile then 
				featureDefIDtoDecalInfo[id] = {
					texfile = atlassedImages[FD.customParams.decalinfo_texfile],
					sizex = (tonumber(FD.customParams.decalinfo_sizex) or 5) * 16,
					sizez = (tonumber(FD.customParams.decalinfo_sizez) or 5) * 16,
					alpha = (tonumber(FD.customParams.decalinfo_alpha) or 1.0) * 1.0,
				}
			end
		end
	end
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 0
	shaderConfig.FULL_ROTATION = 1 
	shaderConfig.CLIPTOLERANCE = 1.2
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.ZPULL = 512.0 -- send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, pow(texcolor.a,0.85) * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	groundPlateVBO, groundPlateShader = InitDrawPrimitiveAtUnit(shaderConfig, "Ground AO Plates Features")
	if groundPlateVBO == nil then 
		widgetHandler:RemoveWidget()
		return
	end
	groundPlateVBO.featureIDs = true
	ProcessAllFeatures() 
end

local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
end

local commandqueue = {}
function widget:TextCommand(command)
	if string.find(command,"givefeatures", nil, true ) then
		local s = string.split(command, ' ') 
		spEcho("/luaui givefeatures featurename")
		local key = s[2]
		local matches = {}
		for featureDefID, featureDef in ipairs(FeatureDefs) do 
			if string.find(featureDef.name,key, nil, true) then 
				matches[#matches+1] = featureDef.name
			end
		end
		if #matches > 0 then
			local mx, my, mb = Spring.GetMouseState()
			local _, coords = Spring.TraceScreenRay(mx, my, true) 
			local maxx = math.ceil(math.sqrt(#matches))
			local size = 80
			local i = 1
			if coords then 
				for z= coords[3],  coords[3] + size * maxx, size do
					for x= coords[1],  coords[1] + size * maxx, size do
						if i <= #matches then 
							commandqueue[#commandqueue+1] = string.format('give %s @%d,%d,%d',
								matches[i],
								x,
								Spring.GetGroundHeight(x,z),
								z)
							i=i+1
						end
					end
				end
			end
		end
	end
end

function widget:GameFrame()
	if #commandqueue > 0 then 
		Spring.SendCommands({commandqueue[#commandqueue]})
		commandqueue[#commandqueue] = nil
	end
end


