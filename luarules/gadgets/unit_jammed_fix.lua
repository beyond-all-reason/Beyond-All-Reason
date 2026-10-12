local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Snap Jam",
		desc = "Jam buildings at the exact edge of jammers always. And welcome to the slam",
		author = "efrec",
		date = "2026-10",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

-- A building with an even footprint size placed with snapping fits exactly on a cell's edge.
-- This collects those buildings and applies and removes literal edge-case jamming onto them.
-- Jammer and radar emitters aren't perfect circles, either. We have to build discs for them.
-- Mobile jammers move their disc each time they enter a new cell, as the engine's disc does.

local BUILDINGS_PER_FRAME = 32 -- budgeted updates
local BACKSTOP_INTERVAL = 5 * Game.gameSpeed -- for capturing jammer changes that have no callin
local WATCHED_DURATION = 2 * Game.gameSpeed -- minimum frames a jammer is checked after a callin

local math_abs = math.abs
local math_floor = math.floor
local math_min = math.min

local spGetAllUnits = Spring.GetAllUnits
local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsActive = Spring.GetUnitIsActive
local spGetUnitIsStunned = Spring.GetUnitIsStunned
local spGetUnitIsUpkeepPaid = Spring.GetUnitIsUpkeepPaid
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitSensorRadius = Spring.GetUnitSensorRadius
local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
local spGetTeamAllyTeamID = Spring.GetTeamAllyTeamID
local spSetUnitRulesParam = Spring.SetUnitRulesParam

local modrules = VFS.LoadFile("gamedata/modrules.lua") ---@as string
local radarMipLevel = tonumber(modrules:match("radarMipLevel%s*=%s*(%d+)")) ---@as integer
local radarCellSize = Game.squareSize * 2 ^ radarMipLevel
local sensorsRequireUpkeep = Game.sensorsRequireUpkeep == true
local CMD_ONOFF = CMD.ONOFF

local setUnitAttribute ---@type function

local allyTeamList = Spring.GetAllyTeamList()
local ruleAccess = { allied = true }
local ATTRIBUTE_SOURCE = "jammer_edge"

-- Setup -----------------------------------------------------------------------

local buildingDefs = {} ---@type table<UnitDefID, true?> on the build grid, so can sit on a cell line
local jammerDefs = {} ---@type table<UnitDefID, boolean?> `true` for mobile jammers
local watchedFrames = {} ---@type table<UnitDefID, number?> jammers only
for unitDefID, unitDef in ipairs(UnitDefs) do
	if unitDef.isImmobile then
		buildingDefs[unitDefID] = true
	end
	-- Jammers under one cell in radius, like claws and maws, have no coverage at all.
	if unitDef.radarDistanceJam >= radarCellSize then
		jammerDefs[unitDefID] = not unitDef.isImmobile
		local deactivateFrames = (tonumber(unitDef.customParams.deactivate_time) or 8) * Game.gameSpeed
		watchedFrames[unitDefID] = math.max(WATCHED_DURATION, deactivateFrames + Game.gameSpeed)
	end
end

local jammerCells = {} ---@type table<AllyTeamID, table<UnitID, number?>> when powered
local jammerAllyTeams = {} ---@type table<UnitID, AllyTeamID?>
local jammerCellX = {} ---@type table<UnitID, number> radar cell of the jammer's mid position
local jammerCellZ = {} ---@type table<UnitID, number>
local mobileJammers = {} ---@type table<UnitID, true?>
local jamming = {} ---@type table<UnitID, true?> jammers that are on
local edgeBands = {} ---@type table<UnitID, table<UnitID, true?>>
local bandCounts = {} ---@type table<UnitID, number?> bands a building sits in
local edgeJammed = {} ---@type table<UnitID, true?>

for _, allyTeamID in ipairs(allyTeamList) do
	jammerCells[allyTeamID] = {}
end

-- Jammers are checked on each event and on backstop turns, with a limit on checks per frame.
local watchedUntil = {} ---@type table<UnitID, integer?>
local jammerTurns = {} ---@type table<number, table<UnitID, true?>>
for turn = 0, BACKSTOP_INTERVAL - 1 do
	jammerTurns[turn] = {}
end

local checkQueue = {} ---@type UnitID[] buildings only
local checkQueueHead, checkQueueTail = 1, 0
local queuedAt = {} ---@type table<UnitID, integer?> scheduling to queue a unit once per drain
local queueGeneration = 1

-- Local code ------------------------------------------------------------------

local discWidths = {} ---@type table<number, integer[]?> jamming isn't a perfect circle, uses discs

local function setRowWidth(widths, row, width)
	if (widths[row] or -1) < width then
		widths[row] = width
	end
end

---See `MidpointCircleAlgoPerLine` in LosMap.cpp.
local function getDiscWidths(radius)
	local widths = {}
	local x, y, value = radius, 0, 1 - radius
	while x >= y do
		setRowWidth(widths, y, x)
		if value <= 0 then
			y = y + 1
			value = value + 2 * y + 1
		else
			if x ~= y then
				setRowWidth(widths, x, y)
			end
			y = y + 1
			x = x - 1
			value = value + 2 * (y - x) + 1
		end
	end
	discWidths[radius] = widths
	return widths
end

local function isJammerCell(cellCount, cellX, cellZ)
	return cellZ <= cellCount and cellX <= (discWidths[cellCount] or getDiscWidths(cellCount))[cellZ]
end

---@return number cellX, number cellZ, boolean onLineX, boolean onLineZ
local function getUnitCell(unitID)
	local x, _, z = spGetUnitPosition(unitID)
	---@cast x number
	---@cast z number
	return math_floor(x / radarCellSize), math_floor(z / radarCellSize), x % radarCellSize == 0, z % radarCellSize == 0
end

local function isEdgeJammed(jammerID, cellCount, unitCellX, unitCellZ, onLineX, onLineZ)
	if cellCount <= 0 then
		return false -- a zero-cell jammer jams nothing, not even its own cell
	end
	local cellX = unitCellX - jammerCellX[jammerID]
	local cellZ = unitCellZ - jammerCellZ[jammerID]
	if isJammerCell(cellCount, math_abs(cellX), math_abs(cellZ)) then
		return false -- jammed by the engine already
	end
	-- The rule: "A building placed exactly on a cell line belongs to the cells on both sides of it."
	return (onLineX and isJammerCell(cellCount, math_abs(cellX - 1), math_abs(cellZ)))
		or (onLineZ and isJammerCell(cellCount, math_abs(cellX), math_abs(cellZ - 1)))
		or (onLineX and onLineZ and isJammerCell(cellCount, math_abs(cellX - 1), math_abs(cellZ - 1)))
end

local function getJammerCells(jammerID)
	local radius = spGetUnitSensorRadius(jammerID, "radarJammer") ---@as number
	return math_floor(radius / radarCellSize)
end

local function isJamming(jammerID)
	return spGetUnitIsActive(jammerID)
		and not spGetUnitIsStunned(jammerID)
		and (not sensorsRequireUpkeep or spGetUnitIsUpkeepPaid(jammerID))
end

local function queueBuildingCheck(unitID)
	if queuedAt[unitID] ~= queueGeneration then
		queuedAt[unitID] = queueGeneration
		checkQueueTail = checkQueueTail + 1
		checkQueue[checkQueueTail] = unitID
	end
end

local function updateEdgeJammed(unitID)
	local cellX, cellZ, onLineX, onLineZ = getUnitCell(unitID)
	local jammed ---@type true?
	for jammerID, cells in pairs(jammerCells[spGetUnitAllyTeam(unitID)]) do
		if jamming[jammerID] and isEdgeJammed(jammerID, cells, cellX, cellZ, onLineX, onLineZ) then
			jammed = true
			break
		end
	end
	if edgeJammed[unitID] ~= jammed then
		edgeJammed[unitID] = jammed
		setUnitAttribute(unitID, "stealth", jammed, ATTRIBUTE_SOURCE) -- using stealth-as-jammed
		spSetUnitRulesParam(unitID, "jammed", jammed and 1 or 0, ruleAccess)
	end
end

local function drainQueue()
	local last = math_min(checkQueueTail, checkQueueHead + BUILDINGS_PER_FRAME - 1)
	for index = checkQueueHead, last do
		local unitID = checkQueue[index] ---@as UnitID
		checkQueue[index] = nil
		if edgeJammed[unitID] ~= nil or buildingDefs[spGetUnitDefID(unitID) or 0] then
			updateEdgeJammed(unitID)
		end
	end
	checkQueueHead = last + 1
	if checkQueueHead > checkQueueTail then
		checkQueueHead, checkQueueTail = 1, 0
		queueGeneration = queueGeneration + 1
	end
end

local function addToEdgeBand(jammerID, unitID)
	edgeBands[jammerID][unitID] = true
	bandCounts[unitID] = (bandCounts[unitID] or 0) + 1
end

local function removeFromEdgeBand(jammerID, unitID)
	edgeBands[jammerID][unitID] = nil
	local count = bandCounts[unitID] ---@as number
	count = count - 1
	bandCounts[unitID] = count > 0 and count or nil
end

local function clearEdgeBand(jammerID)
	for unitID in pairs(edgeBands[jammerID]) do
		removeFromEdgeBand(jammerID, unitID)
		queueBuildingCheck(unitID)
	end
end

local function buildEdgeBand(jammerID)
	local allyTeamID = jammerAllyTeams[jammerID]
	local cells = jammerCells[allyTeamID][jammerID] ---@as number
	local x = (jammerCellX[jammerID] + 0.5) * radarCellSize
	local z = (jammerCellZ[jammerID] + 0.5) * radarCellSize
	local cover = (cells + 2) * radarCellSize -- extra cells for the mipping and the line rule
	for _, unitID in ipairs(spGetUnitsInRectangle(x - cover, z - cover, x + cover, z + cover)) do
		if buildingDefs[spGetUnitDefID(unitID)] and spGetUnitAllyTeam(unitID) == allyTeamID then
			local cellX, cellZ, onLineX, onLineZ = getUnitCell(unitID)
			if isEdgeJammed(jammerID, cells, cellX, cellZ, onLineX, onLineZ) then
				addToEdgeBand(jammerID, unitID)
				queueBuildingCheck(unitID)
			end
		end
	end
end

---@return number cellX, number cellZ
local function getJammerCell(jammerID)
	local _, _, _, x, _, z = spGetUnitPosition(jammerID, true)
	---@cast x number
	---@cast z number
	return math_floor(x / radarCellSize), math_floor(z / radarCellSize)
end

local function addJammer(jammerID, isMobile)
	local allyTeamID = spGetUnitAllyTeam(jammerID) --[[@as AllyTeamID]]
	jammerAllyTeams[jammerID] = allyTeamID
	jammerCellX[jammerID], jammerCellZ[jammerID] = getJammerCell(jammerID)
	mobileJammers[jammerID] = isMobile or nil
	jammerTurns[jammerID % BACKSTOP_INTERVAL][jammerID] = true
	jammerCells[allyTeamID][jammerID] = getJammerCells(jammerID)
	jamming[jammerID] = isJamming(jammerID) or nil
	edgeBands[jammerID] = {}
	buildEdgeBand(jammerID)
end

local function removeJammer(jammerID)
	jamming[jammerID] = nil
	clearEdgeBand(jammerID)
	jammerCells[jammerAllyTeams[jammerID]][jammerID] = nil
	jammerAllyTeams[jammerID], jammerCellX[jammerID], jammerCellZ[jammerID] = nil, nil, nil
	mobileJammers[jammerID] = nil
	jammerTurns[jammerID % BACKSTOP_INTERVAL][jammerID] = nil
	watchedUntil[jammerID] = nil
	edgeBands[jammerID] = nil
end

---A mobile jammer moves its band along only while it is on; it catches up when switched on.
local function moveJammer(jammerID)
	local cellX, cellZ = getJammerCell(jammerID)
	if cellX ~= jammerCellX[jammerID] or cellZ ~= jammerCellZ[jammerID] then
		clearEdgeBand(jammerID)
		jammerCellX[jammerID], jammerCellZ[jammerID] = cellX, cellZ
		buildEdgeBand(jammerID)
	end
end

local function updateJammerState(jammerID)
	local isOn = isJamming(jammerID) or nil
	if isOn == jamming[jammerID] then
		return false
	end
	jamming[jammerID] = isOn
	if isOn and mobileJammers[jammerID] then
		moveJammer(jammerID)
	end
	for unitID in pairs(edgeBands[jammerID]) do
		queueBuildingCheck(unitID)
	end
	return true
end

local function updateJammerRadius(jammerID)
	local cells = getJammerCells(jammerID)
	local allyTeamID = jammerAllyTeams[jammerID]
	if cells ~= jammerCells[allyTeamID][jammerID] then
		clearEdgeBand(jammerID)
		jammerCells[allyTeamID][jammerID] = cells
		buildEdgeBand(jammerID)
	end
end

local function watchJammer(jammerID, unitDefID)
	if jammerAllyTeams[jammerID] then
		watchedUntil[jammerID] = spGetGameFrame() + watchedFrames[unitDefID] ---@as number
	end
end

local function updateWatchedJammers(frame)
	for jammerID, lastFrame in pairs(watchedUntil) do
		if updateJammerState(jammerID) then
			watchedUntil[jammerID] = frame + WATCHED_DURATION
		elseif frame >= lastFrame then
			watchedUntil[jammerID] = nil
		end
	end
end

local function addBuilding(unitID, allyTeamID)
	local cellX, cellZ, onLineX, onLineZ = getUnitCell(unitID)
	for jammerID, cells in pairs(jammerCells[allyTeamID]) do
		if isEdgeJammed(jammerID, cells, cellX, cellZ, onLineX, onLineZ) then
			addToEdgeBand(jammerID, unitID)
		end
	end
	updateEdgeJammed(unitID)
end

---Keeps `edgeJammed`, so a building that is re-added after a transfer can be cleared.
local function removeBuilding(unitID, allyTeamID)
	if bandCounts[unitID] then
		for jammerID in pairs(jammerCells[allyTeamID]) do
			if edgeBands[jammerID][unitID] then
				removeFromEdgeBand(jammerID, unitID)
			end
		end
	end
	queuedAt[unitID] = nil
end

local function addUnit(unitID, unitDefID)
	local isMobileJammer = jammerDefs[unitDefID]
	if isMobileJammer ~= nil then
		addJammer(unitID, isMobileJammer)
	end
	if buildingDefs[unitDefID] then
		addBuilding(unitID, spGetUnitAllyTeam(unitID))
	end
end

local function removeUnit(unitID, unitDefID, teamID)
	if jammerDefs[unitDefID] ~= nil then
		removeJammer(unitID)
	end
	if buildingDefs[unitDefID] then
		removeBuilding(unitID, spGetTeamAllyTeamID(teamID))
	end
end

-- Engine callins --------------------------------------------------------------

function gadget:GameFrame(frame)
	for jammerID in pairs(mobileJammers) do
		if jamming[jammerID] then
			moveJammer(jammerID)
		end
	end
	drainQueue()
	updateWatchedJammers(frame)
	for jammerID in pairs(jammerTurns[frame % BACKSTOP_INTERVAL]) do
		updateJammerRadius(jammerID)
		updateJammerState(jammerID)
	end
end

function gadget:UnitCreated(unitID, unitDefID)
	addUnit(unitID, unitDefID)
end

function gadget:UnitFinished(unitID, unitDefID)
	watchJammer(unitID, unitDefID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	removeUnit(unitID, unitDefID, unitTeam)
	edgeJammed[unitID] = nil
end

function gadget:UnitDamaged(unitID, unitDefID)
	watchJammer(unitID, unitDefID)
end

function gadget:UnitStunned(unitID, unitDefID, unitTeam, stunned)
	if jammerAllyTeams[unitID] then
		updateJammerState(unitID)
		watchJammer(unitID, unitDefID)
	end
end

function gadget:UnitCommand(unitID, unitDefID)
	watchJammer(unitID, unitDefID)
end

function gadget:UnitGiven(unitID, unitDefID, newTeam, oldTeam)
	removeUnit(unitID, unitDefID, oldTeam)
	addUnit(unitID, unitDefID)
end

function gadget:Initialize()
	setUnitAttribute = GG.UnitAttributes.SetUnitAttribute

	gadgetHandler:RegisterUnitCommand(CMD_ONOFF)

	for _, unitID in ipairs(spGetAllUnits()) do
		addUnit(unitID, spGetUnitDefID(unitID))
	end
end

function gadget:Shutdown()
	local hasAttributes = GG.UnitAttributes ~= nil -- unless it has shut down first
	for unitID in pairs(edgeJammed) do
		if hasAttributes then
			setUnitAttribute(unitID, "stealth", nil, ATTRIBUTE_SOURCE)
		end
		spSetUnitRulesParam(unitID, "jammed", 0, ruleAccess)
	end
end
