local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "TEST DrawPrimitiveAtUnit GL4",
		desc = "Draw geometric pritives at any unit",
		author = "Beherith",
		date = "2021.11.02",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end


-- Localized functions for performance

-- Localized Spring API for performance
local spEcho = Spring.Echo
local spGetUnitTeam = Spring.GetUnitTeam

-- Configurable Parts:
local texture = "luaui/images/backgroundtile.png"

---- GL4 Backend Stuff----

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local selectionVBO = nil
local selectShader = nil
local luaShaderDir = "LuaUI/Include/"

-- Localize for speedups:
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local glStencilMask         = gl.StencilMask
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local glClear               = gl.Clear
local GL_ALWAYS             = GL.ALWAYS
local GL_NOTEQUAL           = GL.NOTEQUAL
local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_REPLACE            = GL.REPLACE
local GL_POINTS				= GL.POINTS


local function AddPrimitiveAtUnit(unitID, unitDefID)
	local gf = Spring.GetGameFrame()
	unitDefID = unitDefID or Spring.GetUnitDefID(unitID)
	if unitDefID == nil then return end -- these cant be selected
	local numVertices = 64 -- default to cornered rectangle  
	local cornersize = 0
	
	local radius = Spring.GetUnitRadius(unitID) * 2.6 or 64
	local width = radius 
	local length = radius
	local additionalheight = 0
	
	local unitDef = UnitDefs[unitDefID]
	if UnitDefs[unitDefID].canFly then 
		numVertices = 3
		width = radius /2
		length = radius /2
	end -- triangles for planes
	if unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then 
		width = unitDef.xsize * 8 + 16
		length = unitDef.zsize * 8 + 16 
		cornersize = (width + length) * 0.075
		numVertices = 2
	end
	
	--spEcho(unitID,radius,radius, spGetUnitTeam(unitID), numvertices, 1, gf)
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
			{length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
			spGetUnitTeam(unitID), -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0}, -- these are just padding zeros, that will get filled in 
		unitID, -- this is the key inside the VBO TAble, 
		true, -- update existing element
		nil, -- noupload, dont use unless you 
		unitID) -- last one should be UNITID?
end

local drawFrame = 0
function widget:DrawWorldPreUnit()
	drawFrame = drawFrame + 1
	if selectionVBO.usedElements > 0 then 
		if drawFrame % 100 == 0 then spEcho("selectionVBO.usedElements",selectionVBO.usedElements) end
		local disticon = Spring.GetConfigInt("UnitIconDist", 200) -- iconLength = unitIconDist * unitIconDist * 750.0f;
		--gl.Culling(false)
		disticon = disticon * 27 -- should be sqrt(750) but not really
		glTexture(0, texture)
		selectShader:Activate()
		selectShader:SetUniform("iconDistance",disticon) -- pass
		glStencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		glDepthTest(true)
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
		glClear(GL_STENCIL_BUFFER_BIT ) -- set stencil buffer to 0 

		glStencilFunc(GL_NOTEQUAL, 1, 1); -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
		glStencilMask(1)
	
		selectShader:SetUniform("addRadius",0) -- pass this 
		selectionVBO.VAO:DrawArrays(GL_POINTS,selectionVBO.usedElements)
		
		glStencilFunc(GL_NOTEQUAL, 1, 1);
		glStencilMask(0)
		glDepthTest(true)
		
		selectShader:SetUniform("addRadius",2) -- pass this 
		selectionVBO.VAO:DrawArrays(GL_POINTS,selectionVBO.usedElements)
		
		glStencilMask(1)
		glStencilFunc(GL_ALWAYS, 1, 1);
		glDepthTest(true)
		
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
	--spEcho("UnitDestroyed",unitID)
	RemovePrimitive(unitID)
end

function widget:RenderUnitDestroyed(unitID)
	--spEcho("RenderUnitDestroyed",unitID)
	RemovePrimitive(unitID)
end

function widget:UnitEnteredLos(unitID)
	--spEcho("UnitLeftLos",unitID)
	AddPrimitiveAtUnit(unitID)
end

function widget:UnitLeftLos(unitID)
	--spEcho("UnitLeftLos",unitID)
	RemovePrimitive(unitID)
end

function widget:UnitDestroyedByTeam(unitID, unitDefID, unitTeam, attackerTeamID)
	--spEcho("UnitDestroyedByTeam",unitID)
	RemovePrimitive(unitID)
end

function widget:Initialize()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.BILLBOARD = 0
	selectionVBO, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "TESTDPAU")
	if selectionVBO == nil then 
		widgetHandler:RemoveWidget()
		return
	end
	if true then -- FOR TESTING
		local units = Spring.GetAllUnits()
		for _, unitID in ipairs(units) do
			AddPrimitiveAtUnit(unitID)
		end
	end
end

function widget:ShutDown()
end