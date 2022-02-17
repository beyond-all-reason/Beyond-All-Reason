function widget:GetInfo()
	return {
		name = "EnemySpotter", -- GL4
		desc = "Draw geometric primitives at any unit",
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
local enemyspotterVBO = nil
local enemyspotterShader = nil
local luaShaderDir = "LuaUI/Widgets/Include/"

-- Localize for speedups:
local glDepthTest           = gl.DepthTest
local glTexture             = gl.Texture
local GL_POINTS				= GL.POINTS

local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
local spValidUnitID = Spring.ValidUnitID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam

local unitTeam = {}
local unitUnitDefID = {}

local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local gaiaTeamID = Spring.GetGaiaTeamID()

local unitScale = {}
local unitCanFly = {}
local unitDecoration = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = ((7.5 * ( unitDef.xsize^2 + unitDef.zsize^2 ) ^ 0.5) + 8) * sizeMultiplier
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitScale[unitDefID] = unitScale[unitDefID] * 0.9
	end
	if unitDef.name == 'xmasball' or unitDef.name == 'xmasball2' then
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

local function AddPrimitiveAtUnit(unitID)

	if not unitUnitDefID[unitID] then
		unitUnitDefID[unitID] = Spring.GetUnitDefID(unitID)
	end
	local unitDefID = unitUnitDefID[unitID]
	if unitDefID == nil then return end -- these cant be selected

	local radius = unitScale[unitDefID]

	if not unitTeam[unitID] then
		unitTeam[unitID] = Spring.GetUnitTeam(unitID)
	end

	pushElementInstance(
		enemyspotterVBO, -- push into this Instance VBO Table
		{
			radius, radius, 0, 0,  -- lengthwidthcornerheight
			teamLeader[unitTeam[unitID]], -- teamID
			2, -- how many triangles should we make
			0, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
		},
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you
		unitID -- last one should be UNITID?
	)
end

function widget:Update(dt)
	spec, fullview = Spring.GetSpectatingState()
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

local function RemovePrimitive(unitID)
	if enemyspotterVBO.instanceIDtoIndex[unitID] then
		popElementInstance(enemyspotterVBO, unitID)
	end
end

local function AddUnit(unitID, unitDefID, unitTeamID)
	if (not skipOwnTeam or spGetUnitAllyTeam(unitID) ~= myAllyTeamID) and unitTeamID ~= gaiaTeamID and not unitDecoration[unitDefID] then
		unitTeam[unitID] = unitTeamID
		unitUnitDefID[unitID] = unitDefID
		AddPrimitiveAtUnit(unitID)
	end
end

local function RemoveUnit(unitID, unitDefID)
	if (not skipOwnTeam or spGetUnitAllyTeam(unitID) ~= myAllyTeamID) and not unitDecoration[unitDefID] then
		RemovePrimitive(unitID)
		unitTeam[unitID] = nil
		unitUnitDefID[unitID] = nil
	end
end

function widget:UnitTaken(unitID, unitDefID, oldTeamID, newTeamID)
	if unitTeam[unitID] then
		RemoveUnit(unitID, unitDefID, oldTeamID)
		AddUnit(unitID, unitDefID, newTeamID)
	end
end

function widget:UnitGiven(unitID, unitDefID, oldTeamID, newTeamID)
	if unitTeam[unitID] then
		RemoveUnit(unitID, unitDefID, oldTeamID)
		AddUnit(unitID, unitDefID, newTeamID)
	end
end

function widget:UnitEnteredLos(unitID, unitTeam, allyTeam, unitDefID)
	if fullview then return end
	if spValidUnitID(unitID) then
		AddUnit(unitID, unitDefID or Spring.GetUnitDefID(unitID), unitTeam)
	end
end

function widget:UnitLeftLos(unitID, unitTeam, allyTeam, unitDefID)
	if not fullview then
		RemoveUnit(unitID, unitDefID or Spring.GetUnitDefID(unitID), unitTeam)
	end
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	AddUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	RemoveUnit(unitID, unitDefID, unitTeam)
end

function widget.RenderUnitDestroyed(unitID, unitDefID, unitTeam)
	RemoveUnit(unitID, unitDefID, unitTeam)
end

-- wont be called for enemy units nor can it read spGetUnitMoveTypeData(unitID).aircraftState anyway
function widget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer)
	if unitCanFly[unitDefID] and spGetUnitMoveTypeData(unitID).aircraftState == "crashing" then
		RemoveUnit(unitID, unitDefID, unitTeam)
	end
end

local function init()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.TRANSPARENCY = opacity
	shaderConfig.ANIMATION = 0
	shaderConfig.HEIGHTOFFSET = 3.99
	enemyspotterVBO, enemyspotterShader = InitDrawPrimitiveAtUnit(shaderConfig, "enemyspotter")

	for _, unitID in ipairs(Spring.GetAllUnits()) do
		AddUnit(unitID, Spring.GetUnitDefID(unitID), Spring.GetUnitTeam(unitID))
	end
end

function widget:PlayerChanged(playerID)
	spec, fullview = Spring.GetSpectatingState()
	myTeamID = Spring.GetMyTeamID()
	myAllyTeamID = Spring.GetMyAllyTeamID()
	if skipOwnTeam then
		init()
	end
end

function widget:Initialize()
	init()
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
