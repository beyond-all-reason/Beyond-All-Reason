local widget = widget ---@type Widget

function widget:GetInfo()
	return {
		name 	= "Set unit type target",
		desc 	= "Hold down Alt and set target on an enemy unit to make selected units set target on all future enemies of that type",
		author  = "Flameink",
		date	= "August 1, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer 	= -1, -- won't work at layer 0 for unknown reasons
		enabled = true
	}
end


-- Localized Spring API for performance
local spGetGameFrame = Spring.GetGameFrame

local spGetUnitDefID         = Spring.GetUnitDefID
local spGetUnitPosition      = Spring.GetUnitPosition
local spGetUnitsInCylinder   = Spring.GetUnitsInCylinder
local spAreTeamsAllied       = Spring.AreTeamsAllied
local spGetUnitTeam          = Spring.GetUnitTeam
local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
local spGetSelectedUnits     = Spring.GetSelectedUnits
local spGetMyTeamID          = Spring.GetMyTeamID
local spGetActiveCommand 	 = Spring.GetActiveCommand
local spGetMouseState    	 = Spring.GetMouseState
local spTraceScreenRay   	 = Spring.TraceScreenRay
local spGetModKeyState   	 = Spring.GetModKeyState

local trackedUnitsToUnitDefID = {}
local unitRanges = {}
local cursorPos  -- current cursor position 	  (table{x,y,z})
local snappedPos -- snapped valid target position (table{x,y,z})

local POLLING_RATE = 15
local CMD_STOP = CMD.STOP
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_SET_TARGET = GameCMD.UNIT_SET_TARGET
-- Set target on units that aren't in range yet but may come in range soon
local UNIT_RANGE_MULTIPLIER = 1.5
-- Radius in elmos to search for nearby enemy units when click misses
local SNAP_RADIUS = 100

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

local function GetUnitsInAttackRangeWithDef(unitID, unitDefIDToTarget)
    local unitsInRange = {}

	local unitTeam = spGetUnitTeam(unitID)
	if unitTeam == nil then return unitsInRange end

    local ux, uy, uz = spGetUnitPosition(unitID)
    if not ux then return unitsInRange end

    local maxRange = unitRanges[spGetUnitDefID(unitID)]
    if maxRange == nil or maxRange <= 0 then return unitsInRange end
	maxRange = maxRange * UNIT_RANGE_MULTIPLIER

    local candidateUnits = spGetUnitsInCylinder(ux, uz, maxRange)
	for _, targetID in ipairs(candidateUnits) do
		local targetTeam = spGetUnitTeam(targetID)
        if targetID ~= unitID and targetTeam ~= nil then
            local isAllied = spAreTeamsAllied(unitTeam, targetTeam)
			if not isAllied and spGetUnitDefID(targetID) == unitDefIDToTarget then
				table.insert(unitsInRange, targetID)
            end
        end
    end

    return unitsInRange
end

local function distance(point1, point2)
	if not point1 or not point2 then
		return -1
	end
	
	return math.diag(point1[1] - point2[1],
	                 point1[2] - point2[2],
	                 point1[3] - point2[3])
end

local function clear()
    cursorPos = nil
    snappedPos = nil
end

local function MakeLine(x1, y1, z1, x2, y2, z2)
    gl.Vertex(x1, y1, z1)
    gl.Vertex(x2, y2, z2)
end

local function FindNearestEnemyUnit(x, y, z, radius, myTeam)
	local candidateUnits = spGetUnitsInCylinder(x, z, radius)

	local closestUnit = nil
	local closestDistance = math.huge

	for _, candidateID in ipairs(candidateUnits) do
		local targetTeam = spGetUnitTeam(candidateID)

		if targetTeam and not spAreTeamsAllied(myTeam, targetTeam) then
			local ux, uy, uz = spGetUnitPosition(candidateID)
			if ux then
				local distSq = distance({x, y, z}, {ux, uy, uz})

				if distSq < closestDistance then
					closestUnit = candidateID
					closestDistance = distSq
				end
			end
		end
	end

	return closestUnit
end

function widget:DrawWorld()
    if not cursorPos or not snappedPos then return end
    gl.DepthTest(false)
    gl.LineWidth(2)
    gl.Color(0.3, 1, 0.3, 0.45)
    gl.BeginEnd(GL.LINE_STRIP, MakeLine, cursorPos.x, cursorPos.y, cursorPos.z, snappedPos.x, snappedPos.y, snappedPos.z)
    gl.LineWidth(1)
    gl.DepthTest(true)
end

local function handleSelectionLine()
	local _, cmdID = spGetActiveCommand()
    local alt, ctrl, meta, shift = spGetModKeyState()
	local correctCommand = cmdID == CMD_SET_TARGET and alt and not ctrl and not meta and not shift
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
		local targetID = FindNearestEnemyUnit(
			worldPos[1], worldPos[2], worldPos[3],
			SNAP_RADIUS,
			myTeam
		)
		if targetID then
			local ux, uy, uz = spGetUnitPosition(targetID)
			-- Enable the line
			snappedPos = { x = ux, 			y = uy, 		 z = uz }
			cursorPos  = { x = worldPos[1], y = worldPos[2], z = worldPos[3] }
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

	for unitID, targetUnitDefID in pairs(trackedUnitsToUnitDefID) do
		local candidateUnits = GetUnitsInAttackRangeWithDef(unitID, targetUnitDefID)
		local commandsToGive = {}
		for _, targetID in ipairs(candidateUnits) do
			local newCmdOpts = {}
			if #commandsToGive ~= 0  then
				newCmdOpts = { "shift" }
			end

			commandsToGive[#commandsToGive+1] = { CMD_SET_TARGET, { targetID }, newCmdOpts }
		end

		spGiveOrderArrayToUnit(unitID, commandsToGive)
	end
end

local function cleanupUnitTargeting(unitID)
	trackedUnitsToUnitDefID[unitID] = nil
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
			-- Blocked on https://github.com/beyond-all-reason/RecoilEngine/issues/2793
			-- targetID = Spring.GetClosestEnemyUnit(worldPos[1], worldPos[2], worldPos[3], SNAP_RADIUS, myTeam)
			targetID = FindNearestEnemyUnit(
				worldPos[1], worldPos[2], worldPos[3],
				SNAP_RADIUS,
				myTeam
			)
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
		cleanupUnitTargeting(unitID)
		trackedUnitsToUnitDefID[unitID] = targetUnitDefID
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
