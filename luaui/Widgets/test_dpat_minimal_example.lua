local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "TEST DrawPrimitiveAtUnit GL4 Minimal Example",
		desc = "Draw geometric pritives at any unit",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Configurable Parts:
local texture = "luaui/images/backgroundtile.png"

---- GL4 Backend Stuff----

local InstanceVBOTable = gl.InstanceVBOTable
local pushElementInstance = InstanceVBOTable.pushElementInstance

local selectionVBO = nil
local selectShader = nil
local luaShaderDir = "LuaUI/Include/"

local glTexture             = gl.Texture

local function AddPrimitiveAtUnit(unitID, unitDefID)
	local gf = Spring.GetGameFrame()
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if unitDefID == nil then return end -- these cant be selected
	local numVertices = 62 -- default to circle
	local cornersize = 0
	
	local radius = Spring.GetUnitRadius(unitID) * 2.6 or 64
	local width = radius 
	local length = radius
	local additionalheight = 2*radius
	
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
			{length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
			Spring.GetUnitTeam(unitID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		unitID, -- this is the key inside the VBO TAble, should be unique per unit
		true, -- update existing element
		nil, -- noupload, dont use unless you 
		unitID) -- last one should be UNITID!
end

function widget:DrawWorldPreUnit()
	if selectionVBO.usedElements > 0 then 
		local disticon = 27 * Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		glTexture(0, texture)
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
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 1
	selectionVBO, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "TESTDPAUMinimal")
	if true then -- FOR TESTING
		local units = Spring.GetAllUnits()
		for _, unitID in ipairs(units) do
			AddPrimitiveAtUnit(unitID)
		end
	end
end

function widget:ShutDown()
end