local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Jammed Units Highlight",
		desc = "Faint red tint on allied units standing in allied radar jammer coverage (hidden from enemy radar)",
		author = "Floris",
		date = "2026.10.11",
		license = "GNU GPL v2",
		layer = 0,
		enabled = true,
	}
end

------------------------------------------------------------------------------------------------
-- The engine decides what is jammed: a unit is hidden from enemy radar while its position lies in its own
-- allyteam's jammer map (Spring.GetPositionLosState, 4th return), the same map the jammer preview draws.
-- Buildings exactly on a cell line also count when a cell on either side is jammed: unit_jammed_fix.lua hides
-- those from radar and marks them with the "jammed" unit rules param.
-- Every tracked unit is checked once per POLL_FRAMES game frames, spread evenly over those frames. A change
-- writes a time stamp into unit buffer uniform #7 (Spring.GetDrawSeconds, which is the shaders' timeInfo.y):
-- positive = jammed since then, negative = unjammed since then, 0 = never jammed. The CUS model shaders
-- (modelmaterials_gl4/templates/cus_gl4.vert/frag.glsl, JAMMED_* tunables) fade a red tint and rim in or out
-- from that stamp, so this widget draws nothing itself and only writes on changes. The highlight is shown while the
-- jammer coverage preview (Sensor Ranges Jammer Preview) draws coverage, or at all times without that widget.
-- Players see their own allyteam's units. Spectators with full view see every allyteam's units, each against
-- its own jammers; spectators following a team see that team's allyteam.
------------------------------------------------------------------------------------------------

-- Tunables
local POLL_FRAMES = 6 -- game frames between two checks of the same unit (6 = 5 checks per second)
local UNIFORM_INDEX = 7 -- unit buffer uniform (userDefined[1].w) the CUS shaders read

local spGetUnitPosition = Spring.GetUnitPosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetDrawSeconds = Spring.GetDrawSeconds
local glSetUnitBufferUniforms = gl.SetUnitBufferUniforms
local mathFloor = math.floor
local mathMax = math.max

local hasJammingRule = table.new(#UnitDefs, 0) ---@type table<UnitDefID, true?> see unit_jammed_fix.lua
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile then
		hasJammingRule[unitDefID] = true
	end
end

local gaiaTeamID = Spring.GetGaiaTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local fullview = false

local trackedUnits = {} ---@type table<integer, integer?> index -> unitID, checked in turn
local trackedIndex = {} ---@type table<integer, integer?> unitID -> index in trackedUnits
local trackedCount = 0
local unitAllyTeam = {} ---@type table<integer, integer?> unitID -> allyteam whose jammers can hide it
local checkJamming = {} ---@type table<integer, true?> unitID -> special handling by unit_jammed_fix.lua
local jammed = {} ---@type table<integer, boolean?> unitID -> highlighted right now
local cursor = 1 -- next trackedUnits index to check
local pollBudget = 0 -- unit checks owed, in units * frames: every unit gets checked once per POLL_FRAMES frames

local shown = false -- whether the highlights are written at the moment

local uniformCache = { 0 }

-- the shaders' clock (timeInfo.y); never 0, which the shaders read as "never jammed"
local function drawTime()
	return mathMax(spGetDrawSeconds(), 0.001)
end

local function setStamp(unitID, stamp)
	uniformCache[1] = stamp
	glSetUnitBufferUniforms(unitID, uniformCache, UNIFORM_INDEX)
end

-- whether this viewer's highlight covers the unit, and the allyteam whose jammers can hide it
local function covers(unitID)
	if spGetUnitTeam(unitID) == gaiaTeamID then
		return false, 0
	end
	local allyTeam = spGetUnitAllyTeam(unitID)
	if allyTeam == nil or (not fullview and allyTeam ~= myAllyTeamID) then
		return false, 0
	end
	return true, allyTeam
end

local function isJammed(unitID)
	if checkJamming[unitID] and spGetUnitRulesParam(unitID, "jammed") == 1 then
		return true
	end
	local x, y, z = spGetUnitPosition(unitID)
	if not x then
		return false
	end
	-- a full view spectator has to name the allyteam, a player may only read their own
	local allyTeam = nil
	if fullview then
		allyTeam = unitAllyTeam[unitID]
	end
	local _, _, _, inJammer = spGetPositionLosState(x, y, z, allyTeam)
	return inJammer == true
end

local function checkUnit(unitID, now)
	local was = jammed[unitID] == true
	local is = isJammed(unitID)
	if is ~= was then
		jammed[unitID] = is or nil
		setStamp(unitID, is and now or -now)
	end
end

local function addUnit(unitID)
	if trackedIndex[unitID] then
		return
	end
	local covered, allyTeam = covers(unitID)
	if not covered then
		return
	end
	trackedCount = trackedCount + 1
	trackedUnits[trackedCount] = unitID
	trackedIndex[unitID] = trackedCount
	unitAllyTeam[unitID] = allyTeam
	checkJamming[unitID] = hasJammingRule[spGetUnitDefID(unitID)]
end

local function removeUnit(unitID, now)
	local index = trackedIndex[unitID]
	if not index then
		return
	end
	local last = trackedUnits[trackedCount]
	trackedUnits[index] = last
	trackedIndex[last] = index
	trackedUnits[trackedCount] = nil
	trackedCount = trackedCount - 1
	trackedIndex[unitID] = nil
	unitAllyTeam[unitID] = nil
	checkJamming[unitID] = nil
	if jammed[unitID] then
		jammed[unitID] = nil
		if spGetUnitIsDead(unitID) == false then -- still alive (given away): fade its highlight out
			setStamp(unitID, -now)
		end
	end
end

local function hideAll(now)
	for unitID in pairs(jammed) do
		if spGetUnitIsDead(unitID) == false then
			setStamp(unitID, -now)
		end
	end
	jammed = {}
end

local function pollAll(now)
	for i = 1, trackedCount do
		checkUnit(trackedUnits[i], now)
	end
	cursor = 1
	pollBudget = 0
end

local function refreshViewer()
	local _, currentFullview = Spring.GetSpectatingState()
	fullview = currentFullview
	myAllyTeamID = Spring.GetMyAllyTeamID()
end

local function rebuild(visibleUnits)
	refreshViewer()
	local now = drawTime()
	-- downwards, so a swap-removal only moves units that were already looked at
	for i = trackedCount, 1, -1 do
		local unitID = trackedUnits[i]
		local covered, allyTeam = covers(unitID)
		if visibleUnits[unitID] and covered then
			unitAllyTeam[unitID] = allyTeam
		else
			removeUnit(unitID, now)
		end
	end
	for unitID in pairs(visibleUnits) do
		addUnit(unitID)
	end
	if shown then
		pollAll(now)
	end
end

-- a unit that changed team may have changed allyteam
local function unitChangedTeam(unitID)
	local covered, allyTeam = covers(unitID)
	if not covered then
		removeUnit(unitID, drawTime())
	elseif trackedIndex[unitID] then
		unitAllyTeam[unitID] = allyTeam
	else
		addUnit(unitID)
	end
end

local function coverageShown()
	local preview = WG.jammerPreview
	if preview == nil then
		return true -- no preview to follow, so highlight at all times
	end
	return preview.isCoverageShown()
end

function widget:Update()
	local show = coverageShown()
	if show ~= shown then
		shown = show
		local now = drawTime()
		if show then
			pollAll(now)
		else
			hideAll(now)
		end
	end
end

function widget:GameFrame()
	if not shown or trackedCount == 0 then
		return
	end
	local now = drawTime()
	pollBudget = pollBudget + trackedCount
	local count = mathFloor(pollBudget / POLL_FRAMES)
	pollBudget = pollBudget - count * POLL_FRAMES
	for _ = 1, count do
		if cursor > trackedCount then
			cursor = 1
		end
		checkUnit(trackedUnits[cursor], now)
		cursor = cursor + 1
	end
end

function widget:VisibleUnitAdded(unitID)
	addUnit(unitID)
end

function widget:VisibleUnitRemoved(unitID)
	removeUnit(unitID, drawTime())
end

function widget:VisibleUnitsChanged(visibleUnits)
	rebuild(visibleUnits)
end

function widget:UnitGiven(unitID)
	unitChangedTeam(unitID)
end

function widget:UnitTaken(unitID)
	unitChangedTeam(unitID)
end

function widget:PlayerChanged()
	local tracker = WG.unittrackerapi ---@type table?
	if tracker and tracker.visibleUnits then
		rebuild(tracker.visibleUnits)
	end
end

function widget:Initialize()
	-- no shader support (headless), or no fog of war, which leaves jammers nothing to hide
	local modOptions = Spring.GetModOptions() ---@type table<string, any>
	if not gl.SetUnitBufferUniforms or modOptions.disable_fogofwar then
		widgetHandler:RemoveWidget()
		return
	end
	local tracker = WG.unittrackerapi ---@type table?
	if not (tracker and tracker.visibleUnits) then
		Spring.Echo("Jammed Units Highlight: Unit Tracker API unavailable, exiting")
		widgetHandler:RemoveWidget()
		return
	end
	rebuild(tracker.visibleUnits)
end

function widget:Shutdown()
	hideAll(drawTime())
end
