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
local UPDATE_INTERVAL = 15 --is this too much/too little?
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

local unitSightDistances = {}
local lastMovePosition = {}
local recentlyAttacked = {}
local nonAirUnits = {}

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		if (cmdID == CMD_MOVE or cmdID == CMD_FIGHT) and cmdParams[1] and cmdParams[2] and cmdParams[3] then
			lastMovePosition[unitID] = {
				x = cmdParams[1],
				y = cmdParams[2],
				z = cmdParams[3]
			}
		end
		
		if cmdID == CMD_STOP then
			local x, y, z = spGetUnitPosition(unitID)
			
			if x and y and z then
				lastMovePosition[unitID] = { 
					x = x, 
					y = y, 
					z = z 
				}
			end
		end

	return true
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam)
	local def = UnitDefs[unitDefID]

	if def and def.sightDistance and not def.canFly then
		unitSightDistances[unitID] = def.sightDistance
		nonAirUnits[unitID] = true
	end

	if not lastMovePosition[unitID] then
		local x, y, z = spGetUnitPosition(unitID)
		
		if x and y and z then
			lastMovePosition[unitID] = { 
				x = x, 
				y = y, 
				z = z 
			}
		end
	end
end

function gadget:UnitDamaged(unitID, unitDefID, unitTeam, damage, paralyzer, weaponID, attackerID, attackerDefID, attackerTeam)
	if attackerID and attackerTeam ~= unitTeam then
		recentlyAttacked[unitID] = spGetGameFrame
	end
end

function gadget:UnitDestroyed(unitID)
	unitSightDistances[unitID] = nil
	lastMovePosition[unitID] = nil
	recentlyAttacked[unitID] = nil
	nonAirUnits[unitID] = nil
end

function gadget:GameFrame(frame)
	for unitID, sightDist in pairs(unitSightDistances) do
		if nonAirUnits[unitID] then
			if unitID % UPDATE_INTERVAL == frame % UPDATE_INTERVAL then --first time trying something like this, let me know what you think
				local unitStates = spGetUnitStates(unitID)

				if unitStates.firestate ~= FIRESTATE_HOLDFIRE then
					if unitStates.movestate == MOVESTATE_MANEUVER then
						local cmdQueue = spGetUnitCommands(unitID, 1) or {}
						local currentPosition = { spGetUnitPosition(unitID) }
						local validTargetID = nil
						local targetID = spGetUnitNearestEnemy(unitID, sightDist, true)

						if targetID then
							local targetDefID = spGetUnitDefID(targetID)
							if targetDefID and not UnitDefs[targetDefID].canFly then
								validTargetID = targetID 
							end
						end

						if validTargetID then
							Spring.Echo(validTargetID, "is Valid target")
							-- Spring.Echo(cmdQueue)
							if unitStates.firestate == FIRESTATE_RETURNFIRE then
								local attackedRecently = recentlyAttacked[unitID] and (frame - recentlyAttacked[unitID] <= ATTACK_MEMORY_DURATION)
								
								if attackedRecently then
									if not cmdQueue[1] then
										-- Spring.Echo("[RETURN-FIRE CHASE]", unitID, "->" ,validTargetID) --couldn't get this echo to work
										Spring.Echo("[RETURN-FIRE CHASE]")
										spGiveOrderToUnit(unitID, CMD_ATTACK, {validTargetID}, {})
									end
								end
							else
								if not cmdQueue[1] then
									--This block never runs with current settings (UPDATE_INTERVAL = 15). Race condition with engine MOVESTATE_MANUEVER?
									-- Spring.Echo("[CHASE]", unitID, "->", validTargetID)--couldn't get this echo to work
									Spring.Echo("[CHASE]") 
									spGiveOrderToUnit(unitID, CMD_ATTACK, {validTargetID}, {})
								end
							end
						else
							local origPosition = lastMovePosition[unitID]
							local radius = spGetUnitRadius(unitID) or RADIUS_FALLBACK

							if not cmdQueue[1] and (
								not origPosition or
								math.abs(currentPosition[1] - origPosition.x) > (radius * 2) or
								math.abs(currentPosition[3] - origPosition.z) > (radius * 2)
							) then
								-- Spring.Echo("[RETURNING]", unitID, "->", origPosition.x, origPosition.y, origPosition.z) --couldn't get this echo to work
								Spring.Echo("[RETURNING]")
								spGiveOrderToUnit(unitID, CMD_MOVE, {
									origPosition.x,
									origPosition.y,
									origPosition.z
								}, {})
							end
						end
					else
						local x, y, z = spGetUnitPosition(unitID)
						
						if x and y and z then
							lastMovePosition[unitID] = { 
								x = x, 
								y = y, 
								z = z 
							}
						end
					end
				end
			end
		end
	end
end