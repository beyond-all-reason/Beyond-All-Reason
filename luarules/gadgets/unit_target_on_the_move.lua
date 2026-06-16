local gadget = gadget ---@type Gadget

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

local deleteMaxDistance = 30
local targetListLengthMax = 128

local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE

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
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
	local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
	local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
	local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetAllUnits = Spring.GetAllUnits
	local spGetPlayerInfo = Spring.GetPlayerInfo

	local tremove = table.remove
	local ensureTable = table.ensureTable

	local max = math.max
	local min = math.min
	local clamp = math.clamp
	local diag = math.diag
	local pairsNext = next
	local type = type

	local CMD_STOP = CMD.STOP
	local CMD_ATTACK = CMD.ATTACK
	local CMD_FIGHT = CMD.FIGHT
	local CMD_GUARD = CMD.GUARD
	local CMD_WAIT = CMD.WAIT

	local isAttackCommand = {
		[CMD_ATTACK]      = true,
		[CMD.MANUALFIRE]  = true,
		[CMD.AREA_ATTACK] = true,
		[GameCMD.AREA_ATTACK_GROUND] = true,
	}

	local validUnits = {}
	local unitWeapons = {}
	local unitAlwaysSeen = {}

	local WATERWEAPON = 0
	do
		local allowNonAttackerUnit = { legpede = true } -- Fastpass for units that don't have an attack command for other reasons.

		local function hasTargeting(weapon, canManualFire)
			local weaponDef = WeaponDefs[weapon.weaponDef]
			return weapon.slavedTo == 0
				and weaponDef.type ~= "Shield"
				and not (canManualFire and weaponDef.manualFire)
				and weaponDef.range > 10
		end

		local function canSetTarget(unitDef)
			if (unitDef.canAttack or allowNonAttackerUnit[unitDef.name]) and unitDef.maxWeaponRange > 0 then
				local canManualFire = unitDef.canManualFire
				for _, weapon in pairs(unitDef.weapons) do
					if hasTargeting(weapon, canManualFire) then
						return true
					end
				end
			end
			return false
		end

		-- FIXME: We don't know which weaponDefs have submissile. We can check `nuclear`, for now.
		local function getWeaponType(weapon, canManualFire)
			if hasTargeting(weapon, canManualFire) then
				local weaponDef = WeaponDefs[weapon.weaponDef]
				return weaponDef.waterWeapon and not weaponDef.customParams.nuclear and WATERWEAPON or 1
			else
				return false
			end
		end

		for unitDefID = 1, #UnitDefs do
			local unitDef = UnitDefs[unitDefID]
			if canSetTarget(unitDef) then
				validUnits[unitDefID] = true
				unitWeapons[unitDefID] = table.map(unitDef.weapons, function(weapon, index)
					return getWeaponType(weapon, unitDef.canManualFire), index
				end)
			end
			unitAlwaysSeen[unitDefID] = unitDef.isBuilding or unitDef.speed == 0
		end
	end

	local setTargetData = {} -- holds all unit data
	local activeTargets = {}
	local pausedTargets = {}

	-- Unlike the physical sim, unit, command, and "AI" AI respond to performance bottlenecks.
	-- Use a work queue with a sliding index to process target lists in chunks on every frame.
	local updateWorkQueue = {} -- unitID[] for target updates
	local workQueueLookup = {} -- unitID => queue index lookup -- TODO: shadows activeTargets
	local workQueueLength = 0
	local workQueueIndex = 1
	-- At most chunkSizeMin units will be processed on every frame except slow update frames.
	-- So the update interval below is matched only from (updateFrames x chunkSizeMin) units,
	-- and up to (updateFrames x chunkSizeMax) units, and could be lower or higher otherwise.
	local updateFrames = 0.1667 * Game.gameSpeed
	local chunkSizeMin = 32
	local chunkSizeMax = 1024

	local function addToQueue(unitID)
		if not workQueueLookup[unitID] then
			workQueueLength = workQueueLength + 1
			updateWorkQueue[workQueueLength] = unitID
			workQueueLookup[unitID] = workQueueLength
		end
	end

	local function removeFromQueue(unitID)
		local index = workQueueLookup[unitID]
		if index then
			if index ~= workQueueLength then
				local moveID = updateWorkQueue[workQueueLength]
				updateWorkQueue[index] = moveID
				workQueueLookup[moveID] = index
			end
			updateWorkQueue[workQueueLength] = nil
			workQueueLength = workQueueLength - 1
			workQueueLookup[unitID] = nil
			if workQueueIndex > index then
				workQueueIndex = workQueueIndex - 1
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Commands

	local tooltipText = 'Set a priority attack target,\nto be used when within range\n(not removed by move commands)'

	local unitSetTargetNoGroundCmdDesc = {
		id = CMD_UNIT_SET_TARGET_NO_GROUND,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Set Unit Target',
		action = 'settargetnoground',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = true,
		queueing = false,
	}

	local unitSetTargetCircleCmdDesc = {
		id = CMD_UNIT_SET_TARGET,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = 'Set Target', --extra spaces center the 'Set' text
		action = 'settarget',
		cursor = 'settarget',
		tooltip = tooltipText,
		hidden = false,
		queueing = false,
	}

	local unitCancelTargetCmdDesc = {
		id = CMD_UNIT_CANCEL_TARGET,
		type = CMDTYPE.ICON,
		name = 'Cancel Target',
		action = 'canceltarget',
		tooltip = 'Removes top priority target, if set',
		hidden = false,
		queueing = false,
	}



	--------------------------------------------------------------------------------
	-- Target Handling

	local function isAlliedUnit(teamID, unitID)
		local unitTeam = spGetUnitTeam(unitID)
		return unitTeam and spAreTeamsAllied(teamID, unitTeam)
	end

	local function testTargetUnit(unitID, weaponList, target)
		for weaponNum = 1, #weaponList do
			if weaponList[weaponNum] and spGetUnitWeaponTryTarget(unitID, weaponNum, target) then
				return weaponNum
			end
		end
	end

	local function testTargetPos(unitID, weaponList, x, y, z)
		for weaponNum = 1, #weaponList do
			if
				weaponList[weaponNum]
				and spGetUnitWeaponTestTarget(unitID, weaponNum, x, y, z)
				and spGetUnitWeaponTestRange(unitID, weaponNum, x, y, z)
				and spGetUnitWeaponHaveFreeLineOfFire(unitID, weaponNum, nil, nil, nil, x, y, z)
			then
				return weaponNum
			end
		end
	end

	local function testTarget(unitID, teamID, weaponList, target)
		if type(target) == "number" then
			return CallAsTeam(teamID, testTargetUnit, unitID, weaponList, target)
		else
			return CallAsTeam(teamID, testTargetPos, unitID, weaponList, target[1], target[2], target[3])
		end
	end

	local function checkTarget(teamID, target)
		return type(target) ~= "number" or not isAlliedUnit(teamID, target)
	end

	local function inAttackCommand(unitID)
		local inCommand = spGetUnitCurrentCommand(unitID)
		return inCommand and isAttackCommand[inCommand]
	end

	-- Target precedence goes before target priority and ideally after target visibility, in range, unblocked, etc.
	-- Autotargeting "target priority" is then a weighted value, and Set Target priority uses the order of the list.
	local function hasTargetPrecedence(unitID)
		local inCommand, _, _, param1, param2 = spGetUnitCurrentCommand(unitID)
		if inCommand == CMD_WAIT then
			return false
		elseif not inCommand or not isAttackCommand[inCommand] then
			return true
		elseif param2 or inCommand ~= CMD_ATTACK then
			return false
		end

		local nextCommand, _, _, nextParam1 = spGetUnitCurrentCommand(unitID, 2)
		if not nextCommand then
			return false
		elseif nextCommand == CMD_FIGHT then
			-- Set Target does not violate an active Fight command by prioritizing the user's target.
			-- ! FIXME: We assume the Attack command originated from within Fight but cannot be sure.
			return true
		elseif nextCommand == CMD_GUARD then
			-- Guard and Return Fire have an automatic retaliation behavior that precedes Set Target.
			-- The user intent is to protect either the guardee unit or the unit itself from damages.
			if spValidUnitID(param1) then
				local _, _, target = spGetUnitWeaponTarget(param1, 1)
				if target ~= nextParam1 then -- flimsy
					return true
				end
			end
		end
		return false
	end

	local function setTargetActive(unitID, unitData, targetIndex)
		unitData.activeTarget = true
		unitData.currentIndex = targetIndex
		local targetData = unitData.targets[targetIndex]
		local target = targetData.target
		local targetID, targetX, targetY, targetZ = -1, -1, -1, -1
		if type(target) == "number" then
			targetID = target
			spSetUnitTarget(unitID, targetID, false, targetData.userTarget)
		else
			targetX, targetY, targetZ = target[1], target[2], target[3]
			spSetUnitTarget(unitID, targetX, targetY, targetZ, false, targetData.userTarget)
		end
		spSetUnitRulesParam(unitID, "targetID",     targetID)
		spSetUnitRulesParam(unitID, "targetCoordX", targetX)
		spSetUnitRulesParam(unitID, "targetCoordY", targetY)
		spSetUnitRulesParam(unitID, "targetCoordZ", targetZ)
		SendToUnsynced("targetIndex", unitID, targetIndex, true)
	end

	local function setTargetPassive(unitID, unitData)
		unitData.activeTarget = false
		unitData.currentIndex = 1
		if not inAttackCommand(unitID) then
			spSetUnitTarget(unitID, nil)
		end
		spSetUnitRulesParam(unitID, "targetID",     nil)
		spSetUnitRulesParam(unitID, "targetCoordX", nil)
		spSetUnitRulesParam(unitID, "targetCoordY", nil)
		spSetUnitRulesParam(unitID, "targetCoordZ", nil)
		SendToUnsynced("targetIndex", unitID, 1, false)
	end

	local function isUnseenEnemyUnit(targetData, allyTeam)
		if targetData.alwaysSeen or not spValidUnitID(targetData.target) then
			return false
		end
		local los = spGetUnitLosState(targetData.target, allyTeam, true)
		return not los or los % 4 == 0
	end

	--------------------------------------------------------------------------------
	-- Unit adding/removal

	local function sendTargetsToUnsynced(unitID)
		--tracy.ZoneBeginN(string.format("sendTargetsToUnsynced %d", unitID))
		for index, targetData in ipairs(setTargetData[unitID].targets) do
			if not targetData.sent then
				targetData.sent = true
				local target = targetData.target
				if type(target) == "number" then
					SendToUnsynced("targetList", unitID, index, targetData.userTarget, target)
				else
					SendToUnsynced("targetList", unitID, index, targetData.userTarget, target[1], target[2], target[3])
				end
			end
		end
		--tracy.ZoneEnd()
	end

	local function addUnitTargets(unitID, unitDefID, targetList, append)
		--tracy.ZoneBeginN(string.format("addUnitTargets:%s %d %d", unitID, unitDefID))
		if not spValidUnitID(unitID) then
			--tracy.ZoneEnd()
			return
		end
		local data = setTargetData[unitID]
		if not data then
			data = {
				targets = {},
				currentTargets = {},
				teamID = spGetUnitTeam(unitID),
				allyTeam = spGetUnitAllyTeam(unitID),
				weapons = unitWeapons[unitDefID],
				currentIndex = 1,
				activeTarget = false,
			}
		elseif not append then
			data.targets = {}
			data.currentTargets = {}
			SendToUnsynced("targetList", unitID, 0)
		end
		local teamID = data.teamID
		local targets, currentTargets = data.targets, data.currentTargets
		local targetCount = #targets
		local limitCount = targetListLengthMax - targetCount
		for i = 1, #targetList do
			if limitCount == 0 then
				break
			end
			local targetData = targetList[i]
			local target = targetData.target
			if not currentTargets[target] and checkTarget(teamID, target) then
				limitCount = limitCount - 1
				targetCount = targetCount + 1
				targets[targetCount] = targetData
				if type(target) == "number" then
					currentTargets[target] = true
				end
				targetData.sent = false
			end
		end
		if targetCount == 0 then
			--tracy.ZoneEnd()
			return
		end
		setTargetData[unitID] = data
		activeTargets[unitID] = data
		pausedTargets[unitID] = nil
		addToQueue(unitID)
		sendTargetsToUnsynced(unitID)
		if not data.activeTarget and testTarget(unitID, data.teamID, data.weapons, targets[1].target) then
			setTargetActive(unitID, data, 1)
		end
		--tracy.ZoneEnd()
	end

	local function removeUnit(unitID, keeptrack)
		if activeTargets[unitID] then
			activeTargets[unitID] = nil
			spSetUnitRulesParam(unitID, "targetID", nil)
			spSetUnitRulesParam(unitID, "targetCoordX", nil)
			spSetUnitRulesParam(unitID, "targetCoordY", nil)
			spSetUnitRulesParam(unitID, "targetCoordZ", nil)
			if not inAttackCommand(unitID) then
				spSetUnitTarget(unitID, nil)
			end
		elseif pausedTargets[unitID] then
			pausedTargets[unitID] = nil
		end
		removeFromQueue(unitID)
		if keeptrack then
      SendToUnsynced("targetIndex", unitID, 1, false)
    else
			setTargetData[unitID] = nil
			SendToUnsynced("targetList", unitID, 0)
		end
	end

	local function refreshSendData(unitID, unitData, minIndex)
		local targetList = unitData.targets
		local n = #targetList
		for i = (minIndex or 1), n do
			targetList[i].sent = false -- TODO: There are no other unsent values; we could be sending these directly.
		end
		sendTargetsToUnsynced(unitID)
		SendToUnsynced("targetList", unitID, n + 1) -- clear the last element in case the list shrank
		SendToUnsynced("targetIndex", unitID, unitData.currentIndex, unitData.activeTarget)
	end

	local function updateTarget(unitID, unitData, index, active)
		if active == nil then
			local targetData = unitData.targets[index]
			if targetData then
				active = testTarget(unitID, unitData.teamID, unitData.weapons, targetData.target)
			end
		end
		unitData.currentIndex = index
		unitData.activeTarget = active
	end

	local function removeTarget(unitID, unitData, index)
		local removed = tremove(unitData.targets, index)
		if removed then
			if not unitData.targets[1] then
				removeUnit(unitID)
				return
			end
			unitData.currentTargets[removed.target] = nil
			if index == unitData.currentIndex then
				unitData.currentIndex = 1
				unitData.activeTarget = false
			elseif index < unitData.currentIndex then
				unitData.currentIndex = unitData.currentIndex - 1
			end
			SendToUnsynced("targetDrop", unitID, index)
		end
	end

	local function removeWithStop(unitID)
		local unitData = setTargetData[unitID]
		local targetList = unitData.targets
		local currentTargets = unitData.currentTargets
		local currentIndex = unitData.currentIndex
		local minIndex
		local n = #targetList
		for i = n, 1, -1 do
			if not targetList[i].ignoreStop then
				currentTargets[targetList[i].target] = nil
				tremove(targetList, i)
				minIndex = i
				if i == currentIndex then
					currentIndex = 0 -- invalid, see below
				elseif currentIndex > i then
					currentIndex = currentIndex - 1
				end
			end
		end
		if not targetList[1] then
			removeUnit(unitID)
		elseif minIndex then
			if currentIndex ~= unitData.currentIndex then
				if currentIndex == 0 then
					currentIndex = 1
				end
				updateTarget(unitID, unitData, 1)
			end
			refreshSendData(unitID, unitData, minIndex)
		end
	end

	function GG.getUnitTargetList(unitID)
		return activeTargets[unitID] and activeTargets[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return activeTargets[unitID] and activeTargets[unitID].currentIndex
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_CANCEL_TARGET)

		local allUnits = spGetAllUnits()
		for i = 1, #allUnits do
			local unitID = allUnits[i]
			gadget:UnitCreated(unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID))
		end
	end

	function gadget:UnitCreated(unitID, unitDefID, unitTeam, builderID)
		if validUnits[unitDefID] then
			spInsertUnitCmdDesc(unitID, unitSetTargetNoGroundCmdDesc)
			spInsertUnitCmdDesc(unitID, unitSetTargetCircleCmdDesc)
			spInsertUnitCmdDesc(unitID, unitCancelTargetCmdDesc)
			if setTargetData[builderID] and validUnits[unitDefID] then
				addUnitTargets(unitID, unitDefID, setTargetData[builderID].targets, false)
			end
		end
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam)
		removeUnit(unitID)
	end

	function gadget:UnitTaken(unitID, unitDefID, unitTeam)
		removeUnit(unitID)
	end

	function gadget:UnitDestroyed(unitID, unitDefID, unitTeam, attackerID, attackerDefID, attackerTeam, weaponDefID)
		removeUnit(unitID)
	end


	--------------------------------------------------------------------------------
	-- Command Tracking

	local teamQueryCaches = {}
	local ENEMY_UNITS = -4 -- From UnitAllegiance enum. Includes Gaia and ceasefired targets.

	local function allowTargetUnit(unitID, weaponList, targetID)
		for weaponNum = 1, #weaponList do
			-- This only tests the validity of the target type, not range or other variable things.
			if weaponList[weaponNum] and spGetUnitWeaponTestTarget(unitID, weaponNum, targetID) then
				return true
			end
		end
		return false
	end

	local function allowTargetPos(unitID, weaponList, xyz)
		local x, y, z = xyz[1], xyz[2], xyz[3]
		for weaponNum = 1, #weaponList do
			local weaponType = weaponList[weaponNum]
			-- Quirk: Targets are not adjusted engine-side for water level, unlike Attack commands and weapon aiming.
			if weaponType and spGetUnitWeaponTestTarget(unitID, weaponNum, x, weaponType == WATERWEAPON and y or max(y, 1), z) then
				-- We may or may not adjust this targetY depending on weapon order, which can tend to seem arbitrary.
				if weaponType ~= WATERWEAPON then
					xyz[2] = max(y, 1)
				end
				return true
			end
		end
		return false
	end

	local function inCancelDistance(posA, posB)
		return diag(posA[1] - posB[1], posA[2] - posB[2], posA[3] - posB[3]) < deleteMaxDistance
	end

	local function processCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		--tracy.ZoneBeginN(string.format("processCommand %d %d %d %d %s %s", unitID, unitDefID, teamID, cmdID, tostring(cmdParams), tostring(cmdOptions)))
		--tracy.Message(string.format("processCommand params=%s oprt=%s", Json.encode(cmdParams), Json.encode(cmdOptions)))
		local unitData = setTargetData[unitID]
		local nParams = #cmdParams

		if nParams == 4 and cmdParams[4] < 1 then
			cmdParams[4] = nil
			nParams = 3
		end

		if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND or cmdID == CMD_UNIT_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE then
			local addTargetList

			local weaponList = unitWeapons[unitDefID]
			local append = cmdOptions.shift or false
			local userTarget = not cmdOptions.internal
			local ignoreStop = cmdOptions.ctrl

			if nParams > 3 then
				if not cmdOptions.internal then
					SendToUnsynced("settarget_line_sound", unitTeam, -1, unitID, cmdID)
				end

				local targets
				if nParams == 6 then
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
					local teamCache = ensureTable(teamQueryCaches, spGetUnitAllyTeam(unitID))
					local hash = left + top + right + bot
					targets = teamCache[hash]
					if not targets then
						targets = CallAsTeam(unitTeam, spGetUnitsInRectangle, left, top, right, bot, ENEMY_UNITS)
						teamCache[hash] = targets
					end
				elseif nParams == 4 then
					local teamCache = ensureTable(teamQueryCaches, spGetUnitAllyTeam(unitID))
					local hash = -(cmdParams[1] + cmdParams[2] + cmdParams[3] + cmdParams[4])
					targets = teamCache[hash]
					if not targets then
						targets = CallAsTeam(unitTeam, spGetUnitsInCylinder, cmdParams[1], cmdParams[3], cmdParams[4], ENEMY_UNITS)
						teamCache[hash] = targets
					end
				end
				if targets and targets[1] then
					local targetList, count = {}, 0
					for i = 1, #targets do
						local target = targets[i]
						if allowTargetUnit(unitID, weaponList, target) then
							count = count + 1
							targetList[count] = {
								alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
								ignoreStop = ignoreStop,
								userTarget = userTarget,
								target = target,
								sent = false,
							}
						end
					end
					if count > 0 then
						addTargetList = targetList
					end
				end
			elseif nParams == 3 then
				if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND then
					SendToUnsynced("failCommand", unitTeam)
					--tracy.ZoneEnd()
					return false
				end

				local target = cmdParams
				if target[2] > spGetGroundHeight(target[1], target[3]) then
					target[2] = spGetGroundHeight(target[1], target[3])
				end
				if allowTargetPos(unitID, weaponList, target) then
					addTargetList = {{
						alwaysSeen = true,
						ignoreStop = ignoreStop,
						userTarget = userTarget,
						target = target,
						sent = false,
					}}
				end
			elseif nParams == 1 then
				local target = cmdParams[1]
				if spValidUnitID(target) and not spAreTeamsAllied(unitTeam, spGetUnitTeam(target)) then
					if allowTargetUnit(unitID, weaponList, target) then
						addTargetList = {{
							alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
							ignoreStop = ignoreStop,
							userTarget = userTarget,
							target = target,
							sent = false,
						}}
					end
				end
			end

			if addTargetList then
				addUnitTargets(unitID, unitDefID, addTargetList, append)
			elseif unitData and not append then
				removeUnit(unitID)
			end
			--tracy.ZoneEnd()
			return true
		elseif cmdID == CMD_UNIT_CANCEL_TARGET then
			if not unitData then
				removeUnit(unitID) -- Force clear drawings in unsynced when synced holds no data.
			else
				if nParams == 0 then
					removeUnit(unitID)
				elseif nParams == 1 then
					if cmdOptions.alt then
						local targetIndex = cmdParams[1]
						removeTarget(unitID, unitData, targetIndex)
					else
						local targetID = cmdParams[1]
						for index, targetData in ipairs(unitData.targets) do
							if targetData.target == targetID then
								removeTarget(unitID, unitData, index)
								break
							end
						end
					end
				elseif nParams == 3 then
					for index, targetData in ipairs(unitData.targets) do
						if type(targetData.target) == "table" and inCancelDistance(targetData.target, cmdParams) then
							removeTarget(unitID, unitData, index)
						end
					end
				end
			end
			--tracy.ZoneEnd()
			return true
		end
		--tracy.ZoneEnd()
	end

	local function pauseTargetting(unitID)
		if activeTargets[unitID] and not pausedTargets[unitID] then
			local data = activeTargets[unitID]
			removeUnit(unitID, true)
			pausedTargets[unitID] = data
		end
	end

	local function unpauseTargetting(unitID)
		addUnitTargets(unitID, Spring.GetUnitDefID(unitID), pausedTargets[unitID].targets, true)
	end

	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
		if cmdID == CMD_STOP and setTargetData[unitID] then
			removeWithStop(unitID)
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
		-- Accepts: CMD_UNIT_SET_TARGET_NO_GROUND, CMD_UNIT_SET_TARGET, CMD_UNIT_SET_TARGET_RECTANGLE, CMD_UNIT_CANCEL_TARGET.
		--tracy.ZoneBeginN(string.format("AllowCommand %s %s", tostring(fromSynced), tostring(fromLua)))
		--tracy.Message(string.format("Allowcommand params %s %s", table.toString(cmdOptions), table.toString(cmdParams)))
		if validUnits[unitDefID] then
			processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
		end
		--tracy.ZoneEnd()
		return false -- consume command
	end

	function gadget:RecvLuaMsg(msg, playerID)
		if msg == "settarget_line" then
			local _, _, _, teamID = spGetPlayerInfo(playerID)
			if teamID then
				SendToUnsynced("settarget_line_sound", teamID, playerID, nil, CMD_UNIT_SET_TARGET)
			end
		end
	end

	--------------------------------------------------------------------------------
	-- Target update

	local function processSlowListUpdates()
		for unitID, unitData in pairsNext, setTargetData do
			local targets = unitData.targets
			for index = #targets, 1, -1 do
				if isUnseenEnemyUnit(targets[index], unitData.allyTeam) then
					removeTarget(unitID, unitData, index)
				end
			end
			if not targets[1] then
				removeUnit(unitID)
			elseif activeTargets[unitID] then
				if not hasTargetPrecedence(unitID) then
					pauseTargetting(unitID)
				end
			else
				if hasTargetPrecedence(unitID) then
					unpauseTargetting(unitID)
				end
			end
		end
	end

	local function updateTargetList(unitID)
		local unitData = activeTargets[unitID]
		local targets, teamID, weapons = unitData.targets, unitData.teamID, unitData.weapons
		local targetCount = #targets
		local activeIndex = 0
		local updateIndex = 0 -- table.remove is slow, as is iterating forward then backward, so we do an erase-remove
		for index = 1, targetCount do
			local targetData = targets[index]
			if checkTarget(teamID, targetData.target) then
				updateIndex = updateIndex + 1
				if testTarget(unitID, teamID, weapons, targetData.target) then
					if updateIndex ~= index then
						targets[updateIndex] = targetData
					end
					activeIndex = updateIndex
					updateIndex = index
					-- if moveToIndex == index then
					break -- Avoid continuing tests for better performance.
					-- end
				end
				if updateIndex ~= index then
					targets[updateIndex] = targetData
				end
			else
				SendToUnsynced("targetDrop", unitID, index)
			end
		end
		if updateIndex == 0 then
			removeUnit(unitID)
		elseif activeIndex == 0 then
			if unitData.activeTarget then
				setTargetPassive(unitID, unitData)
			end
			if updateIndex + 1 <= targetCount then
				-- Remove entries only once we are done shifting indices.
				for index = updateIndex + 1, targetCount do
					targets[index] = nil
				end
				SendToUnsynced("targetList", unitID, updateIndex + 1)
			end
		else
			setTargetActive(unitID, unitData, activeIndex)
			-- We broke iter early so have to finish shifting indices.
			local removedCount = updateIndex - activeIndex
			local removeFromIndex = targetCount - removedCount + 1
			for index = activeIndex + 1, targetCount - removedCount do
				updateIndex = updateIndex + 1
				targets[index] = targets[updateIndex]
			end
			if removeFromIndex <= targetCount then
				for index = removeFromIndex, targetCount do
					targets[index] = nil
				end
				SendToUnsynced("targetList", unitID, removeFromIndex)
			end
		end
	end

	local function processTargetListChunk()
		if workQueueLength == 0 then
			return
		end
		local processCount = clamp(workQueueLength / updateFrames, min(workQueueLength, chunkSizeMin), chunkSizeMax)
		for _ = 1, processCount do
			if workQueueIndex > workQueueLength then
				workQueueIndex = 1
			end
			local unitID = updateWorkQueue[workQueueIndex]
			workQueueIndex = workQueueIndex + 1
			updateTargetList(unitID)
		end
	end

	-- Since v103 Attack commands override the unit target on any frame, not just slow updates.
	-- So we try to override the target again, every single frame, to prevent target jittering.
	function gadget:GameFrame(frame)
		teamQueryCaches = {}
		if frame % 15 == 0 then
			processSlowListUpdates()
		else
			processTargetListChunk()
		end
	end


else	-- UNSYNCED


	-- How many units' target lists are fully drawn before any are skipped.
	-- We then skip units in small batches/chunks that slowly grow in size.
	local unitsFullDrawCount = 100 -- So we then skip n+1 and draw n+2 etc.

	-- Large selections of units tend to target a small number of enemies with high repetition.
	-- So though the backoff eventually skips 15 of 16 units, we don't notice anything is culled.
	-- ~1/8th of 32,000 max units => 4k target lists, which is enough to explode a potato PC.
	-- 4k * 100 list length maximum is enough to assume target saturation with 32,000 unit cap.

	local math_min = math.min
	local table_remove = table.remove
	local pairsNext = next

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
	local spValidUnitID = Spring.ValidUnitID
	local spGetMyAllyTeamID = Spring.GetMyAllyTeamID
	local spGetMyTeamID = Spring.GetMyTeamID
	local spIsUnitSelected = Spring.IsUnitSelected
	local spGetSpectatingState = Spring.GetSpectatingState
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spGetUnitTeam = Spring.GetUnitTeam
	local spPlaySoundFile = Spring.PlaySoundFile
	local spSetActiveCommand = Spring.SetActiveCommand
	local spAssignMouseCursor = Spring.AssignMouseCursor
	local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
	local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData
	local spAddWorldIcon = Spring.AddWorldIcon

	local myAllyTeam = spGetMyAllyTeamID()
	local myTeam = spGetMyTeamID()
	local mySpec, fullview = spGetSpectatingState()

	local lineWidth = 1.4
	local queueColour = { 1, 0.75, 0, 0.3 }
	local commandColour = { 1, 0.5, 0, 0.62 }

	local drawAllTargets = {}
	local drawTarget = {}
	local targetList = {}

	function gadget:Initialize()
		gadgetHandler:AddChatAction("targetdrawteam", handleTargetDrawEvent, "toggles drawing targets for units, params: teamID doDraw")
		gadgetHandler:AddChatAction("targetdrawunit", handleUnitTargetDrawEvent, "toggles drawing targets for units, params: unitID")
		gadgetHandler:AddSyncAction("targetList", handleTargetListEvent)
		gadgetHandler:AddSyncAction("targetDrop", handleTargetDropEvent)
		gadgetHandler:AddSyncAction("targetIndex", handleTargetIndexEvent)
		gadgetHandler:AddSyncAction("failCommand", handleFailCommand)

		-- register cursor
		spAssignMouseCursor("settarget", "cursorsettarget", false)
		--show the command in the queue
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET, "settarget", queueColour, true)
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET_NO_GROUND, "settargetrectangle", queueColour, true)
		spSetCustomCommandDrawData(CMD_UNIT_SET_TARGET_RECTANGLE, "settargetnoground", queueColour, true)
	end

	function gadget:PlayerChanged(playerID)
		myAllyTeam = spGetMyAllyTeamID()
		myTeam = spGetMyTeamID()
		mySpec, fullview = spGetSpectatingState()
	end

	function gadget:Shutdown()
		gadgetHandler:RemoveChatAction("targetdrawteam")
		gadgetHandler:RemoveChatAction("targetdrawunit")
		gadgetHandler:RemoveSyncAction("targetList")
		gadgetHandler:RemoveSyncAction("targetDrop")
		gadgetHandler:RemoveSyncAction("targetIndex")
		gadgetHandler:RemoveSyncAction("failCommand")
	end

	function GG.getUnitTargetList(unitID)
		return targetList[unitID] and targetList[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return targetList[unitID] and targetList[unitID].currentIndex
	end

	function handleFailCommand(_, teamID)
		if teamID == myTeam and not mySpec then
			spPlaySoundFile("FailedCommand", 0.75, "ui")
			spSetActiveCommand('settargetnoground')
		end
	end

	local function getUnitTargetList(unitID, removeFromIndex)
		if removeFromIndex == 0 then
			targetList[unitID] = nil
			return
		end
		local unitData = targetList[unitID]
		if not unitData then
			unitData = {
				targets      = {},
				targetIndex  = 1,
				targetActive = false,
			}
			targetList[unitID] = unitData
		end
		if removeFromIndex then
			local targets = unitData.targets
			for i = #targets, removeFromIndex, -1 do
				targets[i] = nil
			end
			if removeFromIndex <= unitData.targetIndex then
				unitData.targetIndex = 1
				unitData.targetActive = false
			end
		end
		return unitData
	end

	function handleTargetListEvent(_, unitID, index, userTarget, targetA, targetB, targetC)
		--tracy.ZoneBeginN(string.format("handleTargetListEvent %d %d ", unitID, index))
		local unitData = getUnitTargetList(unitID, not targetA and index)
		if unitData then
			unitData.targets[index] = {
				userTarget = userTarget,
				target     = (not targetB and targetA) or { targetA, targetB, targetC },
			}
			if index == unitData.targetIndex then
				unitData.targetActive = false
			end
		end
		--tracy.ZoneEnd()
	end

	function handleTargetDropEvent(_, unitID, index)
		local unitData = getUnitTargetList(unitID, false)
		if unitData then
			table_remove(unitData.targets, index)
		end
	end

	function handleTargetIndexEvent(_, unitID, index, active)
		if not targetList[unitID] then
			return
		end
		targetList[unitID].targetIndex = index
		targetList[unitID].targetActive = active
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

	local unitIconsDrawn = {}
	local function drawUnitTarget(cacheKey, x, y, z)
		glVertex(x, y, z)
		if not unitIconsDrawn[cacheKey] then
			-- avoid sending WorldIcons to engine at the same unit/location
			spAddWorldIcon(CMD_UNIT_SET_TARGET, x, y, z)
			unitIconsDrawn[cacheKey] = true
		end
	end

	local function drawTargetCommand(targetData)
		if targetData and targetData.userTarget then
			local target = targetData.target
			local isUnitTarget = type(target) == "number"

			if isUnitTarget and spValidUnitID(target) then
				local _, _, _, x2, y2, z2 = spGetUnitPosition(target, false, true)
				drawUnitTarget(target, x2, y2, z2)
			elseif not isUnitTarget and target then
				-- 3d coordinate target
				local x2, y2, z2 = target[1], target[2], target[3]
				drawUnitTarget(x2+y2+z2, x2, y2, z2)
			end
		end
	end

	-- TODO: Need to handle unit ghosts. None of it works well currently.
	local function isValidTargetData(targetData)
		return type(targetData.target) == "table" or spValidUnitID(targetData.target)
	end

	local function getFirstValidTarget(targets)
		for i = 1, #targets do
			if isValidTargetData(targets[i]) then
				return i, targets[i]
			end
		end
	end

	local function isActiveTargetUnit(unitID, target)
		local weaponNum = 0
		local result
		repeat
			weaponNum = weaponNum + 1
			local _, _, currentTarget = spGetUnitWeaponTarget(unitID, weaponNum)
			if currentTarget then
				result = currentTarget == target
			else
				result = nil
			end
		until result ~= false
		return result == true
	end

	local function isActiveTargetPos(unitID, x, y, z)
		local weaponNum = 0
		local result
		repeat
			weaponNum = weaponNum + 1
			local _, _, currentTarget = spGetUnitWeaponTarget(unitID, weaponNum)
			if currentTarget then
				result = currentTarget[1] == x
					and currentTarget[2] == y
					and currentTarget[3] == z
			else
				result = nil
			end
		until result ~= false
		return result == true
	end

	local function isActiveTarget(unitID, target)
		if type(target) == "number" then
			return isActiveTargetUnit(unitID, target)
		else
			return isActiveTargetPos(unitID, target[1], target[2], target[3])
		end
	end

	local function drawCurrentTarget(unitID, unitData)
		local targetIndex, targetActive = unitData.targetIndex, unitData.targetActive
		local targetData = unitData.targets[targetIndex]

		if not targetData or not isValidTargetData(targetData) then
			-- Unit died or cloaked, LOS lost, etc., so find any target in the list.
			targetIndex, targetData = getFirstValidTarget(unitData.targets)
			if not targetIndex then
				return -- We cannot remove since units can reenter LOS, for example.
			end
			targetActive = isActiveTarget(unitID, targetData.target)
		end

		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)

		if targetActive then
			glColor(commandColour)
			drawTargetCommand(targetData)
			glColor(queueColour)
		else
			drawTargetCommand(targetData)
		end
	end

	local function drawTargetQueue(unitData)
		for _, targetData in ipairs(unitData.targets) do
			drawTargetCommand(targetData)
		end
	end

	local function initDrawing()
		glPushAttrib(GL.LINE_BITS)
		glLineStipple("any") -- use spring's default line stipple pattern, moving
		glDepthTest(false)
		glLineWidth(lineWidth)
		glColor(queueColour)
		return true
	end

	local function stopDrawing()
		glColor(1, 1, 1, 1)
		glLineStipple(false)
		glPopAttrib()
	end

	local function shouldDrawDecorations(unitID)
		return spIsUnitSelected(unitID)
			or drawTarget[unitID]
			or drawAllTargets[spGetUnitTeam(unitID)]
	end

	local function drawDecorations()
		local init = false
		local skipChunkSize, skipChunkLeft = 8, unitsFullDrawCount
		local skipSize, skipLeft = 0, 0
		for unitID, unitData in pairsNext, targetList do
			if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
				if shouldDrawDecorations(unitID) then
					if skipLeft == 0 then
						if not init then
							init = initDrawing()
						end

						glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData)
						glBeginEnd(GL_LINE_STRIP, drawTargetQueue, unitData)

						-- Use a gradual backoff to skip drawing commands at high unit counts.
						skipChunkLeft = skipChunkLeft - 1
						if skipChunkLeft == 0 then
							skipChunkLeft = skipChunkSize
							skipSize = math_min(16, 2 * (skipSize > 0 and skipSize or 1))
						end
						skipLeft = skipSize
					else
						skipLeft = skipLeft - 1
					end
				end
			end
		end
		if init then
			stopDrawing()
		end
		drawTarget = {}
		unitIconsDrawn = {}
	end

	function gadget:DrawWorld()
		if Spring.IsGUIHidden() then
			return
		end

		if fullview then
			drawDecorations()
		else
			CallAsTeam(myTeam, drawDecorations)
		end
	end

end
