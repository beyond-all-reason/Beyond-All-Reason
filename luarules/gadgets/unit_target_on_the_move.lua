function gadget:GetInfo()
	return {
		name = "Target on the move",
		desc = "Adds a command to set a priority attack target",
		author = "Google Frog, adapted by BrainDamage, added priority to Dgun by doo",
		date = "06/05/2013",
		license = "GNU GPL, v2 or later",
		layer = 0,
		enabled = true,
	}
end


local CMD_UNIT_SET_TARGET_NO_GROUND = 34922
local CMD_UNIT_SET_TARGET = 34923
local CMD_UNIT_CANCEL_TARGET = 34924
local CMD_UNIT_SET_TARGET_RECTANGLE = 34925
--export to CMD table
CMD.CMD_UNIT_SET_TARGET_NO_GROUND = CMD_UNIT_SET_TARGET_NO_GROUND
CMD[CMD_UNIT_SET_TARGET_NO_GROUND] = 'UNIT_SET_TARGET_NO_GROUND'
CMD.UNIT_SET_TARGET = CMD_UNIT_SET_TARGET
CMD[CMD_UNIT_SET_TARGET] = 'UNIT_SET_TARGET'
CMD.UNIT_CANCEL_TARGET = CMD_UNIT_SET_TARGET
CMD[CMD_UNIT_CANCEL_TARGET] = 'UNIT_CANCEL_TARGET'
CMD.UNIT_SET_TARGET_RECTANGLE = CMD_UNIT_SET_TARGET_RECTANGLE
CMD[CMD_UNIT_SET_TARGET_RECTANGLE] = 'UNIT_SET_TARGET_RECTANGLE'

local deleteMaxDistance = 30

local spGetUnitRulesParam = Spring.GetUnitRulesParam

function GG.GetUnitTarget(unitID)
	local targetID = spGetUnitRulesParam(unitID, "targetID")
	targetID = tonumber(targetID) and targetID >= 0 and targetID or nil
	if not targetID then
		targetID = {
			spGetUnitRulesParam(unitID, "targetCoordX"),
			spGetUnitRulesParam(unitID, "targetCoordY"),
			spGetUnitRulesParam(unitID, "targetCoordZ"),
		}
		targetID = targetID[1] ~= -1 and targetID[3] ~= -1 and targetID or nil
	end
	return targetID
end


if gadgetHandler:IsSyncedCode() then

	-- Unseen targets will be removed after max USEEN_UPDATE_FREQUENCY frames.
	-- Should be small enough to not be evident, and big enough to save perf.
	local USEEN_UPDATE_FREQUENCY = 15

	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spSetUnitTarget = Spring.SetUnitTarget
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitLosState = Spring.GetUnitLosState
	local spGetUnitTeam = Spring.GetUnitTeam
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spSetUnitRulesParam = Spring.SetUnitRulesParam
	local spGetCommandQueue = Spring.GetCommandQueue
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local spGiveOrderArrayToUnit = Spring.GiveOrderArrayToUnit
	local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
	local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
	local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
	local spGetGroundHeight = Spring.GetGroundHeight

	local tremove = table.remove

	local diag = math.diag

	local CMD_STOP = CMD.STOP
	local CMD_DGUN = CMD.DGUN

	local validUnits = {}
	local unitWeapons = {}
	local unitAlwaysSeen = {}
	for unitDefID, unitDef in pairs(UnitDefs) do
		if (unitDef.canAttack and unitDef.maxWeaponRange and unitDef.maxWeaponRange > 0) then
			validUnits[unitDefID] = true
		end
		local weapons = unitDef.weapons

		if #weapons > 0 then
			-- filter this down to only the params that actually get used, weapons is an array full of stuff!
			unitWeapons[unitDefID] = weapons
			for i=1, #weapons do
				unitWeapons[unitDefID][i] = true
			end
		end
		unitAlwaysSeen[unitDefID] = unitDef.isBuilding or unitDef.speed == 0
	end

	-- fastpass for units that don't have an attack command for other reasons
	if UnitDefNames.legpede then
		validUnits[UnitDefNames.legpede.id] = true
	end

	local unitTargets = {} -- data holds all unitID data
	local pausedTargets = {}
	--------------------------------------------------------------------------------
	-- Commands

	local tooltipText = 'Set a priority attack target,\nto be used when within range\n(not removed by move commands)'

	local unitSetTargetNoGroundCmdDesc = {
		id = CMD_UNIT_SET_TARGET_NO_GROUND,
		type = CMDTYPE.ICON_UNIT,
		name = 'Set Unit Target',
		action = 'settargetnoground',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = true,
	}

	local unitSetTargetRectangleCmdDesc = {
		id = CMD_UNIT_SET_TARGET_RECTANGLE,
		type = CMDTYPE.ICON_UNIT_OR_RECTANGLE,
		name = 'Set Target',
		action = 'settargetrectangle',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = true,
	}

	local unitSetTargetCircleCmdDesc = {
		id = CMD_UNIT_SET_TARGET,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Set Target', --extra spaces center the 'Set' text
		action = 'settarget',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = false,
	}

	local unitCancelTargetCmdDesc = {
		id = CMD_UNIT_CANCEL_TARGET,
		type = CMDTYPE.ICON,
		name = 'Cancel Target',
		action = 'canceltarget',
		tooltip = 'Removes top priority target, if set',
		hidden = false,
	}



	--------------------------------------------------------------------------------
	-- Target Handling

	local function AreUnitsAllied(unitID, targetID)
		--if a unit dies the unitID will still be valid for current frame unit UnitDestroyed is called
		--this means that code can reach here and spGetUnitTeam returns nil, therefore we'll nil check before
		--executing spAreTeamsAllied, returning true to being allied disables rest of the code without having
		--to pass weird nil threestate to be further checked
		local ownTeam, enemyTeam = spGetUnitTeam(unitID), spGetUnitTeam(targetID)
		return ownTeam and enemyTeam and spAreTeamsAllied(ownTeam, enemyTeam)
	end

	local function TargetCanBeReached(unitID, teamID, weaponList, target)
		if not weaponList then
			return
		end
		for weaponID in pairs(weaponList) do
			--GetUnitWeaponTryTarget tests both target type validity and target to be reachable for the moment
			if tonumber(target) and CallAsTeam(teamID, spGetUnitWeaponTryTarget, unitID, weaponID, target) then
				return weaponID
			elseif not tonumber(target) and CallAsTeam(teamID, spGetUnitWeaponTestTarget, unitID, weaponID, target[1], target[2], target[3]) and CallAsTeam(teamID, spGetUnitWeaponTestRange, unitID, weaponID, target[1], target[2], target[3]) then
				if CallAsTeam(teamID, spGetUnitWeaponHaveFreeLineOfFire, unitID, weaponID, nil, nil, nil, target[1], target[2], target[3]) then
					return weaponID
				end
			end
		end
	end

	local function checkTarget(unitID, target)
		return (tonumber(target) and spValidUnitID(target) and not AreUnitsAllied(unitID, target)) or (not tonumber(target) and target)
	end

	local function setTarget(unitID, targetData)
		local unitData = unitTargets[unitID]
		if not TargetCanBeReached(unitID, unitData.teamID, unitData.weapons, targetData.target) then
			local currentCmdID = spGetUnitCurrentCommand(unitID)
			if currentCmdID and currentCmdID == CMD.ATTACK then
				return false
			else
				Spring.SetUnitTarget(unitID, nil)
				return false
			end
		end
		if tonumber(targetData.target) then
			if not spSetUnitTarget(unitID, targetData.target, false, targetData.userTarget) then
				return false
			end

			spSetUnitRulesParam(unitID, "targetID", targetData.target)
			spSetUnitRulesParam(unitID, "targetCoordX", -1)
			spSetUnitRulesParam(unitID, "targetCoordY", -1)
			spSetUnitRulesParam(unitID, "targetCoordZ", -1)

		elseif not tonumber(targetData.target) then

			if not spSetUnitTarget(unitID, targetData.target[1], targetData.target[2], targetData.target[3], false, targetData.userTarget) then
				return false
			end

			spSetUnitRulesParam(unitID, "targetID", -1)
			spSetUnitRulesParam(unitID, "targetCoordX", targetData.target[1])
			spSetUnitRulesParam(unitID, "targetCoordY", targetData.target[2])
			spSetUnitRulesParam(unitID, "targetCoordZ", targetData.target[3])
		end
		return true
	end

	local function removeUnseenTarget(targetData, attackerAllyTeam)
		if not targetData.alwaysSeen and tonumber(targetData.target) and spValidUnitID(targetData.target) then
			local los = spGetUnitLosState(targetData.target, attackerAllyTeam, true)
			if not los or (los % 4 == 0) then
				return true
			end
		end
		return false
	end

	local function distance(posA, posB)
		diag(posA[1] - posB[1], posA[2] - posB[2], posA[3] - posB[3])
	end

	--------------------------------------------------------------------------------
	-- Unit adding/removal

	local function sendTargetsToUnsynced(unitID)
		for index, targetData in ipairs(unitTargets[unitID].targets) do
			if tonumber(targetData.target) then
				SendToUnsynced("targetList", unitID, index, targetData.alwaysSeen, targetData.ignoreStop, targetData.userTarget, targetData.target)
			else
				SendToUnsynced("targetList", unitID, index, targetData.alwaysSeen, targetData.ignoreStop, targetData.userTarget, targetData.target[1], targetData.target[2], targetData.target[3])
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
					weapons = unitWeapons[unitDefID],
				}
			end
			if not append then
				data.targets = {}
			end
			local currentTargets = {}
			for i, targetData in ipairs(data.targets) do
				currentTargets[targetData.target] = true
			end
			for _, targetData in ipairs(targets) do
				if not currentTargets[targetData.target] then	-- check if this target isnt already in targetData
					if checkTarget(unitID, targetData.target) then
						data.targets[#data.targets + 1] = targetData
					end
				end
			end
			if #data.targets == 0 then
				return
			end
			unitTargets[unitID] = data
			sendTargetsToUnsynced(unitID)
			if setTarget(unitID, data.targets[1]) then
				if data.currentIndex ~= 1 then
					unitTargets[unitID].currentIndex = 1
					SendToUnsynced("targetIndex", unitID, 1)
				end
			end
		end
	end

	local function removeUnit(unitID, keeptrack)
		spSetUnitTarget(unitID, nil)
		spSetUnitRulesParam(unitID, "targetID", -1)
		spSetUnitRulesParam(unitID, "targetCoordX", -1)
		spSetUnitRulesParam(unitID, "targetCoordY", -1)
		spSetUnitRulesParam(unitID, "targetCoordZ", -1)
		if unitTargets[unitID] and not keeptrack == true then
			SendToUnsynced("targetList", unitID, 0)
		end
		unitTargets[unitID] = nil
	end

	local function removeTarget(unitID, index)
		tremove(unitTargets[unitID].targets, index)
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
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)
		-- register allowcommand callin
		gadgetHandler:RegisterAllowCommand(CMD_STOP)
		gadgetHandler:RegisterAllowCommand(CMD_DGUN)
		gadgetHandler:RegisterAllowCommand(CMD.INSERT)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_CANCEL_TARGET)

		-- load active units
		for _, unitID in pairs(Spring.GetAllUnits()) do
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
		end

	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if validUnits[unitDefID] then
			--spInsertUnitCmdDesc(unitID, unitSetTargetRectangleCmdDesc)
			spInsertUnitCmdDesc(unitID, unitSetTargetNoGroundCmdDesc)
			spInsertUnitCmdDesc(unitID, unitSetTargetCircleCmdDesc)
			spInsertUnitCmdDesc(unitID, unitCancelTargetCmdDesc)
			if unitTargets[builderID] then
				addUnitTargets(unitID, unitDefID, unitTargets[builderID].targets, false)
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
		if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND or cmdID == CMD_UNIT_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE then
			if validUnits[unitDefID] then
				local weaponList = unitWeapons[unitDefID]
				local append = cmdOptions.shift or false
				local userTarget = not cmdOptions.internal
				local ignoreStop = cmdOptions.ctrl
				if #cmdParams > 3 and not (#cmdParams == 4 and cmdParams[4] == 0) then
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
					elseif #cmdParams == 4 then
						--circle
						targets = CallAsTeam(teamID, spGetUnitsInCylinder, cmdParams[1], cmdParams[3], cmdParams[4])
					end
					if targets then
						local orders = {}
						local optionKeys = {}
						local optionKeysCount = 0
						--re-insert back the command options
						for optionName, optionValue in pairs(cmdOptions) do
							if optionName == 'shift' then
								-- Always add shift to enforce chained commands, but clear orders at
								-- the beginning of our order chain when not an append (shift).
								optionKeysCount = optionKeysCount + 1
								optionKeys[optionKeysCount] = optionName
							elseif optionValue then
								optionKeysCount = optionKeysCount + 1
								optionKeys[optionKeysCount] = optionName
							end
						end
						if not cmdOptions["shift"] and unitTargets[unitID] then
							-- Need to clear orders if not in shift, since just sending the first one
							-- as not-shift would sometimes fail if that unit is in the end not valid.
							orders[1] = {CMD_UNIT_CANCEL_TARGET, {}, {}}
						end
						local base = #orders
						for i = 1, #targets do
							local target = targets[i]
							orders[i+base] = {
								CMD_UNIT_SET_TARGET,
								{ target },
								optionKeys
							}

						end
						--re-insert in the queue as list of individual orders instead of processing directly, so that allowcommand etc can work
						spGiveOrderArrayToUnit(unitID, orders)
					end
				else
					if #cmdParams == 3 or #cmdParams == 4 then
						-- if radius is 0, it's a single click
						if cmdParams[4] == 0 then
							cmdParams[4] = nil
						end
						local target = cmdParams
						--coordinate
						local validTarget = false
						if target[2] > spGetGroundHeight(target[1], target[3]) then
							target[2] = spGetGroundHeight(target[1], target[3])
						end -- clip to ground level
						--only accept valid targets
						if weaponList then
							for weaponID in ipairs(weaponList) do
								validTarget = spGetUnitWeaponTestTarget(unitID, weaponID, target[1], target[2], target[3])
								if validTarget then
									break
								elseif target[2] < 0 and spGetUnitWeaponTestTarget(unitID, weaponID, target[1], 1, target[3]) then
									target[2] = 1 -- clip to waterlevel +1
									validTarget = spGetUnitWeaponTestTarget(unitID, weaponID, target[1], target[2], target[3])
									break
								end
							end
						end
						if validTarget then
							addUnitTargets(unitID, unitDefID, {
								{
									alwaysSeen = true,
									ignoreStop = ignoreStop,
									userTarget = userTarget,
									target = target,
								}
							}, append)
						end
					elseif #cmdParams == 1 then
						--single target
						local target = cmdParams[1]
						if spValidUnitID(target) and not spAreTeamsAllied(teamID, spGetUnitTeam(target)) then
							local validTarget = false
							--only accept valid targets
							if weaponList then
								for weaponID in ipairs(weaponList) do
									--unit test target only tests the validity of the target type, not range or other variable things
									validTarget = spGetUnitWeaponTestTarget(unitID, weaponID, target)
									if validTarget then
										break
									end
								end
							end
							if validTarget then
								addUnitTargets(unitID, unitDefID, {
									{
										alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
										ignoreStop = ignoreStop,
										userTarget = userTarget,
										target = target,
									}
								}, append)
							end
						end
					elseif #cmdParams == 0 then
						--no param, unset target
						removeUnit(unitID)
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
					removeTarget(unitID, cmdParams[1])
				elseif #cmdParams == 1 and not cmdOptions.alt then
					--target is unitID
					for index, val in ipairs(unitTargets[unitID].targets) do
						if tonumber(val) then
							--element is a unitID
							if val == cmdParams[1] then
								removeTarget(unitID, index)
								break
							end
						end
					end
				elseif #cmdParams == 3 then
					--target is a location
					for index, val in ipairs(unitTargets[unitID].targets) do
						if not tonumber(val) and val then
							--element is not a unitID
							if distance(val, cmdParams) < deleteMaxDistance then
								removeTarget(unitID, index)
								break
							end
						end
					end
				end
			end
			return true
		end
	end

	local waitingForInsertRemoval = {}
	local function pauseTargetting(unitID)
		if unitTargets[unitID] and not pausedTargets[unitID] then
			pausedTargets[unitID] = unitTargets[unitID]
			removeUnit(unitID, true)
		end
	end
	local function unpauseTargetting(unitID)
		addUnitTargets(unitID, Spring.GetUnitDefID(unitID), pausedTargets[unitID].targets, true)
		pausedTargets[unitID] = nil
	end

	local emptyCmdOptions = {}
	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdTag, cmdParams, cmdOptions)
		if type(cmdOptions) ~= 'table' then
			-- does UnitCmdDone always returns number instead of table?
			cmdOptions = emptyCmdOptions
		end
		processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		if cmdID == CMD_STOP then
			if unitTargets[unitID] and not unitTargets[unitID].ignoreStop then
				removeUnit(unitID)
			elseif pausedTargets[unitID] then
				SendToUnsynced("targetList", unitID, 0)
				pausedTargets[unitID] = nil
			end
		else
			local activeCommandIsDgun = spGetCommandQueue(unitID, 0) ~= 0 and spGetCommandQueue(unitID, 1)[1].id == CMD_DGUN
			if pausedTargets[unitID] and not activeCommandIsDgun then
				if waitingForInsertRemoval[unitID] then
					waitingForInsertRemoval[unitID] = nil
				else
					unpauseTargetting(unitID)
				end
			elseif not pausedTargets[unitID] and activeCommandIsDgun then
				pauseTargetting(unitID)
			end
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua)
		if spGetCommandQueue(unitID, 0) == 0 or not cmdOptions.meta then
			if processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions) then
				return false --command was used & fully processed, so block command
			elseif cmdID == CMD_STOP then
				if unitTargets[unitID] and not unitTargets[unitID].ignoreStop then
					removeUnit(unitID)
				elseif pausedTargets[unitID] then
					SendToUnsynced("targetList", unitID, 0)
					pausedTargets[unitID] = nil
				end
			elseif cmdID == CMD_DGUN then
				pauseTargetting(unitID)
			elseif (cmdID == CMD.INSERT and cmdParams[2] == CMD_DGUN) then
				pauseTargetting(unitID)
				waitingForInsertRemoval[unitID] = true
			end
		end
		return true  -- command was not used OR was used but not fully processed, so don't block command
	end

	--------------------------------------------------------------------------------
	-- Target update

	function gadget:GameFrame(n)
		-- ideally timing would be synced with slow update to reduce attack jittering
		-- SlowUpdate+ causes attack command to override target command
		-- unfortunately since 103 that's not possible, attempt to override every frame
		-- it might create a slight increase of cpu usage when hundreds of units gets
		-- a set target command, howrever a quick test with 300 fidos only increased by 1%
		-- sim here

		if n % 5 == 4 then
			for unitID, unitData in pairs(unitTargets) do
				local targetIndex
				for index, targetData in ipairs(unitData.targets) do
					if not checkTarget(unitID, targetData.target) then
						removeTarget(unitID, index)
					else
						if setTarget(unitID, targetData) then
							targetIndex = index
							break
						end
					end
				end
				if unitData.currentIndex ~= targetIndex then
					unitData.currentIndex = targetIndex
					SendToUnsynced("targetIndex", unitID, targetIndex)
				end
			end
		end

		if n % USEEN_UPDATE_FREQUENCY == 0 then
			for unitID, unitData in pairs(unitTargets) do
				for index, targetData in ipairs(unitData.targets) do
					if removeUnseenTarget(targetData, unitData.allyTeam) then
						removeTarget(unitID, index)
					end
				end
			end
		end
	end



else	-- UNSYNCED



	local glVertex = gl.Vertex
	local glPushAttrib = gl.PushAttrib
	local glLineStipple = gl.LineStipple
	local glDepthTest = gl.DepthTest
	local glLineWidth = gl.LineWidth
	local glColor = gl.Color
	local glBeginEnd = gl.BeginEnd
	local glPopAttrib = gl.PopAttrib
	local GL_LINE_STRIP = GL.LINE_STRIP
	local GL_LINES = GL.LINES

	local spGetUnitPosition = Spring.GetUnitPosition
	local spGetUnitLosState = Spring.GetUnitLosState
	local spValidUnitID = Spring.ValidUnitID
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetMyTeamID = Spring.GetMyTeamID
	local spIsUnitSelected = Spring.IsUnitSelected
	local spGetSpectatingState = Spring.GetSpectatingState
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitTeam = Spring.GetUnitTeam

	local myAllyTeam = spGetMyAllyTeamID()
	local myTeam = spGetMyTeamID()
	local _, fullview = spGetSpectatingState()

	local lineWidth = 1.4
	local queueColour = { 1, 0.75, 0, 0.3 }
	local commandColour = { 1, 0.5, 0, 0.3 }

	local drawAllTargets = {}
	local drawTarget = {}
	local targetList = {}

	function gadget:Initialize()
		gadgetHandler:AddChatAction("targetdrawteam", handleTargetDrawEvent, "toggles drawing targets for units, params: teamID doDraw")
		gadgetHandler:AddChatAction("targetdrawunit", handleUnitTargetDrawEvent, "toggles drawing targets for units, params: unitID")
		gadgetHandler:AddSyncAction("targetList", handleTargetListEvent)
		gadgetHandler:AddSyncAction("targetIndex", handleTargetIndexEvent)

		-- register cursor
		Spring.AssignMouseCursor("settarget", "cursorsettarget", false)
		--show the command in the queue
		Spring.SetCustomCommandDrawData(CMD_UNIT_SET_TARGET, "settarget", queueColour, true)
		Spring.SetCustomCommandDrawData(CMD_UNIT_SET_TARGET_NO_GROUND, "settargetrectangle", queueColour, true)
		Spring.SetCustomCommandDrawData(CMD_UNIT_SET_TARGET_RECTANGLE, "settargetnoground", queueColour, true)

	end

	function gadget:PlayerChanged(playerID)
		myAllyTeam = spGetMyAllyTeamID()
		myTeam = spGetMyTeamID()
		_, fullview = spGetSpectatingState()
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

	function handleTargetListEvent(_, unitID, index, alwaysSeen, ignoreStop, userTarget, targetA, targetB, targetC)
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
			target = (not tonumber(targetB) and targetA) or { targetA, targetB, targetC },
		}
	end

	function handleTargetIndexEvent(_, unitID, index)
		if not targetList[unitID] then
			return
		end
		targetList[unitID].targetIndex = index
	end

	function handleUnitTargetDrawEvent(_, _, params)
		drawTarget[tonumber(params[1])] = true
		return true
	end

	function handleTargetDrawEvent(_, _, params)
		local teamID = tonumber(params[1])
		local doDraw = tonumber(params[2]) ~= 0
		drawAllTargets[teamID] = doDraw
		return true
	end

	--function handleTargetChangeEvent(_,unitID,dataA,dataB,dataC)
	--	if not dataB then
	--		--single unitID format
	--		unitTargets[unitID] = dataA
	--	elseif dataA and dataB and dataC then
	--		--3d coordinates format
	--		unitTargets[unitID] = {dataA,dataB,dataC}
	--	end
	--    return true
	--end
	local unitIconsDrawn = {}
	local function drawUnitTarget(cacheKey, x, y, z)
		glVertex(x, y, z)
		if not unitIconsDrawn[cacheKey] then
			-- avoid sending WorldIcons to engine at the same unit/location
			Spring.AddWorldIcon(CMD_UNIT_SET_TARGET, x, y, z)
			unitIconsDrawn[cacheKey] = true
		end
	end

	local function drawTargetCommand(targetData, myTeam, myAllyTeam)

		if targetData and targetData.userTarget then
			local target = targetData.target

			if tonumber(target) and spValidUnitID(target) then
				local _, _, _, x2, y2, z2 = spGetUnitPosition(target, false, true)
				drawUnitTarget(target, x2, y2, z2)
			elseif target and not tonumber(target) then
				-- 3d coordinate target
				local x2, y2, z2 = unpack(target)
				drawUnitTarget(x2+y2+z2, x2, y2, z2)
			end
		end
	end

	local function drawCurrentTarget(unitID, unitData, myTeam, myAllyTeam)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		drawTargetCommand(unitData.targets[unitData.targetIndex], myTeam, myAllyTeam)
	end

	local function drawTargetQueue(unitID, unitData, myTeam, myAllyTeam)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		for _, targetData in ipairs(unitData.targets) do
			drawTargetCommand(targetData, myTeam, myAllyTeam)
		end
	end

	local function drawDecorations()
		local init = false
		for unitID, unitData in pairs(targetList) do
			if drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)] or spIsUnitSelected(unitID) then
				if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
					if not init then
						init = true
						glPushAttrib(GL.LINE_BITS)
						glLineStipple("any") -- use spring's default line stipple pattern, moving
						glDepthTest(false)
						glLineWidth(lineWidth)
					end
					glColor(queueColour)
					glBeginEnd(GL_LINE_STRIP, drawTargetQueue, unitID, unitData, myTeam, myAllyTeam)
					if unitData.targetIndex then
						glColor(commandColour)
						glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData, myTeam, myAllyTeam)
					end
				end
			end
		end
		if init then
			glColor(1, 1, 1, 1)
			glLineStipple(false)
			glPopAttrib()
		end
		drawTarget = {}
		unitIconsDrawn = {}
	end

	function gadget:DrawWorld()
		if fullview then
			drawDecorations()
		else
			CallAsTeam(myAllyTeam, drawDecorations)
		end
	end

end
