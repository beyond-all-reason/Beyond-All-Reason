local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name = "Set unit type target",
		desc = "Hold down Alt and set target on an enemy unit to make selected units set target on all future enemies of that type",
		author = "Flameink",
		date = "August 1, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer = -1, -- won't work at layer 0 for unknown reasons
		enabled = true,
	}
end

-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetClosestEnemyUnit = Spring.GetClosestEnemyUnit
local spAreTeamsAllied = Spring.AreTeamsAllied
local spGetUnitTeam = Spring.GetUnitTeam
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetSelectedUnits = Spring.GetSelectedUnits
local spGetTimer = Spring.GetTimer
local spDiffTimers = Spring.DiffTimers
local spGetMyTeamID = Spring.GetLocalTeamID
local spGetActiveCommand = Spring.GetActiveCommand
local spGetMouseState = Spring.GetMouseState
local spTraceScreenRay = Spring.TraceScreenRay
local spGetModKeyState = Spring.GetModKeyState
local spGetUnitRulesParam = Spring.GetUnitRulesParam
local spGetUnitRadius = Spring.GetUnitRadius
local spGetGroundHeight = Spring.GetGroundHeight
local spValidUnitID = Spring.ValidUnitID
local ENEMY_UNITS = Spring.ENEMY_UNITS

local table_insert = table.insert
local math_sin = math.sin
local math_cos = math.cos
local math_pi = math.pi
local math_floor = math.floor
local math_clamp = math.clamp

local trackedUnitsToTargetedDefs = {}
local trackedUnitsToTargetID = {}
local unitRanges = {}
local cursorPos -- current cursor position 	    (table{x,y,z})
local snappedPos -- snapped valid target position (table{x,y,z})
local snappedUnitID -- unit the command would snap to (highlighted as "selected")
local resumeKey -- Last position in the unit list
local MAX_UNITS_PER_UPDATE = 100
local MIN_UNITS_PER_UPDATE = 1
local unitsToUpdate = MAX_UNITS_PER_UPDATE
local TARGET_MS = 2 -- time budget for the widget
local avgPerUnitMsCost = 0 -- smoothed cost of processing one tracked unit
local COST_BLEND_RATIO = 0.2 -- smaller number = more smoothing
local POLLING_RATE = 5
local CMD_STOP = CMD.STOP
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET
-- Set target on units that aren't in range yet but may come in range soon
local UNIT_RANGE_MULTIPLIER = 1.5
-- Radius in elmos to search for nearby enemy units when click misses
local SNAP_RADIUS = 100
-- Number of targets that can be assigned. Used to set up the table pools.
local TARGET_BY_TYPE_COUNT_MAX = 128

local gameStarted

for udid, ud in pairs(UnitDefs) do
	local maxRange = 0

	for ii, weapon in ipairs(ud.weapons) do
		if weapon.weaponDef then
			local weaponDef = WeaponDefs[weapon.weaponDef]
			if weaponDef then
				if weaponDef.range > maxRange then
					maxRange = weaponDef.range
				end
			end
		end
	end

	unitRanges[udid] = maxRange
end

local function GetUnitsInAttackRangeWithDef(unitID, unitDefIDsToTarget)
	local unitsInRange = {}

	local unitTeam = spGetUnitTeam(unitID)
	if unitTeam == nil then
		return unitsInRange
	end

	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then
		return unitsInRange
	end

	local maxRange = unitRanges[spGetUnitDefID(unitID)]
	if maxRange == nil or maxRange <= 0 then
		return unitsInRange
	end
	maxRange = maxRange * UNIT_RANGE_MULTIPLIER

	local candidateUnits = spGetUnitsInCylinder(ux, uz, maxRange, ENEMY_UNITS)
	local count = 0
	for index = 1, #candidateUnits do
		local targetID = candidateUnits[index]
		local targetTeam = spGetUnitTeam(targetID)
		if targetID ~= unitID and targetTeam and not spAreTeamsAllied(unitTeam, targetTeam) then
			if unitDefIDsToTarget[spGetUnitDefID(targetID)] then
				count = count + 1
				unitsInRange[count] = targetID
			end
		end
	end

	return unitsInRange
end

local function distance(point1, point2)
	if not point1 or not point2 then
		return -1
	end

	return math.diag(point1[1] - point2[1], point1[2] - point2[2], point1[3] - point2[3])
end

local function clear()
	cursorPos = nil
	snappedPos = nil
	snappedUnitID = nil
end

local function MakeLine(x1, y1, z1, x2, y2, z2)
	gl.Vertex(x1, y1, z1)
	gl.Vertex(x2, y2, z2)
end

local SELECTION_RING_SEGMENTS = 48

-- Emit a ring of vertices around (cx, cz) that hugs the terrain.
local function MakeGroundRing(cx, cz, radius)
	for i = 0, SELECTION_RING_SEGMENTS do
		local a = (i / SELECTION_RING_SEGMENTS) * math_pi * 2
		local px = cx + math_sin(a) * radius
		local pz = cz + math_cos(a) * radius
		gl.Vertex(px, spGetGroundHeight(px, pz) + 4, pz)
	end
end

-- Emit a filled disc (triangle fan) around (cx, cz) that hugs the terrain.
local function MakeGroundDisc(cx, cz, radius)
	gl.Vertex(cx, spGetGroundHeight(cx, cz) + 4, cz)
	for i = 0, SELECTION_RING_SEGMENTS do
		local a = (i / SELECTION_RING_SEGMENTS) * math_pi * 2
		local px = cx + math_sin(a) * radius
		local pz = cz + math_cos(a) * radius
		gl.Vertex(px, spGetGroundHeight(px, pz) + 4, pz)
	end
end

local function FindNearestEnemyUnit(x, y, z, radius, myTeam)
	if spGetClosestEnemyUnit then
		return spGetClosestEnemyUnit(x, y, z, radius)
	end

	local candidateUnits = spGetUnitsInCylinder(x, z, radius)

	local closestUnit = nil
	local closestDistance = math.huge

	for _, candidateID in ipairs(candidateUnits) do
		local targetTeam = spGetUnitTeam(candidateID)

		if targetTeam and not spAreTeamsAllied(myTeam, targetTeam) then
			local ux, uy, uz = spGetUnitPosition(candidateID)
			if ux then
				local distSq = distance({ x, y, z }, { ux, uy, uz })

				if distSq < closestDistance then
					closestUnit = candidateID
					closestDistance = distSq
				end
			end
		end
	end

	return closestUnit
end

local commandsToGivePool = table.new(TARGET_BY_TYPE_COUNT_MAX, 0)
local nextCmdOpts = { "shift" }
do
	for i = 1, TARGET_BY_TYPE_COUNT_MAX do
		commandsToGivePool[i] = { CMD_SET_TARGET, -1, nextCmdOpts }
	end
end
local function targetUnitsInRangeWithDef(unitID, targetUnitDefIDTable)
	local candidateUnits = GetUnitsInAttackRangeWithDef(unitID, targetUnitDefIDTable)

	-- Always keep the originally-targeted unit on the list, even when it is out of
	-- range. This is less confusing for the player.
	if trackedUnitsToTargetID[unitID] then
		if spGetUnitDefID(trackedUnitsToTargetID[unitID]) then
			table_insert(candidateUnits, 1, trackedUnitsToTargetID[unitID])
		else
			trackedUnitsToTargetID[unitID] = nil
		end
	end

	if candidateUnits[1] then
		local unitTargetID = spGetUnitRulesParam(unitID, "unitTargetID")
		local commandTarget = { CMD_SET_TARGET, unitTargetID }
		local commandsToGive = table.new(TARGET_BY_TYPE_COUNT_MAX + 1, 0)
		commandsToGive[1] = { CMD_SET_TARGET, candidateUnits[1] }
		local candidateCount = #candidateUnits
		for index = 2, candidateCount do
			if candidateUnits[index] == unitTargetID then
				-- Keep the active target at the front of the target list to avoid target flap.
				commandsToGive[1][3] = nextCmdOpts -- First command gains shift modifier.
				table_insert(commandsToGive, 1, commandTarget)
			elseif index <= TARGET_BY_TYPE_COUNT_MAX then
				local commandTable = commandsToGivePool[index]
				commandTable[2] = candidateUnits[index]
				commandsToGive[index] = commandTable
			end
		end
		-- We can use a nil boundary to stop iter in ParseCommandTable because we are careful
		-- not to introduce a new hash part. luaH_next jumps to the hash following the array.
		if candidateCount < TARGET_BY_TYPE_COUNT_MAX then
			commandsToGive[candidateCount + 1] = nil
		end
		spGiveOrderArrayToUnit(unitID, commandsToGive)
	else -- TODO: only give order if unit has a target list:
		spGiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET)
	end
end

function widget:DrawWorld()
	if not cursorPos or not snappedPos then
		return
	end
	gl.DepthTest(false)

	-- Highlight the unit that would be snapped to, so it reads as "selected".
	if snappedUnitID and spValidUnitID(snappedUnitID) then
		local ux, _, uz = spGetUnitPosition(snappedUnitID)
		if ux then
			local radius = (spGetUnitRadius(snappedUnitID) or 32) * 1.15
			gl.Color(1, 1, 0.3, 0.13)
			gl.BeginEnd(GL.TRIANGLE_FAN, MakeGroundDisc, ux, uz, radius)
			gl.LineWidth(2)
			gl.Color(1, 1, 0.3, 0.7)
			gl.BeginEnd(GL.LINE_LOOP, MakeGroundRing, ux, uz, radius)
		end
	end

	gl.LineWidth(2)
	gl.Color(1, 1, 0.3, 0.45)
	gl.BeginEnd(
		GL.LINE_STRIP,
		MakeLine,
		cursorPos.x,
		cursorPos.y,
		cursorPos.z,
		snappedPos.x,
		snappedPos.y,
		snappedPos.z
	)
	gl.LineWidth(1)
	gl.DepthTest(true)
end

local function handleSelectionLine()
	local _, cmdID = spGetActiveCommand()
	local alt, ctrl, meta, shift = spGetModKeyState()
	local correctCommand = cmdID == CMD_SET_TARGET and alt and not ctrl and not meta
	if not correctCommand then
		clear()
		return
	end

	local mx, my = spGetMouseState()
	local _, worldPos = spTraceScreenRay(mx, my, true)
	if not worldPos then
		clear()
		return
	end

	if worldPos and worldPos[1] then
		local myTeam = spGetMyTeamID()
		local targetID = FindNearestEnemyUnit(worldPos[1], worldPos[2], worldPos[3], SNAP_RADIUS, myTeam)
		if targetID then
			local ux, uy, uz = spGetUnitPosition(targetID)
			-- Enable the line
			snappedPos = { x = ux, y = uy, z = uz }
			cursorPos = { x = worldPos[1], y = worldPos[2], z = worldPos[3] }
			snappedUnitID = targetID
		else
			clear()
			return
		end
	end
end

function widget:GameFrame(frame)
	handleSelectionLine()

	if frame % POLLING_RATE ~= 0 then
		return
	end

	if resumeKey ~= nil and trackedUnitsToTargetedDefs[resumeKey] == nil then
		-- Our resume key is invalid now
		resumeKey = nil
	end

	local tLoop = spGetTimer()
	local processed = 0
	local unitID, targetUnitDefIDTable = next(trackedUnitsToTargetedDefs, resumeKey)
	while unitID ~= nil and processed < math_floor(unitsToUpdate) do
		targetUnitsInRangeWithDef(unitID, targetUnitDefIDTable)
		processed = processed + 1
		resumeKey = unitID
		unitID, targetUnitDefIDTable = next(trackedUnitsToTargetedDefs, unitID)
	end

	-- Reached the end of the table; wrap around on the next update.
	if unitID == nil then
		resumeKey = nil
	end

	-- Keep this loop near TARGET_MS by scaling the budget.
	local loopMs = spDiffTimers(spGetTimer(), tLoop) * 1000
	if processed > 0 and loopMs > 0 then
		local currentPerUnitCost = loopMs / processed
		-- Smooth the average cost, since some batches can take longer than others
		avgPerUnitMsCost = (avgPerUnitMsCost * (1.0 - COST_BLEND_RATIO) + currentPerUnitCost * COST_BLEND_RATIO)
		unitsToUpdate = math_clamp(TARGET_MS / avgPerUnitMsCost, MIN_UNITS_PER_UPDATE, MAX_UNITS_PER_UPDATE)
	end
end

local function cleanupUnitTargeting(unitID)
	trackedUnitsToTargetedDefs[unitID] = nil
	trackedUnitsToTargetID[unitID] = nil
end

function widget:CommandNotify(cmdID, cmdParams, cmdOpts)
	local shouldCleanupTargeting = false
	local selectedUnits = spGetSelectedUnits()
	local targetID = nil

	if cmdID == CMD_UNIT_CANCEL_TARGET or cmdID == CMD_STOP then
		shouldCleanupTargeting = true
	end

	if cmdID == CMD_SET_TARGET and not cmdOpts.alt then
		shouldCleanupTargeting = true
	end

	if cmdID == CMD_SET_TARGET and #cmdParams ~= 1 and #cmdParams ~= 4 then
		shouldCleanupTargeting = true
	end

	if #cmdParams == 4 and not shouldCleanupTargeting then
		local mx, my = spGetMouseState()
		local _, worldPos = spTraceScreenRay(mx, my, true)

		if worldPos and worldPos[1] then
			local myTeam = spGetMyTeamID()
			targetID = FindNearestEnemyUnit(worldPos[1], worldPos[2], worldPos[3], SNAP_RADIUS, myTeam)
			-- If there's no enemy to snap the command to, clean up the targeting
			if targetID == nil then
				shouldCleanupTargeting = true
			end
		end
	end

	if shouldCleanupTargeting then
		for _, unitID in ipairs(selectedUnits) do
			cleanupUnitTargeting(unitID)
		end
	end

	if cmdID ~= CMD_SET_TARGET or not cmdOpts.alt or (#cmdParams ~= 1 and #cmdParams ~= 4) then
		return
	end

	if #cmdParams == 1 then
		targetID = cmdParams[1]
	end

	if not targetID then
		return
	end

	local targetUnitDefID = spGetUnitDefID(targetID)

	-- Unit might have died between finding it and this call
	if not targetUnitDefID then
		return
	end

	for _, unitID in ipairs(selectedUnits) do
		local newTargetedDefs = {}
		if cmdOpts.shift and trackedUnitsToTargetedDefs[unitID] then
			newTargetedDefs = trackedUnitsToTargetedDefs[unitID]
		end
		cleanupUnitTargeting(unitID)
		newTargetedDefs[targetUnitDefID] = true
		trackedUnitsToTargetedDefs[unitID] = newTargetedDefs

		trackedUnitsToTargetID[unitID] = targetID

		spGiveOrderToUnit(unitID, CMD_UNIT_CANCEL_TARGET)
		if #selectedUnits < MAX_UNITS_PER_UPDATE then
			targetUnitsInRangeWithDef(unitID, newTargetedDefs)
		end
	end

	return true
end

function maybeRemoveSelf()
	if Spring.GetSpectatingState() and (spGetGameFrame() > 0 or gameStarted) then
		widgetHandler:RemoveWidget()
	end
end

function widget:GameStart()
	gameStarted = true
	maybeRemoveSelf()
end

function widget:PlayerChanged(playerID)
	maybeRemoveSelf()
end

function widget:Initialize()
	if Spring.IsReplay() or spGetGameFrame() > 0 then
		maybeRemoveSelf()
	end
end

function widget:UnitDestroyed(unitID, unitDefID, unitTeam)
	cleanupUnitTargeting(unitID)
end
