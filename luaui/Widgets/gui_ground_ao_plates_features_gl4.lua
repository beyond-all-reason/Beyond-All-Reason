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

local atlas = require("unittextures/decals_features/featureaoplates_atlas")
local plateAtlas
local featureDefIDtoDecalInfo = {}

---- GL4 Backend Stuff----
local groundPlateVBO = nil
local groundPlateShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable = gl.InstanceVBOTable

local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance = InstanceVBOTable.popElementInstance

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local function AddPrimitiveAtUnit(featureID, featureDefID, noUpload)
	local gf = Spring.GetGameFrame()
	featureDefID = featureDefID or Spring.GetFeatureDefID(featureID)

	if featureDefID == nil or featureDefIDtoDecalInfo[featureDefID] == nil then
		return
	end -- these can't have plates
	local decalInfo = featureDefIDtoDecalInfo[featureDefID]

	--local texname = "unittextures/decals/".. UnitDefs[featureDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds

	local numVertices = 4 -- default to circle
	local additionalheight = 0

	local p, q, s, t = unpack(decalInfo.uv)
	if decalInfo.atlasIndex == 1 then
		s, t = 1 - s, 1 - t -- runtime atlas images use the opposite Y orientation
	end
	--spEcho (featureDefID,featureID,decalInfo.texfile, decalInfo.sizez, decalInfo.sizex , decalInfo.alpha, p, q, s,t)

	pushElementInstance(
		groundPlateVBO, -- push into this Instance VBO Table
		{
			decalInfo.sizeZ,
			decalInfo.sizeX,
			0,
			additionalheight, -- lengthwidthcornerheight
			0, --Spring.GetUnitTeam(featureID), -- teamID
			numVertices, -- how many triangles should we make
			gf,
			decalInfo.atlasIndex, -- parameters.y selects the prebuilt/runtime atlas
			decalInfo.alpha * decalAlpha,
			0, -- the gameFrame (for animations), and any other parameters one might want to add
			q,
			p,
			t,
			s, -- These are our default UV atlas transformations, note how X axis is flipped for atlas
			0,
			0,
			0,
			0,
		}, -- these are just padding zeros, that will get filled in
		featureID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		featureID
	) -- last one should be featureID!
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
		if plateAtlas.runtimeTexture then
			glTexture(1, plateAtlas.runtimeTexture)
		end
		groundPlateShader:Activate()
		groundPlateShader:SetUniform("iconDistance", disticon)
		groundPlateShader:SetUniform("addRadius", 0)
		groundPlateVBO.VAO:DrawArrays(GL.POINTS, groundPlateVBO.usedElements)
		groundPlateShader:Deactivate()
		glTexture(0, false)
		if plateAtlas.runtimeTexture then
			glTexture(1, false)
		end
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
	widgetHandler:AddAction("givefeatures", givefeaturesCmd, nil, "t")

	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	local GroundAOAtlas = VFS.Include(luaShaderDir .. "GroundAOAtlas.lua")
	plateAtlas = GroundAOAtlas.Create(atlas, "unittextures/decals_features", FeatureDefs, "feature")
	local runtimeImages = {}
	local runtimeImageCount = 0
	for _, plate in pairs(plateAtlas.plates) do
		if plate.atlasIndex == 1 and not runtimeImages[plate.texturePath] then
			runtimeImages[plate.texturePath] = true
			runtimeImageCount = runtimeImageCount + 1
		end
	end
	local runtimeInfo = plateAtlas.runtimeTexture and gl.TextureInfo(plateAtlas.runtimeTexture)
	Spring.Echo(
		"Ground AO feature incremental atlas: "
			.. runtimeImageCount
			.. " image(s), "
			.. (runtimeInfo and (runtimeInfo.xsize .. "x" .. runtimeInfo.ysize) or "not created")
	)
	featureDefIDtoDecalInfo = plateAtlas.plates
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 1.0
	shaderConfig.ANIMATION = 0
	shaderConfig.USE_SECONDARY_TEXTURE = plateAtlas.runtimeTexture and 1 or 0
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
		plateAtlas:Delete()
		widgetHandler:RemoveWidget()
		return
	end
	groundPlateVBO.featureIDs = true
	ProcessAllFeatures()
end

local spec, fullview = spGetSpectatingState()
local allyTeamID = Spring.GetLocalAllyTeamID()

function widget:PlayerChanged()
	spec, fullview = spGetSpectatingState()
	allyTeamID = Spring.GetLocalAllyTeamID()
end

local commandqueue = {}
function givefeaturesCmd(_, line)
	spEcho("/luaui givefeatures featurename")
	local key = (line or ""):match("%S+")
	if not key then
		return true
	end
	local matches = {}
	for featureDefID, featureDef in ipairs(FeatureDefs) do
		if string.find(featureDef.name, key, nil, true) then
			matches[#matches + 1] = featureDef.name
		end
	end
	if #matches > 0 then
		local mx, my, _ = Spring.GetMouseState()
		local _, coords = Spring.TraceScreenRay(mx, my, true)
		local maxx = math.ceil(math.sqrt(#matches))
		local size = 80
		local i = 1
		if coords then
			for z = coords[3], coords[3] + size * maxx, size do
				for x = coords[1], coords[1] + size * maxx, size do
					if i <= #matches then
						commandqueue[#commandqueue + 1] =
							string.format("give %s @%d,%d,%d", matches[i], x, Spring.GetGroundHeight(x, z), z)
						i = i + 1
					end
				end
			end
		end
	end
	return true
end

function widget:GameFrame()
	if #commandqueue > 0 then
		Spring.SendCommands({ commandqueue[#commandqueue] })
		commandqueue[#commandqueue] = nil
	end
end

function widget:Shutdown()
	widgetHandler:RemoveAction("givefeatures", "t")
	if plateAtlas then
		plateAtlas:Delete()
	end
	if type(groundPlateShader) == "table" then
		groundPlateShader:Finalize()
		groundPlateShader = nil
	end
end
