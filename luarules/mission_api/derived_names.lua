---
--- A derived unit name comes from a rule, not from an action. A unit has it while the unit is finished, matches
--- the rule's filter, and matches none of its exceptions, and only this module names or unnames units with it.
---

local derivedNamesByUnitName = GG["MissionAPI"].derivedNamesByUnitName
local tracking = GG["MissionAPI"].Modules.Tracking
local unitQuery = GG["MissionAPI"].Modules.UnitQuery
local trackedUnitIDs = GG["MissionAPI"].trackedUnitIDs
local trackedUnitNames = GG["MissionAPI"].trackedUnitNames

local spGetAllUnits = Spring.GetAllUnits
local spGetTeamUnits = Spring.GetTeamUnits
local spGetUnitDefID = Spring.GetUnitDefID
local spGetUnitIsBeingBuilt = Spring.GetUnitIsBeingBuilt
local spGetUnitIsDead = Spring.GetUnitIsDead
local spGetUnitTeam = Spring.GetUnitTeam

local doesUnitHaveName = tracking.DoesUnitHaveName
local trackUnitUnderDerivedName = tracking.TrackUnitUnderDerivedName
local untrackUnitUnderDerivedName = tracking.UntrackUnitUnderDerivedName

local statistics ---@type table
local unitsOwnedType

local NO_UNIT_DEF_ID = -1

local derivedNamesInOrder = {} ---@type table[]
local derivedNamesByRuleUnitName = {}
local derivedNamesByTeamAndDef = {}
local derivedNamesLeftAndJoined = {}

local unitsWithRuleUnitName = {}

-- The old team ID while a unit changes team, else true while the statistics module counts the unit's names itself.
local uncountedUnits = {}

local function compileRule(filter, except)
	local unitDef = filter.unitDefName and UnitDefNames[filter.unitDefName]
	local rule = {
		teamID = filter.teamName,
		unitDefID = filter.unitDefName and (unitDef and unitDef.id or NO_UNIT_DEF_ID),
		unitName = filter.unitName,
		exceptsEveryUnit = false,
		exceptUnitDefIDs = {},
		exceptTeamIDs = {},
		exceptTeamAndDefs = {},
		exceptUnitNames = {},
		exceptFiltersWithUnitName = {},
	}
	for _, exception in ipairs(except) do
		local exceptedDef = exception.unitDefName and UnitDefNames[exception.unitDefName]
		if exception.unitDefName and not exceptedDef then
			-- Matches no unit.
		elseif exception.unitName then
			if exception.unitDefName or exception.teamName then
				rule.exceptFiltersWithUnitName[#rule.exceptFiltersWithUnitName + 1] = exception
			else
				rule.exceptUnitNames[#rule.exceptUnitNames + 1] = exception.unitName
			end
		elseif exceptedDef and exception.teamName then
			rule.exceptTeamAndDefs[#rule.exceptTeamAndDefs + 1] =
				{ teamID = exception.teamName, unitDefID = exceptedDef.id }
		elseif exceptedDef then
			rule.exceptUnitDefIDs[exceptedDef.id] = true
		elseif exception.teamName then
			rule.exceptTeamIDs[exception.teamName] = true
		else
			rule.exceptsEveryUnit = true
		end
	end
	return rule
end

local function doesRuleMatchTeamAndDef(rule, teamID, unitDefID)
	if (rule.teamID ~= nil and rule.teamID ~= teamID) or (rule.unitDefID ~= nil and rule.unitDefID ~= unitDefID) then
		return false
	end
	if rule.exceptsEveryUnit or rule.exceptUnitDefIDs[unitDefID] or rule.exceptTeamIDs[teamID] then
		return false
	end
	local exceptTeamAndDefs = rule.exceptTeamAndDefs
	for i = 1, #exceptTeamAndDefs do
		if exceptTeamAndDefs[i].teamID == teamID and exceptTeamAndDefs[i].unitDefID == unitDefID then
			return false
		end
	end
	return true
end

local function doesRuleMatchNames(rule, unitID, unitDefID, teamID)
	if rule.unitName ~= nil and not doesUnitHaveName(unitID, rule.unitName) then
		return false
	end
	local exceptUnitNames = rule.exceptUnitNames
	for i = 1, #exceptUnitNames do
		if doesUnitHaveName(unitID, exceptUnitNames[i]) then
			return false
		end
	end
	local exceptFiltersWithUnitName = rule.exceptFiltersWithUnitName
	for i = 1, #exceptFiltersWithUnitName do
		if unitQuery.DoesUnitMatchFilter(unitID, exceptFiltersWithUnitName[i], unitDefID, teamID) then
			return false
		end
	end
	return true
end

local function getDerivedNamesOfTeamAndDef(teamID, unitDefID)
	local byDef = derivedNamesByTeamAndDef[teamID]
	if byDef == nil then
		byDef = {}
		derivedNamesByTeamAndDef[teamID] = byDef
	end
	local list = byDef[unitDefID]
	if list == nil then
		list = {}
		for i = 1, #derivedNamesInOrder do
			local rule = derivedNamesInOrder[i].rule
			-- A rule that refers to a unit name is decided per unit, not by team and def.
			if rule.unitName == nil and doesRuleMatchTeamAndDef(rule, teamID, unitDefID) then
				list[#list + 1] = derivedNamesInOrder[i]
			end
		end
		byDef[unitDefID] = list
	end
	return list
end

local function getDerivedNamesLeftAndJoined(oldTeamID, newTeamID, unitDefID)
	local byNewTeam = derivedNamesLeftAndJoined[oldTeamID]
	if byNewTeam == nil then
		byNewTeam = {}
		derivedNamesLeftAndJoined[oldTeamID] = byNewTeam
	end
	local byDef = byNewTeam[newTeamID]
	if byDef == nil then
		byDef = {}
		byNewTeam[newTeamID] = byDef
	end
	local leftAndJoined = byDef[unitDefID]
	if leftAndJoined == nil then
		local before = getDerivedNamesOfTeamAndDef(oldTeamID, unitDefID)
		local after = getDerivedNamesOfTeamAndDef(newTeamID, unitDefID)
		local isBefore, isAfter = {}, {}
		for i = 1, #before do
			isBefore[before[i]] = true
		end
		for i = 1, #after do
			isAfter[after[i]] = true
		end
		leftAndJoined = { left = {}, joined = {} }
		for i = 1, #before do
			if not isAfter[before[i]] then
				leftAndJoined.left[#leftAndJoined.left + 1] = before[i]
			end
		end
		for i = 1, #after do
			if not isBefore[after[i]] then
				leftAndJoined.joined[#leftAndJoined.joined + 1] = after[i]
			end
		end
		byDef[unitDefID] = leftAndJoined
	end
	return leftAndJoined
end

local function scanForRuleUnitName(unitID)
	local names = trackedUnitNames[unitID]
	if names ~= nil then
		for name in pairs(names) do
			if derivedNamesByRuleUnitName[name] then
				return true
			end
		end
	end
	return false
end

local function doesUnitHaveRuleUnitName(unitID)
	if unitsWithRuleUnitName[unitID] then
		return true
	end
	local mapi = GG["MissionAPI"]
	return unitID == mapi.unitIDBeingSpawned and derivedNamesByRuleUnitName[mapi.nameOfUnitBeingSpawned] ~= nil
end

local function indexDerivedNames(changedUnitName)
	local list, byRuleUnitName = {}, {}
	local isListed = false
	for i = 1, #derivedNamesInOrder do
		local unitName = derivedNamesInOrder[i].unitName
		if derivedNamesByUnitName[unitName] ~= nil then
			list[#list + 1] = derivedNamesByUnitName[unitName]
		end
		isListed = isListed or unitName == changedUnitName
	end
	-- A new derived name goes last, so every pass visits derived names in the order they were added.
	if not isListed and derivedNamesByUnitName[changedUnitName] ~= nil then
		list[#list + 1] = derivedNamesByUnitName[changedUnitName]
	end

	local withRuleUnitName = {}
	for _, derivedName in ipairs(list) do
		for ruleUnitName in pairs(derivedName.ruleUnitNames) do
			local derivedNamesOfRuleUnitName = byRuleUnitName[ruleUnitName]
			if derivedNamesOfRuleUnitName == nil then
				derivedNamesOfRuleUnitName = {}
				byRuleUnitName[ruleUnitName] = derivedNamesOfRuleUnitName
				for unitID in pairs(trackedUnitIDs[ruleUnitName] or {}) do
					withRuleUnitName[unitID] = true
				end
			end
			derivedNamesOfRuleUnitName[#derivedNamesOfRuleUnitName + 1] = derivedName
		end
	end

	derivedNamesInOrder, derivedNamesByRuleUnitName = list, byRuleUnitName
	derivedNamesByTeamAndDef, derivedNamesLeftAndJoined = {}, {}
	unitsWithRuleUnitName = withRuleUnitName
end

local function countMembershipChange(unitName, unitDefID, teamID, direction)
	statistics.CountUnitNameChange(unitsOwnedType, teamID, UnitDefs[unitDefID].name, unitName, direction)
end

local function updateMembership(derivedName, unitID, unitDefID, teamID, finished)
	local rule = derivedName.rule
	local isMember = finished
		and doesRuleMatchTeamAndDef(rule, teamID, unitDefID)
		and doesRuleMatchNames(rule, unitID, unitDefID, teamID)

	local unitName = derivedName.unitName
	if isMember then
		if trackUnitUnderDerivedName(unitName, unitID) and not uncountedUnits[unitID] then
			countMembershipChange(unitName, unitDefID, teamID, 1)
		end
	elseif untrackUnitUnderDerivedName(unitName, unitID) and not uncountedUnits[unitID] then
		countMembershipChange(unitName, unitDefID, teamID, -1)
	end
end

local function updateUnitInDerivedNames(list, unitID, unitDefID, teamID, finished)
	for i = 1, #list do
		updateMembership(list[i], unitID, unitDefID, teamID, finished)
	end
end

local function onUnitNameChanged(unitID, name)
	local derivedNamesOfRuleUnitName = derivedNamesByRuleUnitName[name]
	if derivedNamesOfRuleUnitName == nil then
		return
	end
	unitsWithRuleUnitName[unitID] = scanForRuleUnitName(unitID) or nil
	if spGetUnitIsDead(unitID) ~= false then
		return
	end

	local finished = not spGetUnitIsBeingBuilt(unitID)
	updateUnitInDerivedNames(
		derivedNamesOfRuleUnitName,
		unitID,
		spGetUnitDefID(unitID),
		spGetUnitTeam(unitID),
		finished
	)
end

local function isDerivedNameRefused(unitName, ruleUnitNames)
	for ruleUnitName in pairs(ruleUnitNames) do
		if ruleUnitName == unitName or derivedNamesByUnitName[ruleUnitName] then
			return true
		end
	end
	for _, otherDerivedName in ipairs(derivedNamesByRuleUnitName[unitName] or {}) do
		if otherDerivedName.unitName ~= unitName then
			return true
		end
	end
	return derivedNamesByUnitName[unitName] == nil and not tracking.IsUnitNameUntracked(unitName)
end

----------------------------------------------------------------
--- Exported functions:
----------------------------------------------------------------

local function init(dependencies)
	statistics = dependencies.statistics
	unitsOwnedType = GG["MissionAPI"].ConditionDefinitions.Types.UnitsOwned
	tracking.ReportUnitNameChanges(onUnitNameChanged)
	derivedNamesInOrder = {}
	indexDerivedNames()
end

---Adding a derived unit name already in use replaces its rule.
---Refuses one whose rule refers to a derived name, whose name another rule refers to, or that units already have.
local function addDerivedUnitName(unitName, filter, except)
	except = except or {}
	local ruleUnitNames = {}
	if filter.unitName then
		ruleUnitNames[filter.unitName] = true
	end
	for _, exception in ipairs(except) do
		if exception.unitName then
			ruleUnitNames[exception.unitName] = true
		end
	end
	if isDerivedNameRefused(unitName, ruleUnitNames) then
		return
	end

	local replacing = derivedNamesByUnitName[unitName] ~= nil
	local derivedName = {
		unitName = unitName,
		rule = compileRule(filter, except),
		ruleUnitNames = ruleUnitNames,
	}
	derivedNamesByUnitName[unitName] = derivedName
	indexDerivedNames(unitName)

	-- A replaced rule's old members can be on any team.
	local unitIDs
	if replacing then
		unitIDs = spGetAllUnits()
	elseif filter.unitName then
		unitIDs = unitQuery.MatchingUnits(filter.unitName)
		if filter.unitName == GG["MissionAPI"].nameOfUnitBeingSpawned then
			unitIDs[#unitIDs + 1] = GG["MissionAPI"].unitIDBeingSpawned
		end
	elseif filter.teamName then
		unitIDs = spGetTeamUnits(filter.teamName)
	else
		unitIDs = spGetAllUnits()
	end
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		-- A unit that died this frame is still listed, and was uncounted with its names already.
		if spGetUnitIsDead(unitID) == false then
			local finished = not spGetUnitIsBeingBuilt(unitID)
			updateMembership(derivedName, unitID, spGetUnitDefID(unitID), spGetUnitTeam(unitID), finished)
		end
	end
end

local function removeDerivedUnitName(unitName)
	if derivedNamesByUnitName[unitName] == nil then
		return
	end
	derivedNamesByUnitName[unitName] = nil
	indexDerivedNames(unitName)

	local unitIDs = unitQuery.MatchingUnits(unitName)
	for i = 1, #unitIDs do
		local unitID = unitIDs[i]
		untrackUnitUnderDerivedName(unitName, unitID)
		if not uncountedUnits[unitID] then
			countMembershipChange(unitName, spGetUnitDefID(unitID), spGetUnitTeam(unitID), -1)
		end
	end
end

---Call before UnitFinished's dispatch.
local function onUnitFinished(unitID, unitDefID)
	-- A gadget that hears of the unit first can have destroyed it or given it away.
	if derivedNamesInOrder[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end
	local teamID = spGetUnitTeam(unitID)
	if doesUnitHaveRuleUnitName(unitID) then
		updateUnitInDerivedNames(derivedNamesInOrder, unitID, unitDefID, teamID, true)
		return
	end

	local joined = getDerivedNamesOfTeamAndDef(teamID, unitDefID)
	if joined[1] == nil then
		return
	end
	local counted = not uncountedUnits[unitID]
	for i = 1, #joined do
		local unitName = joined[i].unitName
		if trackUnitUnderDerivedName(unitName, unitID) and counted then
			countMembershipChange(unitName, unitDefID, teamID, 1)
		end
	end
end

local function onUnitReverseBuilt(unitID, unitDefID)
	if derivedNamesInOrder[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end
	local teamID = spGetUnitTeam(unitID)
	if doesUnitHaveRuleUnitName(unitID) then
		updateUnitInDerivedNames(derivedNamesInOrder, unitID, unitDefID, teamID, false)
		return
	end

	local left = getDerivedNamesOfTeamAndDef(teamID, unitDefID)
	if left[1] == nil then
		return
	end
	local counted = not uncountedUnits[unitID]
	for i = 1, #left do
		local unitName = left[i].unitName
		if untrackUnitUnderDerivedName(unitName, unitID) and counted then
			countMembershipChange(unitName, unitDefID, teamID, -1)
		end
	end
end

---Call before MetaUnitAdded's dispatch.
local function onMetaUnitAdded(unitID, unitDefID, teamID)
	-- A team ID here means the unit is changing team.
	local oldTeamID = uncountedUnits[unitID]
	uncountedUnits[unitID] = true
	if not oldTeamID or oldTeamID == true or derivedNamesInOrder[1] == nil or spGetUnitIsDead(unitID) ~= false then
		return
	end

	local finished = not spGetUnitIsBeingBuilt(unitID)
	if doesUnitHaveRuleUnitName(unitID) then
		updateUnitInDerivedNames(derivedNamesInOrder, unitID, unitDefID, teamID, finished)
	elseif finished then
		-- Joins come before leaves, so the unit keeps its table of names throughout.
		local leftAndJoined = getDerivedNamesLeftAndJoined(oldTeamID, teamID, unitDefID)
		local joined, left = leftAndJoined.joined, leftAndJoined.left
		for i = 1, #joined do
			trackUnitUnderDerivedName(joined[i].unitName, unitID)
		end
		for i = 1, #left do
			untrackUnitUnderDerivedName(left[i].unitName, unitID)
		end
	end
end

---Call after MetaUnitAdded's dispatch and before its Increment.
local function onMetaUnitAddedCounted(unitID)
	uncountedUnits[unitID] = nil
end

---Call after MetaUnitRemoved's dispatch and before its Decrement.
local function onMetaUnitRemoved(unitID, unitDefID, teamID)
	uncountedUnits[unitID] = spGetUnitIsDead(unitID) == false and teamID or true
end

local function onUnitDestroyed(unitID)
	unitsWithRuleUnitName[unitID] = nil
	uncountedUnits[unitID] = nil
end

return {
	Init = init,
	AddDerivedUnitName = addDerivedUnitName,
	RemoveDerivedUnitName = removeDerivedUnitName,
	OnUnitFinished = onUnitFinished,
	OnUnitReverseBuilt = onUnitReverseBuilt,
	OnMetaUnitAdded = onMetaUnitAdded,
	OnMetaUnitAddedCounted = onMetaUnitAddedCounted,
	OnMetaUnitRemoved = onMetaUnitRemoved,
	OnUnitDestroyed = onUnitDestroyed,
}
