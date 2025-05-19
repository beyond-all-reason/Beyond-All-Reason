local widget = widget ---@type Widget

function widget:GetInfo()
   return {
	  name      = "Unit Wait Icons",
	  desc      = "Shows the wait/pause icon above units",
	  author    = "Floris, Beherith, Robert82",
	  date      = "May 2025",
	  license   = "GNU GPL, v2 or later",
	  layer     = -40,
	  enabled   = true
   }
end

local iconSequenceImages = 'anims/icexuick_200/cursorwait_' 	-- must be png's
local iconSequenceNum = 44	-- always starts at 1
local iconSequenceFrametime = 0.02	-- duration per frame

local CMD_WAIT = CMD.WAIT

local waitingUnits = {}
local needsCheck = {} -- unitID → {frame = n+5, defID = …, team = …}
local checkDelay = 5
local unitsPerFrame = 300
local gf = Spring.GetGameFrame()

local spGetUnitCommands = Spring.GetUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spec = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local spValidUnitID = Spring.ValidUnitID

local spIsGUIHidden   = Spring.IsGUIHidden()
local spGetConfigInt  = Spring.GetConfigInt

local unitConf = {}
for udid, unitDef in pairs(UnitDefs) do
	if not unitDef.customParams.removewait then
		local xsize, zsize = unitDef.xsize, unitDef.zsize
		local scale = 4 * ( (xsize+2)^2 + (zsize+2)^2 )^0.5
		unitConf[udid] = {7.5 +(scale/2.2), unitDef.height-0.1, unitDef.isFactory}
	end
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

-- GL4 Backend stuff:
local iconVBO = nil
local energyIconShader = nil
local luaShaderDir = "LuaUI/Include/"

local function initGL4()
	local DrawPrimitiveAtUnit = VFS.Include(luaShaderDir.."DrawPrimitiveAtUnit.lua")
	local InitDrawPrimitiveAtUnit = DrawPrimitiveAtUnit.InitDrawPrimitiveAtUnit
	local shaderConfig = DrawPrimitiveAtUnit.shaderConfig -- MAKE SURE YOU READ THE SHADERCONFIG TABLE in DrawPrimitiveAtUnit.lua
	shaderConfig.BILLBOARD = 1
	shaderConfig.HEIGHTOFFSET = 0
	shaderConfig.TRANSPARENCY = 0.75
	shaderConfig.ANIMATION = 1
	shaderConfig.FULL_ROTATION = 0
	shaderConfig.CLIPTOLERANCE = 1.2
	shaderConfig.INITIALSIZE = 0.22
	shaderConfig.BREATHESIZE = 0--0.1
  -- MATCH CUS position as seed to sin, then pass it through geoshader into fragshader
	--shaderConfig.POST_VERTEX = "v_parameters.w = max(-0.2, sin(timeInfo.x * 2.0/30.0 + (v_centerpos.x + v_centerpos.z) * 0.1)) + 0.2; // match CUS glow rate"
	shaderConfig.POST_GEOMETRY = " gl_Position.z = (gl_Position.z) - 512.0 / (gl_Position.w); // send 16 elmos forward in depth buffer"
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


function widget:Initialize()
	if spec or not gl.CreateShader or not initGL4() then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	initUnits()
end
local function MarkAsWaiting(unitID, unitDefID, unitTeam)
	if unitTeam == myTeamID and unitConf[unitDefID] then --(not onlyOwnTeam or
		waitingUnits[unitID] = unitDefID
	end
end

local function UnmarkAsWaiting(unitID, unitDefID, unitTeam)
	if waitingUnits[unitID] then
		waitingUnits[unitID] = nil           -- erase flag
	end
	if iconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(iconVBO, unitID)
	end
end

local function CheckWaitingStatus(unitID, unitDefID, unitTeam)
	if not unitConf[unitDefID] then return end
	local queue = unitConf[unitDefID] and unitConf[unitDefID][3] and spGetFactoryCommands(unitID, 1) or spGetUnitCommands(unitID, 1)
	if queue ~= nil and queue[1] and queue[1].id == CMD_WAIT then
		MarkAsWaiting(unitID, unitDefID, unitTeam)
	else
		UnmarkAsWaiting(unitID, unitDefID, unitTeam)
	end
end


function forgetUnit(unitID, unitDefID, unitTeam)
	needsCheck[unitID]   = nil
	UnmarkAsWaiting(unitID, unitDefID, unitTeam)
end

local function updateIcons()
	for unitID, unitDefID in pairs(waitingUnits) do
		if not iconVBO.instanceIDtoIndex[unitID] then--if visibleUnits[unitID] then
			if spValidUnitID(unitID) then
			pushElementInstance(iconVBO,
				{unitConf[unitDefID][1], unitConf[unitDefID][1], 0, unitConf[unitDefID][2],
				0, 4, gf, 0, 0.75, 0,  0,1,0,1,  0,0,0,0},
				unitID, false, true, unitID)
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

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	forgetUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	forgetUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOpts, cmdTag)
	if unitTeam ~= myTeamID then return end -- onlyOwnTeam and
		needsCheck[unitID] = {
		frame = gf + checkDelay,
		defID = unitDefID,
		team  = unitTeam
		}
end

function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID)
	CheckWaitingStatus(unitID, unitDefID, unitTeam)
end

function widget:UnitIdle(unitID, unitDefID, unitTeam)
	CheckWaitingStatus(unitID, unitDefID, unitTeam)
end

function initUnits()
	waitingUnits  = {}      -- forget any previous “waiting” flags
	local unitDefID
	for _, unitID in pairs(Spring.GetTeamUnits(myTeamID)) do
		unitDefID = Spring.GetUnitDefID(unitID)
		needsCheck[unitID] = {
			frame = gf + checkDelay,
			defID = unitDefID,
			team  = myTeamID
		}
	end
end


function widget:GameFrame(n)
	local currentUnitPerFrame = 0
	gf = n
	for unitID, data in pairs(needsCheck) do
		currentUnitPerFrame = currentUnitPerFrame +1
		if currentUnitPerFrame < unitsPerFrame then
			if n >= data.frame then
				CheckWaitingStatus(unitID, data.defID, data.team)
				needsCheck[unitID] = nil -- done, remove from queue
			end
		end
	end
	if gf % 24 == 0 and next(waitingUnits) then
		updateIcons()
	end
end

function widget:DrawWorld()
	if spIsGUIHidden then return end
	if iconVBO.usedElements > 0 then
		local disticon = spGetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
		gl.DepthTest(true)
		gl.DepthMask(false)
		local clock = os.clock() * (1*(iconSequenceFrametime*iconSequenceNum))	-- adjust speed relative to anim frame speed of 0.02sec per frame (59 frames in total)
		local animFrame = math.max(1, math.ceil(iconSequenceNum * (clock - math.floor(clock))))
		gl.Texture(iconSequenceImages..animFrame..'.png')
		energyIconShader:Activate()
		energyIconShader:SetUniform("iconDistance",disticon)
		energyIconShader:SetUniform("addRadius",0)
		iconVBO.VAO:DrawArrays(GL.POINTS,iconVBO.usedElements)
		energyIconShader:Deactivate()
		gl.Texture(false)
		gl.DepthTest(false)
		gl.DepthMask(true)
	end
end
