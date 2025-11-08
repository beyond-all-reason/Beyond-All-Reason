local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "TeamPlatter", -- GL4
		desc = "Draw geometric primitives at any unit",
		author = "Beherith, Floris",
		date = "November 2021",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Configurable Parts:
local opacity = 0.25
local skipOwnTeam = false

---- GL4 Backend Stuff----

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local teamplatterVBO = nil
local teamplatterShader = nil
local luaShaderDir = "LuaUI/Include/"

-- Localize for speedups:
local glStencilFunc         = gl.StencilFunc
local glStencilOp           = gl.StencilOp
local glStencilTest         = gl.StencilTest
local glStencilMask         = gl.StencilMask
local glDepthTest           = gl.DepthTest
local glClear               = gl.Clear
local GL_ALWAYS             = GL.ALWAYS
local GL_NOTEQUAL           = GL.NOTEQUAL
local GL_KEEP               = 0x1E00 --GL.KEEP
local GL_STENCIL_BUFFER_BIT = GL.STENCIL_BUFFER_BIT
local GL_REPLACE            = GL.REPLACE
local GL_POINTS				= GL.POINTS

local hasBadCulling = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == true)

local spGetUnitTeam = Spring.GetUnitTeam

local myTeamID = Spring.GetMyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

local unitScale = {}
local unitCanFly = {}
local unitBuilding = {}
local unitDecoration = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = (7.5 * ( unitDef.xsize*xsize + unitDef.zsize*zsize ) ^ 0.5) + 8
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.7
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitBuilding[unitDefID] = {
			unitDef.xsize * 8.2 + 12,
			unitDef.zsize * 8.2 + 12
		}
	end
	if unitDef.customParams.decoration then
		unitDecoration[unitDefID] = true
	end
end

local function AddPrimitiveAtUnit(unitID, unitDefID, unitTeamID, noUpload)
	if (not skipOwnTeam or unitTeamID ~= myTeamID) and unitTeamID ~= gaiaTeamID and not unitDecoration[unitDefID] then
		local gf = Spring.GetGameFrame()

		local numVertices = 64 -- default to circle
		local cornersize = 0

		local radius = unitScale[unitDefID]

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

		pushElementInstance(
			teamplatterVBO, -- push into this Instance VBO Table
			{
				length, width, cornersize, additionalheight,  -- lengthwidthcornerheight
				unitTeamID, -- teamID
				numVertices, -- how many trianges should we make
				gf, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
				0, 1, 0, 1, -- These are our default UV atlas tranformations
				0, 0, 0, 0 -- these are just padding zeros, that will get filled in
			},
			unitID, -- this is the key inside the VBO TAble,
			true, -- update existing element
			noUpload, -- noupload, dont use unless you
			unitID -- last one should be UNITID?
		)
	end
end

local drawFrame = 0
function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end
	drawFrame = drawFrame + 1
	if teamplatterVBO.usedElements > 0 then
		teamplatterShader:Activate()
		teamplatterShader:SetUniform("iconDistance", 99999) -- pass
		glStencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
		glDepthTest(true)
		glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE) -- Set The Stencil Buffer To 1 Where Draw Any Polygon		this to the shader
		glClear(GL_STENCIL_BUFFER_BIT ) -- set stencil buffer to 0

		glStencilFunc(GL_NOTEQUAL, 1, 1) -- use NOTEQUAL instead of ALWAYS to ensure that overlapping transparent fragments dont get written multiple times
		glStencilMask(1)

		if hasBadCulling then
			gl.Culling(false)
		else
			gl.Culling(GL.BACK)
		end

		teamplatterShader:SetUniform("addRadius", 0)
		teamplatterVBO.VAO:DrawArrays(GL_POINTS, teamplatterVBO.usedElements)

		--[[ -- this second draw pass is only needed if we actually want to draw the unit's radius
		glStencilFunc(GL_NOTEQUAL, 1, 1)
		glStencilMask(0)
		glDepthTest(true)

		teamplatterShader:SetUniform("addRadius", 0.15)
		teamplatterVBO.VAO:DrawArrays(GL_POINTS, teamplatterVBO.usedElements)
		]]--

		glStencilMask(1)
		glStencilFunc(GL_ALWAYS, 1, 1)
		glDepthTest(true)

		teamplatterShader:Deactivate()
	end
end

local function RemoveUnit(unitID)
	if teamplatterVBO.instanceIDtoIndex[unitID] then
		popElementInstance(teamplatterVBO, unitID)
	end
end

--- Look how easy api_unit_tracker is to use!
function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddPrimitiveAtUnit(unitID, unitDefID, unitTeam)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(teamplatterVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddPrimitiveAtUnit(unitID, unitDefID, spGetUnitTeam(unitID), true) -- add them with noUpload = true
	end
	InstanceVBOTable.uploadAllElements(teamplatterVBO) -- upload them all
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	RemoveUnit(unitID)
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemoveUnit(unitID)
end

local function init()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
	shaderConfig.USETEXTURE = 0
	teamplatterVBO, teamplatterShader = InitDrawPrimitiveAtUnit(shaderConfig, "teamPlatters")
	if teamplatterVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
	return true
end

function widget:Initialize()
	if not init() then return end
	WG['teamplatter'] = {}
	WG['teamplatter'].getOpacity = function()
		return opacity
	end
	WG['teamplatter'].setOpacity = function(value)
		opacity = value
		init()
	end
	WG['teamplatter'].getSkipOwnTeam = function()
		return skipOwnTeam
	end
	WG['teamplatter'].setSkipOwnTeam = function(value)
		skipOwnTeam = value
		init()
	end
end

function widget:Shutdown()
	WG['teamplatter'] = nil
end

function widget:GetConfigData(data)
	return {
		opacity = opacity,
		skipOwnTeam = skipOwnTeam,
	}
end

function widget:SetConfigData(data)
	opacity = data.opacity or opacity
	skipOwnTeam = data.skipOwnTeam or skipOwnTeam
end
