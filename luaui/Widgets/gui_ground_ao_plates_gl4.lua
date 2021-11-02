function widget:GetInfo()
	return {
		name = "Ground AO Plates GL4",
		desc = "Draw the same ground ao plates that we otherwise would, just with Lua",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Configurable Parts:
--local texture = "luaui/images/backgroundtile.png"

local atlasID = nil
local atlasSize = 2048
local atlassedImages = {}

local iconTypes, iconSizes
-- remember, we can use xXyY = gl.GetAtlasTexture(atlasID, texture) to query the atlas

local function addDirToAtlas(atlas, path)
	local imgExts = {bmp = true,tga = true,jpg = true,png = true,dds = true, tif = true}
	local numadded = 0
	local files = VFS.DirList(path)
	--Spring.Echo("Adding",#files, "images to atlas from", path)
	for i=1, #files do
		if imgExts[string.sub(files[i],-3,-1)] then
			gl.AddAtlasTexture(atlas,files[i])
			Spring.Echo(files[i])
			atlassedImages[files[i]] = true 
			numadded = numadded + 1
		end
	end
	return numadded
end

local function makeAtlas()
	atlasID = gl.CreateTextureAtlas(atlasSize,atlasSize,0)
	addDirToAtlas(atlasID, "unittextures/decals/")
	Spring.Echo("Finalizing Unit Texture Atlas")
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

	if unitDefID == nil or UnitDefs[unitDefID].useBuildingGroundDecal == false then return end -- these cant have plates
	
	local texname = "unittextures/decals/".. UnitDefs[unitDefID].name .. "_aoplane.dds" --unittextures/decals/armllt_aoplane.dds
	local width = UnitDefs[unitDefID].buildingDecalSizeX * 16
	local length = UnitDefs[unitDefID].buildingDecalSizeY * 16 
	
	local numVertices = 4 -- default to circle
	
	local additionalheight = 0
	
	local p,q,s,t = gl.GetAtlasTexture(atlasID, texname)
	--Spring.Echo (unitDefName, p,q,s,t)
	
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
			{length, width, 0, additionalheight,  -- lengthwidthcornerheight
			Spring.GetUnitTeam(unitID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			p,q,s,t, -- These are our default UV atlas tranformations
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		unitID, -- this is the key inside the VBO TAble, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you 
		unitID) -- last one should be UNITID!
end

function widget:DrawWorldPreUnit()
	if selectionVBO.usedElements > 0 then 
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		glTexture(0, atlasID)
		selectShader:Activate()
		selectShader:SetUniform("iconDistance",disticon) 
		selectShader:SetUniform("addRadius",0) 
		selectionVBO.VAO:DrawArrays(GL.POINTS,selectionVBO.usedElements)
		selectShader:Deactivate()
		glTexture(0, false)
	end
end

function widget:UnitCreated(unitID)
	if not Spring.IsUnitAllied(unitID) then return end
	AddPrimitiveAtUnit(unitID)
end

function widget:UnitDestroyed(unitID)
	RemovePrimitive(unitID)
end

function widget:Initialize()
	makeAtlas()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 0
	shaderConfig.HEIGHTOFFSET = 1
	shaderConfig.TRANSPARENCY = 1
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