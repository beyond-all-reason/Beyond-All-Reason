lastReturnMovePositionlocal gadget = gadget ---@type Gadget

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
local RADIUS_BUFFER_MULTIPLIER = 2
local RADIUS_FALLBACK = 16
local MAX_RETURN_ATTEMPTS = 2

local spGetUnitCommands = Spring.GetUnitCommands
local spGetUnitNearestEnemy = Spring.GetUnitNearestEnemy
local spGetUnitStates = Spring.GetUnitStates
local spGetUnitPosition = Spring.GetUnitPosition
local spGiveOrderToUnit = Spring.GiveOrderToUnit
local spGetUnitRadius = Spring.GetUnitRadius
local spGetUnitDefID = Spring.GetUnitDefID
local spGetGameFrame = Spring.GetGameFrame

local lastMovePosition = {}
local lastReturnMovePosition = {}
local returnRetryCount = {}
local recentlyAttacked = {}
local customManeuverUnitIDs = {}
local returningToOrigin = {}
local hasSightNotFlyingNotBuilding = {}

for i = 1, #UnitDefs do
	local def = UnitDefs[i]
	if not def.canFly and not def.isBuilding and def.sightDistance then
		hasSightNotFlyingNotBuilding[i] = def.sightDistance
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions) --implement saurtrons comment (Should gadgetHandler:RegisterAllowCommand(cmdID) at gadget:Initialize for the relevant cmdIDs)
	if (cmdID == CMD_MOVE or cmdID == CMD_FIGHT) and cmdParams[1] and cmdParams[2] and cmdParams[3] then
		lastMovePosition[unitID] = { cmdParams[1], cmdParams[2], cmdParams[3] }
	elseif cmdID == CMD_STOP then
		local x, y, z = spGetUnitPosition(unitID)
		lastMovePosition[unitID] = { x, y, z }
	end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local sightDist = hasSightNotFlyingNotBuilding[unitDefID]

	if sightDist then
		customManeuverUnitIDs[unitID] = sightDist
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerTeam ~= unitTeam then
		recentlyAttacked[unitID] = spGetGameFrame()
	end
end

function gadget:UnitDestroyed(unitID)
	lastMovePosition[unitID] = nil
	recentlyAttacked[unitID] = nil
	returningToOrigin[unitID] = nil
	customManeuverUnitIDs[unitID] = nil
	lastReturnMovePosition[unitID]= nil
	returnRetryCount[unitID] = nil
end

local function ReturnToOrigin(unitID, cmdQueue)
	cmdQueue = cmdQueue or {}
	local currentPosition = { spGetUnitPosition(unitID) }
	local originalPosition = lastMovePosition[unitID]
	
	if not originalPosition then 
		return 
	end
	
	local radius = spGetUnitRadius(unitID) or RADIUS_FALLBACK
	local buffer = radius * RADIUS_BUFFER_MULTIPLIER
	local distX = math.abs(currentPosition[1] - originalPosition[1]) --refactor this probably
	local distZ = math.abs(currentPosition[3] - originalPosition[3])
	local insideBuffer = distX * distX + distZ * distZ <= buffer * buffer

	if insideBuffer then
		return
	end

	local returnPosition = lastReturnMovePosition[unitID] or originalPosition
	if returnPosition then
		local distX2 = originalPosition[1] - returnPosition[1] --refactor this probably
		local distZ2 = originalPosition[3] - returnPosition[3]
		local stillTryingToReturn = distX2 * distX2 + distZ2 * distZ2 <= buffer * buffer
		if stillTryingToReturn then
			returnRetryCount[unitID] = (returnRetryCount[unitID] or 0) + 1
			if returnRetryCount[unitID] > MAX_RETURN_ATTEMPTS then
				Spring.Echo(unitID, "[GAVE UP RETURNING]")
				lastMovePosition[unitID] = currentPosition
				lastReturnMovePosition[unitID] = nil
				returnRetryCount[unitID] = 0
				return
			end
		else
			returnRetryCount[unitID] = 1
			lastReturnMovePosition[unitID] = { originalPosition[1], originalPosition[3] } --refactor this probably
		end
	else
		returnRetryCount[unitID] = 1
		lastReturnMovePosition[unitID] = { originalPosition[1], originalPosition[3] } --refactor this probably
	end

	Spring.Echo(unitID, "[RETURN TO ORIGIN]")
	spGiveOrderToUnit(unitID, CMD_MOVE, originalPosition, {})
	returningToOrigin[unitID] = true
end

function gadget:GameFrame(frame)
	for unitID, sightDist in pairs(customManeuverUnitIDs) do
		if unitID % UPDATE_INTERVAL == frame % UPDATE_INTERVAL then
			local unitStates = spGetUnitStates(unitID)
			-- Spring.Echo(unitID, "[IDLE]")

			if unitStates.movestate == MOVESTATE_MANEUVER then
				local cmdQueue = spGetUnitCommands(unitID, 1) or {}
				local targetID

				if unitStates.firestate == FIRESTATE_RETURNFIRE then
					local attackedRecently = recentlyAttacked[unitID] and (frame - recentlyAttacked[unitID] <= ATTACK_MEMORY_DURATION)
					targetID = spGetUnitNearestEnemy(unitID, sightDist, true)
					
					if attackedRecently then
						if targetID then
							local targetDefID = spGetUnitDefID(targetID)
							
							if targetDefID and hasSightNotFlyingNotBuilding[targetDefID] and (not cmdQueue[1] or returningToOrigin[unitID]) then
								Spring.Echo(unitID, "[RETURNING CHASE]")
								spGiveOrderToUnit(unitID, CMD_ATTACK, targetID)
								returningToOrigin[unitID] = false
							end
						end
					end
				end
				
				if not cmdQueue[1] and not targetID then
					ReturnToOrigin(unitID)
				end
			end
		end
	end
end
--add some debug

--tests
--spam maneuver factory no waypoint
--	fire
--	return
--	hold
--spam maneuver factory waypoint
--	fire
--	return
--	hold
--fire chase 1
--	chase
--	interrupt
--	return
--fire chase many
--	chase
--	interrupt
--	return
--hold chase
--return chase 1
--	chase
--	interrupt
--	return
--return chase many
--	chase
--	interrupt
--	return
--fire vs air
--hold vs air
--return vs air
