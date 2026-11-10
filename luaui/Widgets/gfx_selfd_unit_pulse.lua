local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Self-Destruct Unit Pulse",
		desc = "Unit models pulse red while their self-destruct counts down, faster in the last seconds",
		author = "Floris",
		date = "2026.11.09",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

------------------------------------------------------------------------------------------------
-- As the self-destruct button of the order menu does. This widget only writes the game frame a countdown ends on
-- into unit buffer uniform #13, when it starts, is cancelled or drifts (a stunned unit's countdown waits), and its
-- length into #15, which the pulse builds up over. The CUS
-- model shaders (modelmaterials_gl4/templates/cus_gl4.vert/frag.glsl, SELFD_* tunables) pulse from that, so nothing is
-- drawn or written per frame. Spring.GetUnitSelfDTime only reads units of the viewer's allyteam, or all with full view.
------------------------------------------------------------------------------------------------

local UNIFORM_END = 13 -- unit buffer uniforms the CUS shaders read: userDefined[3].y
local UNIFORM_LENGTH = 15 -- userDefined[3].w
local POLL_FRAMES = 8 -- game frames between two looks at the units with a countdown, or one queued
local FRAMES_PER_STEP = 15 -- a countdown steps once per slow update (UNIT_SLOWUPDATE_RATE)
local RESYNC_FRAMES = 20 -- written again when the end moved further than this (more than a step's rounding)

local CMD_SELFD = CMD.SELFD

local spGetUnitSelfDTime = Spring.GetUnitSelfDTime
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitCommandCount = Spring.GetUnitCommandCount
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetGameFrame = Spring.GetGameFrame
local glSetUnitBufferUniforms = gl.SetUnitBufferUniforms
local mathAbs = math.abs

local isFactoryDef = {}
local countdownSeconds = {} ---@type table<integer, number>
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isFactory then
		isFactoryDef[unitDefID] = true
	end
	countdownSeconds[unitDefID] = unitDef.selfDCountdown or 0
end

local watched = {} ---@type table<integer, boolean?> unitID -> has a countdown or one queued
local endFrames = {} ---@type table<integer, integer?> unitID -> the frame written, while it pulses
local checkAll = false -- a self-destruct order was given: looked at on the next game frame
local fullview, myAllyTeamID = false, 0
local uniformCache = { 0 }

local function setUniform(unitID, index, value)
	uniformCache[1] = value
	glSetUnitBufferUniforms(unitID, uniformCache, index)
end

-- Also reaches units this viewer can no longer see (after a spectator view switch), which would keep pulsing otherwise.
-- Unit getters return nil for those, so only a known dead unit is skipped; the write raises an error for a unit that
-- no longer exists.
local function writeUniform(unitID, index, value)
	if spGetUnitIsDead(unitID) ~= true then
		pcall(setUniform, unitID, index, value)
	end
end

-- reads the queue without building command tables
local function hasSelfDQueued(unitID)
	-- a factory reports the queue of the units it builds, only its first command counts
	local count = isFactoryDef[spGetUnitDefID(unitID)] and 1 or spGetUnitCommandCount(unitID)
	for i = 1, count or 0 do
		local cmdID = spGetUnitCurrentCommand(unitID, i)
		if cmdID == CMD_SELFD then
			return true
		elseif cmdID == nil then
			return false
		end
	end
	return false
end

local function stopPulse(unitID)
	if endFrames[unitID] then
		endFrames[unitID] = nil
		writeUniform(unitID, UNIFORM_END, 0)
	end
end

local function checkUnit(unitID, frame)
	local left = spGetUnitSelfDTime(unitID)
	if left == nil then -- gone, or no longer ours to read
		stopPulse(unitID)
		watched[unitID] = nil
	elseif left > 0 then
		watched[unitID] = true
		local finish = frame + left * FRAMES_PER_STEP
		local written = endFrames[unitID]
		if not written then
			writeUniform(unitID, UNIFORM_LENGTH, countdownSeconds[spGetUnitDefID(unitID)] or 0)
		end
		if not written or mathAbs(finish - written) > RESYNC_FRAMES then
			endFrames[unitID] = finish
			writeUniform(unitID, UNIFORM_END, finish)
		end
	else
		stopPulse(unitID)
		watched[unitID] = hasSelfDQueued(unitID) or nil
	end
end

local function rebuild()
	for unitID in pairs(endFrames) do
		stopPulse(unitID)
	end
	watched = {}
	local frame = spGetGameFrame()
	local units = Spring.GetAllUnits()
	for i = 1, #units do
		checkUnit(units[i], frame)
	end
end

local function readViewer()
	local _, currentFullview = Spring.GetSpectatingState()
	fullview, myAllyTeamID = currentFullview, Spring.GetMyAllyTeamID()
end

function widget:GameFrame(frame)
	if not checkAll and frame % POLL_FRAMES ~= 0 then
		return
	end
	checkAll = false
	for unitID in pairs(watched) do
		checkUnit(unitID, frame)
	end
end

-- (only CMD_SELFD: Initialize; before the engine has started or cancelled the countdown)
function widget:UnitCommand(unitID)
	watched[unitID], checkAll = true, true
end
widget.UnitGiven = widget.UnitCommand
widget.UnitTaken = widget.UnitCommand

function widget:UnitDestroyed(unitID)
	watched[unitID], endFrames[unitID] = nil, nil
end

-- called for every player's change, only the viewer's full view and allyteam matter here
function widget:PlayerChanged()
	local wasFullview, wasAllyTeam = fullview, myAllyTeamID
	readViewer()
	if fullview ~= wasFullview or (not fullview and myAllyTeamID ~= wasAllyTeam) then
		rebuild()
	end
end

function widget:Initialize()
	if not gl.SetUnitBufferUniforms then -- no shader support (headless)
		widgetHandler:RemoveWidget()
		return
	end
	widgetHandler:RegisterUnitCommand(CMD_SELFD)
	readViewer()
	rebuild()
end

function widget:Shutdown()
	for unitID in pairs(endFrames) do
		stopPulse(unitID)
	end
end
