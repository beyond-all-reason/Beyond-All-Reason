local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Unit Wait Icons",
		desc = "Shows the wait/pause icon above units",
		author = "Floris, Beherith, Robert82",
		date = "May 2025",
		license = "GNU GPL, v2 or later",
		layer = -40,
		enabled = true,
	}
end

local iconSequenceImages = "anims/icexuick_200/cursorwait_" -- must be png's
local iconSequenceNum = 44 -- always starts at 1
local iconSequenceFrametime = 0.02 -- duration per frame

local iconSequenceTextures = {}
for i = 1, iconSequenceNum do
	iconSequenceTextures[i] = iconSequenceImages .. i .. ".png"
end

local CMD_WAIT = CMD.WAIT

local waitingUnits = {}
local needsCheckFrame = {} -- unitID → frame
local needsCheckDefID = {} -- unitID → defID
local checkDelay = 5
local unitsPerFrame = 300
local gf = Spring.GetGameFrame()

local spGetGameFrame = Spring.GetGameFrame
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetFactoryCommands = Spring.GetFactoryCommands
local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetLocalTeamID()
local spValidUnitID = Spring.ValidUnitID

local spIsGUIHidden = Spring.IsGUIHidden

-- "UnitIconDistance" is not an engine setting, so this is the default unless someone sets it
local iconDistance = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
local shaderIconDistance

---@type table<integer, table>
local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	if not unitDef.customParams.removewait then
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 4 * ((xsize + 2) ^ 2 + (zsize + 2) ^ 2) ^ 0.5
		unitConf[udid] = { 7.5 + (scale / 2.2), unitDef.height - 0.1, unitDef.isFactory }
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GL4 Backend stuff:

local InstanceVBOTable = gl.InstanceVBOTable

local popElementInstance = InstanceVBOTable.popElementInstance
local pushElementInstance = InstanceVBOTable.pushElementInstance
local uploadAllElements = InstanceVBOTable.uploadAllElements

---@type InstanceVBOTable?
local iconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Include/"

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir .. "DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.75
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0 --0.1
	-- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.POST_GEOMETRY =
		" gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
	shaderConfig.POST_SHADING = "fragColor.rgba = vec4(texcolor.rgb, texcolor.a * g_uv.z);"
	shaderConfig.MAXVERTICES = 4
	shaderConfig.USE_CIRCLES = nil
	shaderConfig.USE_CORNERRECT = nil
	iconVBO, energyIconShader = InitDrawPrimitiveAtUnit(shaderConfig, "energy icons")
	if iconVBO == nil then
		widgetHandler:RemoveWidget()
		return false
	end
	return true
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GameFrame only runs while units wait or wait for a check
local gameFrameActive = true

local function stopGameFrameWhenIdle()
	if gameFrameActive and next(needsCheckFrame) == nil and next(waitingUnits) == nil then
		gameFrameActive = false
		widgetHandler:RemoveCallIn("GameFrame")
	end
end

local function scheduleCheck(unitID, unitDefID, delay)
	if not gameFrameActive then
		gameFrameActive = true
		gf = spGetGameFrame() -- not kept up to date while GameFrame is off
		widgetHandler:UpdateCallIn("GameFrame")
	end
	needsCheckFrame[unitID] = gf + delay
	needsCheckDefID[unitID] = unitDefID
end

local function MarkAsWaiting(unitID, unitDefID)
	if unitConf[unitDefID] then
		waitingUnits[unitID] = unitDefID
	end
end

local function UnmarkAsWaiting(unitID)
	if waitingUnits[unitID] then
		waitingUnits[unitID] = nil -- erase flag
	end
	if iconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(iconVBO, unitID)
	end
end

-- only units of my team get checked
local function CheckWaitingStatus(unitID, unitDefID)
	local conf = unitConf[unitDefID]
	if not conf then
		return
	end
	local waiting
	if conf[3] then
		-- a factory keeps its own orders, WAIT included, in its build queue
		local queue = spGetFactoryCommands(unitID, 1)
		waiting = queue ~= nil and queue[1] ~= nil and queue[1].id == CMD_WAIT
	else
		-- returns nothing for an empty queue
		waiting = spGetUnitCurrentCommand(unitID) == CMD_WAIT
	end
	if waiting then
		MarkAsWaiting(unitID, unitDefID)
	else
		UnmarkAsWaiting(unitID)
	end
end

local function forgetUnit(unitID)
	needsCheckFrame[unitID] = nil
	needsCheckDefID[unitID] = nil
	UnmarkAsWaiting(unitID)
end

---@type number[]
local instanceData = { 0, 0, 0, 0, 0, 4, 0, 0, 0.75, 0, 0, 1, 0, 1, 0, 0, 0, 0 }

local function updateIcons()
	for unitID, unitDefID in pairs(waitingUnits) do
		if not iconVBO.instanceIDtoIndex[unitID] then --if visibleUnits[unitID] then
			if spValidUnitID(unitID) then
				local conf = unitConf[unitDefID]
				instanceData[1] = conf[1]
				instanceData[2] = conf[1]
				instanceData[4] = conf[2]
				instanceData[7] = gf
				pushElementInstance(iconVBO, instanceData, unitID, false, true, unitID)
			end
		end
	end
	for unitID in pairs(iconVBO.instanceIDtoIndex) do
		if not waitingUnits[unitID] then
			popElementInstance(iconVBO, unitID, true)
		end
	end
	if iconVBO.dirty then
		uploadAllElements(iconVBO)
	end
end

local function initUnits()
	waitingUnits = {} -- forget any previous “waiting” flags
	local unitDefID
	for _, unitID in pairs(Spring.GetTeamUnits(myTeamID)) do
		unitDefID = Spring.GetUnitDefID(unitID)
		scheduleCheck(unitID, unitDefID, checkDelay)
	end
	stopGameFrameWhenIdle()
end

function widget:Initialize()
	if spec or not gl.CreateShader or not initGL4() then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	-- load every animation frame now: loading one inside a draw stalls ~10 ms, which hit each frame of the first cycle
	for i = 1, iconSequenceNum do
		gl.TextureInfo(iconSequenceTextures[i])
	end
	initUnits()
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	forgetUnit(unitID)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	forgetUnit(unitID)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitTeam ~= myTeamID then
		return
	end
	scheduleCheck(unitID, unitDefID, checkDelay)
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID)
	if unitTeam ~= myTeamID then
		return
	end
	if cmdID == CMD_WAIT then
		-- wait command just completed (toggled off), directly unmark
		UnmarkAsWaiting(unitID)
	else
		-- another command finished, defer check to GameFrame batch
		scheduleCheck(unitID, unitDefID, 1)
	end
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	-- idle = no commands, can't be waiting
	UnmarkAsWaiting(unitID)
end

function widget:GameFrame(n)
	local currentUnitPerFrame = 0
	gf = n
	for unitID, frame in pairs(needsCheckFrame) do
		if n >= frame then
			currentUnitPerFrame = currentUnitPerFrame + 1
			if currentUnitPerFrame < unitsPerFrame then
				CheckWaitingStatus(unitID, needsCheckDefID[unitID])
				needsCheckFrame[unitID] = nil
				needsCheckDefID[unitID] = nil
			end
		end
	end
	if gf % 24 == 0 and next(waitingUnits) then
		updateIcons()
	end
	stopGameFrameWhenIdle()
end

function widget:DrawScreenEffects()
	-- DrawScreenEffects so icons render after deferred lighting/distortion/bloom/tonemap;
	-- shader still uses engine cameraViewProj UBO and depth-test for terrain occlusion.
	-- Stays registered while empty: re-registering moves a widget behind the others of its layer,
	-- which would change which icon is on top when several of them overlap.
	if iconVBO.usedElements == 0 or spIsGUIHidden() then
		return
	end

	gl.DepthTest(true)
	gl.DepthMask(false)
	local clock = os.clock() * (1 * (iconSequenceFrametime * iconSequenceNum)) -- adjust speed relative to anim frame speed of 0.02sec per frame (59 frames in total)
	local animFrame = math.max(1, math.ceil(iconSequenceNum * (clock - math.floor(clock))))
	gl.Texture(iconSequenceTextures[animFrame])
	energyIconShader:Activate()
	-- addRadius stays at its default of 0
	if shaderIconDistance ~= iconDistance then
		shaderIconDistance = iconDistance
		energyIconShader:SetUniform("iconDistance", iconDistance)
	end
	iconVBO.VAO:DrawArrays(GL.POINTS, iconVBO.usedElements)
	energyIconShader:Deactivate()
	gl.Texture(false)
	gl.DepthTest(false)
	gl.DepthMask(true)
end

function widget:Shutdown()
	if type(energyIconShader) == "table" then
		energyIconShader:Finalize()
		energyIconShader = nil
	end
end
