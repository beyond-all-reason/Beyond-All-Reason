local widget = widget ---@type Widget

function widget:GetInfo()
   return {
      name      = "Unit Wait Icons",
      desc      = "Shows the wait/pause icon above units",
      author    = "Floris, Beherith, Robert82",
      date      = "June 2024",
      license   = "GNU GPL, v2 or later",
      layer     = -40,
      enabled   = truev
   }
end

local onlyOwnTeam = true

local iconSequenceImages = 'anims/icexuick_200/cursorwait_' 	-- must be png's
local iconSequenceNum = 44	-- always starts at 1
local iconSequenceFrametime = 0.02	-- duration per frame

local CMD_WAIT = CMD.WAIT

local unitScope = {} -- table of teamid to table of stallable unitID : unitDefID
local trackedUnits = {}
local waitingUnits = {}
local teamList = {} -- {team1, team2, team3....}

local spGetUnitCommands = Spring.GetUnitCommands
local spGetFactoryCommands = Spring.GetFactoryCommands
local spGetUnitTeam = Spring.GetUnitTeam
local spec, fullview = Spring.GetSpectatingState()
local myTeamID = Spring.GetMyTeamID()
local spValidUnitID = Spring.ValidUnitID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitStates = Spring.GetUnitStates
local spIsUnitInView = Spring.IsUnitInView


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

-- function widget:VisibleUnitsChanged(extVisibleUnits, extNumVisibleUnits)
-- 	spec, fullview = Spring.GetSpectatingState()
-- 	teamList = fullview and Spring.GetTeamList() or Spring.GetTeamList(Spring.GetMyAllyTeamID())
-- 	clearInstanceTable(iconVBO) -- clear all instances
-- 	unitScope = {}
-- 	for unitID, unitDefID in pairs(extVisibleUnits) do
-- 		widget:VisibleUnitAdded(unitID, unitDefID, spGetUnitTeam(unitID))
-- 	end
-- 	uploadAllElements(iconVBO) -- upload them all
-- end


function widget:Initialize()
	if spec or not gl.CreateShader or not initGL4() then -- no shader support, so just remove the widget itself, especially for headless
		widgetHandler:RemoveWidget()
		return
	end
	refreshTrackedUnits()
	-- if WG['unittrackerapi'] and WG['unittrackerapi'].visibleUnits then
	-- 	widget:VisibleUnitsChanged(WG['unittrackerapi'].visibleUnits, nil)
	-- end
end



local function updateIcons()
  local gf = Spring.GetGameFrame()

  for unitID, unitDefID in pairs(waitingUnits) do
    if spIsUnitInView(unitID) then
      if not iconVBO.instanceIDtoIndex[unitID] and spValidUnitID(unitID) then
        pushElementInstance(iconVBO,
          {unitConf[unitDefID][1], unitConf[unitDefID][1], 0, unitConf[unitDefID][2],
           0, 4, gf, 0, 0.75, 0,  0,1,0,1,  0,0,0,0},
          unitID, false, true, unitID)
      end
    elseif iconVBO.instanceIDtoIndex[unitID] then
      popElementInstance(iconVBO, unitID, true)
    end
  end

  if iconVBO.dirty then uploadAllElements(iconVBO) end
end

function widget:GameFrame(n)
	if Spring.GetGameFrame() % 24 == 0 then
		updateIcons()
	end
end


function TrackUnit(unitID, unitDefID, unitTeam) --needed for exact calculations
	if (myTeamID == unitTeam) and unitConf[unitDefID] then
		trackedUnits[unitID] = unitDefID
	end
end

function UntrackUnit(unitID, unitDefID, unitTeam) -- needed for exact calculations
	trackedUnits[unitID] = nil
	UnmarkAsWaiting(uID)
	if iconVBO.instanceIDtoIndex[unitID] then
		popElementInstance(iconVBO, unitID)
	end
end

function widget:UnitTaken(unitID, unitDefID, unitTeam)
	UntrackUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitGiven(unitID, unitDefID, unitTeam)
	TrackUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitCreated(unitID, unitDefID, unitTeam)
	TrackUnit(unitID, unitDefID, unitTeam)
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	UntrackUnit(unitID, unitDefID, unitTeam)
end


local function MarkAsWaiting(unitID, unitDefID, unitTeam)
  if (not onlyOwnTeam or unitTeam == myTeamID) and unitConf[unitDefID] then
    waitingUnits[unitID] = unitDefID
  end
end

local function UnmarkAsWaiting(unitID)
  waitingUnits[unitID] = nil           -- erase flag
  if iconVBO.instanceIDtoIndex[unitID] then
    popElementInstance(iconVBO, unitID)
  end
end

-- fires for *every* accepted command
function widget:UnitCommand(unitID, unitDefID, unitTeam,
                             cmdID, cmdParams, cmdOpts, cmdTag)
  if onlyOwnTeam and unitTeam ~= myTeamID then return end   -- filter once

  if cmdID == CMD_WAIT then          -- player pressed WAIT key
    if waitingUnits[unitID] then
      UnmarkAsWaiting(unitID)        -- toggle OFF
    else
      MarkAsWaiting(unitID, unitDefID, unitTeam) -- toggle ON
    end

  elseif waitingUnits[unitID] then   -- any other cmd cancels the wait
    UnmarkAsWaiting(unitID)
  end
end

-- WAIT reached the head of the queue and disappeared
function widget:UnitCmdDone(unitID, unitDefID, unitTeam, cmdID)
  if cmdID == CMD_WAIT then
    UnmarkAsWaiting(unitID)
  end
end

-- unit has no more commands
function widget:UnitIdle(unitID, unitDefID, unitTeam)
  UnmarkAsWaiting(unitID)
end





function widget:PlayerChanged()
	refreshTrackedUnits()
	if displayComCounter then
		countComs(true)
	end
end

-- function refreshTrackedUnits()
-- 	trackedUnits = {}
-- 	for _, unitID in pairs(Spring.GetTeamUnits(myTeamID)) do
-- 		TrackUnit(unitID, Spring.GetUnitDefID(unitID), myTeamID)
-- 	end
-- end



function refreshTrackedUnits()
  trackedUnits  = {}
  waitingUnits  = {}      -- forget any previous “waiting” flags

  local units = Spring.GetTeamUnits(myTeamID)
  for i = 1, #units do
    local uID   = units[i]
    local uDef  = Spring.GetUnitDefID(uID)

    TrackUnit(uID, uDef, myTeamID)          -- rebuild the tracked set

    -- if this unit is already paused, mark it right now ---------------
    local isFactory = unitConf[uDef] and unitConf[uDef][3]
    local q = (isFactory and Spring.GetFactoryCommands(uID, 1))
           or               Spring.GetUnitCommands   (uID, 1)

    if q and q[1] and q[1].id == CMD_WAIT then
      MarkAsWaiting(uID, uDef, myTeamID)    -- adds to waitingUnits
    end
  end
end


function widget:DrawWorld()
	if Spring.IsGUIHidden() then return end
	if iconVBO.usedElements > 0 then
		local disticon = Spring.GetConfigInt("UnitIconDistance", 200) * 27.5 -- iconLength = unitIconDist * unitIconDist * 750.0f;
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
