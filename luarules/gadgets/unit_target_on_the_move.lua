
function gadget:GetInfo()
  return {
	name 	= "Target on the move",
	desc	= "Adds a command to set a priority attack target",
	author	= "Google Frog, adapted for BA by BrainDamage",
	date	= "06/05/2013",
	license	= "GNU GPL, v2 or later",
	layer	= 0,
	enabled = true,
  }
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then --SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spInsertUnitCmdDesc	= Spring.InsertUnitCmdDesc
local spGetUnitAllyTeam		= Spring.GetUnitAllyTeam
local spSetUnitTarget		= Spring.SetUnitTarget
local spValidUnitID			= Spring.ValidUnitID
local spGetUnitPosition		= Spring.GetUnitPosition
local spGetGroundHeight		= Spring.GetGroundHeight
local spGetUnitDefID		= Spring.GetUnitDefID
local spGetUnitLosState		= Spring.GetUnitLosState
local spGetUnitSeparation	= Spring.GetUnitSeparation
local spGetUnitIsCloaked	= Spring.GetUnitIsCloaked
local spGetUnitPosition		= Spring.GetUnitPosition
local spGetUnitTeam			= Spring.GetUnitTeam
local spAreTeamsAllied		= Spring.AreTeamsAllied
local spGetUnitsInRectangle	= Spring.GetUnitsInRectangle
local spGetUnitsInCylinder	= Spring.GetUnitsInCylinder

local CMD_STOP				= CMD.STOP
local LICHE = UnitDefNames["armcybr"].id

local noUnitTarget			= 0

--------------------------------------------------------------------------------
-- Config

-- Unseen targets will be removed after at least UNSEEN_TIMEOUT*USEEN_UPDATE_FREQUENCY frames 
-- and at most (UNSEEN_TIMEOUT+1)*USEEN_UPDATE_FREQUENCY frames/
local USEEN_UPDATE_FREQUENCY = 150
local UNSEEN_TIMEOUT = 2 

--------------------------------------------------------------------------------
-- Globals

local validUnits = {}

for i=1, #UnitDefs do
	local ud = UnitDefs[i]
	if (ud.canAttack and ud.maxWeaponRange and ud.maxWeaponRange > 0) or ud.isFactory then
		if (not (ud.canFly and ud.isBomber)) and ud.canMove and (not (i == LICHE)) then
			validUnits[i] = true
		end
	end
end

local units = {} -- data holds all unitID data

--------------------------------------------------------------------------------
-- Commands

--include("LuaRules/Configs/customcmds.h.lua")

local CMD_UNIT_SET_TARGET_RECTANGLE = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_UNIT_SET_TARGET_CIRCLE = 34925

local unitSetTargetRectangleCmdDesc = {
	id		= CMD_UNIT_SET_TARGET_RECTANGLE,
	type	= CMDTYPE.ICON_UNIT_OR_RECTANGLE,
	name	= 'Set Target',
	action	= 'settargetrectangle',
	cursor	= 'settarget',
	tooltip	= 'Sets target for unit, not removed by move commands',
	hidden	= true,
}

local unitSetTargetCircleCmdDesc = {
	id		= CMD_UNIT_SET_TARGET_CIRCLE,
	type	= CMDTYPE.ICON_UNIT_OR_AREA,
	name	= 'Set Target',
	action	= 'settarget',
	cursor	= 'settarget',
	tooltip	= 'Sets a top priority attack target, to be used if within range (not removed by move commands)',
	hidden	= false,
}

local unitCancelTargetCmdDesc = {
	id		= CMD_UNIT_CANCEL_TARGET,
	type	= CMDTYPE.ICON,
	name	= 'Cancel Target',
	action	= 'canceltarget',
	tooltip	= 'Removes top priority target, if set',
	hidden	= false,
}



--------------------------------------------------------------------------------
-- Gadget Interaction

function GG.GetUnitTarget(unitID)
	return units[unitID] and units[unitID].target
end

--------------------------------------------------------------------------------
-- Target Handling

local function unitInRange(unitID, targetID, range)
	local dis = spGetUnitSeparation(unitID, targetID) -- 2d range
	return dis and range and dis < range
end

local function locationInRange(unitID, x, y, z, range)
	local ux, uy, uz = spGetUnitPosition(unitID)
	return range and ((ux - x)^2 + (uz - z)^2) < range^2
end

local function setTarget(data)
	if spValidUnitID(data.id) then
		if tonumber(data.target) and spValidUnitID(data.target) and spGetUnitAllyTeam(data.target) ~= data.allyTeam then
			if data.bypassRangeCheck or unitInRange(data.id, data.target, data.range) then
				spSetUnitTarget(data.id, data.target)
				if GG.GetUnitTarget(unitID) ~= data.target then
					SendToUnsynced("targetChange",data.id, data.target)
				end
			end
		elseif not tonumber(data.target) and data.target then
			if data.bypassRangeCheck or locationInRange(data.id, data.target[1], data.target[2], data.target[3], data.range) then
				spSetUnitTarget(data.id, data.target[1],data.target[2],data.target[3])
				if GG.GetUnitTarget(unitID) ~= data.target then
					SendToUnsynced("targetChange",data.id, data.target[1],data.target[2],data.target[3])
				end
			end
		else
			return false
		end
	end
	return true
end

local function removeUnseenTarget(data)
	if tonumber(data.target) and not data.alwaysSeen and spValidUnitID(data.target) then
		local los = spGetUnitLosState(data.target, data.allyTeam, false)
		if not (los and (los.los or los.radar)) then
			if data.unseenTargetTimer == UNSEEN_TIMEOUT then
				return true
			elseif not data.unseenTargetTimer then
				data.unseenTargetTimer = 1
			else
				data.unseenTargetTimer = data.unseenTargetTimer + 1
			end
		elseif data.unseenTargetTimer then
			data.unseenTargetTimer = nil
		end
	end
end

--------------------------------------------------------------------------------
-- Unit adding/removal

local function addUnit(unitID, data)
	if spValidUnitID(unitID) then
		if setTarget(data) then
			units[unitID] = data
		end
	end
end

local function removeUnit(unitID)
	spSetUnitTarget(unitID, noUnitTarget)
	if GG.GetUnitTarget(unitID) then
		SendToUnsynced("targetChange",unitID)
	end
	units[unitID] = nil
end

function gadget:Initialize()

	-- register cursor
	Spring.AssignMouseCursor("settarget", "cursorsettarget", false)
	
	-- register command
	gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
	gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
	
	-- load active units
	for _, unitID in ipairs(Spring.GetAllUnits()) do
		local unitDefID = spGetUnitDefID(unitID)
		local teamID = spGetUnitTeam(unitID)
		gadget:UnitCreated(unitID, unitDefID, teamID)
	end
	
end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID) 
	if validUnits[unitDefID] then
		--spInsertUnitCmdDesc(unitID, unitSetTargetRectangleCmdDesc)
		spInsertUnitCmdDesc(unitID, unitSetTargetCircleCmdDesc)
		spInsertUnitCmdDesc(unitID, unitCancelTargetCmdDesc)
	end
	
end

function gadget:UnitFromFactory(unitID, unitDefID, unitTeam, facID, facDefID)
	if validUnits[unitDefID] and units[facID] then
		local data = units[facID]
		addUnit(unitID, {
			id = unitID, 
			target = data.target,
			allyTeam = spGetUnitAllyTeam(unitID), 
			range = UnitDefs[unitDefID].maxWeaponRange,
			alwaysSeen = data.alwaysSeen,
			bypassRangeCheck = data.bypassRangeCheck,
			ignoreStop = data.ignoreStop,
		})
	end
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	removeUnit(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, oldTeamID, teamID)
	removeUnit(unitID)
end

--------------------------------------------------------------------------------
-- Command Tracking

local function disSQ(x1,y1,x2,y2)
	return (x1 - x2)^2 + (y1 - y2)^2
end

local function setTargetClosestFromList(unitID, unitDefID, team, choiceUnits, bypassRangeCheck, ignoreStop)

	local ux, uy, uz = spGetUnitPosition(unitID)
				
	local bestDis = false
	local bestUnit = false

	if ux and choiceUnits then
		for i = 1, #choiceUnits do
			local tTeam = spGetUnitTeam(choiceUnits[i])
			if tTeam and not spAreTeamsAllied(team,tTeam) then
				local tx,ty,tz = spGetUnitPosition(choiceUnits[i])
				if tx then
					local newDis = disSQ(ux,uz,tx,tz)
					if (not bestDis) or bestDis > newDis then
						bestDis = newDis
						bestUnit = choiceUnits[i]
					end
				end
			end
		end
	end
	
	if bestUnit then
		local targetUnitDef = spGetUnitDefID(bestUnit)
		local tud = targetUnitDef and UnitDefs[targetUnitDef]
		addUnit(unitID, {
			id = unitID, 
			target = bestUnit, 
			allyTeam = spGetUnitAllyTeam(unitID), 
			range = UnitDefs[unitDefID].maxWeaponRange,
			alwaysSeen = tud and (tud.isBuilding == true or tud.maxAcc == 0),
			bypassRangeCheck = bypassRangeCheck,
			ignoreStop = ignoreStop,
		})
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	
	if cmdID == CMD_UNIT_SET_TARGET_RECTANGLE or cmdID == CMD_UNIT_SET_TARGET_CIRCLE then
		if validUnits[unitDefID] then
			local bypassRangeCheck = not cmdOptions.meta
			local ignoreStop = cmdOptions.ctrl
			if #cmdParams == 6 then
				--rectangle
				local team = spGetUnitTeam(unitID)
				
				if not team then
					return false
				end
				
				local top, bot, left, right
				if cmdParams[1] < cmdParams[4] then
					left = cmdParams[1]
					right = cmdParams[4]
				else
					left = cmdParams[4]
					right = cmdParams[1]
				end
				
				if cmdParams[3] < cmdParams[6] then
					top = cmdParams[3]
					bot = cmdParams[6]
				else
					bot = cmdParams[6]
					top = cmdParams[3]
				end
				
				local units = CallAsTeam(team,
					function ()
					return spGetUnitsInRectangle(left,top,right,bot) end)
				
				setTargetClosestFromList(unitID, unitDefID, team, units, bypassRangeCheck, ignoreStop)
			
			elseif #cmdParams == 4 then
				--circle
				local team = spGetUnitTeam(unitID)
				
				if not team then
					return false
				end
				
				local units = CallAsTeam(team,
					function ()
					return spGetUnitsInCylinder(cmdParams[1],cmdParams[3],cmdParams[4]) end)
					
				setTargetClosestFromList(unitID, unitDefID, team, units, bypassRangeCheck, ignoreStop)
				
			elseif #cmdParams == 3 then
				--coordinate
				addUnit(unitID, {
					id = unitID, 
					target = {
						cmdParams[1],
						CallAsTeam(teamID, function () return spGetGroundHeight(cmdParams[1],cmdParams[3]) end),
						cmdParams[3],
					},
					allyTeam = spGetUnitAllyTeam(unitID), 
					range = UnitDefs[unitDefID].maxWeaponRange,
					bypassRangeCheck = bypassRangeCheck,
					ignoreStop = ignoreStop,
				})
			elseif #cmdParams == 1 then
				--single target
				local targetUnitDef = spGetUnitDefID(cmdParams[1])
				local tud = targetUnitDef and UnitDefs[targetUnitDef]
				addUnit(unitID, {
					id = unitID, 
					target = cmdParams[1], 
					allyTeam = spGetUnitAllyTeam(unitID), 
					range = UnitDefs[unitDefID].maxWeaponRange,
					alwaysSeen = tud and (tud.isBuilding == true or tud.maxAcc == 0),
					bypassRangeCheck = bypassRangeCheck,
					ignoreStop = ignoreStop,
				})
			elseif #cmdParams == 0 then
				--no param, unset target
				removeUnit(unitID)
			end
		end
		return false  -- command was used
	elseif cmdID == CMD_UNIT_CANCEL_TARGET then
		if validUnits[unitDefID] then
			removeUnit(unitID)
		end
		return false  -- command was used
	elseif cmdID == CMD_STOP then
		if units[unitID] and not units[unitID].ignoreStop then 
			removeUnit(unitID)
		end
	end
	return true  -- command was not used
end

--------------------------------------------------------------------------------
-- Target update

function gadget:GameFrame(n)
	if n%16 == 15 then -- timing synced with slow update to reduce attack jittering
		-- 15 causes attack command to override target command
		-- 0 causes target command to take precedence
		
		for unitID, data in pairs(units) do
			if not setTarget(data) then
				removeUnit(unitID)
			end
		end
	end
	
	if n%USEEN_UPDATE_FREQUENCY == 0 then
		for unitID, data in pairs(units) do
			if removeUnseenTarget(data) then
				removeUnit(unitID)
			end
		end
	end
	
end

--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
else -- UNSYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local glVertex 		= gl.Vertex
local glPushAttrib	= gl.PushAttrib
local glLineStipple	= gl.LineStipple
local glDepthTest	= gl.DepthTest
local glLineWidth	= gl.LineWidth
local glColor		= gl.Color
local glBeginEnd	= gl.BeginEnd
local glPopAttrib	= gl.PopAttrib
local glCreateList	= gl.CreateList
local glCallList	= gl.CallList
local glDeleteList  = gl.DeleteList
local GL_LINES		= GL.LINES

local spIsUnitInView 		= Spring.IsUnitInView
local spGetUnitPosition 	= Spring.GetUnitPosition
local spGetUnitLosState 	= Spring.GetUnitLosState
local spValidUnitID 		= Spring.ValidUnitID
local spGetMyAllyTeamID 	= Spring.GetMyAllyTeamID 	
local spGetMyTeamID			= Spring.GetMyTeamID
local spIsUnitSelected		= Spring.IsUnitSelected
local spGetModKeyState		= Spring.GetModKeyState
local spGetSpectatingState	= Spring.GetSpectatingState
local spGetUnitAllyTeam		= Spring.GetUnitAllyTeam
local spGetUnitTeam			= Spring.GetUnitTeam

local myAllyTeam = spGetMyAllyTeamID()
local myTeam = spGetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()


local drawAllTargets = {}
local drawTarget = {}
local unitTargets = {}

function gadget:Initialize()
	gadgetHandler:AddChatAction("targetdrawteam", handleTargetDrawEvent,"toggles drawing targets for units, params: teamID doDraw")
	gadgetHandler:AddChatAction("targetdrawunit", handleUnitTargetDrawEvent,"toggles drawing targets for units, params: unitID")
	gadgetHandler:AddSyncAction("targetChange", handleTargetChangeEvent)
	
	Spring.SendCommands("bind y settarget")
	Spring.SendCommands("bind j canceltarget")
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction('targetDraw')
end

function handleUnitTargetDrawEvent(_,_,params)
	drawTarget[tonumber(params[1])] = true
end

function handleTargetDrawEvent(_,_,params)
	local teamID = tonumber(params[1])
	local doDraw = tonumber(params[2]) ~= 0
	drawAllTargets[teamID] = doDraw
end

function handleTargetChangeEvent(_,unitID,dataA,dataB,dataC)
	if not dataB then
		--single unitID format
		unitTargets[unitID] = dataA
	elseif dataA and dataB and dataC then
		--3d coordinates format
		unitTargets[unitID] = {dataA,dataB,dataC}
	end
end

local function pos2func(u2) 
	local _,_,_,x2,y2,z2 = spGetUnitPosition(u2,true)
	return x2,y2,z2
end

local function unitDraw(u1, u2) 
	local _,_,_,x1,y1,z1 = spGetUnitPosition(u1,true)
	glVertex(x1,y1,z1)
	glVertex(CallAsTeam(myTeam, pos2func, u2)) -- check teams los for target
end

local function unitDrawVisible(u1, u2)
	local _,_,_,x1,y1,z1 = spGetUnitPosition(u1,true)
	local _,_,_,x2,y2,z2 = spGetUnitPosition(u2,true)
	glVertex(x1,y1,z1)
	glVertex(x2,y2,z2)
end

local function terrainDraw(u, x, y, z)
	local _,_,_,x1,y1,z1 = spGetUnitPosition(u,true)
	glVertex(x1,y1,z1)
	glVertex(x,y,z)
end


function gadget:DrawWorld()
	local alt,ctrl,meta,shift = spGetModKeyState()
	local spectator = spGetSpectatingState()
	glPushAttrib(GL.LINE_BITS)
	glLineStipple(true)
	glDepthTest(false)
	glLineWidth(1.4)
	glColor(1, 0.75, 0, 1)
	for unitID, unitTarget in pairs(unitTargets) do
		if drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)] or spIsUnitSelected(unitID) then
			if spectator or spGetUnitAllyTeam(unitID) == myAllyTeam then
				glBeginEnd(GL_LINES, function()
					if tonumber(unitTarget) and spValidUnitID(unitTarget) then
						--single unit target
						if spectator then
							unitDrawVisible(unitID, unitTarget)
						else
							local los = spGetUnitLosState(unitTarget, myAllyTeam, false)
							if los and (los.los or los.radar) then
								unitDraw(unitID, unitTarget)
							end
						end
					elseif not tonumber(unitTarget) and unitTarget then
						-- 3d coordinate target
						terrainDraw(unitID, unitTarget[1],unitTarget[2],unitTarget[3])
					end
				end)
			end
		end
	end
	glColor(1,1,1,1)
	glLineStipple(false)
	glPopAttrib()
	drawTarget = {}
end


end
