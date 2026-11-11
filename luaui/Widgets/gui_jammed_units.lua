local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Jammed Units Highlight",
		desc = "Faint red tint and outline on allied units standing in allied radar jammer coverage (hidden from enemy radar)",
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
-- Only units a jammer can reach get checked: a coarse grid holds where each allyteam's jammers reach, and every unit
-- is looked up in it once per VISIT_FRAMES game frames. Buildings in reach are checked on that visit, moving units
-- in reach once per POLL_FRAMES. A toggle or view change redoes all of it over a few draw frames. A change
-- writes a time stamp into unit buffer uniform #7 (Spring.GetDrawSeconds, which is the shaders' timeInfo.y):
-- positive = jammed since then, negative = unjammed since then, 0 = never jammed. The CUS model shaders
-- (modelmaterials_gl4/templates/cus_gl4.vert/frag.glsl, JAMMED_* tunables) fade a red tint and rim in or out
-- from that stamp, so this widget draws nothing itself and only writes on changes. Jammed units also get a red
-- outline from Outline Shader GL4 (WG.unitOutlines) while that widget runs. The highlight is shown while the
-- jammer coverage preview (Sensor Ranges Jammer Preview) draws coverage, or at all times without that widget.
-- Players see their own allyteam's units. Spectators with full view see every allyteam's units, each against
-- its own jammers; spectators following a team see that team's allyteam.
------------------------------------------------------------------------------------------------

-- Tunables
local POLL_FRAMES = 6 -- game frames between two checks of a moving unit in jammer reach (6 = 5 checks per second)
local VISIT_FRAMES = 30 -- game frames between two visits of a unit, which also checks a building in jammer reach
local CELL_SIZE = 256 -- elmos, of the grid that holds where jammers reach
local RANGE_MARGIN = 192 -- elmos on top of a jammer's range: radar cells round outwards, units move between visits
local MIN_JAMMER_RANGE = 32 -- a smaller range covers no radar cell, see unit_jammed_fix.lua
local SWEEP_FRAMES = 8 -- draw frames that a check of all units is spread over
local SWEEP_MIN_UNITS = 64 -- units such a check handles per draw frame at least
local UNIFORM_INDEX = 7 -- unit buffer uniform (userDefined[1].w) the CUS shaders read
local OUTLINE_OWNER = "jammed"
-- width and blur in pixels at 1080p, see gfx_outline_shader_gl4.lua
local OUTLINE_STYLE = { color = { 1, 0.25, 0.18, 0.2 }, width = 0.8, blur = 0.5, fadeTime = 0.3 }

local spGetUnitPosition = Spring.GetUnitPosition
local spGetPositionLosState = Spring.GetPositionLosState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitTeam = Spring.GetUnitTeam
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetDrawSeconds = Spring.GetDrawSeconds
local glSetUnitBufferUniforms = gl.SetUnitBufferUniforms
local mathAbs = math.abs
local mathCeil = math.ceil
local mathFloor = math.floor
local mathMax = math.max
local mathMin = math.min
local mathSqrt = math.sqrt

local isBuildingDef = table.new(#UnitDefs, 0) ---@type table<UnitDefID, true?> never move, and see unit_jammed_fix.lua
local jammerDefReach = {} ---@type table<UnitDefID, number?> how far from this jammer a unit counts as in reach
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile then
		isBuildingDef[unitDefID] = true
	end
	if unitDef.radarDistanceJam >= MIN_JAMMER_RANGE then
		-- a jammer's mark in the grid can be two walks over the units old
		local moved = unitDef.speed * 2 * VISIT_FRAMES / Game.gameSpeed
		jammerDefReach[unitDefID] = unitDef.radarDistanceJam + RANGE_MARGIN + moved
	end
end

local cellsX = mathCeil(Game.mapSizeX / CELL_SIZE) + 1 -- the spare column keeps units just off the map out of other rows
local cellsZ = mathCeil(Game.mapSizeZ / CELL_SIZE) + 1
local cellsPerAllyTeam = cellsX * cellsZ

local gaiaTeamID = Spring.GetGaiaTeamID()
local myAllyTeamID = Spring.GetMyAllyTeamID()
local fullview = false

local trackedUnits = {} ---@type table<integer, integer?> index -> unitID, checked in turn
local trackedIndex = {} ---@type table<integer, integer?> unitID -> index in trackedUnits
local trackedCount = 0
local unitAllyTeam = {} ---@type table<integer, integer?> unitID -> allyteam whose jammers can hide it
local fixedX = {} ---@type table<integer, number?> unitID -> position of a building
local fixedZ = {} ---@type table<integer, number?>
local jammerReach = {} ---@type table<integer, number?> unitID -> reach, for jammers
local nearUnits = {} ---@type table<integer, integer?> index -> unitID of moving units in jammer reach, checked in turn
local nearIndex = {} ---@type table<integer, integer?> unitID -> index in nearUnits
local nearCount = 0
local jammed = {} ---@type table<integer, boolean?> unitID -> highlighted right now
local cursor = 1 -- next trackedUnits index to visit
local nearCursor = 1 -- next nearUnits index to check
local visitBudget = 0 -- visits owed, in units * frames: every unit gets one per VISIT_FRAMES frames
local pollBudget = 0 -- checks owed, in units * frames: every unit in nearUnits gets one per POLL_FRAMES frames
local nearCells = {} ---@type table<number, number?> allyteam and cell -> generation that a jammer last reached it
local generation = 1 -- one per walk over the units; marks last two walks, as a unit can come before its jammer
local sweepLeft = 0 -- units left to check after a toggle or view change, works while paused too
local sweepStep = 0 -- of those, how many per draw frame

local shown = false -- whether the highlights are written at the moment
local outlineApi = nil -- WG.unitOutlines when last seen, to outline the jammed units again when it (re)loads

local uniformCache = { 0 }

-- the shaders' clock (timeInfo.y); never 0, which the shaders read as "never jammed"
local function drawTime()
	return mathMax(spGetDrawSeconds(), 0.001)
end

local function setStamp(unitID, stamp)
	uniformCache[1] = stamp
	glSetUnitBufferUniforms(unitID, uniformCache, UNIFORM_INDEX)
end

local function setOutline(unitID, on)
	local outlines = WG.unitOutlines ---@type table?
	if outlines then
		if on then
			outlines.add(OUTLINE_OWNER, unitID, OUTLINE_STYLE)
		else
			outlines.remove(OUTLINE_OWNER, unitID)
		end
	end
end

-- Also reaches units this viewer can no longer see (after a spectator view switch), which would stay red otherwise.
-- Unit getters return nil for those, so only a known dead unit is skipped; the write raises an error for a unit that
-- no longer exists.
local function writeStamp(unitID, stamp)
	if spGetUnitIsDead(unitID) ~= true then
		pcall(setStamp, unitID, stamp)
	end
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

local function isJammed(unitID, x, z)
	-- a full view spectator has to name the allyteam, a player may only read their own
	local allyTeam = nil
	if fullview then
		allyTeam = unitAllyTeam[unitID]
	end
	-- the jammer map has no height
	local _, _, _, inJammer = spGetPositionLosState(x, 0, z, allyTeam)
	if inJammer == true then
		return true
	end
	return fixedX[unitID] ~= nil and spGetUnitRulesParam(unitID, "jammed") == 1
end

local function checkUnit(unitID, now, x, z)
	local was = jammed[unitID] == true
	local is = shown and x ~= nil and isJammed(unitID, x, z)
	if is ~= was then
		jammed[unitID] = is or nil
		writeStamp(unitID, is and now or -now)
		setOutline(unitID, is)
	end
end

local function setNear(unitID, near)
	local index = nearIndex[unitID]
	if near == (index ~= nil) then
		return
	end
	if near then
		nearCount = nearCount + 1
		nearUnits[nearCount] = unitID
		nearIndex[unitID] = nearCount
	else
		local last = nearUnits[nearCount]
		nearUnits[index] = last
		nearIndex[last] = index
		nearUnits[nearCount] = nil
		nearCount = nearCount - 1
		nearIndex[unitID] = nil
	end
end

local function markJammer(allyTeam, x, z, reach)
	local first = allyTeam * cellsPerAllyTeam
	local lastZ = mathMin(mathFloor((z + reach) / CELL_SIZE), cellsZ - 1)
	for cellZ = mathMax(mathFloor((z - reach) / CELL_SIZE), 0), lastZ do
		local rowDistance = mathMax(mathAbs(z - (cellZ + 0.5) * CELL_SIZE) - CELL_SIZE * 0.5, 0)
		local halfWidth = mathSqrt(mathMax(reach * reach - rowDistance * rowDistance, 0))
		local row = first + cellZ * cellsX
		local lastX = mathMin(mathFloor((x + halfWidth) / CELL_SIZE), cellsX - 1)
		for cellX = mathMax(mathFloor((x - halfWidth) / CELL_SIZE), 0), lastX do
			nearCells[row + cellX] = generation
		end
	end
end

-- two generations on, so that marks from before the highlight was hidden no longer count
local function markAllJammers()
	generation = generation + 2
	for unitID, reach in pairs(jammerReach) do
		local x, _, z = spGetUnitPosition(unitID)
		if x then
			markJammer(unitAllyTeam[unitID], x, z, reach)
		end
	end
end

local function inJammerReach(allyTeam, x, z)
	local cellX, cellZ = (x - x % CELL_SIZE) / CELL_SIZE, (z - z % CELL_SIZE) / CELL_SIZE
	local mark = nearCells[allyTeam * cellsPerAllyTeam + cellZ * cellsX + cellX]
	return mark ~= nil and mark >= generation - 1
end

local function visitUnit(unitID, now, isSweep)
	if not shown then
		if jammed[unitID] then
			checkUnit(unitID, now)
		end
		return
	end
	local x, z = fixedX[unitID], fixedZ[unitID]
	local isBuilding = x ~= nil
	if not isBuilding then
		local _
		x, _, z = spGetUnitPosition(unitID)
	end
	local near = false
	if x then
		local allyTeam = unitAllyTeam[unitID]
		local reach = jammerReach[unitID]
		if reach then
			markJammer(allyTeam, x, z, reach)
		end
		near = inJammerReach(allyTeam, x, z)
	end
	if not isBuilding then
		setNear(unitID, near)
	end
	-- a moving unit in reach waits for its turn in nearUnits, outside of a sweep
	if near and (isBuilding or isSweep) or (not near and jammed[unitID]) then
		checkUnit(unitID, now, x, z)
	end
end

local function visitNext(count, now, isSweep)
	for _ = 1, mathMin(count, trackedCount) do
		if cursor > trackedCount then
			cursor = 1
			generation = generation + 1
		end
		visitUnit(trackedUnits[cursor], now, isSweep)
		cursor = cursor + 1
	end
end

local function pollNear(count, now)
	for _ = 1, mathMin(count, nearCount) do
		if nearCursor > nearCount then
			nearCursor = 1
		end
		local unitID = nearUnits[nearCursor] ---@as UnitID
		local x, _, z = spGetUnitPosition(unitID)
		checkUnit(unitID, now, x, z)
		nearCursor = nearCursor + 1
	end
end

local function startSweep()
	if shown then
		markAllJammers()
	end
	sweepLeft = trackedCount
	sweepStep = mathMax(mathCeil(trackedCount / SWEEP_FRAMES), SWEEP_MIN_UNITS)
end

local function addUnit(unitID)
	if trackedIndex[unitID] then
		return false
	end
	local covered, allyTeam = covers(unitID)
	if not covered then
		return false
	end
	trackedCount = trackedCount + 1
	trackedUnits[trackedCount] = unitID
	trackedIndex[unitID] = trackedCount
	unitAllyTeam[unitID] = allyTeam
	local unitDefID = spGetUnitDefID(unitID)
	jammerReach[unitID] = jammerDefReach[unitDefID]
	if isBuildingDef[unitDefID] then
		local x, _, z = spGetUnitPosition(unitID)
		fixedX[unitID], fixedZ[unitID] = x, z
	end
	return true
end

-- visits at once, so that a new jammer and the units around it don't wait for their turn
local function addAndVisit(unitID)
	if addUnit(unitID) and shown then
		visitUnit(unitID, drawTime(), true)
	end
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
	fixedX[unitID], fixedZ[unitID] = nil, nil
	jammerReach[unitID] = nil
	setNear(unitID, false)
	if jammed[unitID] then
		jammed[unitID] = nil
		writeStamp(unitID, -now)
		setOutline(unitID, false)
	end
end

local function hideAll(now)
	for unitID in pairs(jammed) do
		writeStamp(unitID, -now)
		setOutline(unitID, false)
	end
	jammed = {}
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
		startSweep()
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
		addAndVisit(unitID)
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
	local outlines = WG.unitOutlines ---@type table?
	if outlines ~= outlineApi then
		outlineApi = outlines
		for unitID in pairs(jammed) do
			setOutline(unitID, true)
		end
	end
	local show = coverageShown()
	if show ~= shown then
		shown = show
		startSweep()
	end
	if sweepLeft > 0 then
		local count = mathMin(sweepLeft, sweepStep)
		sweepLeft = sweepLeft - count
		visitNext(count, drawTime(), true)
	end
end

function widget:GameFrame()
	if not shown or trackedCount == 0 or sweepLeft > 0 then
		return
	end
	local now = drawTime()
	visitBudget = visitBudget + trackedCount
	local visits = mathFloor(visitBudget / VISIT_FRAMES)
	visitBudget = visitBudget - visits * VISIT_FRAMES
	visitNext(visits, now, false)
	pollBudget = pollBudget + nearCount
	local polls = mathFloor(pollBudget / POLL_FRAMES)
	pollBudget = pollBudget - polls * POLL_FRAMES
	pollNear(polls, now)
end

function widget:VisibleUnitAdded(unitID)
	addAndVisit(unitID)
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

-- called for every player's change, only the viewer's full view and allyteam matter here
function widget:PlayerChanged()
	local wasFullview, wasAllyTeam = fullview, myAllyTeamID
	refreshViewer()
	if fullview == wasFullview and (fullview or myAllyTeamID == wasAllyTeam) then
		return
	end
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
