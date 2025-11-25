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
		enabled = true   --  loaded by default?
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local gameSpeed = Game.gameSpeed

local shouldNotBuggeroff = {}
local cachedUnitDefs = {}
local mostRecentCommandFrame = {}
local gameFrame = 0
local unitSpeedMax = 0

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile then
		shouldNotBuggeroff[unitDefID] = true
	elseif unitDef.speed > unitSpeedMax and not unitDef.canFly then
		unitSpeedMax = unitDef.speed
	end

	cachedUnitDefs[unitDefID] = { radius = unitDef.radius, isBuilder = unitDef.isBuilder}
end

local slowUpdateBuilders 	= {}
local watchedBuilders 		= {}
local builderRadiusOffsets 	= {}
local needsUpdate 			= false
local areaCommandCooldown	= {}

local FAST_UPDATE_RADIUS	= 400
-- builders take about this much to enter build stance; determined empirically
local BUILDER_DELAY_SECONDS = 3.3
local BUILDER_BUILD_RADIUS  = 200 -- ! varies per-unit
-- Assume the units are super-fast and medium-sized.
local SEARCH_RADIUS_OFFSET  = unitSpeedMax + 2 * (Game.squareSize * Game.footprintScale)
local FAST_UPDATE_FREQUENCY = gameSpeed * 0.5
local SLOW_UPDATE_FREQUENCY = gameSpeed * 1.5
local BUGGEROFF_RADIUS_INCREMENT = 2 * Game.squareSize
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
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	if not ux then return false end

	local vx, vy, vz = Spring.GetUnitVelocity(unitID)
	if not vx then return false end

	local sx = ux - tx
	local sz = uz - tz

	-- If unit starts in area, allow to leave quickly; else, check over a long period.
	local seconds = math.diag(sx, sz) <= maxDistance and 0.5 or BUILDER_DELAY_SECONDS
	local dx = ux + vx * seconds - tx
	local dz = uz + vz * seconds - tz

	if math.diag(dx, dz) <= maxDistance then
		-- Unit ends within the area after `seconds`.
		return true
	end

	local ix = tx - ux
	local iz = tz - uz

	if math.diag(ix , iz) > maxDistance then
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
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	if not ux then return false end
	return math.diag(ux - x, uz - z) <= radius
end

local function IsUnitRepeatOn(unitID)
	local cmdDescs = Spring.GetUnitCmdDescs(unitID)
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

local function shouldIssueBuggeroff(builderTeam, unitID, unitDefID, x, z, radius)
	local unitTeam = Spring.GetUnitTeam(unitID)
	if not unitTeam then
		return false
	end
	
	if Spring.AreTeamsAllied(unitTeam, builderTeam) == false then
		return false
	end

	if shouldNotBuggeroff[unitDefID] then
		return false
	end

	if mostRecentCommandFrame[unitID] and (gameFrame - mostRecentCommandFrame[unitID] < USER_COMMAND_TIMEOUT) then
		return false
	end

	if willBeNearTarget(unitID, x, z, radius) then
		return true
	end

	return false
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if frame % FAST_UPDATE_FREQUENCY ~= 0 then
		return
	end

	local visitedTeams = {}
	local visitedUnits = {}
	local cylinderCache = {}  -- Cache GetUnitsInCylinder results per location

	for builderID, _ in pairs(watchedBuilders) do
		local cmdID, _, _, targetX, targetY, targetZ =  Spring.GetUnitCurrentCommand(builderID, 1)
		local isBuilding  	 = Spring.GetUnitIsBuilding(builderID) ~= nil
		local x, y, z		 = Spring.GetUnitPosition(builderID)
		local builderTeam    = Spring.GetUnitTeam(builderID);
		local targetDistance = targetZ and math.distance2d(targetX, targetZ, x, z)

		-- Skip if no valid build command or unit position
		if not cmdID or cmdID > -1 or not x then
			if not x then
				removeBuilder(builderID)
			else
				slowWatchBuilder(builderID)
			end
		elseif targetDistance > FAST_UPDATE_RADIUS then
			slowWatchBuilder(builderID)

		elseif not isBuilding and targetDistance < BUILDER_BUILD_RADIUS + cachedUnitDefs[-cmdID].radius and Spring.GetUnitIsBeingBuilt(builderID) == false then
			local builtUnitDefID	= -cmdID
			local buildDefRadius    = cachedUnitDefs[builtUnitDefID].radius
			local buggerOffRadius	= builderRadiusOffsets[builderID] + buildDefRadius
			local searchRadius		= SEARCH_RADIUS_OFFSET + buildDefRadius

			-- Use cached cylinder lookup to reduce redundant API calls
			local cacheKey = string.format("%.0f_%.0f_%.0f", targetX, targetZ, searchRadius)
			local interferingUnits = cylinderCache[cacheKey]
			if not interferingUnits then
				interferingUnits = Spring.GetUnitsInCylinder(targetX, targetZ, searchRadius)
				cylinderCache[cacheKey] = interferingUnits
			end

			-- Make sure at least one builder per player is never told to move
			if (visitedTeams[builderTeam] == nil) then
				visitedTeams[builderTeam] = true
				visitedUnits[builderID] = true
			end
			-- Escalate the radius every update. We want to send units away the minimum distance, but
			-- if there are many units in the way, they may cause a traffic jam and need to clear more room.
			builderRadiusOffsets[builderID] = builderRadiusOffsets[builderID] + BUGGEROFF_RADIUS_INCREMENT

				for _, interferingID in ipairs(interferingUnits) do
				if builderID ~= interferingID and not visitedUnits[interferingID] and Spring.GetUnitIsBeingBuilt(interferingID) == false then
					-- Only buggeroff from one build site at a time
					visitedUnits[interferingID] = true
					local unitX, _, unitZ = Spring.GetUnitPosition(interferingID)
					local unitDefID  = Spring.GetUnitDefID(interferingID)
					local unitRadius = cachedUnitDefs[unitDefID].radius
					local areaRadius = math.max(buggerOffRadius, buildDefRadius + unitRadius)
					if shouldIssueBuggeroff(builderTeam, interferingID, unitDefID, targetX, targetZ, areaRadius) then
						local vx, vy, vz = Spring.GetUnitVelocity(interferingID)
						unitX, unitZ = unitX + vx * BUGGEROFF_LOOKAHEAD, unitZ + vz * BUGGEROFF_LOOKAHEAD
						local sendX, sendZ = math.closestPointOnCircle(targetX, targetZ, buggerOffRadius + unitRadius, unitX, unitZ)
						if Spring.TestMoveOrder(Spring.GetUnitDefID(interferingID), sendX, targetY, sendZ) then
							Spring.GiveOrderToUnit(interferingID, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_INTERNAL, sendX, targetY, sendZ}, CMD.OPT_ALT)
						end
					end
				end
			end

			if builderRadiusOffsets[builderID] > MAX_BUGGEROFF_RADIUS or IsUnitRepeatOn(builderID) then
				removeBuilder(builderID)
			end

		elseif isBuilding then
			-- We want to keep updating in case the builder has got another job nearby
			builderRadiusOffsets[builderID] = 0
		end
	end

	if frame % SLOW_UPDATE_FREQUENCY ~= 0 and not needsUpdate then
		return
	end

	needsUpdate = false

	for builderID, _ in pairs(slowUpdateBuilders) do
		-- Only check first few commands instead of entire queue for performance
		local builderCommands   = Spring.GetUnitCommands(builderID, 5)
		local hasBuildCommand, buildCommandFirst = false, false
		local targetX, targetZ  = 0, 0

		if builderCommands ~= nil then
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

		local isBuilding  = false
		if Spring.GetUnitIsBuilding(builderID) then isBuilding = true end

		if not hasBuildCommand then
			removeBuilder(builderID)
		elseif buildCommandFirst and not isBuilding and isInTargetArea(builderID, targetX, targetZ, FAST_UPDATE_RADIUS) then
			watchBuilder(builderID)
		end
	end
end

-- TODO: restore ability to do `/luarules reload`, maybe readd MetaUnitAdded
-- function gadget:Initialize()
-- 	for _, teamID in ipairs(Spring.GetTeamList()) do
-- 		local unitList = Spring.GetTeamUnits(teamID)
-- 		for _, unitID in ipairs(unitList) do
-- 			gadget:MetaUnitAdded(unitID, Spring.GetUnitDefID(unitID), teamID)
-- 		end
-- 	end
-- end

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
