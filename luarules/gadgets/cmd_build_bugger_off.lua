local gadget = gadget ---@type gadget

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

local shouldNotBuggeroff = {}
local cachedUnitDefs = {}
local cachedBuilderTeams = {}
for unitDefID, unitDef in pairs(UnitDefs) do
	if unitDef.isImmobile then
		shouldNotBuggeroff[unitDefID] = true
	end
	
	cachedUnitDefs[unitDefID] = { radius = unitDef.radius, isBuilder = unitDef.isBuilder}
end

local function willBeNearTarget(unitID, tx, ty, tz, seconds, maxDistance)
	local ux, uy, uz = Spring.GetUnitPosition(unitID)
	if not ux then return false end
	
	local vx, vy, vz = Spring.GetUnitVelocity(unitID)
	if not vx then return false end
	
	local futureX = ux + vx * seconds * Game.gameSpeed
	local futureY = uy + vy * seconds * Game.gameSpeed
	local futureZ = uz + vz * seconds * Game.gameSpeed
	
	local dx = futureX - tx
	local dy = futureY - ty
	local dz = futureZ - tz
	return math.diag(dx, dy, dz) <= maxDistance
end

local function isInTargetArea(interferingUnitID, x, y, z, radius)
	local ux, uy, uz = Spring.GetUnitPosition(interferingUnitID)
	if not ux then return false end
	return math.diag(ux - x, uz - z) <= radius
end

local slowUpdateBuilders 	= {}
local watchedBuilders 		= {}
local builderRadiusOffsets 	= {}
local needsUpdate 			= false

local FAST_UPDATE_RADIUS	= 400
-- builders take about this much to enter build stance; determined empirically
local BUILDER_DELAY_SECONDS = 3.3
local BUILDER_BUILD_RADIUS  = 200
local SEARCH_RADIUS_OFFSET  = 200
local FAST_UPDATE_FREQUENCY = 30
local SLOW_UPDATE_FREQUENCY = 60
local BUGGEROFF_RADIUS_INCREMENT = FAST_UPDATE_FREQUENCY * 0.5

local function shouldIssueBuggeroff(builderTeam, interferingUnitID, x, y, z, radius)
	if Spring.AreTeamsAllied(Spring.GetUnitTeam(interferingUnitID), builderTeam) == false then
		return false
	end

	if shouldNotBuggeroff[Spring.GetUnitDefID(interferingUnitID)] then
		return false
	end

	if willBeNearTarget(interferingUnitID, x, y, z, BUILDER_DELAY_SECONDS, radius) then
		return true
	end

	if isInTargetArea(interferingUnitID, x, y, z, radius) then
		return true
	end

	return false
end

function gadget:GameFrame(frame)
	if frame % FAST_UPDATE_FREQUENCY ~= 0 then
		return
	end

	for builderID, _ in pairs(watchedBuilders) do
		local cmdID, options, tag, targetX, targetY, targetZ =  Spring.GetUnitCurrentCommand(builderID, 1)
		local isBuilding  	= false
		local x, y, z		= Spring.GetUnitPosition(builderID)
		local targetID		= Spring.GetUnitIsBuilding(builderID)
		if targetID then isBuilding = true end
		local visited = {}
		
		if cmdID == nil or cmdID > -1 or math.distance2d(targetX, targetZ, x, z) > FAST_UPDATE_RADIUS  then
			watchedBuilders[builderID]	  	= nil
			slowUpdateBuilders[builderID]   = true
			builderRadiusOffsets[builderID] = 0

		elseif math.distance2d(targetX, targetZ, x, z) < BUILDER_BUILD_RADIUS + cachedUnitDefs[-cmdID].radius and isBuilding == false then
			local builtUnitDefID	= -cmdID
			local buggerOffRadius	= cachedUnitDefs[builtUnitDefID].radius + builderRadiusOffsets[builderID]
			local searchRadius		= cachedUnitDefs[builtUnitDefID].radius + SEARCH_RADIUS_OFFSET
			local interferingUnits	= Spring.GetUnitsInCylinder(targetX, targetZ, searchRadius)

			-- Escalate the radius every update. We want to send units away the minimum distance, but  
			-- if there are many units in the way, they may cause a traffic jam and need to clear more room.
			builderRadiusOffsets[builderID] = builderRadiusOffsets[builderID] + BUGGEROFF_RADIUS_INCREMENT

			for _, interferingUnitID in ipairs(interferingUnits) do
				if builderID ~= interferingUnitID and visited[interferingUnitID] == nil then
					-- Only buggeroff from one build site at a time
					visited[interferingUnitID] = true
					local unitX, _, unitZ = Spring.GetUnitPosition(interferingUnitID)
					if shouldIssueBuggeroff(cachedBuilderTeams[builderID], interferingUnitID, targetX, targetY, targetZ, buggerOffRadius) then
						local sendX, sendZ = math.closestPointOnCircle(targetX, targetZ, buggerOffRadius, unitX, unitZ)

						if Spring.TestMoveOrder(Spring.GetUnitDefID(interferingUnitID), sendX, targetY, sendZ) then 
							Spring.GiveOrderToUnit(interferingUnitID, CMD.INSERT, {0, CMD.MOVE, CMD.OPT_INTERNAL, sendX, targetY, sendZ}, CMD.OPT_ALT )
						end
					end
				end
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
		local builderCommands   = Spring.GetUnitCommands(builderID, -1)
		local hasBuildCommand, buildCommandFirst = false, false
		local targetX, targetZ  = 0, 0

		if builderCommands ~= nil then
			for idx, command in ipairs(builderCommands) do
				if command.id < 0 then
					hasBuildCommand = true
					if idx == 1 then
						buildCommandFirst = true
						targetX, targetZ  = command.params[1], command.params[3]
					end
				end
			end
		end

		local isBuilding  = false
		if Spring.GetUnitIsBuilding(builderID) then isBuilding = true end

		local x, _, z = Spring.GetUnitPosition(builderID)
		if hasBuildCommand == false then
			slowUpdateBuilders[builderID]   = nil
			builderRadiusOffsets[builderID] = nil
		elseif buildCommandFirst and isBuilding == false and math.distance2d(targetX, targetZ, x, z) <= FAST_UPDATE_RADIUS then
			slowUpdateBuilders[builderID]   = nil
			watchedBuilders[builderID]		= true
		end
	end
end

function gadget:MetaUnitAdded(unitID, unitDefID, unitTeam)
	if cachedUnitDefs[unitDefID].isBuilder then
		cachedBuilderTeams[unitID] = unitTeam
	end
end

function gadget:Initialize()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		local unitList = Spring.GetTeamUnits(teamID)
		for _, unitID in ipairs(unitList) do
			gadget:MetaUnitAdded(unitID, Spring.GetUnitDefID(unitID), teamID)
		end
	end	
end

function gadget:MetaUnitRemoved(unitID, unitDefID, unitTeam)
	cachedBuilderTeams[unitID] = nil
end

function gadget:UnitCommand(unitID, unitDefID, unitTeamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
	if cachedUnitDefs[unitDefID].isBuilder then
		slowUpdateBuilders[unitID]   = true
		builderRadiusOffsets[unitID] = 0
		needsUpdate = true -- Give builder initial slow update right away in case the builder is already close
	end
end
