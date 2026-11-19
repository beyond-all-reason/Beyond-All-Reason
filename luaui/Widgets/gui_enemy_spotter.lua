local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "EnemySpotter", -- GL4
		desc = "Draws a team-colored glowring underneath every enemy unit",
		author = "Beherith, Floris",
		date = "December 2021",
		license = "GNU GPL, v2 or later",
		layer = -1,
		enabled = false,
	}
end

-- Configurable Parts:
local texture = "LuaUI/Images/enemyspotter.dds"
local opacity = 0.23
local skipOwnTeam = true
local sizeMultiplier = 1.25

---- GL4 Backend Stuff----

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

---@type InstanceVBOTable?
local enemyspotterVBO = nil
local enemyspotterShader = nil
local shaderOpacity = -1.0 -- the opacity the shader's uniforms were last set for
local luaShaderDir = "LuaUI/Include/"

-- Localize for speedups:
local glDepthTest = gl.DepthTest
local glTexture = gl.Texture
local GL_POINTS = GL.POINTS

local spGetUnitTeam = Spring.GetUnitTeam
local spIsGUIHidden = Spring.IsGUIHidden

local myAllyTeamID = Spring.GetLocalAllyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

local unitScale = {}
local unitDecoration = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = ((7.5 * (unitDef.xsize * unitDef.xsize + unitDef.zsize * unitDef.zsize) ^ 0.5) + 8)
		* sizeMultiplier
	if unitDef.canFly then
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed == 0 then
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	end
	if unitDef.customParams.decoration then
		unitDecoration[unitDefID] = true
	end
end

local teamLeader = {}
local teamAllyTeam = {}
local allyTeamLeader = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local teamID = teams[i]
	local allyTeamID = select(6, Spring.GetTeamInfo(teamID, false))
	if not allyTeamLeader[allyTeamID] then
		allyTeamLeader[allyTeamID] = teamID -- assign which team color to use for whole allyteam
	end
	teamLeader[teamID] = allyTeamLeader[allyTeamID]
	teamAllyTeam[teamID] = allyTeamID
end
allyTeamLeader = nil

-- pushElementInstance copies the values, so one table serves every unit.
-- u is mirrored so the quad gets the uv layout of a cornerrect with zero corners, at half the vertices.
local instanceCache = {
	0,
	0,
	0,
	0, -- lengthwidthcornerheight
	0, -- teamID
	4, -- numvertices: quad
	0,
	0,
	0,
	0, -- parameters
	1,
	0,
	0,
	1, -- uvoffsets, u mirrored
	0,
	0,
	0,
	0, -- instData, filled in by the engine
}

local function AddPrimitiveAtUnit(unitID, unitDefID, unitTeam, noUpload)
	local radius = unitScale[unitDefID]
	instanceCache[1] = radius
	instanceCache[2] = radius
	instanceCache[5] = teamLeader[unitTeam]
	pushElementInstance(enemyspotterVBO, instanceCache, unitID, true, noUpload, unitID)
end

function widget:DrawWorldPreUnit()
	if enemyspotterVBO.usedElements == 0 or spIsGUIHidden() then
		return
	end
	glTexture(0, texture)
	enemyspotterShader:Activate()
	if shaderOpacity ~= opacity then
		shaderOpacity = opacity
		enemyspotterShader:SetUniform("iconDistance", 99999) -- no distance cutoff
		enemyspotterShader:SetUniform("transparency", opacity)
	end

	glDepthTest(true)

	enemyspotterVBO.VAO:DrawArrays(GL_POINTS, enemyspotterVBO.usedElements)

	enemyspotterShader:Deactivate()
	glTexture(0, false)
end

local function RemoveUnit(unitID)
	if enemyspotterVBO.instanceIDtoIndex[unitID] then
		popElementInstance(enemyspotterVBO, unitID)
	end
end

local function AddUnit(unitID, unitDefID, unitTeamID, noUpload)
	if
		(not skipOwnTeam or teamAllyTeam[unitTeamID] ~= myAllyTeamID)
		and unitTeamID ~= gaiaTeamID
		and not unitDecoration[unitDefID]
	then
		AddPrimitiveAtUnit(unitID, unitDefID, unitTeamID, noUpload)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddUnit(unitID, unitDefID, unitTeam)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(enemyspotterVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddUnit(unitID, unitDefID, spGetUnitTeam(unitID), true) -- add them with noUpload = true
	end
	InstanceVBOTable.uploadAllElements(enemyspotterVBO) -- upload them all
end

local function rebuild()
	widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
end

function widget:VisibleUnitRemoved(unitID) -- remove the corresponding ground plate if it exists
	RemoveUnit(unitID)
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	RemoveUnit(unitID)
end

local function init()
	local DPatUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
	-- quads only, so the geometry shader reserves 4 output vertices instead of 64
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	shaderConfig.USE_TRIANGLES = nil
	enemyspotterVBO, enemyspotterShader = InitDrawPrimitiveAtUnit(shaderConfig, "enemyspotter")
	if enemyspotterVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	if WG.unittrackerapi and WG.unittrackerapi.visibleUnits then
		widget:VisibleUnitsChanged(WG.unittrackerapi.visibleUnits, nil)
	else
		Spring.Echo("Enemy spotter needs unittrackerapi to work!")
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

local function checkMyAllyTeam()
	local allyTeamID = Spring.GetLocalAllyTeamID()
	if allyTeamID ~= myAllyTeamID then
		myAllyTeamID = allyTeamID
		if skipOwnTeam then
			rebuild()
		end
	end
end

function widget:PlayerChanged(playerID)
	checkMyAllyTeam()
end

function widget:GameStart()
	checkMyAllyTeam() -- the engine can reset the local team at game start without a PlayerChanged
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not init() then
		return
	end
	WG.enemyspotter = {}
	WG.enemyspotter.getOpacity = function()
		return opacity
	end
	WG.enemyspotter.setOpacity = function(value)
		opacity = value -- DrawWorldPreUnit passes it to the shader
	end
	WG.enemyspotter.getSkipOwnTeam = function()
		return skipOwnTeam
	end
	WG.enemyspotter.setSkipOwnTeam = function(value)
		skipOwnTeam = value
		rebuild()
	end
end

function widget:Shutdown()
	WG.enemyspotter = nil
	if type(enemyspotterShader) == "table" then
		enemyspotterShader:Finalize()
		enemyspotterShader = nil
	end
	if enemyspotterVBO then
		enemyspotterVBO:Delete()
		enemyspotterVBO = nil
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
