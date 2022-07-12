function widget:GetInfo()
	return {
		name = "Selected Units GL4",
		desc = "Draw geometric pritives at any unit",
		author = "Beherith, Floris",
		date = "2021.05.16",
		license = "GNU GPL, v2 or later",
		layer = -50,
		enabled = true,
	}
end

-- Configurable Parts:
local texture = "luaui/images/solid.png"

local opacity = 0.19
local teamcolorOpacity = 0.6

---- GL4 Backend Stuff----
local selectionVBO = nil
local selectShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

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

local selUnits = {}
local updateSelection = true
local selectedUnits = Spring.GetSelectedUnits()

local unitTeam = {}
local unitUnitDefID = {}

local unitScale = {}
local unitCanFly = {}
local unitBuilding = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = (7.5 * ( unitDef.xsize^2 + unitDef.zsize^2 ) ^ 0.5) + 8
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.7
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitBuilding[unitDefID] = {
			unitDef.xsize * 8.2 + 12,
			unitDef.zsize * 8.2 + 12
		}
	end
end

local function AddPrimitiveAtUnit(unitID)
	if Spring.ValidUnitID(unitID) ~= true or Spring.GetUnitIsDead(unitID) == true then return end
	local gf = Spring.GetGameFrame()

	if not unitUnitDefID[unitID] then
		unitUnitDefID[unitID] = Spring.GetUnitDefID(unitID)
	end
	local unitDefID = unitUnitDefID[unitID]
	if unitDefID == nil then return end -- these cant be selected

	local numVertices = 64 -- default to cornered rectangle
	local cornersize = 0

	local radius = unitScale[unitDefID]

	if not unitTeam[unitID] then
		unitTeam[unitID] = Spring.GetUnitTeam(unitID)
	end

	local additionalheight = 0
	local width, length
	if unitCanFly[unitDefID] then
		numVertices = 3 -- triangles for planes
		width = radius
		length = radius
	elseif unitBuilding[unitDefID] then
		width = unitBuilding[unitDefID][1]
		length = unitBuilding[unitDefID][2]
		cornersize = (width + length) * 0.075
		numVertices = 2
	else
		width = radius
		length = radius
	end

	--Spring.Echo(unitID,radius,radius, Spring.GetUnitTeam(unitID), numvertices, 1, gf)
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
		{
			length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
			unitTeam[unitID], -- teamID
			numVertices, -- how many trianges should we make
			gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you
		unitID -- last one should be UNITID?
	)
end

local drawFrame = 0
function widget:DrawWorldPreUnit()
	drawFrame = drawFrame + 1
	if selectionVBO.usedElements > 0 then
		glTexture(0, texture)
		selectShader:Activate()
		selectShader:SetUniform("iconDistance", 99999) -- pass
		glStencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		glDepthTest(true)
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
		glClear(GL_STENCIL_BUFFER_BIT ) -- set stencil buffer to 0

		glStencilFunc(GL_NOTEQUAL, 1, 1) -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
		glStencilMask(1)

		selectShader:SetUniform("addRadius", 0)
		selectionVBO.VAO:DrawArrays(GL_POINTS, selectionVBO.usedElements)

		glStencilFunc(GL_NOTEQUAL, 1, 1)
		glStencilMask(0)
		glDepthTest(true)

		selectShader:SetUniform("addRadius", 1.7)
		selectionVBO.VAO:DrawArrays(GL_POINTS, selectionVBO.usedElements)

		glStencilMask(1)
		glStencilFunc(GL_ALWAYS, 1, 1)
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

function widget:SelectionChanged(sel)
	updateSelection = true
end

function widget:Update(dt)
	if updateSelection then
		selectedUnits = Spring.GetSelectedUnits()
		updateSelection = false

		local newSelUnits = {}
		-- add to selection
		for i, unitID in ipairs(selectedUnits) do
			newSelUnits[unitID] = true
			if not selUnits[unitID] then
				AddPrimitiveAtUnit(unitID)
			end
		end
		-- remove from selection
		for unitID, _ in pairs(selUnits) do
			if not newSelUnits[unitID] then
				RemovePrimitive(unitID)
			end
		end
		selUnits = newSelUnits
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	if unitTeam[unitID] then
		unitTeam[unitID] = newTeamID
	end
end

function widget:UnitDestroyed(unitID)
	--Spring.Echo("UnitDestroyed(unitID)",unitID, selectedUnits[unitID])
	if selectedUnits[unitID] then
		RemovePrimitive(unitID)
	end
	unitTeam[unitID] = nil
	unitUnitDefID[unitID] = nil
end

local function init()
	updateSelection = true
	selUnits = {}	
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.BILLBOARD = 0
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.INITIALSIZE = 0.75
	shaderConfig.GROWTHRATE = 3.5
	shaderConfig.TEAMCOLORIZATION = teamcolorOpacity	-- not implemented, doing it via POST_SHADING below instead
	shaderConfig.HEIGHTOFFSET = 4
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(mix(g_color.rgb * texcolor.rgb + addRadius, vec3(1.0), "..(1-teamcolorOpacity)..") , texcolor.a * TRANSPARENCY + addRadius);"
	selectionVBO, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "selectedUnits")
	if selectionVBO == nil then 
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

function widget:Initialize()
	if not init() then return end
	WG.selectedunits = {}
	WG.selectedunits.getOpacity = function()
		return opacity
	end
	WG.selectedunits.setOpacity = function(value)
		opacity = value
		init()
	end
	WG.selectedunits.getTeamcolorOpacity = function()
		return teamcolorOpacity
	end
	WG.selectedunits.setTeamcolorOpacity = function(value)
		teamcolorOpacity = value
		init()
	end
	Spring.LoadCmdColorsConfig('unitBox  0 1 0 0')
end

function widget:Shutdown()
	if not (WG.teamplatter or WG.highlightselunits) then
		Spring.LoadCmdColorsConfig('unitBox  0 1 0 1')
	end
	WG.selectedunits = nil
end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
		teamcolorOpacity = teamcolorOpacity
	}
end

function widget:SetConfigData(data)
	opacity = data.opacity or opacity
	teamcolorOpacity = data.teamcolorOpacity or teamcolorOpacity
end
