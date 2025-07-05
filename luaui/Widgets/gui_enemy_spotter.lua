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

local popElementInstance  = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance

local enemyspotterVBO = nil
local enemyspotterShader = nil
local luaShaderDir = "LuaUI/Include/"

-- Localize for speedups:
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local GL_POINTS				= GL.POINTS

local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

local unitScale = {}
local unitDecoration = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = ((7.5 * ( unitDef.xsize^2 + unitDef.zsize^2 ) ^ 0.5) + 8) * sizeMultiplier
	if unitDef.canFly then
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	end
	if unitDef.customParams.decoration then
		unitDecoration[unitDefID] = true
	end
end

local teamLeader = {}
local allyTeamLeader = {}
local teams = Spring.GetTeamList()
for i = 1, #teams do
	local teamID = teams[i]
	local allyTeamID =  select(6, Spring.GetTeamInfo(teamID, false))
	if not allyTeamLeader[allyTeamID] then
		allyTeamLeader[allyTeamID] = teamID	-- assign which team color to use for whole allyteam
	end
	teamLeader[teamID] = allyTeamLeader[allyTeamID]
end
allyTeamLeader = nil

local function AddPrimitiveAtUnit(unitID, unitDefID, unitTeam, noUpload)
	local radius = unitScale[unitDefID]

	pushElementInstance(
		enemyspotterVBO, -- push into this Instance VBO Table
		{
			radius, radius, 0, 0,  -- lengthwidthcornerheight
			teamLeader[unitTeam], -- teamID
			2, -- how many triangles should we make
			0, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		noUpload, -- noupload, dont use unless you
		unitID -- last one should be UNITID?
	)
end

local drawFrame = 0
function widget:DrawWorldPreUnit()
	if Spring.IsGUIHidden() then
		return
	end
	drawFrame = drawFrame + 1
	if enemyspotterVBO.usedElements > 0 then
		glTexture(0, texture)
		enemyspotterShader:Activate()
		enemyspotterShader:SetUniform("iconDistance", 99999) -- pass

		glDepthTest(true)

		enemyspotterShader:SetUniform("addRadius", 0)
		enemyspotterVBO.VAO:DrawArrays(GL_POINTS, enemyspotterVBO.usedElements)

		enemyspotterShader:Deactivate()
		glTexture(0, false)
	end
end

local function RemoveUnit(unitID)
	if enemyspotterVBO.instanceIDtoIndex[unitID] then
		popElementInstance(enemyspotterVBO, unitID)
	end
end

local function AddUnit(unitID, unitDefID, unitTeamID, noUpload)
	if (not skipOwnTeam or spGetUnitAllyTeam(unitID) ~= myAllyTeamID) and unitTeamID ~= gaiaTeamID and not unitDecoration[unitDefID] then
		AddPrimitiveAtUnit(unitID,unitDefID, unitTeamID, noUpload)
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	AddUnit(unitID, unitDefID, unitTeam)
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(enemyspotterVBO) -- clear all instances
	for unitID, unitDefID in pairs(extVisibleUnits) do
		AddUnit(unitID, unitDefID, Spring.GetUnitTeam(unitID), true) -- add them with noUpload = true
	end
	InstanceVBOTable.uploadAllElements(enemyspotterVBO) -- upload them all
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
	enemyspotterVBO, enemyspotterShader = InitDrawPrimitiveAtUnit(shaderConfig, "enemyspotter")
	if enemyspotterVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	else
		Spring.Echo("Enemy spotter needs unittrackerapi to work!")
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

function widget:PlayerChanged(playerID)
	myAllyTeamID = Spring.GetMyAllyTeamID()

	widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not init() then return end
	WG['enemyspotter'] = {}
	WG['enemyspotter'].getOpacity = function()
		return opacity
	end
	WG['enemyspotter'].setOpacity = function(value)
		opacity = value
		init()
	end
	WG['enemyspotter'].getSkipOwnTeam = function()
		return skipOwnTeam
	end
	WG['enemyspotter'].setSkipOwnTeam = function(value)
		skipOwnTeam = value
		init()
	end
end

function widget:Shutdown()
	WG['enemyspotter'] = nil
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
