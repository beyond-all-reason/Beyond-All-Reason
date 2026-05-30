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
local targetListLengthMax = 100

local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE

local isSetTargetCommand = {
	[CMD_UNIT_SET_TARGET_NO_GROUND] = true,
	[CMD_UNIT_SET_TARGET]           = true,
	[CMD_UNIT_CANCEL_TARGET]        = true,
	[CMD_UNIT_SET_TARGET_RECTANGLE] = true,
}

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
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
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
	local diag = math.diag
	local pairsNext = next
	local tonumber = tonumber

	local isEnqueuedFirst = Game.Commands.IsEnqueuedFirst

	local CMD_STOP = CMD.STOP
	local CMD_DGUN = CMD.DGUN

	local validUnits = {}
	local unitWeapons = {}
	local unitAlwaysSeen = {}

	local WATERWEAPON = 0
	do
		-- Fastpass for units that don't have an attack command for other reasons.
		local allowNonAttackerUnit = { legpede = true }

		local function hasTargeting(weapon)
			if weapon.slavedTo == 0 then
				local weaponDef = WeaponDefs[weapon.weaponDef]
				return weaponDef.type ~= "Shield" and not weaponDef.manualFire and weaponDef.range > 10
			else
				return false
			end
		end

		local function canSetTarget(unitDef)
			if (unitDef.canAttack or allowNonAttackerUnit[unitDef.name]) and unitDef.maxWeaponRange > 0 then
				for _, weapon in pairs(unitDef.weapons) do
					if hasTargeting(weapon) then
						return true
					end
				end
			end
			return false
		end

		-- FIXME: We don't know which weaponDefs have submissile. We can check `nuclear`, for now.
		local function getWeaponType(weapon)
			if hasTargeting(weapon) then
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
					return getWeaponType(weapon), index
				end)
			end
			unitAlwaysSeen[unitDefID] = unitDef.isBuilding or unitDef.speed == 0
		end
	end

	local unitTargets = {} -- data holds all unitID data
	local pausedTargets = {}
	local waitForCommandDone = {}
	local checkForManualFire = {}

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

	local function AreUnitsAllied(unitID, targetID)
		--if a unit dies the unitID will still be valid for current frame unit UnitDestroyed is called
		--this means that code can reach here and spGetUnitTeam returns nil, therefore we'll nil check before
		--executing spAreTeamsAllied, returning true to being allied disables rest of the code without having
		--to pass weird nil threestate to be further checked
		local ownTeam, enemyTeam = spGetUnitTeam(unitID), spGetUnitTeam(targetID)
		return ownTeam and enemyTeam and spAreTeamsAllied(ownTeam, enemyTeam)
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

	local function TargetCanBeReached(unitID, teamID, weaponList, target)
		if not weaponList then
			return
		end

		if type(target) == "number" then
			return CallAsTeam(teamID, testTargetUnit, unitID, weaponList, target)
		else
			return CallAsTeam(teamID, testTargetPos, unitID, weaponList, target[1], target[2], target[3])
		end
	end

	local function checkTarget(unitID, target)
		local isUnitTarget = type(target) == "number"
		return (isUnitTarget and spValidUnitID(target) and not AreUnitsAllied(unitID, target)) or (not isUnitTarget and target)
	end

	local function setTarget(unitID, targetData)
		local unitData = unitTargets[unitID]
		if not TargetCanBeReached(unitID, unitData.teamID, unitData.weapons, targetData.target) then
			local currentCmdID = spGetUnitCurrentCommand(unitID)
			if currentCmdID == CMD.ATTACK then
				return false
			else
				Spring.SetUnitTarget(unitID, nil)
				return false
			end
		end
		
		local target = targetData.target
		local isUnitTarget = type(target) == "number"
		
		if isUnitTarget then
			if not spSetUnitTarget(unitID, target, false, targetData.userTarget) then
				return false
			end

			spSetUnitRulesParam(unitID, "targetID", target)
			spSetUnitRulesParam(unitID, "targetCoordX", -1)
			spSetUnitRulesParam(unitID, "targetCoordY", -1)
			spSetUnitRulesParam(unitID, "targetCoordZ", -1)

		else
			if not spSetUnitTarget(unitID, target[1], target[2], target[3], false, targetData.userTarget) then
				return false
			end

			spSetUnitRulesParam(unitID, "targetID", -1)
			spSetUnitRulesParam(unitID, "targetCoordX", target[1])
			spSetUnitRulesParam(unitID, "targetCoordY", target[2])
			spSetUnitRulesParam(unitID, "targetCoordZ", target[3])
		end
		return true
	end

	local function removeUnseenTarget(targetData, attackerAllyTeam)
		local target = targetData.target
		if not targetData.alwaysSeen and type(target) == "number" and spValidUnitID(target) then
			local los = spGetUnitLosState(target, attackerAllyTeam, true)
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
		--tracy.ZoneBeginN(string.format("sendTargetsToUnsynced %d", unitID))
		for index, targetData in ipairs(unitTargets[unitID].targets) do
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

	local function sendTargetsToUnsyncedBatched(unitID)
		--tracy.ZoneBeginN(string.format("sendTargetsToUnsyncedBatched %d", unitID))
		local targetCount = #unitTargets[unitID].targets
		if targetCount == 1 then
			sendTargetsToUnsynced(unitID)
		elseif targetCount > 1 then
			local data = {}
			local length = 0
			for index, targetData in ipairs(unitTargets[unitID].targets) do
				if not targetData.sent then
					targetData.sent = true
					local target = targetData.target
					data[length + 1] = index
					data[length + 2] = targetData.userTarget
					if type(target) == "number" then
						data[length + 3] = target
						data[length + 4] = false
						data[length + 5] = false
					else
						data[length + 3] = target[1]
						data[length + 4] = target[2]
						data[length + 5] = target[3]
					end
					length = length + 5
					if length > 4000 then break end
				end
			end
			if length > 0 then
				SendToUnsynced("targetListBatched", unitID, length, data)
			end
		end
		--tracy.ZoneEnd()
	end

	local function addUnitTargets(unitID, unitDefID, targets, append)
		--tracy.ZoneBeginN(string.format("addUnitTargets:%s %d %d",tostring(reason), unitID, unitDefID))
		if spValidUnitID(unitID) then
			--needSend[#needSend] = unitID
			local data = unitTargets[unitID] or pausedTargets[unitID]
			if not data then
				data = {
					targets = {},
					teamID = spGetUnitTeam(unitID),
					allyTeam = spGetUnitAllyTeam(unitID),
					weapons = unitWeapons[unitDefID],
					currentIndex = 1,
				}
			end
			if not append then
				data.targets = {}
			end
			local currentTargets = {}
			for i, targetData in ipairs(data.targets) do
				currentTargets[targetData.target] = true
			end
			local remaining = targetListLengthMax - #data.targets
			if remaining > 0 then
				for i = 1, #targets do
					local targetData = targets[i]
					if not currentTargets[targetData.target] then
						if checkTarget(unitID, targetData.target) then
							remaining = remaining - 1
							targetData.sent = false
							data.targets[#data.targets + 1] = targetData
						end
						if remaining == 0 then
							break
						end
					end
				end
			end
			if not data.targets[1] then
				return
			end
			unitTargets[unitID] = data
			pausedTargets[unitID] = nil
			if waitForCommandDone[unitID] then
				checkForManualFire[unitID] = true
			end
			sendTargetsToUnsyncedBatched(unitID)
			if setTarget(unitID, data.targets[1]) then
				if data.currentIndex ~= 1 then
					data.currentIndex = 1
					SendToUnsynced("targetIndex", unitID, 1)
				end
			end
		end
		--tracy.ZoneEnd()
	end

	local function removeUnit(unitID, keeptrack)
		if unitTargets[unitID] then
			spSetUnitTarget(unitID, nil)
			spSetUnitRulesParam(unitID, "targetID", -1)
			spSetUnitRulesParam(unitID, "targetCoordX", -1)
			spSetUnitRulesParam(unitID, "targetCoordY", -1)
			spSetUnitRulesParam(unitID, "targetCoordZ", -1)
			if unitTargets[unitID] and not keeptrack then
				SendToUnsynced("targetList", unitID, 0)
			end
			unitTargets[unitID] = nil
		elseif pausedTargets[unitID] then
			SendToUnsynced("targetList", unitID, 0)
			pausedTargets[unitID] = nil
		end
		waitForCommandDone[unitID] = nil
	end


	local function refreshSendList(unitID, unitData, minIndex)
		local targetList = unitData.targets
		local n = #targetList
		for i = (minIndex or 1), n do
			targetList[i].sent = nil
		end
		sendTargetsToUnsynced(unitID)
		SendToUnsynced("targetList", unitID, n + 1) -- clear the last element in case the list shrank
	end

	local function removeTarget(unitID, index)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		tremove(unitData.targets, index)
		if #unitData.targets == 0 then
			removeUnit(unitID)
		else
			refreshSendList(unitID, unitData, index)
		end
	end

	local function removeWithStop(unitID)
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		local targetList = unitData.targets
		local currentIndex = unitData.currentIndex
		local minIndex
		local n = #targetList
		for i = n, 1, -1 do
			if not targetList[i].ignoreStop then
				tremove(targetList, i)
				minIndex = i
				if i == currentIndex then
					currentIndex = 1
				elseif i < currentIndex then
					currentIndex = currentIndex - 1
				end
			end
		end
		if not targetList[1] then
			removeUnit(unitID)
		elseif minIndex then
			unitTargets[unitID].currentIndex = currentIndex
			refreshSendList(unitID, unitData, minIndex)
		end
	end

	function GG.getUnitTargetList(unitID)
		return unitTargets[unitID] and unitTargets[unitID].targets
	end

	function GG.getUnitTargetIndex(unitID)
		return unitTargets[unitID] and unitTargets[unitID].currentIndex
	end

	--[[function gadget:GameFramePost()
		for _, unitID in ipairs(needSend) do
			sendTargetsToUnsyncedBatched(unitID)
		end
		needSend = {}
	end]]

	function gadget:Initialize()
		-- register command
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)
		-- register allowcommand callin
		gadgetHandler:RegisterAllowCommand(CMD_STOP)
		gadgetHandler:RegisterAllowCommand(CMD_DGUN)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_CANCEL_TARGET)

		-- load active units
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
			if unitTargets[builderID] then
				addUnitTargets(unitID, unitDefID, unitTargets[builderID].targets, false, "UnitCreated")
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

	local function processCommand(unitID, unitDefID, unitTeam, cmdID, cmdParams, cmdOptions)
		--tracy.ZoneBeginN(string.format("processCommand %d %d %d %d %s %s", unitID, unitDefID, teamID, cmdID, tostring(cmdParams), tostring(cmdOptions)))
		--tracy.Message(string.format("processCommand params=%s oprt=%s", Json.encode(cmdParams), Json.encode(cmdOptions)))
		local unitData = unitTargets[unitID] or pausedTargets[unitID]
		local nParams = #cmdParams

		if cmdID == CMD_UNIT_SET_TARGET_NO_GROUND or cmdID == CMD_UNIT_SET_TARGET or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE then
			local addTargetList

			if nParams == 4 and cmdParams[4] < 1 then
				cmdParams[4] = nil
				nParams = 3
			end

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
								alwaysSeen = true,
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
			if unitData then
				if nParams == 0 then
					removeUnit(unitID)
				elseif nParams == 1 and cmdOptions.alt then
					--it's a position in the queue
					removeTarget(unitID, cmdParams[1])
				elseif nParams == 1 and not cmdOptions.alt then
					--target is unitID
					for index, val in ipairs(unitData.targets) do
						if tonumber(val) then
							--element is a unitID
							if val == cmdParams[1] then
								removeTarget(unitID, index)
								break
							end
						end
					end
				elseif nParams == 3 then
					--target is a location
					for index, val in ipairs(unitData.targets) do
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
			--tracy.ZoneEnd()
			return true
		end
		--tracy.ZoneEnd()
	end

	local function pauseTargetting(unitID)
		if unitTargets[unitID] and not pausedTargets[unitID] then
			local data = unitTargets[unitID]
			removeUnit(unitID, true)
			pausedTargets[unitID] = data
		end
	end

	local function unpauseTargetting(unitID)
		addUnitTargets(unitID, Spring.GetUnitDefID(unitID), pausedTargets[unitID].targets, true, "unpauseTargetting")
	end

	function gadget:UnitCmdDone(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
		local hasTargetData = unitTargets[unitID] or pausedTargets[unitID]
		if not hasTargetData then
			return
		end

		if cmdID == CMD_STOP then
			removeWithStop(unitID)
		end

		if not waitForCommandDone[unitID] then
			return
		end

		-- We do not know if we are coming from ExecuteInsert or FinishCommand.
		-- So we do not know whether the below command is starting or finished.
		local inCommandID = spGetUnitCurrentCommand(unitID)
		local inManualFire = inCommandID == CMD_DGUN or cmdID == CMD_DGUN -- So, check in either case.

		if inManualFire then
			if not pausedTargets[unitID] then
				checkForManualFire[unitID] = true
			end
		else
			if pausedTargets[unitID] then
				checkForManualFire[unitID] = true
			end
		end
	end

	function gadget:AllowCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag, playerID, fromSynced, fromLua, fromInsert)
		-- Accepts: CMD_STOP, CMD_DGUN, CMD_UNIT_SET_TARGET_NO_GROUND, CMD_UNIT_SET_TARGET, CMD_UNIT_SET_TARGET_RECTANGLE, CMD_UNIT_CANCEL_TARGET.
		--tracy.ZoneBeginN(string.format("AllowCommand %s %s", tostring(fromSynced), tostring(fromLua)))
		--tracy.Message(string.format("Allowcommand params %s %s", table.toString(cmdOptions), table.toString(cmdParams)))
		if isSetTargetCommand[cmdID] then
			if validUnits[unitDefID] then
				processCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions)
			end
			--tracy.ZoneEnd()
			return false -- consume command
		end

		if unitTargets[unitID] or pausedTargets[unitID] then
			if not isEnqueuedFirst(unitID, cmdID, cmdTag, cmdOptions, fromInsert) then
				if cmdID == CMD_DGUN then
					waitForCommandDone[unitID] = true
					checkForManualFire[unitID] = true
				end
			elseif cmdID == CMD_DGUN then
				pauseTargetting(unitID)
				waitForCommandDone[unitID] = true
				checkForManualFire[unitID] = true
			elseif cmdID == CMD_STOP then
				removeWithStop(unitID)
				waitForCommandDone[unitID] = nil
			end
		end

		--tracy.ZoneEnd()
		return true
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

	function gadget:GameFrame(n)
		-- ideally timing would be synced with slow update to reduce attack jittering
		-- SlowUpdate+ causes attack command to override target command
		-- unfortunately since 103 that's not possible, attempt to override every frame
		-- it might create a slight increase of cpu usage when hundreds of units gets
		-- a set target command, howrever a quick test with 300 fidos only increased by 1%
		-- sim here

		if n % 5 == 4 then
			for unitID, unitData in pairsNext, unitTargets do
				local targetIndex, targetOffset = 1, 0
				local targets = unitData.targets
				-- Check each target and find first valid one
				for index = 1, #targets do
					local targetData = targets[index]
					if not checkTarget(unitID, targetData.target) then
						-- Mark for removal, but don't remove during iteration
						targetData.invalid = true
						targetOffset = targetOffset + 1
					elseif not targetData.invalid and setTarget(unitID, targetData) then
						targetIndex = index - targetOffset
						break
					end
				end
				
				-- Remove invalid targets in reverse order
				for index = #targets, 1, -1 do
					if targets[index].invalid then
						removeTarget(unitID, index)
					end
				end
				
				if unitData.currentIndex ~= targetIndex then
					unitData.currentIndex = targetIndex
					SendToUnsynced("targetIndex", unitID, targetIndex)
				end
			end
		end

		if n % USEEN_UPDATE_FREQUENCY == 0 then
			for unitID, unitData in pairsNext, unitTargets do
				local targets = unitData.targets
				-- Iterate backwards to safely handle removals
				for index = #targets, 1, -1 do
					if removeUnseenTarget(targets[index], unitData.allyTeam) then
						removeTarget(unitID, index)
					end
				end
			end
		end

		for unitID in pairs(checkForManualFire) do
			if unitTargets[unitID] then
				if spGetUnitCurrentCommand(unitID) == CMD_DGUN then
					pauseTargetting(unitID)
				end
				checkForManualFire[unitID] = nil
			elseif pausedTargets[unitID] then
				if spGetUnitCurrentCommand(unitID) ~= CMD_DGUN then
					unpauseTargetting(unitID)
				end
				-- continue checking for manual fire
			else
				checkForManualFire[unitID] = nil
				waitForCommandDone[unitID] = nil
			end
		end

		teamQueryCaches = {}
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
	local ensureTable = table.ensureTable

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
	local spSetCustomCommandDrawData = Spring.SetCustomCommandDrawData
	local spAddWorldIcon = Spring.AddWorldIcon
	local pairsNext = next

	local myAllyTeam = spGetMyAllyTeamID()
	local myTeam = spGetMyTeamID()
	local mySpec, fullview = spGetSpectatingState()

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
		gadgetHandler:AddSyncAction("targetListBatched", handleTargetListBatchedEvent)
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
		gadgetHandler:RemoveSyncAction("targetListBatched")
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

	local function getEventTargetList(unitID, index, remove)
		if index == 0 then
			targetList[unitID] = nil
			return
		end

		local unitData = ensureTable(targetList, unitID)
		local targets = ensureTable(unitData, "targets")

		if remove then
			if index == 1 then
				targets = {}
				unitData.targets = targets
			else
				for i = index, #targets do
					targets[i] = nil
				end
			end
		end

		return targets
	end

	function handleTargetListEvent(_, unitID, index, userTarget, targetA, targetB, targetC)
		--tracy.ZoneBeginN(string.format("handleTargetListEvent %d %d ", unitID, index))
		local targets = getEventTargetList(unitID, index, targetA == nil)

		if not targets then
			--tracy.ZoneEnd()
			return
		end

		targets[index] = {
			userTarget = userTarget,
			target     = (not targetB and targetA) or { targetA, targetB, targetC },
		}
		--tracy.ZoneEnd()
	end

	function handleTargetListBatchedEvent(_, unitID, length, data)
		local targets = getEventTargetList(unitID, data[1], false)
		for i = 1, length, 5 do
			targets[data[i]] = {
				userTarget = data[i+1],
				target     = (not data[i+3] and data[i+2]) or { data[i+2], data[i+3], data[i+4] },
			}
		end
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

	local function drawCurrentTarget(unitID, unitData, myTeam, myAllyTeam)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		drawTargetCommand(unitData.targets[unitData.targetIndex])
	end

	local function drawTargetQueue(unitID, unitData, myTeam, myAllyTeam)
		local _, _, _, x1, y1, z1 = spGetUnitPosition(unitID, true)
		glVertex(x1, y1, z1)
		for _, targetData in ipairs(unitData.targets) do
			drawTargetCommand(targetData)
		end
	end

	local function drawDecorations()
		local init = false
		local skipChunkSize, skipChunkLeft = 8, unitsFullDrawCount
		local skipSize, skipLeft = 0, 0
		for unitID, unitData in pairsNext, targetList do
			if fullview or spGetUnitAllyTeam(unitID) == myAllyTeam then
				if skipLeft == 0 and (drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)] or spIsUnitSelected(unitID)) then
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
		if init then
			glColor(1, 1, 1, 1)
			glLineStipple(false)
			glPopAttrib()
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
