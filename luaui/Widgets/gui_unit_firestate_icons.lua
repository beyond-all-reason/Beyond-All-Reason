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
local iconVBO        = nil
local fireIconShader = nil

local luaShaderDir = "LuaUI/Include/"
local InstanceVBOTable    = gl.InstanceVBOTable
local uploadAllElements   = InstanceVBOTable.uploadAllElements
local pushElementInstance = InstanceVBOTable.pushElementInstance

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
local unitToTeam        = {} -- [unitID] = teamID; needed to filter dead-allyteam units
local deadAllyTeams     = {} -- [allyTeamID] = true when entire allyteam has been wiped out
local teamToAllyTeam    = {} -- [teamID] = allyTeamID; built at Initialize
local deadTeamCount     = {} -- [allyTeamID] = number of dead teams in that allyteam
local allyTeamTeamCount = {} -- [allyTeamID] = total number of teams in that allyteam
local myPlayerID      = spGetMyPlayerID()
local myTeamID        = spGetMyTeamID()
local manualHoldStore = nil
local iconAnimStart   = {} -- [unitID] = cached spawn frame per fire state; avoids replaying grow-in on re-push
local returnFireIcons = {} -- [unitID] = unitDefID; event-driven membership for return-fire draw pass
local holdFireIcons   = {} -- [unitID] = unitDefID; event-driven membership for hold-fire draw pass
local returnPassDirty = true
local holdPassDirty   = true

-- Pre-allocated and reused for every pushElementInstance call to avoid per-push table allocation
local instanceData = {0, 0, 0, 0,  0,  4,  0, 0, 0.85, 0,  0, 1, 0, 1,  0, 0, 0, 0}

--------------------------------------------------------------------------------
-- GL4 Initialization
--------------------------------------------------------------------------------
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

	iconVBO, fireIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "fire state icons")
	if iconVBO == nil then
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

local function engineStateToIcon(engineState)
	if engineState == HOLD_FIRE then return HOLD_FIRE end
	if engineState == RETURN_FIRE then return RETURN_FIRE end
end

local function getDisplayFireState(unitID)
	if not spValidUnitID(unitID) then return nil end
	local engineState = select(1, Spring.GetUnitStates(unitID, false))
	return engineStateToIcon(engineState)
end

local function iconStateFromCommand(cmdID, cmdParams)
	if not cmdParams then return nil end
	if cmdID == CMD_FIRE_STATE then return engineStateToIcon(tonumber(cmdParams[1])) end
	if cmdID == CMD_USER_FIRESTATE then
		if cmdParams[1] == Firestates.PASSIVE then return HOLD_FIRE end
		if cmdParams[1] == Firestates.RETURN_FIRE then return RETURN_FIRE end
	end
end

local function clearIconAnim(unitID)
	iconAnimStart[unitID] = nil
end

local function getIconAnimStart(unitID, fs)
	local cached = iconAnimStart[unitID]
	if not cached or cached.fs ~= fs then
		cached = { fs = fs, start = spGetGameFrame() }
		iconAnimStart[unitID] = cached
	end
	return cached.start
end

local function markAllPassesDirty()
	returnPassDirty = true
	holdPassDirty = true
end

--------------------------------------------------------------------------------
-- Helper: push a unit into the shared icon VBO
--------------------------------------------------------------------------------
local function pushToVBO(unitID, unitDefID, animFs)
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then return end
	local conf = unitConf[unitDefID]
	if not conf then return end -- unit has no weapons, skip
	instanceData[1] = conf[1]  -- width
	instanceData[2] = conf[1]  -- height
	instanceData[4] = conf[2]  -- unit height offset
	instanceData[7] = getIconAnimStart(unitID, animFs) -- gameframe for animation
	pushElementInstance(iconVBO, instanceData, unitID, false, true, unitID)
end

--------------------------------------------------------------------------------
-- Apply a fire-state change for one unit into the icon membership tables
--------------------------------------------------------------------------------
local function applyFireState(unitID, unitDefID, fs)
	local wasReturn = returnFireIcons[unitID] ~= nil
	local wasHold = holdFireIcons[unitID] ~= nil

	returnFireIcons[unitID] = nil
	holdFireIcons[unitID] = nil

	local isReturn = fs == RETURN_FIRE
	local isHold = fs == HOLD_FIRE and (showAllHoldFireIcons or manuallyHeldFire[unitID])

	if isReturn then
		returnFireIcons[unitID] = unitDefID
	end
	if isHold then
		holdFireIcons[unitID] = unitDefID
	end

	if wasReturn ~= isReturn then
		returnPassDirty = true
	end
	if wasHold ~= isHold then
		holdPassDirty = true
	end
end

local function removeIconMembership(unitID)
	if returnFireIcons[unitID] then
		returnFireIcons[unitID] = nil
		returnPassDirty = true
	end
	if holdFireIcons[unitID] then
		holdFireIcons[unitID] = nil
		holdPassDirty = true
	end
end

-- Rebuild the shared VBO from one membership table, then draw with the matching texture.
local function drawIconPass(iconSet, animFs, texture, disticon, passDirty, vboInvalidated)
	if not next(iconSet) then return false end
	if passDirty or vboInvalidated then
		InstanceVBOTable.clearInstanceTable(iconVBO)
		for unitID, unitDefID in pairs(iconSet) do
			pushToVBO(unitID, unitDefID, animFs)
		end
		if iconVBO.usedElements == 0 then return false end
		uploadAllElements(iconVBO)
		if animFs == RETURN_FIRE then
			returnPassDirty = false
		else
			holdPassDirty = false
		end
	end
	gl.Texture(texture)
	fireIconShader:Activate()
	fireIconShader:SetUniform("iconDistance", disticon)
	fireIconShader:SetUniform("addRadius", 0)
	iconVBO.VAO:DrawArrays(GL.POINTS, iconVBO.usedElements)
	fireIconShader:Deactivate()
	gl.Texture(false)
	return true
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

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	visibleUnits = {}
	unitFireState = {}
	unitToTeam = {}
	iconAnimStart = {}
	returnFireIcons = {}
	holdFireIcons = {}
	markAllPassesDirty()
	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
		local teamID = Spring.GetUnitTeam(unitID)

		if teamID ~= gaiaTeamID then
			unitToTeam[unitID] = teamID
			if not crashingUnits[unitID] and not deadAllyTeams[teamToAllyTeam[teamID]] then
				local fs = getDisplayFireState(unitID)
				unitFireState[unitID] = fs
				applyFireState(unitID, unitDefID, fs)
			end
		end
	end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	if unitTeam == gaiaTeamID then return end
	visibleUnits[unitID] = unitDefID
	unitToTeam[unitID] = unitTeam
	if crashingUnits[unitID] or deadAllyTeams[teamToAllyTeam[unitTeam]] then return end
	local fs = getDisplayFireState(unitID)
	unitFireState[unitID] = fs
	applyFireState(unitID, unitDefID, fs)
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
	unitFireState[unitID] = nil
	unitToTeam[unitID] = nil
	crashingUnits[unitID] = nil
	clearIconAnim(unitID)
	removeIconMembership(unitID)
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	if teamID == gaiaTeamID then return end
	crashingUnits[unitID] = true
	unitFireState[unitID] = nil
	manuallyHeldFire[unitID] = nil
	clearIconAnim(unitID)
	removeIconMembership(unitID)
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD_FIRE_STATE and cmdID ~= CMD_USER_FIRESTATE then return false end
	local cmdFs = iconStateFromCommand(cmdID, cmdParams)
	local selectedUnits = spGetSelectedUnits()
	for i = 1, #selectedUnits do
		local unitID = selectedUnits[i]
		manuallyHeldFire[unitID] = cmdFs == HOLD_FIRE or nil
		local unitDefID = visibleUnits[unitID]
		if unitDefID and cmdFs then
			unitFireState[unitID] = cmdFs
			applyFireState(unitID, unitDefID, cmdFs)
		end
	end
	return false
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts, cmdTag, playerID, fromSynced, fromLua)
	if teamID == gaiaTeamID or (cmdID ~= CMD_FIRE_STATE and cmdID ~= CMD_USER_FIRESTATE) then return end
	local cmdFs = iconStateFromCommand(cmdID, cmdParams)
	manuallyHeldFire[unitID] = cmdFs == HOLD_FIRE or nil
	local fs = cmdFs or getDisplayFireState(unitID)
	if not visibleUnits[unitID] or crashingUnits[unitID] or deadAllyTeams[teamToAllyTeam[teamID]] then return end
	if unitFireState[unitID] == fs then return end
	unitFireState[unitID] = fs
	applyFireState(unitID, unitDefID, fs)
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
			clearIconAnim(unitID)
			removeIconMembership(unitID)
		end
	end
end

function widget:PlayerChanged(playerID)
	myPlayerID = spGetMyPlayerID()
	myTeamID = spGetMyTeamID()
	if myPlayerID == nil or myTeamID == nil then return end
	for unitID, unitTeamID in pairs(unitToTeam) do
		if unitTeamID == myTeamID and holdFireIcons[unitID] and unitFireState[unitID] == HOLD_FIRE and not manuallyHeldFire[unitID] then
			holdFireIcons[unitID] = nil
			holdPassDirty = true
		end
	end
end

function widget:UnitDestroyed(unitID)
	manuallyHeldFire[unitID] = nil
	clearIconAnim(unitID)
end

function widget:UnitGiven(unitID)
	manuallyHeldFire[unitID] = nil
end

function widget:UnitTaken(unitID)
	manuallyHeldFire[unitID] = nil
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

	if not next(returnFireIcons) and not next(holdFireIcons) then
		return
	end

	local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5
	local bothActive = next(returnFireIcons) and next(holdFireIcons)
	local membershipDirty = returnPassDirty or holdPassDirty

	gl.DepthTest(true)
	gl.DepthMask(false)

	local vboInvalidated = drawIconPass(returnFireIcons, RETURN_FIRE, returnFireTexture, disticon, returnPassDirty or membershipDirty or bothActive, false)
	drawIconPass(holdFireIcons, HOLD_FIRE, holdFireTexture, disticon, holdPassDirty or membershipDirty or bothActive, vboInvalidated)

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
