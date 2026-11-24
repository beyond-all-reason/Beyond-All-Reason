local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Builder buggeroff",
		desc = "Enables busy builders and moving units to buggeroff",
		author = "Flameink",
		date = "March 14, 2025",
		version = "1.0",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return
end

local math_abs = math.abs
local math_floor = math.floor
local math_diag = math.diag
local math_pointOnCircle = math.closestPointOnCircle

local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsBuilding = Spring.GetUnitIsBuilding
local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spGetUnitTeam = Spring.GetUnitTeam

local spPos2BuildPos = Spring.Pos2BuildPos
local spAreTeamsAllied = Spring.AreTeamsAllied
local spDestroyUnit = Spring.DestroyUnit
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spTestMoveOrder = Spring.TestMoveOrder

local gameSpeed = Game.gameSpeed
local footprint = Game.squareSize * Game.footprintScale
local squareSize = Game.squareSize

local CMD_GUARD = CMD.GUARD
local CMD_INSERT = CMD.INSERT
local CMD_OPT_ALT = CMD.OPT_ALT
local insertMoveParams = { 0, CMD.MOVE, CMD.OPT_INTERNAL, 0, 0, 0 }

local isStateCommand = {}
for commandName in pairs(VFS.Include("common/stateCommands.lua")) do
	local commandID = CMD[commandName] or GameCMD[commandName]
	if commandID then
		isStateCommand[commandID] = true
	end
end

local cachedUnitDefs = {}
local unitSpeedMax = 0

for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.speed > unitSpeedMax and not unitDef.canFly then
		unitSpeedMax = unitDef.speed
	end

	cachedUnitDefs[unitDefID] = {
		isImmobile = unitDef.isImmobile,
		isBlocking = not unitDef.reclaimable
			and unitDef.customParams.decoration
			and unitDef.customParams.subfolder ~= "other/hats",
		isBuilder = unitDef.isBuilder,
		radius = unitDef.radius,
		xsizeBuild = unitDef.xsize,
		zsizeBuild = unitDef.zsize,
		xsizeMobile = unitDef.moveDef.xsize or unitDef.xsize,
		zsizeMobile = unitDef.moveDef.zsize or unitDef.zsize,
	}
end

local gameFrame = 0
local mostRecentCommandFrame = {}

local slowUpdateBuilders = {}
local watchedBuilders = {}
local builderRadiusOffsets = {}
local needsUpdate = false
local areaCommandCooldown = {}

local FAST_UPDATE_RADIUS = 400
local BUILDER_BUILD_RADIUS = 200 * Spring.GetModOptions().multiplier_builddistance -- ! varies per-unit
-- Assume the units are super-fast and medium-sized.
local SEARCH_RADIUS_OFFSET = unitSpeedMax + 2 * footprint
local FAST_UPDATE_FREQUENCY = gameSpeed * 0.5
local SLOW_UPDATE_FREQUENCY = FAST_UPDATE_FREQUENCY * 3 -- NB: must be a multiple
local BUGGEROFF_RADIUS_INCREMENT = footprint
-- Move away based on predicted position with lookahead:
local BUGGEROFF_LOOKAHEAD = (1 / 6) * gameSpeed
-- The max buggeroff radius = increment * (time * update rate - 1), so we set a max time here also, implicitly.
-- Prevent units from roaming by maintaining a max radius <= 400, the engine's max leash radius (see e.g. CMobileCAI::ExecuteFight).
local MAX_BUGGEROFF_TIME = 13
local MAX_BUGGEROFF_RADIUS = BUGGEROFF_RADIUS_INCREMENT * (MAX_BUGGEROFF_TIME * gameSpeed / FAST_UPDATE_FREQUENCY - 1) -- => 400 elmos
-- Don't buggeroff units that were ordered to do something recently
local USER_COMMAND_TIMEOUT = 2 * gameSpeed
-- Cooldown for area commands to prevent mass slowWatchBuilder calls
local AREA_COMMAND_COOLDOWN = 2 * gameSpeed
-- Clear units guarding a traveling builder out of its forward path corridor
local PATH_CLEAR_SEARCH_EXTRA = 3 * footprint
local PATH_CLEAR_FORWARD_EXTRA = 2 * footprint
local PATH_CLEAR_LATERAL_EXTRA = footprint

local function doesFootprintOverlap(x, z, xsize, zsize, buildX1, buildZ1, buildX2, buildZ2)
	local x1 = math_floor(x / squareSize) - math_floor(xsize / 2)
	local z1 = math_floor(z / squareSize) - math_floor(zsize / 2)
	return x1 < buildX2 and buildX1 < x1 + xsize and z1 < buildZ2 and buildZ1 < z1 + zsize
end

local function willBeNearTarget(ux, uz, vx, vz, xsize, zsize, buildX1, buildZ1, buildX2, buildZ2)
	if doesFootprintOverlap(ux, uz, xsize, zsize, buildX1, buildZ1, buildX2, buildZ2) then
		return true
	end
	local frames = 2.25 * BUGGEROFF_LOOKAHEAD
	return doesFootprintOverlap(ux + vx * frames, uz + vz * frames, xsize, zsize, buildX1, buildZ1, buildX2, buildZ2)
end

local function isInTargetArea(unitID, x, z, radius)
	local ux, uy, uz = spGetUnitPosition(unitID)
	if not ux then
		return false
	end
	return math_diag(ux - x, uz - z) <= radius
end

local function IsUnitRepeatOn(unitID)
	local states = spGetUnitStates(unitID)
	return states and states["repeat"] == true
end

local function watchBuilder(builderID)
	slowUpdateBuilders[builderID] = nil
	watchedBuilders[builderID] = true
	builderRadiusOffsets[builderID] = 0
end

local function removeBuilder(builderID)
	slowUpdateBuilders[builderID] = nil
	watchedBuilders[builderID] = nil
	builderRadiusOffsets[builderID] = nil
end

local function slowWatchBuilder(builderID)
	watchedBuilders[builderID] = nil
	slowUpdateBuilders[builderID] = true
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

local function isGuardingBuilder(unitID, builderID)
	local cmdID, _, _, guardTargetID = spGetUnitCurrentCommand(unitID, 1)
	return cmdID == CMD_GUARD and guardTargetID == builderID
end

-- Nudge units whose current order is GUARD on this builder out of its travel corridor.
local function clearGuardsFromBuilderPath(builderID, bx, by, bz, tx, tz, builderDefData, visitedUnits, moveParams)
	local dx, dz = tx - bx, tz - bz
	local dist = math_diag(dx, dz)
	if dist < footprint then
		return
	end

	local inv = 1 / dist
	local dirX, dirZ = dx * inv, dz * inv
	local builderRadius = builderDefData.radius
	local searchRadius = builderRadius + PATH_CLEAR_SEARCH_EXTRA
	local nearbyUnits = spGetUnitsInCylinder(bx, bz, searchRadius)

	for i = 1, #nearbyUnits do
		local unitID = nearbyUnits[i]
		if unitID ~= builderID and not visitedUnits[unitID] then
			local unitDefID = spGetUnitDefID(unitID)
			local unitDefData = unitDefID and cachedUnitDefs[unitDefID]
			if unitDefData and not ignoreBuggeroff(unitID, unitDefData) and isGuardingBuilder(unitID, builderID) then
				local ux, _, uz = spGetUnitPosition(unitID)
				if ux then
					local toX, toZ = ux - bx, uz - bz
					local forward = toX * dirX + toZ * dirZ
					-- Signed offset along (dirZ, -dirX); positive = one side of the path
					local lateral = toX * dirZ - toZ * dirX
					local unitRadius = unitDefData.radius
					local blockWidth = builderRadius + unitRadius
					local maxForward = blockWidth + PATH_CLEAR_FORWARD_EXTRA
					local absLateral = math_abs(lateral)

					if forward > 0 and forward < maxForward and absLateral < blockWidth then
						-- Push further out on the same side; never across the centerline
						local side = lateral >= 0 and 1 or -1
						local clearDist = blockWidth + PATH_CLEAR_LATERAL_EXTRA
						local push = clearDist - absLateral
						local sendX = ux + dirZ * side * push
						local sendZ = uz - dirX * side * push

						if spTestMoveOrder(unitDefID, sendX, by, sendZ) then
							moveParams[4], moveParams[5], moveParams[6] = sendX, by, sendZ
							spGiveOrderToUnit(unitID, CMD_INSERT, moveParams, CMD_OPT_ALT)
							visitedUnits[unitID] = true
						end
					end
				end
			end
		end
	end
end

function gadget:GameFrame(frame)
	gameFrame = frame
	if frame % FAST_UPDATE_FREQUENCY ~= 0 then
		return
	end

	local visitedTeams = {}
	local visitedUnits = {}
	local cylinderCache = {} -- Cache GetUnitsInCylinder results per location

	local moveParams = insertMoveParams

	-- Collect deferred actions to avoid modifying tables during pairs() iteration
	local deferRemove = {}
	local deferSlow = {}
	local deferRemoveCount = 0
	local deferSlowCount = 0

	for builderID, _ in pairs(watchedBuilders) do
		local cmdID, _, _, targetX, targetY, targetZ, targetFacing = spGetUnitCurrentCommand(builderID, 1)
		local isBuilding = spGetUnitIsBuilding(builderID) ~= nil
		local x, y, z = spGetUnitPosition(builderID)
		local builderTeam = spGetUnitTeam(builderID)
		local targetDistance = targetZ and x and math_diag(targetX - x, targetZ - z)
		local buildUnitDefData = cmdID and cachedUnitDefs[-cmdID]
		local builderDefData = cachedUnitDefs[spGetUnitDefID(builderID)]

		if not x then
			deferRemoveCount = deferRemoveCount + 1
			deferRemove[deferRemoveCount] = builderID
		elseif not buildUnitDefData then
			deferSlowCount = deferSlowCount + 1
			deferSlow[deferSlowCount] = builderID
		elseif not isBuilding and spGetUnitIsBeingBuilt(builderID) == false then
			-- Keep guards from blocking the builder while it travels to the build site.
			if builderDefData then
				clearGuardsFromBuilderPath(
					builderID,
					x,
					y,
					z,
					targetX,
					targetZ,
					builderDefData,
					visitedUnits,
					moveParams
				)
			end

			if targetDistance > FAST_UPDATE_RADIUS then
				deferSlowCount = deferSlowCount + 1
				deferSlow[deferSlowCount] = builderID
			elseif targetDistance < BUILDER_BUILD_RADIUS + buildUnitDefData.radius then
				local buildDefRadius = buildUnitDefData.radius
				local searchRadius = SEARCH_RADIUS_OFFSET + buildDefRadius

				-- Use cached cylinder lookup to reduce redundant API calls
				-- Nested numeric tables avoid string format allocation/GC overhead
				local cache1 = cylinderCache[targetX]
				if not cache1 then
					cache1 = {}
					cylinderCache[targetX] = cache1
				end
				local cacheKey2 = targetZ * 10000 + searchRadius
				local interferingUnits = cache1[cacheKey2]
				if not interferingUnits then
					interferingUnits = spGetUnitsInCylinder(targetX, targetZ, searchRadius)
					cache1[cacheKey2] = interferingUnits
				end

				-- Escalate the radius every update. We want to send units away the minimum distance, but
				-- if there are many units in the way, they may cause a traffic jam and need to clear more room.
				local buggerOffRadius = builderRadiusOffsets[builderID] + buildDefRadius
				local buggerOffRadiusOffset = builderRadiusOffsets[builderID] + BUGGEROFF_RADIUS_INCREMENT

				local buildXsize, buildZsize = buildUnitDefData.xsizeBuild, buildUnitDefData.zsizeBuild
				if targetFacing and targetFacing % 2 == 1 then
					buildXsize, buildZsize = buildZsize, buildXsize
				end
				local buildX, _, buildZ = spPos2BuildPos(-cmdID, targetX, targetY, targetZ, targetFacing)
				local buggerOffSquares = math_floor(builderRadiusOffsets[builderID] / squareSize)
				local buildX1 = math_floor(buildX / squareSize) - math_floor(buildXsize / 2) - buggerOffSquares
				local buildZ1 = math_floor(buildZ / squareSize) - math_floor(buildZsize / 2) - buggerOffSquares
				local buildX2 = buildX1 + buildXsize + 2 * buggerOffSquares
				local buildZ2 = buildZ1 + buildZsize + 2 * buggerOffSquares

				-- Make sure at least one builder per player is never told to move
				if visitedTeams[builderTeam] == nil then
					visitedTeams[builderTeam] = true
					visitedUnits[builderID] = true
				end

				for _, interferingID in ipairs(interferingUnits) do
					local unitDefID = spGetUnitDefID(interferingID)
					local unitDefData = unitDefID and cachedUnitDefs[unitDefID]

					if not unitDefData or builderID == interferingID or visitedUnits[interferingID] then
						-- continue
					elseif shouldBuggeroff(interferingID, unitDefData, visitedUnits, builderTeam) then
						local unitX, _, unitZ = spGetUnitPosition(interferingID)
						if unitX then
							local speedX, _, speedZ = spGetUnitVelocity(interferingID)
							if speedX then
								local unitRadius = unitDefData.radius
								if
									willBeNearTarget(
										unitX,
										unitZ,
										speedX,
										speedZ,
										unitDefData.xsizeMobile,
										unitDefData.zsizeMobile,
										buildX1,
										buildZ1,
										buildX2,
										buildZ2
									)
								then
									local predX = unitX + speedX * BUGGEROFF_LOOKAHEAD
									local predZ = unitZ + speedZ * BUGGEROFF_LOOKAHEAD
									local sendX, sendZ =
										math_pointOnCircle(targetX, targetZ, buggerOffRadius + unitRadius, predX, predZ)

									if spTestMoveOrder(unitDefID, sendX, targetY, sendZ) then
										moveParams[4], moveParams[5], moveParams[6] = sendX, targetY, sendZ
										spGiveOrderToUnit(interferingID, CMD_INSERT, moveParams, CMD_OPT_ALT)
									end
								end
							end
						end
					end
				end

				if
					buggerOffRadiusOffset > MAX_BUGGEROFF_RADIUS
					or (not buildUnitDefData.isImmobile and IsUnitRepeatOn(builderID))
				then
					deferRemoveCount = deferRemoveCount + 1
					deferRemove[deferRemoveCount] = builderID
				else
					builderRadiusOffsets[builderID] = buggerOffRadiusOffset
				end
			end
		elseif isBuilding then
			-- We want to keep updating in case the builder has got another job nearby
			builderRadiusOffsets[builderID] = 0
		end
	end

	-- Apply deferred removals/transitions after iteration is complete
	for i = 1, deferRemoveCount do
		removeBuilder(deferRemove[i])
	end
	for i = 1, deferSlowCount do
		slowWatchBuilder(deferSlow[i])
	end

	if frame % SLOW_UPDATE_FREQUENCY ~= 0 and not needsUpdate then
		return
	end

	needsUpdate = false

	local deferSlowRemove = {}
	local deferWatch = {}
	local deferSlowRemoveCount = 0
	local deferWatchCount = 0
	local pathVisitedUnits = {}

	for builderID in pairs(slowUpdateBuilders) do
		-- Use spGetUnitCurrentCommand per-index to avoid allocating command tables
		local hasBuildCommand, buildCommandFirst = false, false
		local targetX, targetZ = 0, 0

		for idx = 1, 5 do
			local cmdID, _, _, px, _, pz = spGetUnitCurrentCommand(builderID, idx)
			if not cmdID then
				break
			end
			if cmdID < 0 then
				hasBuildCommand = true
				if idx == 1 and px and pz then
					buildCommandFirst = true
					targetX, targetZ = px, pz
				end
				break
			end
		end

		if not hasBuildCommand then
			deferSlowRemoveCount = deferSlowRemoveCount + 1
			deferSlowRemove[deferSlowRemoveCount] = builderID
		elseif buildCommandFirst and not spGetUnitIsBuilding(builderID) then
			-- Long-range travel: still clear guarding units from the builder's path
			local bx, by, bz = spGetUnitPosition(builderID)
			local builderDefData = cachedUnitDefs[spGetUnitDefID(builderID)]
			if bx and builderDefData then
				clearGuardsFromBuilderPath(
					builderID,
					bx,
					by,
					bz,
					targetX,
					targetZ,
					builderDefData,
					pathVisitedUnits,
					moveParams
				)
			end

			if isInTargetArea(builderID, targetX, targetZ, FAST_UPDATE_RADIUS) then
				deferWatchCount = deferWatchCount + 1
				deferWatch[deferWatchCount] = builderID
			end
		end
	end

	for i = 1, deferSlowRemoveCount do
		removeBuilder(deferSlowRemove[i])
	end
	for i = 1, deferWatchCount do
		watchBuilder(deferWatch[i])
	end
end

-- TODO: restore ability to do `/luarules reload`, maybe re-add MetaUnitAdded

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	if cachedUnitDefs[unitDefID].isBuilder then
		removeBuilder(unitID)
	end
	mostRecentCommandFrame[unitID] = nil
	areaCommandCooldown[unitID] = nil
end

function gadget:Initialize()
	gadgetHandler:RegisterUnitCommand(CMD.ANY)
end

function gadget:UnitCommand(
	unitID,
	unitDefID,
	unitTeamID,
	cmdID,
	cmdParams,
	cmdOptions,
	cmdTag,
	playerID,
	fromSynced,
	fromLua
)
	if isStateCommand[cmdID] then
		return
	end
	if cachedUnitDefs[unitDefID].isBuilder then
		-- Throttle area command processing to avoid performance spikes with many builders
		if cmdID < 0 then -- Build command
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
	-- Ignore Lua-issued orders (e.g. our own path-clear moves) so they don't immunize units
	if not fromLua then
		mostRecentCommandFrame[unitID] = gameFrame
	end
end
