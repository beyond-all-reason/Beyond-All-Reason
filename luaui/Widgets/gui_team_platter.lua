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

local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

---@type InstanceVBOTable?
local teamplatterVBO = nil
local teamplatterShader = nil
local shaderOpacity = -1.0 -- the opacity the shader's uniforms were last set for
local luaShaderDir = "LuaUI/Include/"

-- Localize for speedups:
local glStencilFunc = gl.StencilFunc
local glStencilOp = gl.StencilOp
local glStencilTest = gl.StencilTest
local glStencilMask = gl.StencilMask
local glDepthTest = gl.DepthTest
local glCulling = gl.Culling
local glColorMask = gl.ColorMask
local GL_ALWAYS = GL.ALWAYS
local GL_EQUAL = GL.EQUAL
local GL_KEEP = GL.KEEP
local GL_REPLACE = GL.REPLACE
local GL_ZERO = GL.ZERO
local GL_POINTS = GL.POINTS
local GL_BACK = GL.BACK

local hasBadCulling = ((Platform.gpuVendor == "AMD" and Platform.osFamily == "Linux") == true)

local spGetUnitTeam = Spring.GetUnitTeam
local spIsGUIHidden = Spring.IsGUIHidden

local myTeamID = Spring.GetLocalTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

-- per unitDefID primitive: length, width, corner size and numvertices (64 circle, 3 triangle, 2 cornerrect)
local unitLength = {}
local unitWidth = {}
local unitCorner = {}
local unitNumVertices = {}
local unitDecoration = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	local radius = (7.5 * (unitDef.xsize * unitDef.xsize + unitDef.zsize * unitDef.zsize) ^ 0.5) + 8
	local width, length, cornersize, numVertices = radius, radius, 0, 64
	if unitDef.canFly then
		width = radius * 0.7
		length = width
		numVertices = 3
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0 then
		width = unitDef.xsize * 8.2 + 12
		length = unitDef.zsize * 8.2 + 12
		cornersize = (width + length) * 0.075
		numVertices = 2
	end
	unitLength[unitDefID] = length
	unitWidth[unitDefID] = width
	unitCorner[unitDefID] = cornersize
	unitNumVertices[unitDefID] = numVertices
	if unitDef.customParams.decoration then
		unitDecoration[unitDefID] = true
	end
end

-- pushElementInstance copies the values, so one table serves every unit
local instanceCache = {
	0,
	0,
	0,
	0, -- lengthwidthcornerheight
	0, -- teamID
	0, -- numvertices
	0,
	0,
	0,
	0, -- parameters (the spawn frame is only read with ANIMATION)
	0,
	1,
	0,
	1, -- uvoffsets
	0,
	0,
	0,
	0, -- instData, filled in by the engine
}

local function AddPrimitiveAtUnit(unitID, unitDefID, unitTeamID, noUpload)
	if (not skipOwnTeam or unitTeamID ~= myTeamID) and unitTeamID ~= gaiaTeamID and not unitDecoration[unitDefID] then
		instanceCache[1] = unitLength[unitDefID]
		instanceCache[2] = unitWidth[unitDefID]
		instanceCache[3] = unitCorner[unitDefID]
		instanceCache[5] = unitTeamID
		instanceCache[6] = unitNumVertices[unitDefID]
		pushElementInstance(teamplatterVBO, instanceCache, unitID, true, noUpload, unitID)
	end
end

local function drawPlatters()
	teamplatterVBO.VAO:DrawArrays(GL_POINTS, teamplatterVBO.usedElements)
end

function widget:DrawWorldPreUnit()
	if teamplatterVBO.usedElements == 0 or spIsGUIHidden() then
		return
	end
	teamplatterShader:Activate()
	if shaderOpacity ~= opacity then
		shaderOpacity = opacity
		teamplatterShader:SetUniform("iconDistance", 99999) -- no distance cutoff
		teamplatterShader:SetUniform("transparency", opacity)
	end
	glStencilTest(true) --https://learnopengl.com/Advanced-OpenGL/Stencil-testing
	glDepthTest(true)
	glStencilMask(1)

	if hasBadCulling then
		glCulling(false)
	else
		glCulling(GL_BACK)
	end

	-- Overlapping platters must blend each pixel once: mark their pixels in stencil bit 0, then draw where marked and
	-- unmark in the same pass. The first platter still wins, and the bit ends at 0 without full-screen stencil clears
	-- (one costs ~50 us at 5K right after a pass that wrote stencil).
	glColorMask(false, false, false, false)
	glStencilFunc(GL_ALWAYS, 1, 1)
	glStencilOp(GL_KEEP, GL_KEEP, GL_REPLACE)
	drawPlatters()
	glColorMask(true, true, true, true)
	glStencilFunc(GL_EQUAL, 1, 1)
	glStencilOp(GL_KEEP, GL_KEEP, GL_ZERO)
	drawPlatters()

	glStencilFunc(GL_ALWAYS, 1, 1)

	teamplatterShader:Deactivate()

	-- Restore default state (same as gui_selectedunits_gl4), so culling/stencil state doesn't
	-- leak into widgets drawn after this one:
	glCulling(false)
	glStencilTest(false)
	glStencilMask(255)
	glStencilOp(GL_KEEP, GL_KEEP, GL_KEEP)
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

local function rebuild()
	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	end
end

local function checkMyTeam()
	local teamID = Spring.GetLocalTeamID()
	if teamID ~= myTeamID then
		myTeamID = teamID
		if skipOwnTeam then
			rebuild()
		end
	end
end

function widget:PlayerChanged(playerID)
	checkMyTeam()
end

function widget:GameStart()
	checkMyTeam() -- the engine can reset the local team at game start without a PlayerChanged
end

local function init()
	local DPatUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
	shaderConfig.USETEXTURE = 0
	shaderConfig.USE_QUADS = nil
	teamplatterVBO, teamplatterShader = InitDrawPrimitiveAtUnit(shaderConfig, "teamPlatters")
	if teamplatterVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	rebuild()
	return true
end

function widget:Initialize()
	if not init() then
		return
	end
	WG.teamplatter = {}
	WG.teamplatter.getOpacity = function()
		return opacity
	end
	WG.teamplatter.setOpacity = function(value)
		opacity = value -- DrawWorldPreUnit passes it to the shader
	end
	WG.teamplatter.getSkipOwnTeam = function()
		return skipOwnTeam
	end
	WG.teamplatter.setSkipOwnTeam = function(value)
		skipOwnTeam = value
		rebuild()
	end
end

function widget:Shutdown()
	WG.teamplatter = nil
	if type(teamplatterShader) == "table" then
		teamplatterShader:Finalize()
		teamplatterShader = nil
	end
	if teamplatterVBO then
		teamplatterVBO:Delete()
		teamplatterVBO = nil
	end
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
