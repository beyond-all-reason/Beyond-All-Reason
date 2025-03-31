include("keysym.h.lua")

local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Ally Selected Units", -- GL4
		desc      = "Shows units selected by teammates",
		author    = "Beherith, Floris",
		date      = "April 2022",
		license   = "GNU GPL, v2 or later",
		layer     = 0,
		enabled   = true
	}
end

local showAsSpectator = true
local selectPlayerUnits = true	-- when lockcamera player
local hideBelowGameframe = 100

-- unit platter
local lineSize = 1.45
local lineOpacity = 0.3
local enablePlatter = true
local platterOpacity = 0.1

local useHexagons = true

----------------------------------------------------------------------------

local selectionVBO = nil
local selectShader = nil
local luaShaderDir = "LuaUI/Include/"

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

local spGetUnitDefID        = Spring.GetUnitDefID
local spGetPlayerInfo       = Spring.GetPlayerInfo
local spGetSpectatingState	= Spring.GetSpectatingState

local playerIsSpec = {}
for i,playerID in pairs(Spring.GetPlayerList()) do
	playerIsSpec[playerID] = select(3, spGetPlayerInfo(playerID, false))
end

local spec, fullview = spGetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local myAllyTeam = Spring.GetMyAllyTeamID()
local myPlayerID = Spring.GetMyPlayerID()
local selectedUnits = {}
local lockPlayerID

local unitAllyteam = {}
local spGetUnitTeam = Spring.GetUnitTeam

local unitScale = {}
local unitCanFly = {}
local unitBuilding = {}
local sizeAdd = -(lineSize*1.5)
for unitDefID, unitDef in pairs(UnitDefs) do
	unitScale[unitDefID] = (7.5 * ( unitDef.xsize^2 + unitDef.zsize^2 ) ^ 0.5) + 8
	unitScale[unitDefID] = unitScale[unitDefID] + sizeAdd
	if unitDef.canFly then
		unitCanFly[unitDefID] = true
		unitScale[unitDefID] = unitScale[unitDefID] * 0.7
	elseif unitDef.isBuilding or unitDef.isFactory or unitDef.speed==0 then
		unitBuilding[unitDefID] = {
			(unitDef.xsize * 8.2 + 12) + sizeAdd,
			(unitDef.zsize * 8.2 + 12) + sizeAdd
		}
	end
end

local instanceCache = {
			0,0,0,0,  -- lengthwidthcornerheight
			0, -- teamID
			useHexagons and 6 or 64, -- how many trianges should we make
			0, 0, 0, 0, -- the gameFrame (for animations), and any other parameters one might want to add
			0, 1, 0, 1, -- These are our default UV atlas tranformations
			0, 0, 0, 0 -- these are just padding zeros, that will get filled in
	}

local function AddPrimitiveAtUnit(unitID)
	local unitDefID = Spring.GetUnitDefID(unitID)
	if unitDefID == nil then return end -- these cant be selected

	local numVertices = useHexagons and 6 or 64
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
	instanceCache[1], instanceCache[2], instanceCache[3], instanceCache[4] = length, width, cornersize, additionalheight
	instanceCache[5] = spGetUnitTeam(unitID)
	instanceCache[7] = Spring.GetGameFrame()
	
	pushElementInstance(
		selectionVBO, -- push into this Instance VBO Table
		instanceCache,
		unitID, -- this is the key inside the VBO TAble,
		true, -- update existing element
		nil, -- noupload, dont use unless you
		unitID -- last one should be UNITID?
	)
end

local function RemovePrimitive(unitID)
	if selectionVBO.instanceIDtoIndex[unitID] then
		popElementInstance(selectionVBO, unitID)
	end
end

local function addUnit(unitID)
	if selectedUnits[unitID] ~= nil and selectedUnits[unitID] == false and (fullview or myAllyTeam == unitAllyteam[unitID]) then
		if not Spring.ValidUnitID(unitID) or Spring.GetUnitIsDead(unitID) then
			return
		end
		if enablePlatter then
			AddPrimitiveAtUnit(unitID)
		end
		selectedUnits[unitID] = true
	end
end

local function removeUnit(unitID)
	if selectedUnits[unitID] ~= nil and selectedUnits[unitID] then
		if enablePlatter then
			RemovePrimitive(unitID)
		end
		selectedUnits[unitID] = false
	end
end

local function selectPlayerSelectedUnits(playerID)
	local units = {}
	local count = 0
	local teamID = select(4, spGetPlayerInfo(playerID))
	for unitID, drawn in pairs(selectedUnits) do
		if spGetUnitTeam(unitID) == teamID then
			count = count + 1
			units[count] = unitID
		end
	end
	Spring.SelectUnitArray(units)
end

-- called by gadget
local function selectedUnitsClear(playerID)
	if not spec and playerID == myPlayerID then
		return
	end
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		local teamID = select(4, spGetPlayerInfo(playerID))
		for unitID, drawn in pairs(selectedUnits) do
			if spGetUnitTeam(unitID) == teamID then
				widget:VisibleUnitRemoved(unitID)
			end
		end
	end
	if lockPlayerID and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

-- called by gadget
local function selectedUnitsAdd(playerID,unitID)
	if not spec and playerID == myPlayerID then
		return
	end
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		if spGetUnitDefID(unitID) then
			selectedUnits[unitID] = false
			unitAllyteam[unitID] = select(6, Spring.GetTeamInfo(spGetUnitTeam(unitID), false))
			addUnit(unitID)
		end
	end
	if lockPlayerID and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

-- called by gadget
local function selectedUnitsRemove(playerID,unitID)
	if not spec and playerID == myPlayerID then
		return
	end
	if not playerIsSpec[playerID] or (lockPlayerID ~= nil and playerID == lockPlayerID) then
		widget:VisibleUnitRemoved(unitID)
	end
	if lockPlayerID and playerID == lockPlayerID and selectPlayerUnits then
		selectPlayerSelectedUnits(lockPlayerID)
	end
end

function widget:PlayerRemoved(playerID, reason)
	local teamID = select(4, spGetPlayerInfo(playerID))
	for unitID, drawn in pairs(selectedUnits) do
		if spGetUnitTeam(unitID) == teamID then
			widget:VisibleUnitRemoved(unitID)
		end
	end
end

function widget:PlayerAdded(playerID)
	playerIsSpec[playerID] = select(3, spGetPlayerInfo(playerID, false))
end

function widget:PlayerChanged(playerID)
	if not showAsSpectator and not spec and spGetSpectatingState() then
		widgetHandler:RemoveWidget()
		return
	end
	myTeamID = Spring.GetMyTeamID()
	myAllyTeam = Spring.GetMyAllyTeamID()
	myPlayerID = Spring.GetMyPlayerID()

	-- when changing fullview mode
	local prevFullview = fullview
	spec, fullview = spGetSpectatingState()
	if prevFullview ~= fullview then
		for unitID, drawn in pairs(selectedUnits) do
			if fullview then
				addUnit(unitID)
			else
				if unitAllyteam[unitID] ~= myAllyTeam then
					removeUnit(unitID)
				end
			end
		end
	end

	for i,playerID in pairs(Spring.GetPlayerList()) do
		local spec = select(3, spGetPlayerInfo(playerID, false))
		if spec and not playerIsSpec[playerID] then
			selectedUnitsClear(playerID)
		end
		playerIsSpec[playerID] = spec
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	addUnit(unitID)
end

function widget:VisibleUnitRemoved(unitID)
	removeUnit(unitID)
	selectedUnits[unitID] = nil
	unitAllyteam[unitID] = nil
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	clearInstanceTable(selectionVBO)
	for unitID, drawn in pairs(selectedUnits) do
		removeUnit(unitID)
	end
	for unitID, unitDefID in pairs(extVisibleUnits) do
		addUnit(unitID)
	end
end

local updateTime = 0
local checkLockPlayerInterval = 1
function widget:Update(dt)
	if WG.lockcamera then
		updateTime = updateTime + dt
		if updateTime > checkLockPlayerInterval then
			lockPlayerID = WG.lockcamera.GetPlayerID()
			if lockPlayerID ~= nil and selectPlayerUnits then
				selectPlayerSelectedUnits(lockPlayerID)
			end
			updateTime = 0
		end
	end
end

local function init()
	local DPatUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DPatUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DPatUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE!
	shaderConfig.BILLBOARD = 0
	shaderConfig.TRANSPARENCY = platterOpacity
	shaderConfig.INITIALSIZE = 0.75
	shaderConfig.GROWTHRATE = 8
	shaderConfig.HEIGHTOFFSET = 3.9
	shaderConfig.USETEXTURE = 0
	shaderConfig.LINETRANSPARANCY = lineOpacity
	shaderConfig.ROTATE_CIRCLES = 0
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(g_color.rgb, TRANSPARENCY + step( 0.01, addRadius) * LINETRANSPARANCY);"
	selectionVBO, selectShader = InitDrawPrimitiveAtUnit(shaderConfig, "allySelectedUnits")
	if selectionVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

function widget:Initialize()
	if not gl.CreateShader then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	if not init() then return end
	for _, playerID in pairs(Spring.GetPlayerList()) do
		widget:PlayerAdded(playerID)
	end
	widget:PlayerChanged(myPlayerID)

	widgetHandler:RegisterGlobal('selectedUnitsRemove', selectedUnitsRemove)
	widgetHandler:RegisterGlobal('selectedUnitsClear', selectedUnitsClear)
	widgetHandler:RegisterGlobal('selectedUnitsAdd', selectedUnitsAdd)

	WG['allyselectedunits'] = {}
	WG['allyselectedunits'].getSelectPlayerUnits = function()
		return selectPlayerUnits
	end
	WG['allyselectedunits'].setSelectPlayerUnits = function(value)
		selectPlayerUnits = value
	end
end

function widget:Shutdown()
	widgetHandler:DeregisterGlobal('selectedUnitsRemove')
	widgetHandler:DeregisterGlobal('selectedUnitsClear')
	widgetHandler:DeregisterGlobal('selectedUnitsAdd')
	for unitID, drawn in pairs(selectedUnits) do
		removeUnit(unitID)
	end
end

local drawFrame = 0
function widget:DrawWorldPreUnit()
	if Spring.GetGameFrame() < hideBelowGameframe then return end

	if Spring.IsGUIHidden() then return end

	if enablePlatter then
		drawFrame = drawFrame + 1
		if selectionVBO.usedElements > 0 then
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

			selectShader:SetUniform("addRadius", lineSize)
			selectionVBO.VAO:DrawArrays(GL_POINTS, selectionVBO.usedElements)

			glStencilMask(1)
			glStencilFunc(GL_ALWAYS, 1, 1)
			glDepthTest(true)

			selectShader:Deactivate()
		end
	end
end

function widget:GetConfigData()
    return {
        selectPlayerUnits = selectPlayerUnits,
        version = 2.0
    }
end

function widget:SetConfigData(data)
    if data.version ~= nil and data.version == 2.0 then
		if data.selectPlayerUnits ~= nil then
			selectPlayerUnits = data.selectPlayerUnits
		end
    end
end
