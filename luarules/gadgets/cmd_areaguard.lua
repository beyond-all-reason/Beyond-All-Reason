--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if not gadgetHandler:IsSyncedCode() then
	return
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

function gadget:GetInfo()
  return {
    name      = "Area Guard",
    desc      = "Replace Guard with Area Guard",
    author    = "CarRepairer",
    date      = "2013-06-12",
    license   = "GNU GPL, v2 or later",
	handler = true,
    layer     = 0,
    enabled   = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spUtilities = Spring.Utilities
--local SUC = spUtilities.CMD

local env = getfenv()
local SUC = VFS.Include("LuaRules/Configs/customcmds.lua", nil, VFS.GAME)
for cmdName, cmdID in pairs(SUC) do
	env["CMD_" .. cmdName] = cmdID
end
env.CMD_SETHAVEN = SUC.RETREAT_ZONE

local CMD_AREA_GUARD = SUC.AREA_GUARD
local CMD_ORBIT = SUC.ORBIT
local CMD_ORBIT_DRAW = SUC.ORBIT_DRAW
----------
---------
local GiveClampedMoveGoalToUnit = spUtilities.GiveClampedMoveGoalToUnit
local Angle = VFS.Include("LuaRules/Utilities/vector.lua", nil, VFS.GAME)
--local Angle = spUtilities.Vector.Angle

local spGetUnitPosition = Spring.GetUnitPosition
local spGetUnitVelocity = Spring.GetUnitVelocity
local spAreTeamsAllied  = Spring.AreTeamsAllied
local spGetUnitTeam     = Spring.GetUnitTeam
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Global Variables

local areaGuardCmd = {
	id      = CMD_AREA_GUARD,
	name    = "Guard2",
	action  = "areaguard",
	cursor  = 'Guard',
	type    = CMDTYPE.ICON_UNIT_OR_AREA,
	tooltip = "Guard the unit or units",
	--hidden  = true,
}

local orbitDrawCmd = {
	id      = CMD_ORBIT_DRAW,
	name    = "OrbitDraw",
	action  = "orbitdraw",
	cursor  = 'Guard',
	type    = CMDTYPE.ICON_UNIT,
	tooltip = "Circle around the unit in a protective manner",
	hidden  = true,
}

-- ud.canGuard is true for units for which it should not be true. This table
-- is generated as new unit types are created. It check for guard commands.
local canGuardUnitDefIDs = {}

local newGuards = {}
local oldGuards = {}

local oldcircuitTime = {}
local newcircuitTime = {}
local alreadyHandled = {}

local keepOrder = {}
local nextKeepOrder = {}
local unitOrder = {}

local circleDirection = {}
local lastUpdateTime = {}

local guardAngle = {}

local frame = 0

-- 2*pi comes from the circumference of the circle.
-- 15 comes from the gap between move goals being recieved.
local RAW_MOVE_MODE = false

local CIRC_MULT = 15 * 2*math.pi

local UPDATE_MULT = 2
local PREDICTION = 30
local UPDATE_GAP_LEEWAY = 30*UPDATE_MULT

local RADIUS_BAND_SIZE = 100
local ALLOW_CIRCLE_ENEMY = true

local cos = math.cos
local sin = math.sin
local pi = math.pi

local CMD_GUARD     = CMD.GUARD
local CMD_STOP      = CMD.STOP
local CMD_OPT_SHIFT = CMD.OPT_SHIFT
local spGiveOrderToUnit = Spring.GiveOrderToUnit

for i = 1, #UnitDefs do
	local ud = UnitDefs[i]
	canGuardUnitDefIDs[i] = not ud.isImmobile or ud.isFactory
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Functions

local function RandomPermutation(n)
	local perm = {}
	local taken = {}
	for i = 1, n do
		local entry = math.random(i, n)
		if taken[entry] then
			perm[i] = taken[entry]
		else
			perm[i] = entry
		end
		taken[entry] = i
	end
	return perm
end

local function DoAreaGuard(unitID, unitDefID, unitTeam, cmdParams, cmdOptions )
	local cmdOptions2 = cmdOptions.coded

	if #cmdParams == 1 then
		if unitID ~= cmdParams[1] then
			spGiveOrderToUnit(unitID, CMD_GUARD, cmdParams[1], cmdOptions2)
		end
		return
	end
	
	if (not cmdOptions.shift) then
		spGiveOrderToUnit(unitID, CMD_STOP, 0, cmdOptions2)
		cmdOptions2 = cmdOptions2 + CMD_OPT_SHIFT
	end
	
	local alreadyGuarding = {}
	local cmdQueue = Spring.GetUnitCommands(unitID, -1);
	for _,cmd in ipairs(cmdQueue) do
		if cmd.id == CMD.GUARD and #cmd.params == 1 then
			alreadyGuarding[ cmd.params[1] ] = true
		end
	end
	
    local units = Spring.GetUnitsInSphere( unpack(cmdParams) )
	local perm = RandomPermutation(#units)
	
	-- Give teleport command if a teleporter is in the area
	for i = 1, #units do
		local otherUnitID = units[perm[i]]
		if otherUnitID ~= unitID and not alreadyGuarding[otherUnitID] then
			local teamID = Spring.GetUnitTeam(otherUnitID)
			if Spring.AreTeamsAllied( unitTeam, teamID ) then
				if not GG.Teleport_AllowCommand(unitID, unitDefID, CMD.GUARD, {otherUnitID}, cmdOptions2) then
					return
				end
			end
		end
	end
	
	-- Otherwise, give a guard command to all units in the area
    for i = 1, #units do
		local otherUnitID = units[perm[i]]
		if otherUnitID ~= unitID and not alreadyGuarding[otherUnitID] then
			local teamID = Spring.GetUnitTeam(otherUnitID)
			if Spring.AreTeamsAllied( unitTeam, teamID ) then
				spGiveOrderToUnit(unitID, CMD_GUARD, otherUnitID, cmdOptions2)
			end
		end
    end
	
end

local function DoCircleGuard(unitID, unitDefID, teamID, cmdParams, cmdOptions)
	-- targetID is the unitID of the unit to guard.
	-- radius is the radius to keep from the unit.
	-- facing is an optional parameter which restricts to 120 degrees in that direction(set to 0 to disable).
	local targetID = cmdParams[1]
	local radius   = cmdParams[2]
	local facing   = cmdParams[3] and cmdParams[3] >= 0 and cmdParams[3]
	
	local ud = unitDefID and UnitDefs[unitDefID]
	
	--// Check command validity
	if not (ud and targetID and Spring.ValidUnitID(targetID)) then
		if RAW_MOVE_MODE then
			GG.RemoveRawMoveUnit(unitID)
		end
		return true
	end

	local targetTeamID = spGetUnitTeam(targetID)
	if not spAreTeamsAllied(teamID, targetTeamID) and not ALLOW_CIRCLE_ENEMY then
		if RAW_MOVE_MODE then
			GG.RemoveRawMoveUnit(unitID)
		end
		return true -- remove
	end
	
	-- Keep factory queue but don't do anything with it.
	if ud.isFactory then
		return false
	end
	
	if alreadyHandled[unitID] then
		return false
	end
	
	-- Options.ctrl removes coordination from the units. They move at their max speed.
	-- This is similar to how Ctrl with a move order makes units match speed.
	local ctrl = cmdOptions.ctrl
	
	local ux,_,uz = spGetUnitPosition(targetID)
	local vx,_,vz, speed = spGetUnitVelocity(targetID)
	
	ux, uz = ux + vx*PREDICTION, uz + vz*PREDICTION
	
	--// First Circling Guarder does some bookkeeping
	if not (newGuards[targetID] or facing) then
		-- Update guard circle direction. This swaps whenever there is a gap in which
		-- no guarders are assigned.
		if not circleDirection[targetID] then
			circleDirection[targetID] = 2*math.random(0,1) - 1
		end
		
		if lastUpdateTime[targetID] then
			if lastUpdateTime[targetID] + UPDATE_GAP_LEEWAY < frame then
				circleDirection[targetID] = -circleDirection[targetID]
			end
		end
		lastUpdateTime[targetID] = frame

		-- Make sure some old tables exist, for convinience.
		guardAngle[targetID] = guardAngle[targetID] or {}
		oldcircuitTime[targetID] = oldcircuitTime[targetID] or {}
		oldGuards[targetID] = oldGuards[targetID] or {}
		
		-- Reinitalize new tables
		newcircuitTime[targetID] = {}
		newGuards[targetID] = {}
	end
	
	--// Get the desired angle for the unit
	local angle, perpSize
	if facing then
		if ctrl then
			facing = facing - Spring.GetUnitHeading(targetID)/2^15*math.pi
			-- Keep relative heading mode
			angle = facing
			perpSize = 0
		else
			-- Absolute mode
			angle = facing
			perpSize = 0
		end
	elseif ctrl then
		-- Free movement mode
		local mySpeed  = (Spring.GetUnitRulesParam(unitID, "totalMoveSpeedChange") or 1)*(ud.speed/30)
		local circumference = 2*pi*radius
		
		local x,_,z = Spring.GetUnitPosition(unitID)
		local myAngle = Angle(x - ux, z - uz)
		local circuitTime = circumference/(mySpeed*UPDATE_MULT)
		
		-- Factor of 3 acts as leeway because if a unit gets stuck nothing is
		-- going to move it.
		angle = myAngle + 3*circleDirection[targetID]*CIRC_MULT/circuitTime
		perpSize = circleDirection[targetID]*50
		
	else
		-- Fixed spacing and matched speed along circle mode
		-- Group with units of nearby radius
		local radGroup = math.ceil(radius/RADIUS_BAND_SIZE)
		
		-- First guard of this circut updates the angle
		if not newGuards[targetID][radGroup] then
			local circuitTime = oldcircuitTime[targetID] and oldcircuitTime[targetID][radGroup]
			-- Update circuit positon
			if circuitTime then
				guardAngle[targetID] = guardAngle[targetID] or {}
				guardAngle[targetID][radGroup] = ((guardAngle[targetID] and guardAngle[targetID][radGroup]) or 0) + circleDirection[targetID]*CIRC_MULT/circuitTime
			end
		end
		
		-- Determine circuit time, distance around the circle
		local mySpeed  = (Spring.GetUnitRulesParam(unitID, "totalMoveSpeedChange") or 1)*(ud.speed/30)
		local circumference = 2*pi*radius
		local adjustedSpeed = mySpeed - speed
		if adjustedSpeed < 0.01 then
			newcircuitTime[targetID][radGroup] = false
		elseif newcircuitTime[targetID][radGroup] ~= false then
			local circuitTime = circumference/(adjustedSpeed*UPDATE_MULT)
			newcircuitTime[targetID][radGroup] = math.max(circuitTime, newcircuitTime[targetID][radGroup] or 0)
		end
		
		-- Update the number of units in the circle
		local guards = (oldGuards[targetID] and oldGuards[targetID][radGroup]) or 1
		local circleOrder = newGuards[targetID][radGroup] or 0
		newGuards[targetID][radGroup] = circleOrder + 1
		
		if unitOrder[unitID] and keepOrder[targetID] and keepOrder[targetID][radGroup] then
			circleOrder = unitOrder[unitID]
		else
			unitOrder[unitID] = circleOrder
		end
		
		-- Update whether the number of orbiters has changed
		if circleOrder == guards - 1 then
			nextKeepOrder[targetID] = nextKeepOrder[targetID] or {}
			nextKeepOrder[targetID][radGroup] = true
		elseif circleOrder >= guards and nextKeepOrder[targetID] and nextKeepOrder[targetID][radGroup] then
			nextKeepOrder[targetID][radGroup] = false
		end
		
		-- Calculate my own angle
		angle = ((guardAngle[targetID] and guardAngle[targetID][radGroup]) or 0) + 2*pi*circleOrder/guards
		perpSize = circleDirection[targetID]*50
	end
	
	--// Set new position
	local perpAngle = angle + pi/2
	
	local gX = ux + radius*cos(angle) + perpSize*cos(perpAngle)
	local gZ = uz + radius*sin(angle) + perpSize*sin(perpAngle)
	
	if RAW_MOVE_MODE then
		local myX, _, myZ = spGetUnitPosition(unitID)
		GiveClampedMoveGoalToUnit(unitID, gX, gZ, nil, GG.RawMove_IsPathFree(unitDefID, myX, myZ, gX, gZ))
		GG.AddRawMoveUnit(unitID)
	else
		GiveClampedMoveGoalToUnit(unitID, gX, gZ)
	end
	alreadyHandled[unitID] = true
	return false
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
-- Callins

function gadget:UnitCreated(unitID, unitDefID, team)
	local cmdDescID = Spring.FindUnitCmdDesc(unitID, CMD.GUARD)
	if cmdDescID then
		local cmdArray = {hidden = true}
		Spring.EditUnitCmdDesc(unitID, cmdDescID, cmdArray)
		Spring.InsertUnitCmdDesc(unitID, 500, areaGuardCmd)
		Spring.InsertUnitCmdDesc(unitID, 501, orbitDrawCmd)
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, team)
	if guardAngle[unitID] then
		guardAngle[unitID] = nil
	end
end

function gadget:AllowCommand_GetWantedCommand()
	Spring.Echo('asdfAdsf')
	return {[CMD_GUARD] = true, [CMD_AREA_GUARD] = true, [CMD_ORBIT] = true, [CMD_ORBIT_DRAW] = true}
end

function gadget:AllowCommand_GetWantedUnitDefID()
	return true
end

function gadget:AllowCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_GUARD then
		if #cmdParams == 1 and unitID == cmdParams[1] then
			return false
		end
	elseif cmdID == CMD_AREA_GUARD then
		DoAreaGuard(unitID, unitDefID, unitTeam, cmdParams, cmdOptions )
		return false
	elseif cmdID == CMD_ORBIT or cmdID == CMD_ORBIT_DRAW then
		return canGuardUnitDefIDs[unitDefID] and unitID ~= cmdParams[1]
	end
	return true
end

function gadget:CommandFallback(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_ORBIT then
		-- return true from DoCircleGuard to remove the command.
		-- return false from DoCircleGuard to keep the command in the queue.
		return true, DoCircleGuard(unitID, unitDefID, unitTeam, cmdParams, cmdOptions)
	end
	return false -- command not used
end

function gadget:GameFrame(f)
	frame = f
	if f%(15*UPDATE_MULT) == 0 then
		oldGuards = newGuards
		newGuards = {}
		
		keepOrder = nextKeepOrder
		nextKeepOrder = {}
		
		oldcircuitTime = newcircuitTime
		newcircuitTime = {}
		alreadyHandled = {}
	end
end

function gadget:Initialize()
	gadgetHandler:RegisterCMDID(CMD_ORBIT_DRAW)
	Spring.SetCustomCommandDrawData(CMD_ORBIT_DRAW, "Guard", {0.3, 0.3, 1.0, 0.7})
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = Spring.GetUnitDefID(unitID)
		--local team = spGetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, team)
	end
end
