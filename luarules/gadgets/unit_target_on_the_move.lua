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

local CMD_UNIT_SET_TARGET_NO_GROUND = GameCMD.UNIT_SET_TARGET_NO_GROUND
local CMD_UNIT_SET_TARGET = GameCMD.UNIT_SET_TARGET
local CMD_UNIT_CANCEL_TARGET = GameCMD.UNIT_CANCEL_TARGET
local CMD_UNIT_SET_TARGET_RECTANGLE = GameCMD.UNIT_SET_TARGET_RECTANGLE
local CMD_UNIT_SET_TARGETS = GameCMD.UNIT_SET_TARGETS
local CMD_ATTACK = CMD.ATTACK

if gadgetHandler:IsSyncedCode() then
	local SharedTargetListStore = VFS.Include("luarules/Utilities/shared_target_list_store.lua")

	-- Ground targets within this many elmos are treated as the same target when
	-- applying the command that removes a target near the clicked position.
	local deleteMaxDistance = 30
	-- Keep a unit target for this many seconds after it leaves LOS or radar.
	local unseenGraceTime = 1.5
	-- Per-unit and global caps on expensive weapon-targetability checks. The
	-- global cap prevents a large shared order from monopolizing a sim frame.
	local targetChecksPerUnitUpdate = 128
	local targetChecksPerFrame = 8192
	-- Per-list and global caps on LOS, death, and alliance validity checks. List
	-- validation is shared, so each target is checked once rather than per unit.
	local listValidityChecksPerUpdate = 256
	local listValidityChecksPerFrame = 8192

	local spInsertUnitCmdDesc = Spring.InsertUnitCmdDesc
	local spGetUnitAllyTeam = Spring.GetUnitAllyTeam
	local spSetUnitTarget = Spring.SetUnitTarget
	local spValidUnitID = Spring.ValidUnitID
	local spGetUnitDefID = Spring.GetUnitDefID
	local spGetUnitIsDead = Spring.GetUnitIsDead
	local spGetUnitMoveTypeData = Spring.GetUnitMoveTypeData
	local spGetUnitLosState = Spring.GetUnitLosState
	local spGetUnitTeam = Spring.GetUnitTeam
	local spAreTeamsAllied = Spring.AreTeamsAllied
	local spGetUnitsInRectangle = Spring.GetUnitsInRectangle
	local spGetUnitsInCylinder = Spring.GetUnitsInCylinder
	local spGetUnitCurrentCommand = Spring.GetUnitCurrentCommand
	local spGetUnitWeaponTarget = Spring.GetUnitWeaponTarget
	local spGetUnitWeaponTryTarget = Spring.GetUnitWeaponTryTarget
	local spGetUnitWeaponTestTarget = Spring.GetUnitWeaponTestTarget
	local spGetUnitWeaponTestRange = Spring.GetUnitWeaponTestRange
	local spGetUnitWeaponHaveFreeLineOfFire = Spring.GetUnitWeaponHaveFreeLineOfFire
	local spGetGroundHeight = Spring.GetGroundHeight
	local spGetAllUnits = Spring.GetAllUnits
	local spGetPlayerInfo = Spring.GetPlayerInfo
	local spGetUnitStates = Spring.GetUnitStates
	local spSetUnitRulesParam = Spring.SetUnitRulesParam

	local ensureTable = table.ensureTable
	local max = math.max
	local min = math.min
	local clamp = math.clamp
	local diag = math.diag
	local bit_and = math.bit_and
	local pairsNext = next
	local type = type

	local CMD_STOP = CMD.STOP
	local CMD_ATTACK_TARGETS = GameCMD.ATTACK_TARGETS
	local CMD_FIGHT = CMD.FIGHT
	local CMD_GUARD = CMD.GUARD
	local CMD_WAIT = CMD.WAIT
	local OPT_INTERNAL = CMD.OPT_INTERNAL
	local FIRESTATE_RETURNFIRE = CMD.FIRESTATE_RETURNFIRE

	local isAttackCommand = {
		[CMD_ATTACK] = true,
		[CMD.MANUALFIRE] = true,
		[CMD.AREA_ATTACK] = true,
		[GameCMD.AREA_ATTACK_GROUND] = true,
		[GameCMD.ATTACK_TARGETS] = true,
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

	-- Units with the same targets share one list object. The active target and
	-- range scan position remain unit-specific, while LOS and death are checked
	-- once for the shared list. When one unit edits its targets, only its list
	-- reference is reassigned to the shared list matching the new contents.
	-- Automatic target removal reassigns every unit referencing the old list.
	local targetListStore = SharedTargetListStore.new()
	local sentSharedTargetLists = {}
	---@type table<integer, SharedTargetList?>
	local validationWorkQueue = {}
	---@type table<SharedTargetList, integer?>
	local validationWorkQueueLookup = {}
	local validationWorkQueueLength = 0
	local validationWorkQueueIndex = 1
	---@type fun(targetID: integer, targetTeam: integer)
	local removeTransferredTargetFromLists
	local pendingTargetListUpdates = {}
	local pendingTargetListReferences = {}
	local pendingTargetListReleases = {}
	local pendingTargetIndices = {}
	local pendingTargetPauses = {}
	-- Maximum shared-list entries sent to unsynced Lua in one simulation frame.
	local targetListSendBudget = 8192

	local function addListToValidationQueue(list)
		if validationWorkQueueLookup[list.id] then
			return
		end
		validationWorkQueueLength = validationWorkQueueLength + 1
		validationWorkQueue[validationWorkQueueLength] = list
		validationWorkQueueLookup[list.id] = validationWorkQueueLength
	end

	local function removeListFromValidationQueue(list)
		local index = validationWorkQueueLookup[list.id]
		if not index then
			return
		end
		if index ~= validationWorkQueueLength then
			local movedList = validationWorkQueue[validationWorkQueueLength]
			---@cast movedList SharedTargetList
			validationWorkQueue[index] = movedList
			---@diagnostic disable-next-line: inject-field -- Dynamic list-object lookup.
			validationWorkQueueLookup[movedList.id] = index
		end
		validationWorkQueue[validationWorkQueueLength] = nil
		validationWorkQueueLength = validationWorkQueueLength - 1
		validationWorkQueueLookup[list.id] = nil
		if validationWorkQueueIndex > index then
			validationWorkQueueIndex = validationWorkQueueIndex - 1
		end
	end

	local function releaseTargetList(list, unitID)
		if not list then
			return
		end
		list.units[unitID] = nil
		list.refCount = list.refCount - 1
		if list.refCount == 0 then
			removeListFromValidationQueue(list)
			targetListStore:removeSharedTargetList(list)
			if sentSharedTargetLists[list.id] then
				sentSharedTargetLists[list.id] = nil
				pendingTargetListReleases[list.id] = true
			end
		end
	end

	local function assignTargetList(unitData, list)
		if unitData.targetList == list then
			return
		end
		local unitID = unitData.unitID
		releaseTargetList(unitData.targetList, unitID)
		unitData.targetList = list
		unitData.targets = list and list.entries or nil
		unitData.currentTargets = list and list.lookup or nil
		if list then
			if list.refCount == 0 then
				addListToValidationQueue(list)
			end
			list.refCount = list.refCount + 1
			list.units[unitID] = true
		end
	end

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

	local unseenGraceFrames = math.floor(unseenGraceTime * Game.gameSpeed)

	--------------------------------------------------------------------------------
	-- Commands

	local tooltipText = "Set a priority attack target,\nto be used when within range\n(not removed by move commands)"

	local unitSetTargetNoGroundCmdDesc = {
		id = CMD_UNIT_SET_TARGET_NO_GROUND,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = "Set Unit Target",
		action = "settargetnoground",
		cursor = "settarget",
		tooltip = tooltipText,
		hidden = true,
		queueing = false,
	}

	local unitSetTargetCircleCmdDesc = {
		id = CMD_UNIT_SET_TARGET,
		type = CMDTYPE.ICON_UNIT_OR_AREA,
		name = "Set Target", --extra spaces center the 'Set' text
		action = "settarget",
		cursor = "settarget",
		tooltip = tooltipText,
		hidden = false,
		queueing = false,
	}

	local unitCancelTargetCmdDesc = {
		id = CMD_UNIT_CANCEL_TARGET,
		type = CMDTYPE.ICON,
		name = "Cancel Target",
		action = "canceltarget",
		tooltip = "Removes top priority target, if set",
		hidden = false,
		queueing = false,
	}

	local unitSetTargetsCmdDesc = {
		id = CMD_UNIT_SET_TARGETS,
		type = CMDTYPE.ICON,
		name = "Set Targets",
		action = "settargets",
		cursor = "settarget",
		tooltip = tooltipText,
		hidden = true,
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

	local function inReturnFire(unitID)
		return spGetUnitStates(unitID, false) == FIRESTATE_RETURNFIRE
	end

	local function inRetaliationAttack(aggressorID, protectID)
		local _, isUserTarget, target = spGetUnitWeaponTarget(aggressorID, 1)
		return not isUserTarget and target == protectID
	end

	local function hasAutoTarget(cmdOptions)
		return bit_and(cmdOptions, OPT_INTERNAL) ~= 0
	end

	local function hasUserTarget(unitID, unitData)
		for weaponNum, check in pairs(unitData.weapons) do
			if check then
				local _, isUserTarget = spGetUnitWeaponTarget(unitID, weaponNum)
				if isUserTarget then
					return true
				end
			end
		end
		return false
	end

	local function hasTargetPrecedence(unitID, unitData)
		local inCommand, options, _, param1, param2 = spGetUnitCurrentCommand(unitID)
		if inCommand == CMD_WAIT then
			return false
		elseif not inCommand or not isAttackCommand[inCommand] then
			return true
		elseif inCommand == CMD_ATTACK_TARGETS then
			return true
		elseif unitData.sourceKey and inCommand == CMD_ATTACK then
			-- Attack Targets uses an ordinary Attack command for movement. When it
			-- finishes, the controller advances the target list and queues the next Attack.
			return true
		elseif param2 or inCommand ~= CMD_ATTACK then
			return false
		end

		local nextCommand, _, _, nextParam1 = spGetUnitCurrentCommand(unitID, 2)
		-- ! FIXME: We assume the Attack command originated from within Fight but cannot be sure.
		if nextCommand == CMD_FIGHT then
			return true
		end
		-- Retaliation behaviors take priority to protect the guardee despite being automatic.
		if nextCommand == CMD_GUARD and inRetaliationAttack(param1, nextParam1) then
			return false
		elseif inReturnFire(unitID) and inRetaliationAttack(param1, unitID) then
			return false
		end

		return hasAutoTarget(options) or not hasUserTarget(unitID, unitData)
	end

	local function setTargetActive(unitID, unitData, targetIndex)
		unitData.activeTarget = true
		unitData.currentIndex = targetIndex
		local targetData = unitData.targets[targetIndex]
		local target = targetData.target
		if type(target) == "number" then
			spSetUnitTarget(unitID, target, false, targetData.userTarget)
			spSetUnitRulesParam(unitID, "unitTargetID", target)
		else
			spSetUnitTarget(unitID, target[1], target[2], target[3], false, targetData.userTarget)
			spSetUnitRulesParam(unitID, "unitTargetID", nil)
		end
		pendingTargetIndices[unitID] = { targetIndex, true }
	end

	local function setTargetPassive(unitID, unitData)
		if not unitData then
			return
		end
		unitData.activeTarget = false
		unitData.currentIndex = 1
		spSetUnitRulesParam(unitID, "unitTargetID", nil)
		if not inAttackCommand(unitID) then
			spSetUnitTarget(unitID, nil)
		end
		pendingTargetIndices[unitID] = { 1, false }
	end

	local function wasTargetLost(target, alwaysSeen, allyTeam)
		if type(target) ~= "number" then
			return false, false
		end
		local moveTypeData = spGetUnitMoveTypeData(target)
		local isDead = spGetUnitIsDead(target) ~= false or (moveTypeData and moveTypeData.aircraftState == "crashing")
		if isDead then
			return true, true
		elseif alwaysSeen then
			return false, false
		end
		local los = spGetUnitLosState(target, allyTeam, true)
		if not los then
			return true, true
		end
		return los % 4 == 0, false
	end

	--------------------------------------------------------------------------------
	-- Unit adding/removal
	local function sendSharedTargetEntryToUnsynced(list, index)
		local targetData = list.entries[index]
		local target = targetData.target
		local unavailable = not not list.unavailable[target]
		if type(target) == "number" then
			SendToUnsynced("targetListShared", list.id, index, targetData.userTarget, unavailable, target)
		else
			SendToUnsynced(
				"targetListShared",
				list.id,
				index,
				targetData.userTarget,
				unavailable,
				target[1],
				target[2],
				target[3]
			)
		end
	end

	local function queueTargetsToUnsynced(unitID, minIndex)
		local unitData = setTargetData[unitID]
		local list = unitData.targetList
		local firstIndex = not sentSharedTargetLists[list.id] and 1 or minIndex
		if firstIndex then
			local update = pendingTargetListUpdates[list.id]
			if not update or firstIndex < update.firstIndex then
				pendingTargetListUpdates[list.id] = { list = list, firstIndex = firstIndex, nextIndex = firstIndex }
			end
		end
		pendingTargetListReferences[unitID] = true
	end

	local function flushTargetsToUnsynced()
		for listID in pairsNext, pendingTargetListReleases do
			SendToUnsynced("targetListRelease", listID)
		end
		pendingTargetListReleases = {}

		---@type number
		local remainingBudget = targetListSendBudget
		for listID, update in pairsNext, pendingTargetListUpdates do
			local list = update.list
			if list.refCount == 0 then
				pendingTargetListUpdates[listID] = nil
			elseif remainingBudget > 0 then
				if update.nextIndex > #list.entries then
					SendToUnsynced("targetListShared", listID, #list.entries + 1)
					sentSharedTargetLists[listID] = true
					pendingTargetListUpdates[listID] = nil
				else
					local lastIndex = min(#list.entries, update.nextIndex + remainingBudget - 1)
					for index = update.nextIndex, lastIndex do
						sendSharedTargetEntryToUnsynced(list, index)
					end
					remainingBudget = remainingBudget - (lastIndex - update.nextIndex + 1)
					update.nextIndex = lastIndex + 1
					if update.nextIndex > #list.entries then
						SendToUnsynced("targetListShared", listID, #list.entries + 1)
						sentSharedTargetLists[listID] = true
						pendingTargetListUpdates[listID] = nil
					end
				end
			end
		end

		for unitID in pairsNext, pendingTargetListReferences do
			local unitData = setTargetData[unitID]
			if unitData and unitData.targetList and sentSharedTargetLists[unitData.targetList.id] then
				SendToUnsynced("targetListReference", unitID, unitData.targetList.id, unitData.renderAsAttack)
				pendingTargetListReferences[unitID] = nil
			elseif not unitData or not unitData.targetList then
				pendingTargetListReferences[unitID] = nil
			end
		end

		for unitID, indexData in pairsNext, pendingTargetIndices do
			local unitData = setTargetData[unitID]
			if unitData and sentSharedTargetLists[unitData.targetList.id] then
				SendToUnsynced("targetIndex", unitID, indexData[1], indexData[2])
				pendingTargetIndices[unitID] = nil
			end
		end

		for unitID, paused in pairsNext, pendingTargetPauses do
			local unitData = setTargetData[unitID]
			if unitData and sentSharedTargetLists[unitData.targetList.id] then
				SendToUnsynced("targetPause", unitID, paused)
				pendingTargetPauses[unitID] = nil
			end
		end
	end

	local function removeUnit(unitID, keeptrack)
		if activeTargets[unitID] and not inAttackCommand(unitID) then
			spSetUnitTarget(unitID, nil)
		end
		activeTargets[unitID] = nil
		removeFromQueue(unitID)
		if keeptrack then
			setTargetPassive(unitID, setTargetData[unitID])
		else
			local unitData = setTargetData[unitID]
			if unitData then
				assignTargetList(unitData, nil)
			end
			setTargetData[unitID] = nil
			pausedTargets[unitID] = nil
			SendToUnsynced("targetList", unitID, 0) -- clear command gfx
		end
		pendingTargetListReferences[unitID] = nil
		pendingTargetIndices[unitID] = nil
		pendingTargetPauses[unitID] = nil
		spSetUnitRulesParam(unitID, "unitTargetID", nil)
	end

	---@param unitID UnitID
	---@param unitDefID UnitDefID
	---@param targetList table
	---@param append boolean?
	---@param renderAsAttack boolean?
	---@param prepend boolean?
	---@param useSharedAppend boolean?
	---@param targetingEnabled boolean?
	local function addUnitTargets(
		unitID,
		unitDefID,
		targetList,
		append,
		renderAsAttack,
		prepend,
		useSharedAppend,
		targetingEnabled
	)
		if not spValidUnitID(unitID) then
			return
		end

		local data = setTargetData[unitID]
		if not data then
			data = {
				unitID = unitID,
				teamID = spGetUnitTeam(unitID),
				allyTeam = spGetUnitAllyTeam(unitID),
				weapons = unitWeapons[unitDefID],
				currentIndex = 1,
				scanIndex = 1,
				activeTarget = false,
			}
		elseif not append then
			data.currentIndex = 1
			data.scanIndex = 1
			data.activeTarget = false
		end
		if targetingEnabled == nil then
			targetingEnabled = true
		end
		data.targetingEnabled = targetingEnabled
		if not targetingEnabled and not append then
			-- A controller-only list must not retain an explicit weapon target from
			-- the previously assigned target list.
			spSetUnitTarget(unitID, nil)
			spSetUnitRulesParam(unitID, "unitTargetID", nil)
		end

		local teamID = data.teamID
		local entries = {}
		local providedSharedList = not append and not prepend and targetList.sharedList
		if
			providedSharedList
			and (providedSharedList.teamID ~= data.teamID or providedSharedList.allyTeam ~= data.allyTeam)
		then
			providedSharedList = nil
		end
		if renderAsAttack ~= nil then
			data.renderAsAttack = renderAsAttack
		elseif not append then
			data.renderAsAttack = false
		end

		-- The legacy area Set Target path calls this function once per shifted
		-- unit target. Once a unit owns its list exclusively, copying the growing
		-- list for every appended target is quadratic and can exhaust synced Lua.
		-- Detach a shared list once, then extend the private list and its unsynced
		-- mirror in place. Explicit multi-target commands still use immutable,
		-- shared lists and retain cross-unit sharing. useSharedAppend keeps explicit
		-- list commands on that path even when a packet chunk contains one target.
		local incomingEntries = targetList.sharedList and targetList.sharedList.entries or targetList
		if append and not useSharedAppend and data.targetList and #incomingEntries == 1 then
			local targetData = incomingEntries[1]
			local target = targetData.target
			local alreadyPresent = type(target) == "number" and data.currentTargets[target]
			if not alreadyPresent and checkTarget(teamID, target) then
				local list = data.targetList
				local entries
				if list.refCount == 1 then
					targetListStore:makeTargetListPrivate(list)
					entries = list.entries
					entries[#entries + 1] = targetData
					if type(target) == "number" then
						list.lookup[target] = #entries
					end
				else
					entries = {}
					for index = 1, #list.entries do
						entries[index] = list.entries[index]
					end
					entries[#entries + 1] = targetData
					assignTargetList(data, targetListStore:createTargetList(entries, data.teamID, data.allyTeam))
					list = data.targetList
				end

				data.scanIndex = min(data.scanIndex or 1, #entries)
				setTargetData[unitID] = data
				activeTargets[unitID] = targetingEnabled and data or nil
				pausedTargets[unitID] = nil
				if targetingEnabled then
					addToQueue(unitID)
				else
					removeFromQueue(unitID)
				end
				queueTargetsToUnsynced(unitID, #entries)
				pendingTargetPauses[unitID] = false
				if
					targetingEnabled
					and not data.activeTarget
					and testTarget(unitID, data.teamID, data.weapons, entries[1].target)
				then
					setTargetActive(unitID, data, 1)
				end
				return
			end
		end

		local seenTargets = {}
		if append and data.currentTargets then
			for target, index in pairs(data.currentTargets) do
				seenTargets[target] = index
			end
		end
		if providedSharedList then
			entries = providedSharedList.entries
		elseif append and data.targets then
			for index = 1, #data.targets do
				entries[index] = data.targets[index]
			end
		end
		local targetCount = #entries
		if not providedSharedList or append then
			for i = 1, #incomingEntries do
				local targetData = incomingEntries[i]
				local target = targetData.target
				local alreadyPresent = type(target) == "number" and seenTargets[target]
				if not alreadyPresent and checkTarget(teamID, target) then
					targetCount = targetCount + 1
					entries[targetCount] = targetData
					if type(target) == "number" then
						seenTargets[target] = targetCount
					end
				end
			end
		end
		if prepend and data.targets then
			for index = 1, #data.targets do
				local targetData = data.targets[index]
				local target = targetData.target
				local alreadyPresent = type(target) == "number" and seenTargets[target]
				if not alreadyPresent then
					targetCount = targetCount + 1
					entries[targetCount] = targetData
					if type(target) == "number" then
						seenTargets[target] = targetCount
					end
				end
			end
		end

		if targetCount == 0 then
			if setTargetData[unitID] then
				removeUnit(unitID)
			end
			return
		end

		local sharedList = providedSharedList
			or targetListStore:getOrCreateSharedTargetList(entries, data.teamID, data.allyTeam)
		if not append and not prepend then
			targetList.sharedList = sharedList
		end
		assignTargetList(data, sharedList)
		data.scanIndex = min(data.scanIndex or 1, targetCount)

		setTargetData[unitID] = data
		activeTargets[unitID] = targetingEnabled and data or nil
		pausedTargets[unitID] = nil
		if targetingEnabled then
			addToQueue(unitID)
		else
			removeFromQueue(unitID)
		end
		queueTargetsToUnsynced(unitID)
		pendingTargetPauses[unitID] = false

		if
			targetingEnabled
			and not data.activeTarget
			and testTarget(unitID, data.teamID, data.weapons, entries[1].target)
		then
			setTargetActive(unitID, data, 1)
		end
	end

	local function refreshSendData(unitID, unitData, minIndex)
		queueTargetsToUnsynced(unitID)
		pendingTargetIndices[unitID] = { unitData.currentIndex, unitData.activeTarget }
	end

	local function removeTarget(unitID, unitData, index)
		local removed = unitData.targets[index]
		if removed then
			local entries = {}
			for oldIndex = 1, #unitData.targets do
				if oldIndex ~= index then
					entries[#entries + 1] = unitData.targets[oldIndex]
				end
			end
			if not entries[1] then
				removeUnit(unitID)
				return
			end
			assignTargetList(
				unitData,
				targetListStore:getOrCreateSharedTargetList(entries, unitData.teamID, unitData.allyTeam)
			)
			if index == unitData.currentIndex then
				setTargetPassive(unitID, unitData)
			elseif index < unitData.currentIndex then
				unitData.currentIndex = unitData.currentIndex - 1
			end
			if index < unitData.scanIndex then
				unitData.scanIndex = unitData.scanIndex - 1
			end
			unitData.scanIndex = min(unitData.scanIndex, #entries)
			refreshSendData(unitID, unitData, index)
		end
	end

	local function removeWithStop(unitID)
		local unitData = setTargetData[unitID]
		local targetList = unitData.targets
		local n = #targetList
		-- It is highly likely that we remove the unit:
		local canRemoveAll = true
		for i = 1, n do
			if targetList[i].ignoreStop then
				canRemoveAll = false
				break
			end
		end
		if canRemoveAll then
			removeUnit(unitID)
			return
		end
		-- Otherwise there really are targets to keep:
		local oldIndex = unitData.currentIndex
		local currentIndex = oldIndex
		local minIndex
		local entries = {}
		for i = 1, n do
			if targetList[i].ignoreStop then
				local moveToIndex = #entries + 1
				entries[moveToIndex] = targetList[i]
				if oldIndex == i then
					currentIndex = moveToIndex
				end
			else
				if not minIndex then
					minIndex = i
				end
				if oldIndex == i then
					currentIndex = 0 -- invalid, see below
				end
			end
		end
		if not minIndex then
			return
		end
		assignTargetList(
			unitData,
			targetListStore:getOrCreateSharedTargetList(entries, unitData.teamID, unitData.allyTeam)
		)
		if currentIndex == 0 then
			unitData.currentIndex = 1
			unitData.activeTarget = false
		else
			unitData.currentIndex = currentIndex
			-- The active target remains the same.
		end
		---@diagnostic disable-next-line: assign-type-mismatch -- Both inputs are integer indices.
		unitData.scanIndex = min(unitData.scanIndex, #entries)
		refreshSendData(unitID, unitData, minIndex)
	end

	---A single entry in a unit's target queue, as tracked on the synced side.
	---@class UnitTargetEntry
	---@field target UnitID|Position3D Either a target unitID or a `{x, y, z}` ground position.
	---@field alwaysSeen boolean? Target does not need to stay in sensor range to be kept.
	---@field ignoreStop boolean? Target survives a Stop command.
	---@field userTarget boolean? Target was set by the player rather than by Lua.
	---@field sent boolean? Target has already been pushed to the unit's weapons.

	---Returns the unit's currently active target.
	---@param unitID UnitID
	---@return UnitID|Position3D|nil target A unitID, a `{x, y, z}` ground position, or `nil` when untargeted.
	function GG.GetUnitTarget(unitID)
		local unitData = activeTargets[unitID]
		local targetData = unitData and unitData.targets[unitData.currentIndex]
		return targetData and targetData.target
	end

	---Returns the unit's whole target queue.
	---@param unitID UnitID
	---@return UnitTargetEntry[]? targets `nil` when the unit has no targets.
	function GG.GetUnitTargetList(unitID)
		return setTargetData[unitID] and setTargetData[unitID].targets
	end

	---Returns the immutable shared target-list identifier used by a unit.
	---@param unitID UnitID
	---@return integer? listID
	function GG.GetUnitTargetListID(unitID)
		local unitData = setTargetData[unitID]
		return unitData and unitData.targetList and unitData.targetList.id
	end

	---Returns the position in the target queue that is currently active.
	---@param unitID UnitID
	---@return integer? index `nil` when the unit has no targets.
	function GG.GetUnitTargetIndex(unitID)
		return activeTargets[unitID] and activeTargets[unitID].currentIndex
	end

	function gadget:Initialize()
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_CANCEL_TARGET)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGETS)
		gadgetHandler:RegisterCMDID(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_NO_GROUND)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGET_RECTANGLE)
		gadgetHandler:RegisterAllowCommand(CMD_UNIT_SET_TARGETS)
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
			spInsertUnitCmdDesc(unitID, unitSetTargetsCmdDesc)
			if setTargetData[builderID] and validUnits[unitDefID] then
				addUnitTargets(unitID, unitDefID, setTargetData[builderID].targets, false)
			end
		end
	end

	function gadget:UnitGiven(unitID, unitDefID, unitTeam)
		removeUnit(unitID)
		removeTransferredTargetFromLists(unitID, unitTeam)
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
	local preparedTargetListCache = {}
	---@type table<string, any>
	local explicitTargetListCache = {}
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
			if
				weaponType
				and spGetUnitWeaponTestTarget(unitID, weaponNum, x, weaponType == WATERWEAPON and y or max(y, 1), z)
			then
				-- We may or may not adjust this targetY depending on weapon order, which can tend to seem arbitrary.
				if weaponType ~= WATERWEAPON then
					xyz[2] = max(y, 1)
				end
				return true
			end
		end
		return false
	end

	local function getExplicitTargetList(unitID, unitDefID, unitTeam, targetIDs, ignoreStop, userTarget)
		local cacheKey = table.concat({ unitTeam, unitDefID, ignoreStop and 1 or 0, userTarget and 1 or 0 }, ":")
		local cached = explicitTargetListCache[cacheKey]
		if cached and #cached.targetIDs == #targetIDs then
			local matches = true
			for index = 1, #targetIDs do
				if cached.targetIDs[index] ~= targetIDs[index] then
					matches = false
					break
				end
			end
			if matches then
				return cached.targetList
			end
		end

		local weaponList = unitWeapons[unitDefID]
		local entries = {}
		for index = 1, #targetIDs do
			local targetID = targetIDs[index]
			if
				spValidUnitID(targetID)
				and not spAreTeamsAllied(unitTeam, spGetUnitTeam(targetID))
				and allowTargetUnit(unitID, weaponList, targetID)
			then
				entries[#entries + 1] = {
					alwaysSeen = unitAlwaysSeen[spGetUnitDefID(targetID)],
					ignoreStop = ignoreStop,
					userTarget = userTarget,
					target = targetID,
				}
			end
		end
		if not entries[1] then
			return
		end

		local targetIDCopy = {}
		for index = 1, #targetIDs do
			targetIDCopy[index] = targetIDs[index]
		end
		local targetList = {
			sharedList = targetListStore:getOrCreateSharedTargetList(entries, unitTeam, spGetUnitAllyTeam(unitID)),
		}
		---@diagnostic disable-next-line: inject-field -- Dynamic string-keyed cache.
		explicitTargetListCache[cacheKey] = {
			targetIDs = targetIDCopy,
			targetList = targetList,
		}
		return targetList
	end

	---Assign an explicit unit-target list through the shared target-list backend.
	---Command gadgets can use this for compact storage and rendering while
	---retaining engine movement and weapon targeting.
	---@param unitID UnitID
	---@param unitDefID UnitDefID
	---@param targetIDs UnitID[]
	---@param sourceKey any
	---@return integer? listID
	function GG.SetUnitTargetList(unitID, unitDefID, targetIDs, sourceKey)
		if not validUnits[unitDefID] or not spValidUnitID(unitID) then
			return
		end
		local unitTeam = spGetUnitTeam(unitID)
		local targetList = getExplicitTargetList(unitID, unitDefID, unitTeam, targetIDs, false, true)
		if not targetList then
			return
		end
		addUnitTargets(unitID, unitDefID, targetList, false, true, false, false, false)
		local unitData = setTargetData[unitID]
		---@cast unitData table
		unitData.sourceKey = sourceKey
		return unitData.targetList.id
	end

	---Append explicit unit targets without mutating the list shared by other units.
	---@param unitID UnitID
	---@param unitDefID UnitDefID
	---@param targetIDs UnitID[]
	---@param sourceKey any
	---@return integer? listID
	function GG.AppendUnitTargetList(unitID, unitDefID, targetIDs, sourceKey)
		local unitData = setTargetData[unitID]
		if
			not validUnits[unitDefID]
			or not spValidUnitID(unitID)
			or not unitData
			or unitData.sourceKey ~= sourceKey
		then
			return
		end
		local unitTeam = spGetUnitTeam(unitID)
		local targetList = getExplicitTargetList(unitID, unitDefID, unitTeam, targetIDs, false, true)
		if not targetList then
			return unitData.targetList.id
		end
		addUnitTargets(unitID, unitDefID, targetList, true, true, false, true, false)
		unitData = setTargetData[unitID]
		---@cast unitData table
		unitData.sourceKey = sourceKey
		return unitData.targetList.id
	end

	---@param unitID UnitID
	---@param sourceKey any
	function GG.ClearUnitTargetList(unitID, sourceKey)
		local unitData = setTargetData[unitID]
		if unitData and unitData.sourceKey == sourceKey then
			removeUnit(unitID)
		end
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

		if
			cmdID == CMD_UNIT_SET_TARGET_NO_GROUND
			or cmdID == CMD_UNIT_SET_TARGET
			or cmdID == CMD_UNIT_SET_TARGET_RECTANGLE
			or cmdID == CMD_UNIT_SET_TARGETS
		then
			local addTargetList

			local weaponList = unitWeapons[unitDefID]
			local append = cmdOptions.shift or false
			local prepend = cmdOptions.meta and not append
			local userTarget = not cmdOptions.internal
			local ignoreStop = cmdOptions.ctrl

			if cmdID == CMD_UNIT_SET_TARGETS then
				addTargetList = getExplicitTargetList(unitID, unitDefID, unitTeam, cmdParams, ignoreStop, userTarget)
			elseif nParams > 3 then
				if not cmdOptions.internal then
					SendToUnsynced("settarget_line_sound", unitTeam, -1, unitID, cmdID)
				end

				local targets
				local queryHash
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
					queryHash = left + top + right + bot
					targets = teamCache[queryHash]
					if not targets then
						targets = CallAsTeam(unitTeam, spGetUnitsInRectangle, left, top, right, bot, ENEMY_UNITS)
						teamCache[queryHash] = targets
					end
				elseif nParams == 4 then
					local teamCache = ensureTable(teamQueryCaches, spGetUnitAllyTeam(unitID))
					queryHash = -(cmdParams[1] + cmdParams[2] + cmdParams[3] + cmdParams[4])
					targets = teamCache[queryHash]
					if not targets then
						targets = CallAsTeam(
							unitTeam,
							spGetUnitsInCylinder,
							cmdParams[1],
							cmdParams[3],
							cmdParams[4],
							ENEMY_UNITS
						)
						teamCache[queryHash] = targets
					end
				end
				if targets and targets[1] then
					local cacheKey = table.concat({
						spGetUnitAllyTeam(unitID),
						queryHash,
						unitDefID,
						ignoreStop and 1 or 0,
						userTarget and 1 or 0,
					}, ":")
					addTargetList = preparedTargetListCache[cacheKey]
					if addTargetList == nil then
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
								}
							end
						end
						if count > 0 then
							addTargetList = targetList
							preparedTargetListCache[cacheKey] = targetList
						else
							preparedTargetListCache[cacheKey] = false
						end
					end
					if addTargetList == false then
						addTargetList = nil
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
					addTargetList = {
						{
							alwaysSeen = true,
							ignoreStop = ignoreStop,
							userTarget = userTarget,
							target = target,
						},
					}
				end
			elseif nParams == 1 then
				local target = cmdParams[1]
				if spValidUnitID(target) and not spAreTeamsAllied(unitTeam, spGetUnitTeam(target)) then
					if allowTargetUnit(unitID, weaponList, target) then
						addTargetList = {
							{
								alwaysSeen = unitAlwaysSeen[spGetUnitDefID(target)],
								ignoreStop = ignoreStop,
								userTarget = userTarget,
								target = target,
							},
						}
					end
				end
			end

			if addTargetList then
				addUnitTargets(unitID, unitDefID, addTargetList, append, nil, prepend, cmdID == CMD_UNIT_SET_TARGETS)
				setTargetData[unitID].sourceKey = nil
			elseif unitData and not append and not prepend then
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
		pausedTargets[unitID] = activeTargets[unitID]
		removeUnit(unitID, true)
		pendingTargetPauses[unitID] = true
	end

	local function unpauseTargetting(unitID)
		activeTargets[unitID] = pausedTargets[unitID]
		pausedTargets[unitID] = nil
		addToQueue(unitID)
		pendingTargetPauses[unitID] = false
	end

	function gadget:UnitCommand(unitID, unitDefID, teamID, cmdID, cmdParams, cmdOptions, cmdTag)
		if cmdID == CMD_STOP and setTargetData[unitID] then
			removeWithStop(unitID)
		end
	end

	function gadget:AllowCommand(
		unitID,
		unitDefID,
		teamID,
		cmdID,
		cmdParams,
		cmdOptions,
		cmdTag,
		playerID,
		fromSynced,
		fromLua,
		fromInsert
	)
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
			if not unitData.targets[1] then
				removeUnit(unitID)
			elseif not unitData.targetingEnabled then
				-- Controller-only lists are displayed and validated but never select weapons.
			elseif activeTargets[unitID] then
				if not hasTargetPrecedence(unitID, unitData) then
					pauseTargetting(unitID)
				end
			else
				if hasTargetPrecedence(unitID, unitData) then
					unpauseTargetting(unitID)
				end
			end
		end
	end

	---@param oldList SharedTargetList
	---@param retainedEntries table[]
	---@param oldToNewIndex table<integer, integer?>
	local function replaceSharedTargetList(oldList, retainedEntries, oldToNewIndex)
		---@type integer[]
		local unitIDs = {}
		for unitID in pairsNext, oldList.units do
			unitIDs[#unitIDs + 1] = unitID
		end

		if not retainedEntries[1] then
			for index = 1, #unitIDs do
				removeUnit(unitIDs[index])
			end
			return
		end

		local newList = targetListStore:getOrCreateSharedTargetList(retainedEntries, oldList.teamID, oldList.allyTeam)
		for oldIndex, newIndex in pairs(oldToNewIndex) do
			---@diagnostic disable-next-line: need-check-nil -- The map only contains retained entry indices.
			local target = oldList.entries[oldIndex].target
			local wasUnavailable = newList.unavailable[target]
			newList.unavailable[target] = oldList.unavailable[target]
			newList.unseenSince[target] = oldList.unseenSince[target]
			if wasUnavailable ~= newList.unavailable[target] and sentSharedTargetLists[newList.id] then
				sendSharedTargetEntryToUnsynced(newList, newIndex)
			end
		end

		local function nextRetainedIndex(oldIndex)
			for index = oldIndex, #oldList.entries do
				if oldToNewIndex[index] then
					return oldToNewIndex[index]
				end
			end
			return 1
		end

		for index = 1, #unitIDs do
			local unitID = unitIDs[index]
			local unitData = setTargetData[unitID]
			if unitData and unitData.targetList == oldList then
				local newCurrentIndex = oldToNewIndex[unitData.currentIndex]
				local newScanIndex = nextRetainedIndex(unitData.scanIndex or 1)
				if unitData.activeTarget and not newCurrentIndex then
					setTargetPassive(unitID, unitData)
				end
				assignTargetList(unitData, newList)
				unitData.currentIndex = newCurrentIndex or 1
				unitData.scanIndex = newScanIndex
				queueTargetsToUnsynced(unitID)
				pendingTargetIndices[unitID] = { unitData.currentIndex, unitData.activeTarget }
			end
		end
	end

	removeTransferredTargetFromLists = function(targetID, targetTeam)
		---@type SharedTargetList[]
		local lists = {}
		for index = 1, validationWorkQueueLength do
			lists[index] = validationWorkQueue[index]
		end

		for index = 1, #lists do
			local list = lists[index]
			local removeIndex = list.lookup[targetID]
			if removeIndex and spAreTeamsAllied(list.teamID, targetTeam) then
				local retainedEntries = {}
				---@type table<integer, integer?>
				local oldToNewIndex = {}
				for oldIndex = 1, #list.entries do
					if oldIndex ~= removeIndex then
						local newIndex = #retainedEntries + 1
						retainedEntries[newIndex] = list.entries[oldIndex]
						oldToNewIndex[oldIndex] = newIndex
					end
				end
				replaceSharedTargetList(list, retainedEntries, oldToNewIndex)
			end
		end
	end

	function GG.ClearTargetListsForAllianceChange(teamA, teamB)
		local unitIDs = {}
		for unitID, unitData in pairsNext, setTargetData do
			if unitData.teamID == teamA or unitData.teamID == teamB then
				unitIDs[#unitIDs + 1] = unitID
			end
		end
		for index = 1, #unitIDs do
			removeUnit(unitIDs[index])
		end
	end

	local function updateSharedTargetList(list, frame, checkBudget)
		local checks = 0
		local maxChecks = min(listValidityChecksPerUpdate, checkBudget, #list.entries)
		local index = list.validationIndex or 1
		---@type table<integer, boolean>?
		local removeIndices

		while checks < maxChecks and list.entries[1] do
			if index > #list.entries then
				index = 1
			end
			local targetData = list.entries[index]
			local target = targetData.target
			local removeTargetFromList = false
			checks = checks + 1

			local wasUnavailable = list.unavailable[target]
			local isLost, isDead = wasTargetLost(target, targetData.alwaysSeen, list.allyTeam)
			local unseenSince = list.unseenSince[target]
			list.unavailable[target] = isLost or nil
			if wasUnavailable ~= list.unavailable[target] and sentSharedTargetLists[list.id] then
				sendSharedTargetEntryToUnsynced(list, index)
			end
			if not isLost then
				list.unseenSince[target] = nil
			elseif isDead or (unseenSince and frame - unseenSince >= unseenGraceFrames) then
				removeTargetFromList = true
			elseif not unseenSince then
				list.unseenSince[target] = frame
			end

			if removeTargetFromList then
				removeIndices = removeIndices or {}
				removeIndices[index] = true
			end
			index = index + 1
		end

		list.validationIndex = index > #list.entries and 1 or index
		if removeIndices then
			local retainedEntries = {}
			local oldToNewIndex = {}
			for oldIndex = 1, #list.entries do
				if not removeIndices[oldIndex] then
					local newIndex = #retainedEntries + 1
					retainedEntries[newIndex] = list.entries[oldIndex]
					oldToNewIndex[oldIndex] = newIndex
				end
			end
			replaceSharedTargetList(list, retainedEntries, oldToNewIndex)
		end
		return checks
	end

	local function processSharedTargetLists(frame)
		local checks = 0
		local processedLists = 0
		local listsAtStart = validationWorkQueueLength
		while checks < listValidityChecksPerFrame and processedLists < listsAtStart and validationWorkQueueLength > 0 do
			if validationWorkQueueIndex > validationWorkQueueLength then
				validationWorkQueueIndex = 1
			end
			local list = validationWorkQueue[validationWorkQueueIndex]
			validationWorkQueueIndex = validationWorkQueueIndex + 1
			processedLists = processedLists + 1
			checks = checks + updateSharedTargetList(list, frame, listValidityChecksPerFrame - checks)
		end
	end

	local function updateTargetList(unitID, frame, checkBudget)
		local unitData = activeTargets[unitID]
		if not unitData then
			removeFromQueue(unitID)
			return 0
		end

		local checks = 0
		local maxChecks = min(targetChecksPerUnitUpdate, checkBudget)
		---@type integer?
		local candidateIndex
		local activeIndex = unitData.activeTarget and unitData.currentIndex or nil
		local activeWasChecked = false
		local activeIsAttackable = false
		local index = unitData.scanIndex or 1

		while checks < maxChecks and unitData.targets[1] do
			local targets = unitData.targets
			local targetCount = #targets
			if index > targetCount then
				index = 1
			end

			local targetData = targets[index]
			local target = targetData.target
			checks = checks + 1

			if unitData.targetList.unavailable[target] then
				index = index + 1
			else
				local attackable = testTarget(unitID, unitData.teamID, unitData.weapons, target)
				if activeIndex == index then
					activeWasChecked = true
					---@diagnostic disable-next-line: assign-type-mismatch -- nil is the function's false result.
					activeIsAttackable = attackable
				end
				---@diagnostic disable: unnecessary-if -- testTarget returns true or nil.
				if
					attackable
					and (not activeIndex or index < activeIndex)
					and (not candidateIndex or index < candidateIndex)
				then
					candidateIndex = index
				end
				---@diagnostic enable: unnecessary-if
				index = index + 1
			end
		end

		if not setTargetData[unitID] then
			return checks
		end
		if unitData.targets[1] then
			unitData.scanIndex = index > #unitData.targets and 1 or index
		end

		if candidateIndex then
			setTargetActive(unitID, unitData, candidateIndex)
		elseif activeWasChecked and not activeIsAttackable then
			setTargetPassive(unitID, unitData)
		end

		return checks
	end

	local function processTargetListChunk(frame)
		if workQueueLength == 0 then
			return
		end
		local processCount = clamp(workQueueLength / updateFrames, min(workQueueLength, chunkSizeMin), chunkSizeMax)
		local checks = 0
		for _ = 1, processCount do
			if checks >= targetChecksPerFrame then
				break
			end
			if workQueueIndex > workQueueLength then
				workQueueIndex = 1
			end
			local unitID = updateWorkQueue[workQueueIndex]
			workQueueIndex = workQueueIndex + 1
			checks = checks + updateTargetList(unitID, frame, targetChecksPerFrame - checks)
		end
	end

	-- Since v103 Attack commands override the unit target on any frame, not just slow updates.
	-- So we try to override the target again, every single frame, to prevent target jittering.
	function gadget:GameFrame(frame)
		teamQueryCaches = {}
		preparedTargetListCache = {}
		explicitTargetListCache = {}
		processSharedTargetLists(frame)
		if frame % 15 == 0 then
			processSlowListUpdates()
		else
			processTargetListChunk(frame)
		end
		flushTargetsToUnsynced()
	end
else -- UNSYNCED
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
	local spGetMyAllyTeamID = Spring.GetLocalAllyTeamID
	local spGetMyTeamID = Spring.GetLocalTeamID
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
	local attackQueueColour = { 1, 0.2, 0.2, 0.4 }
	local attackCommandColour = { 1, 0, 0, 0.7 }

	local drawAllTargets = {}
	local drawTarget = {}
	local targetList = {}
	local sharedTargetLists = {}

	function gadget:Initialize()
		gadgetHandler:AddChatAction(
			"targetdrawteam",
			handleTargetDrawEvent,
			"toggles drawing targets for units, params: teamID doDraw"
		)
		gadgetHandler:AddChatAction(
			"targetdrawunit",
			handleUnitTargetDrawEvent,
			"toggles drawing targets for units, params: unitID"
		)
		gadgetHandler:AddSyncAction("targetList", handleTargetListEvent)
		gadgetHandler:AddSyncAction("targetDrop", handleTargetDropEvent)
		gadgetHandler:AddSyncAction("targetListShared", handleSharedTargetListEvent)
		gadgetHandler:AddSyncAction("targetListReference", handleTargetListReferenceEvent)
		gadgetHandler:AddSyncAction("targetListRelease", handleTargetListReleaseEvent)
		gadgetHandler:AddSyncAction("targetIndex", handleTargetIndexEvent)
		gadgetHandler:AddSyncAction("targetPause", handleTargetPauseEvent)
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
		gadgetHandler:RemoveSyncAction("targetListShared")
		gadgetHandler:RemoveSyncAction("targetListReference")
		gadgetHandler:RemoveSyncAction("targetListRelease")
		gadgetHandler:RemoveSyncAction("targetIndex")
		gadgetHandler:RemoveSyncAction("targetPause")
		gadgetHandler:RemoveSyncAction("failCommand")
	end

	---An entry in the unsynced mirror of a unit's target queue, kept for drawing.
	---@class UnitTargetEntryUnsynced
	---@field target UnitID|Position3D Either a target unitID or a `{x, y, z}` ground position.
	---@field userTarget boolean? Target was set by the player rather than by Lua.
	---@field unavailable boolean? Target is outside the owning allyTeam's sensors.

	---Returns the unsynced mirror of the unit's target queue.
	---@param unitID UnitID
	---@return table<integer, UnitTargetEntryUnsynced>? targets `nil` when the unit has no known targets.
	function GG.getUnitTargetList(unitID)
		return targetList[unitID] and targetList[unitID].targets
	end

	---Returns the position in the unsynced target queue that is currently active.
	---@param unitID UnitID
	---@return integer? index `nil` when the unit has no known targets.
	function GG.getUnitTargetIndex(unitID)
		return targetList[unitID] and targetList[unitID].currentIndex
	end

	function handleFailCommand(_, teamID)
		if teamID == myTeam and not mySpec then
			spPlaySoundFile("FailedCommand", 0.75, "ui")
			spSetActiveCommand("settargetnoground")
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
				targets = {},
				targetIndex = 1,
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
		if unitData and targetA then
			unitData.targets[index] = {
				userTarget = userTarget,
				target = (not targetB and targetA) or { targetA, targetB, targetC },
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

	function handleSharedTargetListEvent(_, listID, index, userTarget, unavailable, targetA, targetB, targetC)
		local targets = sharedTargetLists[listID]
		if not targets then
			targets = {}
			sharedTargetLists[listID] = targets
		end
		if not targetA then
			for removeIndex = #targets, index, -1 do
				targets[removeIndex] = nil
			end
			return
		end
		targets[index] = {
			userTarget = userTarget,
			unavailable = unavailable,
			target = (not targetB and targetA) or { targetA, targetB, targetC },
		}
	end

	function handleTargetListReferenceEvent(_, unitID, listID, renderAsAttack)
		local targets = sharedTargetLists[listID]
		if not targets then
			return
		end
		local unitData = targetList[unitID]
		if not unitData then
			unitData = {
				targetIndex = 1,
				targetActive = false,
			}
			targetList[unitID] = unitData
		end
		unitData.listID = listID
		unitData.targets = targets
		unitData.renderAsAttack = renderAsAttack
		if unitData.targetIndex > #targets then
			unitData.targetIndex = 1
			unitData.targetActive = false
		end
	end

	function handleTargetListReleaseEvent(_, listID)
		sharedTargetLists[listID] = nil
	end

	function handleTargetIndexEvent(_, unitID, index, active)
		if not targetList[unitID] then
			return
		end
		targetList[unitID].targetIndex = index
		targetList[unitID].targetActive = active
	end

	function handleTargetPauseEvent(_, unitID, paused)
		local unitData = targetList[unitID]
		if unitData then
			unitData.paused = paused
		end
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
	local sharedQueuesDrawn = {}
	local function drawUnitTarget(cacheKey, x, y, z, commandID)
		glVertex(x, y, z)
		cacheKey = commandID .. ":" .. cacheKey
		if not unitIconsDrawn[cacheKey] then
			-- avoid sending WorldIcons to engine at the same unit/location
			spAddWorldIcon(commandID, x, y, z)
			unitIconsDrawn[cacheKey] = true
		end
	end

	local function drawTargetCommand(targetData, renderAsAttack)
		if targetData and targetData.userTarget then
			local target = targetData.target
			local isUnitTarget = type(target) == "number"
			local commandID = renderAsAttack and CMD_ATTACK or CMD_UNIT_SET_TARGET

			if isUnitTarget and (fullview or not targetData.unavailable) and spValidUnitID(target) then
				local _, _, _, x2, y2, z2 = spGetUnitPosition(target, false, true)
				drawUnitTarget(target, x2, y2, z2, commandID)
			elseif not isUnitTarget and target then
				-- 3d coordinate target
				local x2, y2, z2 = target[1], target[2], target[3]
				drawUnitTarget(x2 + y2 + z2, x2, y2, z2, commandID)
			end
		end
	end

	-- TODO: Need to handle unit ghosts. None of it works well currently.
	local function isValidTargetData(targetData)
		return type(targetData.target) == "table"
			or ((fullview or not targetData.unavailable) and spValidUnitID(targetData.target))
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
			if type(currentTarget) == "table" then
				result = currentTarget[1] == x and currentTarget[2] == y and currentTarget[3] == z
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
			glColor(unitData.renderAsAttack and attackCommandColour or commandColour)
			drawTargetCommand(targetData, unitData.renderAsAttack)
			glColor(unitData.renderAsAttack and attackQueueColour or queueColour)
		else
			drawTargetCommand(targetData, unitData.renderAsAttack)
		end
	end

	local function drawTargetQueue(unitData)
		for _, targetData in ipairs(unitData.targets) do
			drawTargetCommand(targetData, unitData.renderAsAttack)
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
		return spIsUnitSelected(unitID) or drawTarget[unitID] or drawAllTargets[spGetUnitTeam(unitID)]
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

						glColor(unitData.renderAsAttack and attackQueueColour or queueColour)
						if not unitData.paused then
							glBeginEnd(GL_LINES, drawCurrentTarget, unitID, unitData)
						end
						local queueKey = (unitData.renderAsAttack and "attack:" or "settarget:")
							.. (unitData.listID or unitID)
						if not sharedQueuesDrawn[queueKey] then
							sharedQueuesDrawn[queueKey] = true
							glBeginEnd(GL_LINE_STRIP, drawTargetQueue, unitData)
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
		end
		if init then
			stopDrawing()
		end
		drawTarget = {}
		unitIconsDrawn = {}
		sharedQueuesDrawn = {}
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
