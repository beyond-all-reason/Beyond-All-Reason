local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Fire State Icons", -- GL4
		desc      = "Shows hold fire and return fire icons above units",
		author    = "Floris",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -39,
		enabled   = true
	}
end

local showFireStateIcons = true
local showAllHoldFireIcons = false	-- else only show for user triggered hold fire states

--------------------------------------------------------------------------------
-- Localized Spring API
--------------------------------------------------------------------------------
local spGetGameFrame  = Spring.GetGameFrame
local spValidUnitID   = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetMyPlayerID = Spring.GetMyPlayerID
local spGetMyTeamID   = Spring.GetMyTeamID

local gaiaTeamID = Spring.GetGaiaTeamID()

local HOLD_FIRE   = 0
local RETURN_FIRE = 1
local CMD_FIRE_STATE = CMD.FIRE_STATE
local CMD_USER_FIRESTATE = GameCMD.USER_FIRESTATE
local Firestates = VFS.Include("modules/firestates.lua")

-- Textures to display (replace with dedicated icons if available)
local holdFireTexture   = "LuaUI/Images/holdfire.png"
local returnFireTexture = "LuaUI/Images/returnfire.png"

--------------------------------------------------------------------------------
-- GL4 Backend
--------------------------------------------------------------------------------
local holdFireVBO    = nil
local returnFireVBO  = nil
local fireIconShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable    = gl.InstanceVBOTable
local uploadAllElements   = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance
local popElementInstance  = InstanceVBOTable.popElementInstance

--------------------------------------------------------------------------------
-- Per-UnitDef config: [unitDefID] = {iconSize, iconHeight}
-- Only populated for units that have at least one weapon
--------------------------------------------------------------------------------
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
    local hasWeapons = unitDef.weapons and #unitDef.weapons > 0
    local isFactory  = unitDef.isFactory
	local isDrone    = unitDef.customParams and unitDef.customParams.drone
    if (hasWeapons or isFactory) and not isDrone then
        local xsize, zsize = unitDef.xsize, unitDef.zsize
        local scale = 2.5 * (xsize*xsize + zsize*zsize)^0.5
        unitConf[udid] = {11 + (scale / 2.2), unitDef.height}
    end
end

-- All visible units: [unitID] = unitDefID
local visibleUnits    = {}
local crashingUnits   = {} -- unitIDs currently crashing; skip icon for these
local chobbyInterface = false
local unitFireState   = {} -- [unitID] = cached fire state; avoids GetUnitStates every frame
local manuallyHeldFire = {} -- [unitID] = true if this client explicitly ordered hold fire
local manuallyReturnFire = {} -- [unitID] = true if this client explicitly ordered return fire
local unitToTeam        = {} -- [unitID] = teamID; needed to filter dead-allyteam units
local deadAllyTeams     = {} -- [allyTeamID] = true when entire allyteam has been wiped out
local teamToAllyTeam    = {} -- [teamID] = allyTeamID; built at Initialize
local deadTeamCount     = {} -- [allyTeamID] = number of dead teams in that allyteam
local allyTeamTeamCount = {} -- [allyTeamID] = total number of teams in that allyteam
local userOrderedFirestate = {} -- [unitID] = userState; pending until UnitCommand confirms user order
local deferredUserFirestate = {}
local deferredUserFirestateFrame = -1
local deferredUserFirestateDirty = false
local myPlayerID      = spGetMyPlayerID()
local myTeamID        = spGetMyTeamID()
local manualHoldStore = nil

-- Pre-allocated and reused for every pushElementInstance call to avoid per-push table allocation
local instanceData = {0, 0, 0, 0,  0,  4,  0, 0, 0.85, 0,  0, 1, 0, 1,  0, 0, 0, 0}

--------------------------------------------------------------------------------
-- GL4 Initialization
--------------------------------------------------------------------------------
local function createFireIconVBO(shaderConfig, vboName, useGeometryShaderForThisShader)
	local instanceLayout
	local unitIDattribID
	if useGeometryShaderForThisShader then
		instanceLayout = {
			{id = 0, name = 'lengthwidthcorner', size = 4},
			{id = 1, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 2, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'parameters', size = 4},
			{id = 4, name = 'uvoffsets', size = 4},
			{id = 5, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		}
		unitIDattribID = 5
	else
		instanceLayout = {
			{id = 1, name = 'lengthwidthcorner', size = 4},
			{id = 2, name = 'teamID', size = 1, type = GL.UNSIGNED_INT},
			{id = 3, name = 'numvertices', size = 1, type = GL.UNSIGNED_INT},
			{id = 4, name = 'parameters', size = 4},
			{id = 5, name = 'uvoffsets', size = 4},
			{id = 6, name = 'instData', size = 4, type = GL.UNSIGNED_INT},
		}
		unitIDattribID = 6
	end

	local vboTable = InstanceVBOTable.makeInstanceVBOTable(
		instanceLayout,
		64,
		vboName,
		unitIDattribID
	)
	if vboTable == nil then
		return nil
	end

	if useGeometryShaderForThisShader then
		local vao = gl.GetVAO()
		vao:AttachVertexBuffer(vboTable.instanceVBO)
		vboTable.VAO = vao
	else
		local numSlots = math.max(shaderConfig.MAXVERTICES or 64, 8)
		local templateVBO = gl.GetVBO(GL.ARRAY_BUFFER, false)
		templateVBO:Define(numSlots, {{id = 0, name = 'vinfo', size = 1}})
		local vertexData = {}
		for slot = 0, numSlots - 1 do
			vertexData[#vertexData + 1] = slot
		end
		templateVBO:Upload(vertexData)

		local indexData = {}
		for i = 1, numSlots - 2 do
			indexData[#indexData + 1] = 0
			indexData[#indexData + 1] = i
			indexData[#indexData + 1] = i + 1
		end
		local indexVBO = gl.GetVBO(GL.ELEMENT_ARRAY_BUFFER, false)
		indexVBO:Define(#indexData)
		indexVBO:Upload(indexData)

		local realVAO = InstanceVBOTable.makeVAOandAttach(templateVBO, vboTable.instanceVBO, indexVBO)
		if realVAO == nil then
			return nil
		end

		vboTable.nogsTemplateVBO = templateVBO
		vboTable.nogsIndexVBO = indexVBO
		local indexCount = #indexData
		vboTable.VAO = {
			realVAO = realVAO,
			indexCount = indexCount,
			DrawArrays = function(self, _primitiveType, instanceCount)
				if instanceCount and instanceCount > 0 then
					self.realVAO:DrawElements(GL.TRIANGLES, self.indexCount, 0, instanceCount)
				end
			end,
			Delete = function(self)
				self.realVAO:Delete()
			end,
		}
	end
	return vboTable
end

local function initGL4()
	local DrawPrimitiveAtUnit    = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig           = DrawPrimitiveAtUnit.shaderConfig

	shaderConfig.BILLBOARD      = 1
	shaderConfig.HEIGHTOFFSET   = 0
	shaderConfig.TRANSPARENCY   = 0.85
	shaderConfig.ANIMATION      = 1
	shaderConfig.FULL_ROTATION  = 0
	shaderConfig.CLIPTOLERANCE  = 1.2
	shaderConfig.INITIALSIZE    = 0.22
	shaderConfig.BREATHESIZE    = 0.05
	shaderConfig.ZPULL          = 512.0
	shaderConfig.POST_SHADING   = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES    = 4
	shaderConfig.USE_CIRCLES    = nil
	shaderConfig.USE_CORNERRECT = nil

	holdFireVBO, fireIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "hold fire icons")
	if holdFireVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	-- Second call reuses the same compiled shader but allocates a new VBO
	local useGeometryShaderForThisShader = holdFireVBO.VAO.realVAO == nil
	returnFireVBO = createFireIconVBO(shaderConfig, "return fire icons", useGeometryShaderForThisShader)
	if returnFireVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	return true
end

WG['unitfirestate'] = {}
WG['unitfirestate'].setEnabled = function(value)
    showFireStateIcons = value
end
WG['unitfirestate'].setShowAllHoldFireIcons = function(value)
	showAllHoldFireIcons = (value and true) or false
	if widget and widget.VisibleUnitsChanged and visibleUnits then
		widget:VisibleUnitsChanged(visibleUnits, nil)
	end
end
WG['unitfirestate'].getShowAllHoldFireIcons = function()
	return showAllHoldFireIcons
end

local function userStateToIconState(userState)
	if userState == Firestates.PASSIVE then
		return HOLD_FIRE
	end
	if userState == Firestates.DEFEND or userState == Firestates.RETURN_FIRE then
		return RETURN_FIRE
	end
end

local function getActualFireState(unitID)
	if not spValidUnitID(unitID) then return nil end
	return userStateToIconState(Firestates.fromEngineFirestate(select(1, Spring.GetUnitStates(unitID, false))))
end

local function fireStateFromCmdParams(cmdParams)
	if not cmdParams then return nil end
	return userStateToIconState(Firestates.fromEngineFirestate(tonumber(cmdParams[1])))
end

local function resolveUserStateFromCommand(cmdID, cmdParams, unitID)
	if not cmdParams then return nil end
	if cmdID == CMD_USER_FIRESTATE then
		return tonumber(cmdParams[1])
	end
	if cmdID == CMD_FIRE_STATE then
		if Spring.GetModOptions().experimental_defend_firestate then
			--DEFEND FIRESTATE REWORK: Remove engine fallback; always use user_firestate rules param
			return Firestates.resolveUserFirestate(unitID)
		end
		return Firestates.fromEngineFirestate(tonumber(cmdParams[1]))
	end
end

local function setManualFireState(unitID, userState)
	if userState == Firestates.PASSIVE then
		manuallyHeldFire[unitID] = true
		manuallyReturnFire[unitID] = nil
	elseif userState == Firestates.DEFEND or userState == Firestates.RETURN_FIRE then
		manuallyHeldFire[unitID] = nil
		manuallyReturnFire[unitID] = true
	elseif userState ~= nil then
		manuallyHeldFire[unitID] = nil
		manuallyReturnFire[unitID] = nil
	end
end

local function migrateManualFireStores()
	for unitID, value in pairs(manuallyHeldFire) do
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			manuallyHeldFire[unitID] = nil
		elseif value == true then
		elseif value == RETURN_FIRE or value == 1 then
			manuallyHeldFire[unitID] = nil
			manuallyReturnFire[unitID] = true
		elseif value == HOLD_FIRE or value == 0 then
			manuallyHeldFire[unitID] = true
		else
			manuallyHeldFire[unitID] = nil
		end
	end
	for unitID, value in pairs(manuallyReturnFire) do
		if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then
			manuallyReturnFire[unitID] = nil
		elseif value ~= true then
			manuallyReturnFire[unitID] = true
		end
	end
end

local function shouldApplyScriptFireState(unitID, fs, cmdParams)
	if manuallyHeldFire[unitID] then
		return fs == HOLD_FIRE
	end
	if manuallyReturnFire[unitID] then
		if fs == RETURN_FIRE then
			return true
		end
		if fs == HOLD_FIRE and cmdParams and tonumber(cmdParams[1]) == Firestates.ENGINE_HOLD_FIRE and Spring.GetUnitIsCloaked(unitID) then
			return true
		end
		return false
	end
	return false
end

local function shouldShowIcon(unitID, fs)
	if fs == HOLD_FIRE then
		return showAllHoldFireIcons or manuallyHeldFire[unitID]
	end
	if fs == RETURN_FIRE then
		return manuallyReturnFire[unitID]
	end
	return false
end

--------------------------------------------------------------------------------
-- Helper: push a unit into a fire-state VBO
--------------------------------------------------------------------------------
local function pushToVBO(vbo, unitID, unitDefID, gf)
	if vbo.instanceIDtoIndex[unitID] then return end
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then return end
	local conf = unitConf[unitDefID]
	if not conf then return end -- unit has no weapons, skip
	instanceData[1] = conf[1]  -- width
	instanceData[2] = conf[1]  -- height
	instanceData[4] = conf[2]  -- unit height offset
	instanceData[7] = gf       -- gameframe for animation
	pushElementInstance(vbo, instanceData, unitID, false, true, unitID)
end

--------------------------------------------------------------------------------
-- Apply a fire-state change for one unit into the appropriate VBOs
--------------------------------------------------------------------------------
local function applyFireState(unitID, unitDefID, fs, gf)
	local showHold = fs == HOLD_FIRE and shouldShowIcon(unitID, HOLD_FIRE)
	local showReturn = fs == RETURN_FIRE and shouldShowIcon(unitID, RETURN_FIRE)
	if showHold then
		pushToVBO(holdFireVBO, unitID, unitDefID, gf)
		if returnFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(returnFireVBO, unitID, true)
		end
	elseif holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID, true)
	end
	if showReturn then
		pushToVBO(returnFireVBO, unitID, unitDefID, gf)
		if holdFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(holdFireVBO, unitID, true)
		end
	elseif returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID, true)
	end
end

local function applyUserFireStateOrder(userState, unitIDs)
	if userState == nil or not unitIDs then return end
	local fs = userStateToIconState(userState)
	local gf = spGetGameFrame()
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		if spValidUnitID(unitID) and not spGetUnitIsDead(unitID) then
			setManualFireState(unitID, userState)
			local unitDefID = visibleUnits[unitID] or Spring.GetUnitDefID(unitID)
			local teamID = unitToTeam[unitID] or Spring.GetUnitTeam(unitID)
			if unitDefID and teamID and teamID ~= gaiaTeamID then
				if not visibleUnits[unitID] then
					visibleUnits[unitID] = unitDefID
					unitToTeam[unitID] = teamID
				end
				if not crashingUnits[unitID] and not deadAllyTeams[teamToAllyTeam[teamID]] then
					unitFireState[unitID] = fs
					applyFireState(unitID, unitDefID, fs, gf)
				end
			end
		end
	end
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

local function iconUserStatePriority(userState)
	if userState == Firestates.RETURN_FIRE or userState == Firestates.DEFEND then
		return 3
	end
	if userState == Firestates.PASSIVE then
		return 2
	end
	return 1
end

local function mergeDeferredUserState(currentState, newState)
	if newState == nil then return currentState end
	if currentState == nil then return newState end
	if iconUserStatePriority(newState) > iconUserStatePriority(currentState) then
		return newState
	end
	if iconUserStatePriority(newState) < iconUserStatePriority(currentState) then
		return currentState
	end
	return newState
end

local function queueUserFirestateOrder(userState, unitIDs)
	local gf = spGetGameFrame()
	if deferredUserFirestateFrame ~= gf then
		deferredUserFirestateFrame = gf
		deferredUserFirestate = {}
	end
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		deferredUserFirestate[unitID] = mergeDeferredUserState(deferredUserFirestate[unitID], userState)
		userOrderedFirestate[unitID] = deferredUserFirestate[unitID]
	end
	deferredUserFirestateDirty = true
end

local function flushDeferredUserFirestateOrders()
	if not deferredUserFirestateDirty then return end
	if deferredUserFirestateFrame ~= spGetGameFrame() then return end
	deferredUserFirestateDirty = false
	local ordersByState = {}
	for unitID, mergedUserState in pairs(deferredUserFirestate) do
		if not ordersByState[mergedUserState] then
			ordersByState[mergedUserState] = {}
		end
		local unitList = ordersByState[mergedUserState]
		unitList[#unitList + 1] = unitID
	end
	deferredUserFirestate = {}
	for mergedUserState, unitList in pairs(ordersByState) do
		applyUserFireStateOrder(mergedUserState, unitList)
	end
end

WG['unitfirestate'].markUserFirestate = function(userState, unitIDs)
	if not unitIDs then return end
	queueUserFirestateOrder(userState, unitIDs)
end

--------------------------------------------------------------------------------
-- Widget callbacks
--------------------------------------------------------------------------------
function widget:Initialize()
	if not gl.CreateShader then -- headless / no shader support
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then return end

	-- Persist manual hold-fire flags across widget reloads within the same LuaUI session.
	WG['unitfirestate_manualhold'] = WG['unitfirestate_manualhold'] or {}
	manualHoldStore = WG['unitfirestate_manualhold']
	manuallyHeldFire = manualHoldStore
	WG['unitfirestate_manualreturn'] = WG['unitfirestate_manualreturn'] or {}
	manuallyReturnFire = WG['unitfirestate_manualreturn']
	migrateManualFireStores()

	-- Build team → allyteam mapping
	for _, allyTeamID in ipairs(Spring.GetAllyTeamList()) do
		local teams = Spring.GetTeamList(allyTeamID)
		allyTeamTeamCount[allyTeamID] = #teams
		deadTeamCount[allyTeamID] = 0
		for _, teamID in ipairs(teams) do
			teamToAllyTeam[teamID] = allyTeamID
		end
	end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

function widget:GameFrame()
	flushDeferredUserFirestateOrders()
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(holdFireVBO)
	InstanceVBOTable.clearInstanceTable(returnFireVBO)
	visibleUnits = {}
	unitFireState = {}
	unitToTeam = {}
	local gf = spGetGameFrame()
	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
		local teamID = Spring.GetUnitTeam(unitID)

		if teamID ~= gaiaTeamID then
			unitToTeam[unitID] = teamID
			if not crashingUnits[unitID] and not deadAllyTeams[teamToAllyTeam[teamID]] then
				local fs = getActualFireState(unitID)
				unitFireState[unitID] = fs
				applyFireState(unitID, unitDefID, fs, gf)
			end
		end
	end
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID then return end
	visibleUnits[unitID] = unitDefID
	unitToTeam[unitID] = unitTeam
	if crashingUnits[unitID] or deadAllyTeams[teamToAllyTeam[unitTeam]] then return end
	local fs = getActualFireState(unitID)
	unitFireState[unitID] = fs
	applyFireState(unitID, unitDefID, fs, spGetGameFrame())
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
	unitFireState[unitID] = nil
	unitToTeam[unitID] = nil
	crashingUnits[unitID] = nil
	if holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID)
	end
	if returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID)
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	if teamID == gaiaTeamID then return end
	crashingUnits[unitID] = true
	unitFireState[unitID] = nil
	manuallyHeldFire[unitID] = nil
	manuallyReturnFire[unitID] = nil
	if holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID)
	end
	if returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID)
	end
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	return false
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID == gaiaTeamID then return end
	if cmdID == CMD_USER_FIRESTATE then
		local pendingState = userOrderedFirestate[unitID]
		userOrderedFirestate[unitID] = nil
		local userState = pendingState or tonumber(cmdParams[1])
		if userState ~= nil then
			applyUserFireStateOrder(userState, {unitID})
		end
		return
	end
	if cmdID ~= CMD_FIRE_STATE then return end
	local pendingState = userOrderedFirestate[unitID]
	if pendingState then
		userOrderedFirestate[unitID] = nil
		applyUserFireStateOrder(pendingState, {unitID})
		return
	end
	if not manuallyHeldFire[unitID] and not manuallyReturnFire[unitID] then return end
	local fs
	if cmdParams and cmdParams[1] ~= nil then
		fs = fireStateFromCmdParams(cmdParams)
	else
		fs = getActualFireState(unitID)
	end
	if not shouldApplyScriptFireState(unitID, fs, cmdParams) then
		return
	end
	unitFireState[unitID] = fs
	if not visibleUnits[unitID] or crashingUnits[unitID] or deadAllyTeams[teamToAllyTeam[teamID]] then return end
	applyFireState(unitID, unitDefID, fs, spGetGameFrame())
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

function widget:TeamDied(teamID)
	if teamID == gaiaTeamID then return end
	local allyTeamID = teamToAllyTeam[teamID]
	if not allyTeamID then return end
	deadTeamCount[allyTeamID] = (deadTeamCount[allyTeamID] or 0) + 1
	if deadTeamCount[allyTeamID] < (allyTeamTeamCount[allyTeamID] or 1) then
		return -- still has surviving teams in this allyteam
	end
	-- All teams in allyteam are dead — remove all their icons (a wipeout sets hold fire for all units, but this will just be visual clutter at this point)
	deadAllyTeams[allyTeamID] = true
	for unitID, tid in pairs(unitToTeam) do
		if teamToAllyTeam[tid] == allyTeamID then
			unitFireState[unitID] = nil
			manuallyHeldFire[unitID] = nil
			manuallyReturnFire[unitID] = nil
			if holdFireVBO.instanceIDtoIndex[unitID] then
				popElementInstance(holdFireVBO, unitID)
			end
			if returnFireVBO.instanceIDtoIndex[unitID] then
				popElementInstance(returnFireVBO, unitID)
			end
		end
	end
end

function widget:PlayerChanged(playerID)
	myPlayerID = spGetMyPlayerID()
	myTeamID = spGetMyTeamID()
	if myPlayerID == nil or myTeamID == nil then return end
	for unitID, unitTeamID in pairs(unitToTeam) do
		if unitTeamID == myTeamID and unitFireState[unitID] == HOLD_FIRE and not manuallyHeldFire[unitID] then
			if holdFireVBO.instanceIDtoIndex[unitID] then
				popElementInstance(holdFireVBO, unitID, true)
			end
		end
	end
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
end

function widget:UnitDestroyed(unitID)
	manuallyHeldFire[unitID] = nil
	manuallyReturnFire[unitID] = nil
end

function widget:UnitGiven(unitID)
	manuallyHeldFire[unitID] = nil
	manuallyReturnFire[unitID] = nil
end

function widget:UnitTaken(unitID)
	manuallyHeldFire[unitID] = nil
	manuallyReturnFire[unitID] = nil
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects renders after deferred lighting/distortion/bloom/tonemap;
	-- the shader still uses engine cameraViewProj UBO and depth-tests terrain occlusion.
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end
	if not showFireStateIcons then return end

	if holdFireVBO.usedElements == 0 and returnFireVBO.usedElements == 0 then
		return
	end

	local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5

	gl.DepthTest(true)
	gl.DepthMask(false)

	if holdFireVBO.usedElements > 0 then
		gl.Texture(holdFireTexture)
		fireIconShader:Activate()
		fireIconShader:SetUniform("iconDistance", disticon)
		fireIconShader:SetUniform("addRadius", 0)
		holdFireVBO.VAO:DrawArrays(GL.POINTS, holdFireVBO.usedElements)
		fireIconShader:Deactivate()
		gl.Texture(false)
	end

	if returnFireVBO.usedElements > 0 then
		gl.Texture(returnFireTexture)
		fireIconShader:Activate()
		fireIconShader:SetUniform("iconDistance", disticon)
		fireIconShader:SetUniform("addRadius", 0)
		returnFireVBO.VAO:DrawArrays(GL.POINTS, returnFireVBO.usedElements)
		fireIconShader:Deactivate()
		gl.Texture(false)
	end

	gl.DepthTest(false)
	gl.DepthMask(true)
end

function widget:GetConfigData(data)
	return {
		showAllHoldFireIcons = showAllHoldFireIcons,
	}
end

function widget:SetConfigData(data)
	if data.showAllHoldFireIcons ~= nil then
		showAllHoldFireIcons = data.showAllHoldFireIcons and true or false
	end
end
