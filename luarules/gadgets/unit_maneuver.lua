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
local FIRESTATE_HOLDFIRE = 0
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
	if not def.canFly and def.sightDistance then
		notFlyingWithSight[def.id] = {sightDist = def.sightDistance}
	end
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		if (cmdID == CMD_MOVE or cmdID == CMD_FIGHT) and cmdParams[1] and cmdParams[2] and cmdParams[3] then
			lastMovePosition[unitID] = { cmdParams[1], cmdParams[2], cmdParams[3] }
		end
		
		if cmdID == CMD_STOP then
			lastMovePosition[unitID] = { spGetUnitPosition(unitID) }
		end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	if notFlyingWithSight[unitDefID] then
		customManeuverUnitIDs[unitID] = notFlyingWithSight[unitDefID].sightDist
	end

	-- if not lastMovePosition[unitID] then
	-- 	lastMovePosition[unitID] = { spGetUnitPosition(unitID) }-- returning to origin on factory maneuver setting
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

function gadget:GameFrame(frame)
	for unitID, sightDist in pairs(customManeuverUnitIDs) do
		if unitID % UPDATE_INTERVAL == frame % UPDATE_INTERVAL then
			local unitStates = spGetUnitStates(unitID)
			-- Spring.Echo(unitID, "[IDLE]")

			if unitStates.movestate == MOVESTATE_MANEUVER then
				local cmdQueue = spGetUnitCommands(unitID, 1) or {}

				if returnToOrigin[unitID] then
					local currentPosition = { spGetUnitPosition(unitID) }
					local originalPosition = lastMovePosition[unitID]
					local radius = spGetUnitRadius(unitID) or RADIUS_FALLBACK

					if not cmdQueue[1] and (
						not originalPosition or
						math.abs(currentPosition[1] - originalPosition[1]) > (radius * 4) or -- spamming moves in large group becaue can't get to preferred spot
						math.abs(currentPosition[3] - originalPosition[3]) > (radius * 4)
					) then
						Spring.Echo(unitID, "[RETURN TO ORIGIN]")
						spGiveOrderToUnit(unitID, CMD_MOVE, { originalPosition[1], originalPosition[2], originalPosition[3] }, {})
						returnToOrigin[unitID] = false
					end

					if not cmdQueue[1] then
						returnToOrigin[unitID] = false
					end
				elseif unitStates.firestate == FIRESTATE_RETURNFIRE then
					local attackedRecently = recentlyAttacked[unitID] and (frame - recentlyAttacked[unitID] <= ATTACK_MEMORY_DURATION)
					local targetID
					-- Spring.Echo(targetID)

					if attackedRecently then
						-- Spring.Echo("I've been attacked")
						targetID = spGetUnitNearestEnemy(unitID, sightDist, true)

						if targetID then	
							local targetDefID = spGetUnitDefID(targetID)
							if notFlyingWithSight[targetDefID] and not cmdQueue[1] then
								Spring.Echo("[RETURNING CHASE]")
								spGiveOrderToUnit(unitID, CMD_ATTACK, targetID)	
							end
						end
					end
					
					targetID = spGetUnitNearestEnemy(unitID, sightDist, true)
					
					if not targetID then
						-- Spring.Echo("[I'm done chasing]")
						returnToOrigin[unitID] = true
					end
				elseif cmdQueue[1] and cmdQueue[1].id == CMD_ATTACK then
					Spring.Echo(unitID, "[CHASING]")
					returnToOrigin[unitID] = true
				end
			end
		end
	end
end


