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
local spGetGameFrame       = Spring.GetGameFrame
local spGetSpectatingState = Spring.GetSpectatingState
local spGetUnitStates      = Spring.GetUnitStates
local spValidUnitID        = Spring.ValidUnitID
local spGetUnitIsDead      = Spring.GetUnitIsDead

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
--------------------------------------------------------------------------------
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	local xsize, zsize = unitDef.xsize, unitDef.zsize
	local scale = 2.5 * (xsize*xsize + zsize*zsize)^0.5
	unitConf[udid] = {11 + (scale / 2.2), unitDef.height}
end

-- All visible units: [unitID] = unitDefID
local visibleUnits    = {}
local crashingUnits   = {} -- unitIDs currently crashing; skip icon for these
local chobbyInterface = false

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
	pushElementInstance(
		vbo,
		{conf[1], conf[1], 0, conf[2],   -- iconSize x2, corner=0, height
		 0,                               -- teamID (unused)
		 4,                               -- quad (4 vertices)
		 gf, 0, 0.85, 0,                  -- gameFrame, unused, alpha, unused
		 0, 1, 0, 1,                      -- UV atlas: default full texture
		 0, 0, 0, 0},                     -- padding (filled by engine)
		unitID,   -- VBO key
		false,    -- do not update existing
		true,     -- noupload: batch together
		unitID)   -- unit ID for position lookup
end

--------------------------------------------------------------------------------
-- Scan visible units and sync both VBOs to current fire states
--------------------------------------------------------------------------------
local function updateFireStates()
	local gf        = spGetGameFrame()
	local holdDirty = false
	local retDirty  = false

	for unitID, unitDefID in pairs(visibleUnits) do
		if not crashingUnits[unitID] then
			local states = spGetUnitStates(unitID)
			if states then
				local fs = states.firestate
				if fs == HOLD_FIRE then
					-- Add to hold fire VBO if not already present
					if not holdFireVBO.instanceIDtoIndex[unitID] then
						pushToVBO(holdFireVBO, unitID, unitDefID, gf)
						holdDirty = true
					end
					-- Remove from return fire VBO if present
					if returnFireVBO.instanceIDtoIndex[unitID] then
						popElementInstance(returnFireVBO, unitID, true)
						retDirty = true
					end
				elseif fs == RETURN_FIRE then
					-- Add to return fire VBO if not already present
					if not returnFireVBO.instanceIDtoIndex[unitID] then
						pushToVBO(returnFireVBO, unitID, unitDefID, gf)
						retDirty = true
					end
					-- Remove from hold fire VBO if present
					if holdFireVBO.instanceIDtoIndex[unitID] then
						popElementInstance(holdFireVBO, unitID, true)
						holdDirty = true
					end
				else
					-- Fire at will (or other): remove from both VBOs
					if holdFireVBO.instanceIDtoIndex[unitID] then
						popElementInstance(holdFireVBO, unitID, true)
						holdDirty = true
					end
					if returnFireVBO.instanceIDtoIndex[unitID] then
						popElementInstance(returnFireVBO, unitID, true)
						retDirty = true
					end
				end
			end
		end
	end
	if holdDirty or holdFireVBO.dirty then
		uploadAllElements(holdFireVBO)
	end
	if retDirty or returnFireVBO.dirty then
		uploadAllElements(returnFireVBO)
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
	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
	end
	updateFireStates()
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	visibleUnits[unitID] = unitDefID
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
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
	if holdFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(holdFireVBO, unitID)
	end
	if returnFireVBO.instanceIDtoIndex[unitID] then
		popElementInstance(returnFireVBO, unitID)
	end
end

function widget:GameFrame(n)
	if n % 30 == 0 then
		updateFireStates()
	end
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
