local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name      = "Unit Repeat Icons", -- GL4
		desc      = "Shows a repeat icon above units that have the repeat order enabled",
		author    = "Copilot",
		date      = "2026",
		license   = "GNU GPL, v2 or later",
		layer     = -38,
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

local repeatTexture = "LuaUI/Images/repeat.png"

--------------------------------------------------------------------------------
-- GL4 Backend
--------------------------------------------------------------------------------
local repeatVBO       = nil
local repeatShader    = nil

local luaShaderDir        = "LuaUI/Include/"
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
	local scale = 1 * (xsize*xsize + zsize*zsize)^0.5
	unitConf[udid] = {10 + (scale / 2.2), unitDef.height}
end

-- All visible units: [unitID] = unitDefID
local visibleUnits    = {}
local chobbyInterface = false

--------------------------------------------------------------------------------
-- GL4 Initialization
--------------------------------------------------------------------------------
local function initGL4()
	local DrawPrimitiveAtUnit     = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig            = DrawPrimitiveAtUnit.shaderConfig

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

	repeatVBO, repeatShader = InitDrawPrimitiveAtUnit(shaderConfig, "repeat icons")
	if repeatVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
-- Push a unit into the repeat VBO
--------------------------------------------------------------------------------
local function pushToVBO(unitID, unitDefID, gf)
	if repeatVBO.instanceIDtoIndex[unitID] then return end
	if not spValidUnitID(unitID) or spGetUnitIsDead(unitID) then return end
	local conf = unitConf[unitDefID]
	pushElementInstance(
		repeatVBO,
		{conf[1], conf[1], 0, conf[2],   -- iconSize x2, corner=0, height
		 0,                               -- teamID (unused)
		 4,                               -- quad (4 vertices)
		 gf, 0, 0.85, 0,                  -- gameFrame, unused, alpha, unused
		 0, 1, 0, 1,                      -- UV atlas: default full texture
		 0, 0, 0, 0},                     -- padding
		unitID,   -- VBO key
		false,    -- do not update existing
		true,     -- noupload: batch
		unitID)   -- unit ID for position lookup
end

--------------------------------------------------------------------------------
-- Scan visible units and sync the VBO to current repeat states
--------------------------------------------------------------------------------
local function updateRepeatStates()
	local gf    = spGetGameFrame()
	local dirty = false

	for unitID, unitDefID in pairs(visibleUnits) do
		local states = spGetUnitStates(unitID)
		if states then
			if states["repeat"] then
				if not repeatVBO.instanceIDtoIndex[unitID] then
					pushToVBO(unitID, unitDefID, gf)
					dirty = true
				end
			else
				if repeatVBO.instanceIDtoIndex[unitID] then
					popElementInstance(repeatVBO, unitID, true)
					dirty = true
				end
			end
		end
	end

	if dirty or repeatVBO.dirty then
		uploadAllElements(repeatVBO)
	end
end

--------------------------------------------------------------------------------
-- Widget callbacks
--------------------------------------------------------------------------------
function widget:Initialize()
	if not gl.CreateShader then
		widgetHandler:RemoveWidget()
		return
	end
	if not initGL4() then return end

	if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
		widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	end
end

function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
	InstanceVBOTable.clearInstanceTable(repeatVBO)
	visibleUnits = {}
	for unitID, unitDefID in pairs(extVisibleUnits) do
		visibleUnits[unitID] = unitDefID
	end
	updateRepeatStates()
end

function widget:VisibleUnitAdded(unitID, unitDefID, unitTeam)
	visibleUnits[unitID] = unitDefID
end

function widget:VisibleUnitRemoved(unitID)
	visibleUnits[unitID] = nil
	if repeatVBO.instanceIDtoIndex[unitID] then
		popElementInstance(repeatVBO, unitID)
	end
end

function widget:GameFrame(n)
	if n % 30 == 0 then
		updateRepeatStates()
	end
end

function widget:RecvLuaMsg(msg, playerID)
	if msg:sub(1, 18) == 'LobbyOverlayActive' then
		chobbyInterface = (msg:sub(1, 19) == 'LobbyOverlayActive1')
	end
end

function widget:DrawScreenEffects()
	if chobbyInterface then return end
	if Spring.IsGUIHidden() then return end
	if repeatVBO.usedElements == 0 then return end

	local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5

	gl.DepthTest(true)
	gl.DepthMask(false)
	gl.Texture(repeatTexture)
	repeatShader:Activate()
	repeatShader:SetUniform("iconDistance", disticon)
	repeatShader:SetUniform("addRadius", 0)
	repeatVBO.VAO:DrawArrays(GL.POINTS, repeatVBO.usedElements)
	repeatShader:Deactivate()
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(true)
end
