local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = 'Custom Maneuver behaviour',
		desc = 'Return unit to it\'s last move position when it no longer has a valid target in sight',
		author = 'chocolatemalc',
		version = 'v1.0',
		date = 'July 2025',
		license = 'GNU GPL, v2 or later',
		layer = 0,
		enabled = true
	}
end

if not gadgetHandler:IsSyncedCode() then 
	return 
end

local CMD_ATTACK = CMD.ATTACK
local CMD_MOVE = CMD.MOVE
local CMD_STOP = CMD.STOP
local CMD_FIGHT = CMD.FIGHT
local MOVESTATE_MANEUVER = 1
local FIRESTATE_RETURNFIRE = 1
local UPDATE_INTERVAL = 10
local ATTACK_MEMORY_DURATION = 90
local RADIUS_FALLBACK = 16

local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameFrame = Spring.GetGameFrame

local lastMovePosition = {}
local recentlyAttacked = {}
local customManeuverUnitIDs = {}
local returnToOrigin = {}
local notFlyingWithSight = {}

for i = 1, #UnitDefs do
	local def = UnitDefs[i]
	if not def.canFly and not def.isBuilding and def.sightDistance then
		notFlyingWithSight[i] = def.sightDistance
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		if (cmdID == CMD_MOVE or cmdID == CMD_FIGHT) and cmdParams[1] and cmdParams[2] and cmdParams[3] then
			lastMovePosition[unitID] = { cmdParams[1], cmdParams[2], cmdParams[3] }
	elseif cmdID == CMD_STOP then
		local x, y, z = spGetUnitPosition(unitID)
		lastMovePosition[unitID] = { x, y, z }
		end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local sightDist = notFlyingWithSight[unitDefID]

	if sightDist then
		customManeuverUnitIDs[unitID] = sightDist
	end
	-- returning to origin on factory maneuver setting
	-- if not lastMovePosition[unitID] then
	-- 	local x, y, z = spGetUnitPosition(unitID)
	-- 	lastMovePosition[unitID] = { x, y, z }
	-- end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerTeam ~= unitTeam then
		recentlyAttacked[unitID] = spGetGameFrame()
	end
end

function gadget:UnitDestroyed(unitID)
	lastMovePosition[unitID] = nil
	recentlyAttacked[unitID] = nil
	returnToOrigin[unitID] = nil
	customManeuverUnitIDs[unitID] = nil
end

local function IsAlreadyMovingTo()
end

-- units that are pushed out of lastmove position are calling this forever.
-- maybe i need to reset last move for idle units somehow
local function ReturnToOrigin(unitID, cmdQueue)
	local currentPosition = { spGetUnitPosition(unitID) }
	local originalPosition = lastMovePosition[unitID]
	local radius = spGetUnitRadius(unitID) or RADIUS_FALLBACK
	cmdQueue = cmdQueue or {}

	if originalPosition and --not
		(math.abs(currentPosition[1] - originalPosition[1]) > radius * RADIUS_BUFFER_MULTIPLIER or 
		math.abs(currentPosition[3] - originalPosition[3]) > radius * RADIUS_BUFFER_MULTIPLIER) 
	then
		if cmdQueue[1] then
			local params = cmdQueue[1].params
			if params and #params == 3 then
				if not (math.abs(params[1] - originalPosition[1]) <= radius and
						math.abs(params[3] - originalPosition[3]) <= radius)
				then	 
					Spring.Echo(unitID, "[RETURN TO ORIGIN]")
					spGiveOrderToUnit(unitID, CMD_MOVE, originalPosition, {})
				end
			end
		else
			Spring.Echo(unitID, "[RETURN TO ORIGIN]")
			spGiveOrderToUnit(unitID, CMD_MOVE, originalPosition, {})
		end
	end

	returnToOrigin[unitID] = true
end

function gadget:GameFrame(frame)
	for unitID, sightDist in pairs(customManeuverUnitIDs) do
		if unitID % UPDATE_INTERVAL == frame % UPDATE_INTERVAL then
			local unitStates = spGetUnitStates(unitID)
			-- Spring.Echo(unitID, "[IDLE]")

			if unitStates.movestate == MOVESTATE_MANEUVER then
				local cmdQueue = spGetUnitCommands(unitID, 1) or {}

					-- if returnToOrigin[unitID] then
					-- 		local currentPosition = { spGetUnitPosition(unitID) }
					-- 		local originalPosition = lastMovePosition[unitID]
					-- 		local radius = spGetUnitRadius(unitID) or RADIUS_FALLBACK

					-- 		if not originalPosition or
					-- 			(math.abs(currentPosition[1] - originalPosition[1]) > radius * RADIUS_BUFFER_MULTIPLIER or 
					-- 			math.abs(currentPosition[3] - originalPosition[3]) > radius * RADIUS_BUFFER_MULTIPLIER) 
					-- 		then
					-- 			Spring.Echo(unitID, "[RETURN TO ORIGIN]")
					-- 			spGiveOrderToUnit(unitID, CMD_MOVE, originalPosition, {})
					-- 		end
							
					-- 		returnToOrigin[unitID] = false
					-- 	end
					-- elseif unitStates.firestate == FIRESTATE_RETURNFIRE then
				if unitStates.firestate == FIRESTATE_RETURNFIRE then
					local attackedRecently = recentlyAttacked[unitID] and (frame - recentlyAttacked[unitID] <= ATTACK_MEMORY_DURATION)
					local targetID = spGetUnitNearestEnemy(unitID, sightDist, true)

					if attackedRecently then
						if targetID then	
							local targetDefID = spGetUnitDefID(targetID)
							
							-- if targetDefID and notFlyingWithSight[targetDefID] and not cmdQueue[1] then
							if targetDefID and notFlyingWithSight[targetDefID] and (not cmdQueue[1] or returnToOrigin[unitID]) then
								Spring.Echo(unitID, "[RETURNING CHASE]")
								spGiveOrderToUnit(unitID, CMD_ATTACK, targetID)	
								returnToOrigin[unitID] = false
							end
						end
					else
						if not targetID then
							-- returnToOrigin[unitID] = true
							ReturnToOrigin(unitID, cmdQueue)
							end
						end
					end
					
				if not cmdQueue[1] then
					ReturnToOrigin(unitID)
					-- elseif cmdQueue[1] and cmdQueue[1].id == CMD_ATTACK then
					-- Spring.Echo(unitID, "[CHASING]")
					-- returnToOrigin[unitID] = true
				end
			end
		end
	end
end
