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

--------------------------------------------------------------------------------
-- Localized Spring API
--------------------------------------------------------------------------------
local spGetGameFrame  = Spring.GetGameFrame
local spGetUnitStates = Spring.GetUnitStates
local spValidUnitID   = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead

local HOLD_FIRE   = 0
local RETURN_FIRE = 1

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
	if unitDef.weapons and #unitDef.weapons > 0 then
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

	holdFireVBO, fireIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "hold fire icons")
	if holdFireVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	-- Second call reuses the same compiled shader but allocates a new VBO
	returnFireVBO = select(1, InitDrawPrimitiveAtUnit(shaderConfig, "return fire icons"))
	if returnFireVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end

	return true
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
	if fs == HOLD_FIRE then
		pushToVBO(holdFireVBO, unitID, unitDefID, gf)
		if returnFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(returnFireVBO, unitID, true)
		end
	elseif fs == RETURN_FIRE then
		pushToVBO(returnFireVBO, unitID, unitDefID, gf)
		if holdFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(holdFireVBO, unitID, true)
		end
	else
		if holdFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(holdFireVBO, unitID, true)
		end
		if returnFireVBO.instanceIDtoIndex[unitID] then
			popElementInstance(returnFireVBO, unitID, true)
		end
	end
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

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(holdFireVBO)
	InstanceVBOTable.clearInstanceTable(returnFireVBO)
	visibleUnits = {}
	unitFireState = {}
	local gf = spGetGameFrame()
	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
		if not crashingUnits[unitID] then
			local states = spGetUnitStates(unitID)
			if states then
				local fs = states.firestate
				unitFireState[unitID] = fs
				applyFireState(unitID, unitDefID, fs, gf)
			end
		end
	end
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	visibleUnits[unitID] = unitDefID
	if crashingUnits[unitID] then return end
	local states = spGetUnitStates(unitID)
	if not states then return end
	local fs = states.firestate
	unitFireState[unitID] = fs
	applyFireState(unitID, unitDefID, fs, spGetGameFrame())
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
	unitFireState[unitID] = nil
	crashingUnits[unitID] = nil
	if holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID)
	end
	if returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID)
	end
end

function widget:CrashingAircraft(unitID, unitDefID, teamID)
	crashingUnits[unitID] = true
	unitFireState[unitID] = nil
	if holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID)
	end
	if returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID)
	end
end

function widget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOpts)
	if cmdID ~= CMD.FIRE_STATE then return end
	if not visibleUnits[unitID] or crashingUnits[unitID] then return end
	local fs = cmdParams[1]
	if unitFireState[unitID] == fs then return end
	unitFireState[unitID] = fs
	applyFireState(unitID, unitDefID, fs, spGetGameFrame())
	if holdFireVBO.dirty then uploadAllElements(holdFireVBO) end
	if returnFireVBO.dirty then uploadAllElements(returnFireVBO) end
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
