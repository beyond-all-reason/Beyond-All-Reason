
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


--include("LuaRules/Configs/customcmds.h.lua")

local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_UNIT_SET_TARGET_RECTANGLE = 34925

--export to CMD table
CMD.UNIT_SET_TARGET = CMD_UNIT_SET_TARGET
CMD[CMD_UNIT_SET_TARGET] = 'UNIT_SET_TARGET'
CMD.UNIT_CANCEL_TARGET = CMD_UNIT_SET_TARGET
CMD[CMD_UNIT_CANCEL_TARGET] = 'UNIT_CANCEL_TARGET'
CMD.UNIT_SET_TARGET_RECTANGLE = CMD_UNIT_SET_TARGET_RECTANGLE
CMD[CMD_UNIT_SET_TARGET_RECTANGLE] = 'UNIT_SET_TARGET_RECTANGLE'


local deleteMaxDistance = 30

local spGetUnitRulesParam = Spring.GetUnitRulesParam

function GG.GetUnitTarget(unitID)
	local targetID = spGetUnitRulesParam(unitID,"targetID")
	targetID = tonumber(targetID) and targetID >= 0 and targetID or nil
	if not targetID then
		targetID = {
			spGetUnitRulesParam(unitID,"targetCoordX"),
			spGetUnitRulesParam(unitID,"targetCoordY"),
			spGetUnitRulesParam(unitID,"targetCoordZ"),
		}
		targetID = targetID[1] ~= -1 and targetID[3] ~= -1 and targetID or nil
	end
	return targetID
end
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------
if (gadgetHandler:IsSyncedCode()) then --SYNCED
--------------------------------------------------------------------------------
--------------------------------------------------------------------------------

local spInsertUnitCmdDesc		= Spring.InsertUnitCmdDesc
local spGetUnitAllyTeam			= Spring.GetUnitAllyTeam
local spSetUnitTarget			= Spring.SetUnitTarget
local spValidUnitID				= Spring.ValidUnitID
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetUnitDefID			= Spring.GetUnitDefID
local spGetUnitLosState			= Spring.GetUnitLosState
local spGetUnitSeparation		= Spring.GetUnitSeparation
local spGetUnitIsCloaked		= Spring.GetUnitIsCloaked
local spGetUnitPosition			= Spring.GetUnitPosition
local spGetUnitTeam				= Spring.GetUnitTeam
local spAreTeamsAllied			= Spring.AreTeamsAllied
local spGetUnitsInRectangle		= Spring.GetUnitsInRectangle
local spGetUnitsInCylinder		= Spring.GetUnitsInCylinder
local spSetUnitRulesParam		= Spring.SetUnitRulesParam
local spGetCommandQueue     	= Spring.GetCommandQueue
local spGetUnitWeaponTryTarget	= Spring.GetUnitWeaponTryTarget
local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
local spGetUnitWeaponTestRange	= Spring.GetUnitWeaponTestRange
local spGetUnitWeaponHaveFreeLineOfFire	= Spring.GetUnitWeaponHaveFreeLineOfFire
local spGetUnitWeaponTarget		= Spring.GetUnitWeaponTarget

local tremove					= table.remove

local diag						= math.diag

local CMD_STOP					= CMD.STOP


local SlowUpdate				= 15


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
		validUnits[i] = true
	end
end

unitTargets = {} -- data holds all unitID data

--------------------------------------------------------------------------------
-- Commands

local tooltipText = 'Sets a top priority attack target, to be used if within range (not removed by move commands)'

local unitSetTargetRectangleCmdDesc = {
	id		= CMD_UNIT_SET_TARGET_RECTANGLE,
	type	= CMDTYPE.ICON_UNIT_OR_RECTANGLE,
	name	= 'Target',
	action	= 'settargetrectangle',
	cursor	= 'settarget',
	tooltip	= tooltipText,
	hidden	= true,
}

local unitSetTargetCircleCmdDesc = {
	id		= CMD_UNIT_SET_TARGET,
	type	= CMDTYPE.ICON_UNIT_OR_AREA,
	name	= '\n  Set\nTarget\n', --extra spaces center the 'Set' text
	action	= 'settarget',
	cursor	= 'settarget',
	tooltip	= tooltipText,
	hidden	= false,
}


local unitCancelTargetCmdDesc = {
	id		= CMD_UNIT_CANCEL_TARGET,
	type	= CMDTYPE.ICON,
	name	= '\nCancel\nTarget\n',
	action	= 'canceltarget',
	tooltip	= 'Removes top priority target, if set',
	hidden	= false,
}



--------------------------------------------------------------------------------
-- Target Handling

local function AreUnitsAllied(unitID,targetID)
	--if a unit dies the unitID will still be valid for current frame unit UnitDestroyed is called
	--this means that code can reach here and spGetUnitTeam returns nil, therefore we'll nil check before
	--executing spAreTeamsAllied, returning true to being allied disables rest of the code without having
	--to pass weird nil threestate to be further checked
	local ownTeam,enemyTeam = spGetUnitTeam(unitID),spGetUnitTeam(targetID)
	return ownTeam and enemyTeam and spAreTeamsAllied(ownTeam,enemyTeam)
end

local function TargetCanBeReached(unitID, teamID, weaponList, target)
	for weaponID in pairs(weaponList) do
		--GetUnitWeaponTryTarget tests both target type validity and target to be reachable for the moment
		if tonumber(target) and CallAsTeam(teamID, spGetUnitWeaponTryTarget, unitID, weaponID, target) then
			return weaponID
		--FIXME: GetUnitWeaponTryTarget is broken in 99.0 for ground targets, yet spGetUnitWeaponTestTarget, spGetUnitWeaponTestRange and spGetUnitWeaponHaveFreeLineOfFire individually work
		-- replace back with a single function when fixed
		elseif not tonumber(target) and CallAsTeam(teamID, spGetUnitWeaponTestTarget, unitID, weaponID, target[1], target[2], target[3]) and
			CallAsTeam(teamID, spGetUnitWeaponTestRange, unitID, weaponID, target[1], target[2], target[3]) and
			CallAsTeam(teamID, spGetUnitWeaponHaveFreeLineOfFire, unitID, weaponID, target[1], target[2], target[3]) then
				return weaponID
		end
	end
end

local function checkTarget(unitID, target)
	return (tonumber(target) and spValidUnitID(target) and not AreUnitsAllied(unitID,target)) or (not tonumber(target) and target )
end


local function setTarget(unitID, targetData)
	local unitData = unitTargets[unitID]
	if not TargetCanBeReached(unitID, unitData.teamID, unitData.weapons, targetData.target) then
		return false
	end
	if tonumber(targetData.target) then
		if not spSetUnitTarget(unitID, targetData.target,false,targetData.userTarget) then
			return false
		end

		spSetUnitRulesParam(unitID,"targetID",targetData.target)
		spSetUnitRulesParam(unitID,"targetCoordX",-1)
		spSetUnitRulesParam(unitID,"targetCoordY",-1)
		spSetUnitRulesParam(unitID,"targetCoordZ",-1)

	elseif not tonumber(targetData.target) then

		if not spSetUnitTarget(unitID, targetData.target[1],targetData.target[2],targetData.target[3],false,targetData.userTarget) then
			return false
		end

		spSetUnitRulesParam(unitID,"targetID",-1)
		spSetUnitRulesParam(unitID,"targetCoordX",targetData.target[1])
		spSetUnitRulesParam(unitID,"targetCoordY",targetData.target[2])
		spSetUnitRulesParam(unitID,"targetCoordZ",targetData.target[3])
	end
	return true
end

local function removeUnseenTarget(targetData,attackerAllyTeam)
	if tonumber(targetData.target) and not targetData.alwaysSeen and spValidUnitID(targetData.target) then
		local los = spGetUnitLosState(targetData.target, attackerAllyTeam, false)
		if not (los and (los.los or los.radar)) then
			if targetData.unseenTargetTimer == UNSEEN_TIMEOUT then
				return true
			elseif not targetData.unseenTargetTimer then
				targetData.unseenTargetTimer = 1
			else
				targetData.unseenTargetTimer = targetData.unseenTargetTimer + 1
			end
		elseif targetData.unseenTargetTimer then
			targetData.unseenTargetTimer = nil
		end
	end
	return false
end

local function distance(posA,posB)
	diag(posA[1]-posB[1],posA[2]-posB[2],posA[3]-posB[3])
end

--------------------------------------------------------------------------------
-- Unit adding/removal

local function sendTargetsToUnsynced(unitID)
	for index,targetData in ipairs(unitTargets[unitID].targets) do
		if tonumber(targetData.target) then
			SendToUnsynced("targetList",unitID,index,targetData.alwaysSeen,targetData.ignoreStop,targetData.userTarget,targetData.target)
		else
			SendToUnsynced("targetList",unitID,index,targetData.alwaysSeen,targetData.ignoreStop,targetData.userTarget,targetData.target[1],targetData.target[2],targetData.target[3])
		end
	end
end

local function addUnitTargets(unitID, unitDefID, targets, append)
	if spValidUnitID(unitID) then
		local data = unitTargets[unitID]
		if not data then
			data = {
				targets = {},
				teamID = spGetUnitTeam(unitID),
				allyTeam = spGetUnitAllyTeam(unitID),
				weapons = UnitDefs[unitDefID].weapons,
			}
		end
		if not append then
			data.targets = {}
		end
		for _,targetData in ipairs(targets) do
			if checkTarget(unitID,targetData.target) then
				data.targets[#data.targets+1] = targetData
			end
		end
		if #data.targets == 0 then
			return
		end
		unitTargets[unitID] = data
		sendTargetsToUnsynced(unitID)
		if setTarget(unitID,data.targets[1]) then
			if data.currentIndex ~= 1 then
				unitTargets[unitID].currentIndex = 1
				SendToUnsynced("targetIndex",unitID,1)
			end
		end
	end
end

local function removeUnit(unitID)
	spSetUnitTarget(unitID,nil)
	spSetUnitRulesParam(unitID,"targetID",-1)
	spSetUnitRulesParam(unitID,"targetCoordX",-1)
	spSetUnitRulesParam(unitID,"targetCoordY",-1)
	spSetUnitRulesParam(unitID,"targetCoordZ",-1)
	if unitTargets[unitID] then
		SendToUnsynced("targetList",unitID,0)
	end
	unitTargets[unitID] = nil
end

function removeTarget(unitID,index)
	tremove(unitTargets[unitID].targets,index)
	if #unitTargets[unitID].targets == 0 then
		removeUnit(unitID)
	else
		sendTargetsToUnsynced(unitID)
	end
end

function GG.getUnitTargetList(unitID)
	return unitTargets[unitID] and unitTargets[unitID].targets
end

function GG.getUnitTargetIndex(unitID)
	return unitTargets[unitID] and unitTargets[unitID].currentIndex
end

function gadget:Initialize()
	-- register command
	gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
	gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
	gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)

	-- load active units
	for _, unitID in pairs(Spring.GetAllUnits()) do
		gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
	end

end

function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
	if validUnits[unitDefID] then
		--spInsertUnitCmdDesc(unitID, unitSetTargetRectangleCmdDesc)
		spInsertUnitCmdDesc(unitID, unitSetTargetCircleCmdDesc)
		spInsertUnitCmdDesc(unitID, unitCancelTargetCmdDesc)
		if unitTargets[builderID] then
			addUnitTargets(unitID,unitDefID,unitTargets[builderID].targets,false)
		end
	end
end

function gadget:UnitGiven(unitID, unitDefID, unitTeam)
	removeUnit(unitID)
end

function gadget:UnitTaken(unitID, unitDefID, unitTeam)
	removeUnit(unitID)
end

function gadget:UnitDestroyed(unitID, unitDefID, unitTeam)
	removeUnit(unitID)
end


--------------------------------------------------------------------------------
-- Command Tracking

local function processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_UNIT_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE then
		if validUnits[unitDefID] then
			local weaponList = UnitDefs[unitDefID].weapons
			local append = cmdOptions.shift
			local userTarget = not cmdOptions.internal
			local ignoreStop = cmdOptions.ctrl
			local targets = {}
			if #cmdParams == 6 then
				--rectangle
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

				targets = CallAsTeam(teamID, spGetUnitsInRectangle, left, top, right, bot)
				--TODO: perhaps we should insert a new order on top of queue without cancelling area order
				-- much like area reclaim, etc, until there are no enemies available


			elseif #cmdParams == 4 then
				-- if radius is 0, it's a single click
				if cmdParams[4] == 0 then
					--coordinate
					cmdParams[4] = nil
					targets = {cmdParams}
				else
					--circle
					targets = CallAsTeam(teamID, spGetUnitsInCylinder, cmdParams[1], cmdParams[3], cmdParams[4])
					-- perhaps we should insert a new order on top of queue without cancelling area order
				end
			elseif #cmdParams == 3 then
				--coordinate
				targets = {cmdParams}
			elseif #cmdParams == 1 then
				--single target
				targets = cmdParams
			elseif #cmdParams == 0 then
				--no param, unset target
				removeUnit(unitID)
			end
			--filter target list
			if targets then
				local targetList = {}
				for _,target in ipairs(targets) do
					--accept either coordinate targets or enemy units
					if not tonumber(target) or ( spValidUnitID(target) and not spAreTeamsAllied(teamID,spGetUnitTeam(target))) then
						local validTarget = false
						--only accept valid targets
						for weaponID in ipairs(weaponList) do
							--unit test target only tests the validity of the target type, not range or other variable things
							if tonumber(target) then
								--unitID target
								validTarget = spGetUnitWeaponTestTarget(unitID,weaponID,target)
							else
								--coordinate target
								validTarget = spGetUnitWeaponTestTarget(unitID,weaponID,target[1],target[2],target[3])
							end
							if validTarget then
								break
							end
						end
						if validTarget then
							targetList[#targetList+1] = {
								alwaysSeen = not tonumber(target) or UnitDefs[spGetUnitDefID(target)].isBuilding or UnitDefs[spGetUnitDefID(target)].speed == 0,
								ignoreStop = ignoreStop,
								userTarget = userTarget,
								target = target,
							}
						end
					end
				end
				if #targetList > 0 then
					addUnitTargets(unitID, unitDefID, targetList, append )
				end
			end
		end
		return true
	elseif cmdID == CMD_UNIT_CANCEL_TARGET then
		if unitTargets[unitID] then
			if #cmdParams == 0 then
				removeUnit(unitID)
			elseif #cmdParams == 1 and cmdOptions.alt then
				--it's a position in the queue
				removeTarget(unitID,cmdParams[1])
			elseif #cmdParams == 1 and not cmdOptions.alt then
				--target is unitID
				for index,val in ipairs(unitTargets[unitID].targets) do
					if tonumber(val) then --element is a unitID
						if val == cmdParams[1] then
							removeTarget(unitID,index)
							break
						end
					end
				end
			elseif  #cmdParams == 3 then
				--target is a location
				for index,val in ipairs(unitTargets[unitID].targets) do
					if not tonumber(val) and val then --element is not a unitID
						if distance(val,cmdParams) < deleteMaxDistance then
							removeTarget(unitID,index)
							break
						end
					end
				end
			end
		end
		return true
	end
end

function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdTag, cmdParams, cmdOptions)
	processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if cmdID == CMD_STOP then
		if unitTargets[unitID] and not unitTargets[unitID].ignoreStop then
			removeUnit(unitID)
		end
	end
end

function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
	if spGetCommandQueue(unitID, -1, false) == 0 or not cmdOptions.meta then
		if processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions) then
			return false --command was used & fully processed, so block command
		elseif cmdID == CMD_STOP then
			if unitTargets[unitID] and not unitTargets[unitID].ignoreStop then
				removeUnit(unitID)
			end
		end
	end
	return true  -- command was not used OR was used but not fully processed, so don't block command
end

--------------------------------------------------------------------------------
-- Target update

function gadget:GameFrame(n)
	if n%SlowUpdate == SlowUpdate-1 then 
		-- timing synced with slow update to reduce attack jittering
		-- SlowUpdate-1 causes attack command to override target command
		-- 0 causes target command to take precedence

		for unitID, unitData in pairs(unitTargets) do
			local targetIndex
			for index,targetData in ipairs(unitData.targets) do
				if not checkTarget(unitID,targetData.target) then
					removeTarget(unitID,index)
				else
					if setTarget(unitID,targetData) then
						targetIndex = index
						break
					end
				end
			end
			if unitData.currentIndex ~= targetIndex then
				unitData.currentIndex = targetIndex
				SendToUnsynced("targetIndex",unitID,targetIndex)
			end
		end
	end

	if n%USEEN_UPDATE_FREQUENCY == 0 then
		for unitID, unitData in pairs(unitTargets) do
			for index,targetData in ipairs(unitData.targets) do
				if removeUnseenTarget(targetData,unitData.allyTeam) then
					removeTarget(unitID,index)
				end
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
local GL_LINE_STRIP	= GL.LINE_STRIP
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
local spGetLastUpdateSeconds= Spring.GetLastUpdateSeconds

local GetUnitTarget = GG.GetUnitTarget

local myAllyTeam = spGetMyAllyTeamID()
local myTeam = spGetMyTeamID()
local myPlayerID = Spring.GetMyPlayerID()

local lineWidth = 1.4
local queueColour = {1, 0.75, 0, 0.7}
local commandColour = {1, 0.5, 0, 0.7}

local drawAllTargets = {}
local drawTarget = {}
local targetList = {}


function gadget:Initialize()
	gadgetHandler:AddChatAction("targetdrawteam", handleTargetDrawEvent,"toggles drawing targets for units, params: teamID doDraw")
	gadgetHandler:AddChatAction("targetdrawunit", handleUnitTargetDrawEvent,"toggles drawing targets for units, params: unitID")
	gadgetHandler:AddSyncAction("targetList", handleTargetListEvent)
	gadgetHandler:AddSyncAction("targetIndex", handleTargetIndexEvent)

	-- register cursor
	Spring.AssignMouseCursor("settarget", "cursorsettarget", false)
	--show the command in the queue
	Spring.SetCustomCommandDrawData(CMD_UNIT_SET_TARGET,"settarget",queueColour,true)
end

function gadget:Shutdown()
	gadgetHandler:RemoveChatAction("targetdrawteam")
	gadgetHandler:RemoveChatAction("targetdrawunit")
	gadgetHandler:RemoveSyncAction("targetList")
	gadgetHandler:RemoveSyncAction("targetIndex")
end

function GG.getUnitTargetList(unitID)
	return targetList[unitID] and targetList[unitID].targets
end

function GG.getUnitTargetIndex(unitID)
	return targetList[unitID] and targetList[unitID].currentIndex
end

function handleTargetListEvent(_,unitID,index,alwaysSeen,ignoreStop,userTarget,targetA,targetB,targetC)
	if index == 0 then
		targetList[unitID] = nil
		return
	end
	targetList[unitID] = targetList[unitID] or {}
	if index == 1 then
		targetList[unitID].targets = {}
	end
	targetList[unitID].targets[index] = {
		alwaysSeen = alwaysSeen,
		ignoreStop = ignoreStop,
		userTarget = userTarget,
		target = (not tonumber(targetB) and targetA ) or {targetA,targetB,targetC},
	}
end

function handleTargetIndexEvent(_,unitID,index)
	if not targetList[unitID] then
		return
	end
	targetList[unitID].targetIndex = index
end

function handleUnitTargetDrawEvent(_,_,params)
	drawTarget[tonumber(params[1])] = true
    return true
end

function handleTargetDrawEvent(_,_,params)
	local teamID = tonumber(params[1])
	local doDraw = tonumber(params[2]) ~= 0
	drawAllTargets[teamID] = doDraw
    return true
end

function handleTargetChangeEvent(_,unitID,dataA,dataB,dataC)
	if not dataB then
		--single unitID format
		unitTargets[unitID] = dataA
	elseif dataA and dataB and dataC then
		--3d coordinates format
		unitTargets[unitID] = {dataA,dataB,dataC}
	end
    return true
end

local function pos2func(unitID)
	local _,_,_,_,_,_,x2,y2,z2 = spGetUnitPosition(unitID,true,true)
	return x2,y2,z2
end

local function drawTargetCommand(targetData,spectator,myTeam,myAllyTeam)
	if targetData and targetData.userTarget and tonumber(targetData.target) and spValidUnitID(targetData.target) then
		--single unit target
		if spectator then
			local _,_,_,_,_,_,x2,y2,z2 = spGetUnitPosition(targetData.target,true,true)
			glVertex(x2,y2,z2)
		else
			local los = spGetUnitLosState(targetData.target, myAllyTeam, false)
			if los and (los.los or los.radar) then
				-- check teams los for target
				glVertex(CallAsTeam(myTeam, pos2func, targetData.target))
			end
		end
	elseif targetData and targetData.userTarget and not tonumber(targetData.target) and targetData.target then
		-- 3d coordinate target
		glVertex(targetData.target)
	end
end

local function drawCurrentTarget(unitID, unitData, spectator, myTeam, myAllyTeam)
	local _,_,_,x1,y1,z1 = spGetUnitPosition(unitID,true)
	glVertex(x1,y1,z1)
	--TODO: show cursor animation at target point
	drawTargetCommand(unitData.targets[unitData.targetIndex],spectator,myTeam,myAllyTeam)
end

local function drawTargetQueue(unitID, unitData, spectator, myTeam, myAllyTeam)
	local _,_,_,x1,y1,z1 = spGetUnitPosition(unitID,true)
	glVertex(x1,y1,z1)
	for _,targetData in ipairs(unitData.targets) do
		drawTargetCommand(targetData,spectator,myTeam,myAllyTeam)
	end
end

function gadget:DrawWorld()
	local spectator = spGetSpectatingState()
	glPushAttrib(GL.LINE_BITS)
	glLineStipple("any") -- use spring's default line stipple pattern, moving
	glDepthTest(false)
	glLineWidth(lineWidth)
	for unitID, unitData in pairs(targetList) do
		if drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)] or spIsUnitSelected(unitID) then
			if spectator or spGetUnitAllyTeam(unitID) == myAllyTeam then
				glColor(queueColour)
				glBeginEnd(GL_LINE_STRIP, drawTargetQueue, unitID, unitData, spectator, myTeam, myAllyTeam)
				if unitData.targetIndex then
					glColor(commandColour)
					glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData, spectator, myTeam, myAllyTeam)
				end
			end
		end
	end
	glColor(1,1,1,1)
	glLineStipple(false)
	glPopAttrib()
	drawTarget = {}
end


end
