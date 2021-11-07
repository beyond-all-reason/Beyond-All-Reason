function widget:GetInfo()
	return {
		name = "Ground AO Plates GL4",
		desc = "Draw ground ao plates under buildings",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = true,
	}
end
-- advanced geoshader tricount for quads
-- 2x2 - 4
-- 3x3 - 12
-- 4x4 - 40
-- 5x5 - 65!
-- Configurable Parts:
local atlasID = nil
local atlasSize = 2048
local atlassedImages = {}
local unitDefIDtoDecalInfo = {} -- key unitdef, table of {texfile = "", sizex = 4 , sizez = 4}
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas

local function addDirToAtlas(atlas, path)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local files = VFS.DirList(path)
	--Spring.Echo("Adding",#files, "images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			gl.AddAtlasTexture(atlas,files[i])
			atlassedImages[files[i]] = true 
		end
	end
end

local function makeAtlas()
	atlasID = gl.CreateTextureAtlas(atlasSize,atlasSize,0)
	addDirToAtlas(atlasID, "unittextures/decals/")
	gl.FinalizeTextureAtlas(atlasID)
end

---- GL4 Backend Stuff----
local groundPlateVBO = nil
local groundPlateShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture
local glCulling = gl.Culling
local glDepthTest = gl.DepthTest
local GL_BACK = GL.BACK
local GL_LEQUAL = GL.LEQUAL

local function AddPrimitiveAtUnit(unitID, unitDefID, noUpload)
	local gf = Spring.GetGameFrame()
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	if unitDefID == nil or unitDefIDtoDecalInfo[unitDefID] == nil then return end -- these cant have plates
	local decalInfo = unitDefIDtoDecalInfo[unitDefID]
	
	local texname = "unittextures/decals/".. UnitDefs[unitDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds
	local width = decalInfo.sizex * 16
	local length = decalInfo.sizey * 16
	local numVertices = 4 -- default to circle
	local additionalheight = 0
  local alpha = 1.0
	
	local p,q,s,t = gl.GetAtlasTexture(atlasID, decalInfo.texfile)
	--Spring.Echo (unitDefName, p,q,s,t)
	
	pushElementInstance(
		groundPlateVBO, -- push into this Instance VBO Table
			{length, width, 0, additionalheight,  -- lengthwidthcornerheight
			Spring.GetUnitTeam(unitID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, alpha, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			q,p,s,t, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		noUpload, -- noupload, dont use unless you know what you want to batch push/pop
		unitID) -- last one should be UNITID!
end

local doRefresh = false

local function ProcessAllUnits()
	clearInstanceTable(groundPlateVBO)
	local units = Spring.GetAllUnits()
	--Spring.Echo("Refreshing Ground Plates", #units)
	for _, unitID in ipairs(units) do
		AddPrimitiveAtUnit(unitID, nil, true)
	end
	uploadAllElements(groundPlateVBO)
end

function widget:DrawWorldPreUnit()
	if doRefresh then
		ProcessAllUnits()
		doRefresh = false
	end
	if groundPlateVBO.usedElements > 0 then 
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(groundPlateVBO.usedElements)
		glCulling(GL_BACK)
		glDepthTest(GL_LEQUAL)
		glTexture(0, atlasID)
		groundPlateShader:Activate()
		groundPlateShader:SetUniform("iconDistance",disticon) 
		groundPlateShader:SetUniform("addRadius",0) 
		groundPlateVBO.VAO:DrawArrays(GL.POINTS,groundPlateVBO.usedElements)
		groundPlateShader:Deactivate()
		glTexture(0, false)
		glCulling(false)
		glDepthTest(false)
	end
end

local function RemovePrimitive(unitID)
	if groundPlateVBO.instanceIDtoIndex[unitID] then
		popElementInstance(groundPlateVBO, unitID)
	end
end

function widget:UnitCreated(unitID)
	AddPrimitiveAtUnit(unitID)
end

function widget:UnitDestroyed(unitID)
	RemovePrimitive(unitID)
end

function widget:RenderUnitDestroyed(unitID)
	RemovePrimitive(unitID)
end

function widget:UnitEnteredLos(unitID)
	AddPrimitiveAtUnit(unitID)
end

function widget:UnitLeftLos(unitID)
	RemovePrimitive(unitID)
end

function widget:Initialize()
	makeAtlas()
	for id , unitDefID in pairs(UnitDefs) do
		local UD = UnitDefs[id]
		if UD.customParams and UD.customParams.usebuildinggrounddecal and UD.customParams.buildinggrounddecaltype then
			--local UD.name
			local texname = "unittextures/" .. UD.customParams.buildinggrounddecaltype
			---Spring.Echo(texname)
			if atlassedImages[texname] then 
				unitDefIDtoDecalInfo[id] = {
					texfile = texname, 
					sizex  = UD.customParams.buildinggrounddecalsizex, 
					sizey  = UD.customParams.buildinggrounddecalsizey}
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
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
  shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.POST_GEOMETRY = "g_uv.w = dataIn[0].v_parameters.w; gl_Position.z = (gl_Position.z) - 256.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
  shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb* (1.0 + g_uv.w), texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	
	
	groundPlateVBO, groundPlateShader = InitDrawPrimitiveAtUnit(shaderConfig, "Ground AO Plates")

	ProcessAllUnits() 
end

local spec, fullview = Spring.GetSpectatingState()
local allyTeamID = Spring.GetMyAllyTeamID()

function widget:PlayerChanged()
	local prevFullview = fullview
	local myPrevAllyTeamID = allyTeamID
	spec, fullview = Spring.GetSpectatingState()
	allyTeamID = Spring.GetMyAllyTeamID()
	if fullview ~= prevFullview or allyTeamID ~= myPrevAllyTeamID then
		doRefresh = true
	end
end


function widget:ShutDown()
	if atlasID ~= nil then 
		gl.DeleteTextureAtlas(atlasID)
	end
end