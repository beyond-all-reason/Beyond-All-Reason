local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name	= "Builder buggeroff",
		desc	= "Enables busy builders and moving units to buggeroff",
		author  = "Flameink",
		date	= "March 14, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer   = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local math_max = math.max
local math_diag = math.diag
local math_pointOnCircle = math.closestPointOnCircle

local spGetUnitCmdDescs = Spring.GetUnitCmdDescs
local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitTeam = Spring.GetUnitTeam

local spAreTeamsAllied = Spring.AreTeamsAllied
local spDestroyUnit = Spring.DestroyUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spTestMoveOrder = Spring.TestMoveOrder

local gameSpeed = Game.gameSpeed
local footprint = Game.squareSize * Game.footprintScale

local CMD_INSERT = CMD.INSERT
local CMD_OPT_ALT = CMD.OPT_ALT
local insertMoveParams = { 0, CMD.MOVE, CMD.OPT_INTERNAL, 0, 0, 0 }

local cachedUnitDefs = {}
local unitSpeedMax = 0

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.speed > unitSpeedMax and not unitDef.canFly then
		unitSpeedMax = unitDef.speed
	end

	cachedUnitDefs[unitDefID] = {
		isImmobile = unitDef.isImmobile,
		isBlocking = not unitDef.reclaimable and unitDef.customParams.decoration and unitDef.customParams.subfolder ~= "other/hats",
		isBuilder  = unitDef.isBuilder,
		radius     = unitDef.radius,
		semiAxisX  = unitDef.xsize * footprint * 0.5,
		semiAxisZ  = unitDef.zsize * footprint * 0.5,
	}
end

local gameFrame = 0
local mostRecentCommandFrame = {}

local slowUpdateBuilders 	= {}
local watchedBuilders 		= {}
local builderRadiusOffsets 	= {}
local needsUpdate 			= false
local areaCommandCooldown	= {}

local FAST_UPDATE_RADIUS	= 400
-- builders take about this much to enter build stance; determined empirically
local BUILDER_DELAY_SECONDS = 3.3
local BUILDER_BUILD_RADIUS  = 200 * Spring.GetModOptions().multiplier_builddistance -- ! varies per-unit
-- Assume the units are super-fast and medium-sized.
local SEARCH_RADIUS_OFFSET  = unitSpeedMax + 2 * footprint
local FAST_UPDATE_FREQUENCY = gameSpeed * 0.5
local SLOW_UPDATE_FREQUENCY = FAST_UPDATE_FREQUENCY * 3 -- NB: must be a multiple
local BUGGEROFF_RADIUS_INCREMENT = footprint
-- Move away based on predicted position with lookahead:
local BUGGEROFF_LOOKAHEAD   = (1/6) * gameSpeed
-- The max buggeroff radius = increment * (time * update rate - 1), so we set a max time here also, implicitly.
-- Prevent units from roaming by maintaining a max radius <= 400, the engine's max leash radius (see e.g. CMobileCAI::ExecuteFight).
local MAX_BUGGEROFF_TIME    = 13
local MAX_BUGGEROFF_RADIUS  = BUGGEROFF_RADIUS_INCREMENT * (MAX_BUGGEROFF_TIME * gameSpeed / FAST_UPDATE_FREQUENCY - 1) -- => 400 elmos
-- Don't buggeroff units that were ordered to do something recently
local USER_COMMAND_TIMEOUT	= 2 * gameSpeed
-- Cooldown for area commands to prevent mass slowWatchBuilder calls
local AREA_COMMAND_COOLDOWN = 2 * gameSpeed

local function willBeNearTarget(unitID, tx, tz, maxDistance)
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return false end

	local vx, vy, vz = spGetUnitVelocity(unitID)
	if not vx then return false end

	local sx = ux - tx
	local sz = uz - tz

	-- If unit starts in area, allow to leave quickly; else, check over a long period.
	local seconds = math_diag(sx, sz) <= maxDistance and 0.5 or BUILDER_DELAY_SECONDS
	local dx = ux + vx * seconds - tx
	local dz = uz + vz * seconds - tz

	if math_diag(dx, dz) <= maxDistance then
		-- Unit ends within the area after `seconds`.
		return true
	end

	local ix = tx - ux
	local iz = tz - uz

	if math_diag(ix , iz) > maxDistance then
		-- The unit starts within the area but does not end in it.
		return false
	else
		-- Check whether or not the unit passes through the area.
		local a = vx * vx + vz * vz
		local b = (ix * vx + iz * vz) * 2
		local c = ix * ix + iz * iz - maxDistance * maxDistance
		return b * b - 4 * a * c >= 0
	end
end

local function isInTargetArea(unitID, x, z, radius)
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then return false end
	return math_diag(ux - x, uz - z) <= radius
end

local function IsUnitRepeatOn(unitID)
	local cmdDescs = spGetUnitCmdDescs(unitID)
	if not cmdDescs then return false end
	for _, desc in ipairs(cmdDescs) do
		if desc.id == CMD.REPEAT then
			return desc.params and desc.params[1] == "1"
		end
	end
	return false
end

local function watchBuilder(builderID)
	slowUpdateBuilders[builderID]   = nil
	watchedBuilders[builderID]		= true
	builderRadiusOffsets[builderID] = 0
end

local function removeBuilder(builderID)
	slowUpdateBuilders[builderID]   = nil
	watchedBuilders[builderID]	  	= nil
	builderRadiusOffsets[builderID] = nil
end

local function slowWatchBuilder(builderID)
	watchedBuilders[builderID]	  	= nil
	slowUpdateBuilders[builderID]   = true
	builderRadiusOffsets[builderID] = nil
	-- Give builder initial slow update right away in case the builder is already close
	needsUpdate = true
end

local function ignoreBuggeroff(unitID, unitDefData)
	return unitDefData.isImmobile
		or spGetUnitIsDead(unitID) ~= false
		or spGetUnitIsBeingBuilt(unitID) ~= false
		or gameFrame - (mostRecentCommandFrame[unitID] or -USER_COMMAND_TIMEOUT) < USER_COMMAND_TIMEOUT
end

local function shouldBuggeroff(unitID, unitDefData, visitedUnits, builderTeam)
	if unitDefData.isBlocking then
		visitedUnits[unitID] = true
		spDestroyUnit(unitID, false, true)
		return false
	end

	if ignoreBuggeroff(unitID, unitDefData) then
		visitedUnits[unitID] = true
		return false

	elseif spAreTeamsAllied(spGetUnitTeam(unitID), builderTeam) then
		visitedUnits[unitID] = true
		return true
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if frame % FAST_UPDATE_FREQUENCY ~= 0 then
		return
	end

	local visitedTeams = {}
	local visitedUnits = {}
	local cylinderCache = {}  -- Cache GetUnitsInCylinder results per location

	local moveParams = insertMoveParams

	for builderID, _ in pairs(watchedBuilders) do
		local cmdID, _, _, targetX, targetY, targetZ = spGetUnitCurrentCommand(builderID, 1)
		local isBuilding  	 = spGetUnitIsBuilding(builderID) ~= nil
		local x, y, z		 = spGetUnitPosition(builderID)
		local builderTeam    = spGetUnitTeam(builderID);
		local targetDistance = targetZ and x and math_diag(targetX - x, targetZ - z)
		local buildUnitDefData = cmdID and cachedUnitDefs[-cmdID]

		if not x then
			removeBuilder(builderID)

		elseif not buildUnitDefData or targetDistance > FAST_UPDATE_RADIUS then
			slowWatchBuilder(builderID)

		elseif not isBuilding and targetDistance < BUILDER_BUILD_RADIUS + buildUnitDefData.radius and spGetUnitIsBeingBuilt(builderID) == false then
			local buildDefRadius    = buildUnitDefData.radius
			local searchRadius		= SEARCH_RADIUS_OFFSET + buildDefRadius

			-- Use cached cylinder lookup to reduce redundant API calls
			local cacheKey = ("%.0f_%.0f_%.0f"):format(targetX, targetZ, searchRadius)
			local interferingUnits = cylinderCache[cacheKey]
			if not interferingUnits then
				interferingUnits = spGetUnitsInCylinder(targetX, targetZ, searchRadius)
				cylinderCache[cacheKey] = interferingUnits
			end

			-- Escalate the radius every update. We want to send units away the minimum distance, but
			-- if there are many units in the way, they may cause a traffic jam and need to clear more room.
			local buggerOffRadius = builderRadiusOffsets[builderID] + buildDefRadius
			local buggerOffRadiusOffset = builderRadiusOffsets[builderID] + BUGGEROFF_RADIUS_INCREMENT

			-- Make sure at least one builder per player is never told to move
			if (visitedTeams[builderTeam] == nil) then
				visitedTeams[builderTeam] = true
				visitedUnits[builderID] = true
			end

			for _, interferingID in ipairs(interferingUnits) do
				local unitDefID = spGetUnitDefID(interferingID)
				local unitDefData = unitDefID and cachedUnitDefs[unitDefID]

				if not unitDefData or builderID == interferingID or visitedUnits[interferingID] then
					-- continue
				elseif shouldBuggeroff(interferingID, unitDefData, visitedUnits, builderTeam) then
					-- todo: use blocking for "collision" detection, not unit radii, which are not the bounding radii (neither is bounding radius useful)
					local unitRadius = unitDefData.radius
					local areaRadius = math_max(buggerOffRadius, buildDefRadius + unitRadius)

					if willBeNearTarget(interferingID, targetX, targetZ, areaRadius) then
						local unitX, _, unitZ = spGetUnitPosition(interferingID)
						local speedX, _, speedZ = spGetUnitVelocity(interferingID)
						unitX, unitZ = unitX + speedX * BUGGEROFF_LOOKAHEAD, unitZ + speedZ * BUGGEROFF_LOOKAHEAD
						local sendX, sendZ = math_pointOnCircle(targetX, targetZ, buggerOffRadius + unitRadius, unitX, unitZ)

						if spTestMoveOrder(unitDefID, sendX, targetY, sendZ) then
							moveParams[4], moveParams[5], moveParams[6] = sendX, targetY, sendZ
							spGiveOrderToUnit(interferingID, CMD_INSERT, moveParams, CMD_OPT_ALT)
						end
					end
				end
			end

			if buggerOffRadiusOffset > MAX_BUGGEROFF_RADIUS or (not buildUnitDefData.isImmobile and IsUnitRepeatOn(builderID)) then
				removeBuilder(builderID)
			else
				builderRadiusOffsets[builderID] = buggerOffRadiusOffset
			end

		elseif isBuilding then
			-- We want to keep updating in case the builder has got another job nearby
			builderRadiusOffsets[builderID] = 0
		end
	end

	if needsUpdate or frame % SLOW_UPDATE_FREQUENCY ~= 0 then
		return
	end

	needsUpdate = false

	for builderID in pairs(slowUpdateBuilders) do
		-- Only check first few commands instead of entire queue for performance
		local builderCommands = spGetUnitCommands(builderID, 5)
		local hasBuildCommand, buildCommandFirst = false, false
		local targetX, targetZ = 0, 0

		if builderCommands then
			for idx, command in ipairs(builderCommands) do
				if command.id < 0 then
					hasBuildCommand = true
					if idx == 1 and command.params[1] and command.params[3] then
						buildCommandFirst = true
						targetX, targetZ  = command.params[1], command.params[3]
					end
					break  -- Early exit once we find a build command
				end
			end
		end

		if not hasBuildCommand then
			removeBuilder(builderID)
		elseif buildCommandFirst and not spGetUnitIsBuilding(builderID) and isInTargetArea(builderID, targetX, targetZ, FAST_UPDATE_RADIUS) then
			watchBuilder(builderID)
		end
	end
end

-- TODO: restore ability to do `/luarules reload`, maybe readd MetaUnitAdded

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if cachedUnitDefs[unitDefID].isBuilder then
		removeBuilder(unitID)
	end
	mostRecentCommandFrame[unitID] = nil
	areaCommandCooldown[unitID] = nil
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cachedUnitDefs[unitDefID].isBuilder then
		-- Throttle area command processing to avoid performance spikes with many builders
		if cmdID < 0 then  -- Build command
			local lastAreaCommand = areaCommandCooldown[unitID]
			if not lastAreaCommand or gameFrame - lastAreaCommand >= AREA_COMMAND_COOLDOWN then
				slowWatchBuilder(unitID)
				areaCommandCooldown[unitID] = gameFrame
			end
		else
			-- Non-build commands always get tracked
			slowWatchBuilder(unitID)
		end
	end
	mostRecentCommandFrame[unitID] = gameFrame
end
