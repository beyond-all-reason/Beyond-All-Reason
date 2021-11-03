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
local selectionVBO = nil
local selectShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

local glTexture = gl.Texture

local function AddPrimitiveAtUnit(unitID, unitDefID)
	local gf = Spring.GetGameFrame()
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)

	if unitDefID == nil or unitDefIDtoDecalInfo[unitDefID] == nil then return end -- these cant have plates
	local decalInfo = unitDefIDtoDecalInfo[unitDefID]
	
	local texname = "unittextures/decals/".. UnitDefs[unitDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds
	local width = decalInfo.sizex * 16
	local length = decalInfo.sizey * 16
	local numVertices = 4 -- default to circle
	local additionalheight = 0
	
	local p,q,s,t = gl.GetAtlasTexture(atlasID, decalInfo.texfile)
	--Spring.Echo (unitDefName, p,q,s,t)
	
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
			{length, width, 0, additionalheight,  -- lengthwidthcornerheight
			Spring.GetUnitTeam(unitID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			q,p,s,t, -- These are our default UV atlas tranformations, note how X axis is flipped for atlas
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		unitID, -- this is the key inside the VBO Table, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you know what you want to batch push/pop
		unitID) -- last one should be UNITID!
end

function widget:DrawWorldPreUnit()
	if selectionVBO.usedElements > 0 then 
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--Spring.Echo(selectionVBO.usedElements)
		gl.Culling(GL.BACK)
		gl.DepthTest(GL.LEQUAL)
		glTexture(0, atlasID)
		selectShader:Activate()
		selectShader:SetUniform("iconDistance",disticon) 
		selectShader:SetUniform("addRadius",0) 
		selectionVBO.VAO:DrawArrays(GL.POINTS,selectionVBO.usedElements)
		selectShader:Deactivate()
		glTexture(0, false)
	end
end

local function RemovePrimitive(unitID)
	if selectionVBO.instanceIDtoIndex[unitID] then
		popElementInstance(selectionVBO, unitID)
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
	shaderConfig.POST_GEOMETRY = "gl_Position.z = (gl_Position.z) - 256.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	
	
	selectionVBO, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "TESTDPAUMinimal")
	if true then -- FOR TESTING
		local units = Spring.GetAllUnits()
		for _, unitID in ipairs(units) do
			AddPrimitiveAtUnit(unitID)
		end
	end
end

function widget:ShutDown()
	if atlasID ~= nil then 
		gl.DeleteTextureAtlas(atlasID)
	end
end