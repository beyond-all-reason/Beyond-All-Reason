local Protocol = {
	OP_CLEAR = 0,
	OP_DELTA = 1,
	OP_SET_EXPLICIT = 2,
	OP_SET_TEAM = 3,
	OP_SET_DEFS = 4,
}

-- All numeric fields are little-endian u16 values. Semantic snapshots carry
-- the sender's baseline fingerprint, but expand against the receiver's current
-- unit roster so transient frame differences do not discard the selection.
-- DELTA:       op, addCount, removeCount, addIDs, removeIDs
-- SET_EXPLICIT: op, unitCount, unitIDs
-- SET_TEAM:     op, fingerprint(3), includeCount, excludeCount, includeIDs, excludeIDs
-- SET_DEFS:     op, fingerprint(3), defCount, includeCount, excludeCount, defIDs, includeIDs, excludeIDs

local strByte = string.byte
local strChar = string.char
local tConcat = table.concat
local floor = math.floor
local U16_RANGE = 65536

local function packU16(value)
	return strChar(value % 256, floor(value / 256))
end

local function unpackU16(msg, pos)
	if pos + 1 > #msg then
		return nil
	end
	local low, high = strByte(msg, pos, pos + 1)
	return low + high * 256
end

local function appendPackedList(parts, partCount, values, count, packValue)
	for i = 1, count do
		partCount = partCount + 1
		parts[partCount] = packValue(values[i])
	end
	return partCount
end

local function unpackList(msg, pos, count)
	local values = {}
	for i = 1, count do
		values[i] = unpackU16(msg, pos)
		pos = pos + 2
	end
	return values, pos
end

function Protocol.EncodeClear()
	return strChar(Protocol.OP_CLEAR)
end

function Protocol.EncodeDelta(addUnits, addCount, removeUnits, removeCount, packValue)
	packValue = packValue or packU16
	local parts = {
		strChar(Protocol.OP_DELTA),
		packU16(addCount),
		packU16(removeCount),
	}
	local partCount = 3
	partCount = appendPackedList(parts, partCount, addUnits, addCount, packValue)
	partCount = appendPackedList(parts, partCount, removeUnits, removeCount, packValue)
	return tConcat(parts, "", 1, partCount)
end

function Protocol.BuildSnapshotPlan(selectedUnits, selectedCount, teamUnitsByDef)
	local selectedSet = {}
	for i = 1, selectedCount do
		selectedSet[selectedUnits[i]] = true
	end

	local normalizedUnitsByDef = {}
	local teamUnitDef = {}
	local teamUnitCount = 0
	local teamUnitSum = 0
	local teamUnitSumSquares = 0
	for unitDefID, units in pairs(teamUnitsByDef) do
		if type(unitDefID) == "number" and type(units) == "table" then
			local normalizedUnits = {}
			local normalizedCount = 0
			for unitIndex, unitID in pairs(units) do
				if type(unitIndex) == "number" and type(unitID) == "number" then
					normalizedCount = normalizedCount + 1
					normalizedUnits[normalizedCount] = unitID
					teamUnitCount = teamUnitCount + 1
					teamUnitSum = (teamUnitSum + unitID) % U16_RANGE
					teamUnitSumSquares = (teamUnitSumSquares + unitID * unitID) % U16_RANGE
					teamUnitDef[unitID] = unitDefID
				end
			end
			normalizedUnitsByDef[unitDefID] = normalizedUnits
		end
	end

	local selectedCountByDef = {}
	local selectedDefIDs = {}
	local selectedDefCount = 0
	local selectedTeamUnitCount = 0
	local foreignSelectedCount = 0
	for i = 1, selectedCount do
		local unitDefID = teamUnitDef[selectedUnits[i]]
		if unitDefID then
			selectedTeamUnitCount = selectedTeamUnitCount + 1
			if not selectedCountByDef[unitDefID] then
				selectedDefCount = selectedDefCount + 1
				selectedDefIDs[selectedDefCount] = unitDefID
				selectedCountByDef[unitDefID] = 1
			else
				selectedCountByDef[unitDefID] = selectedCountByDef[unitDefID] + 1
			end
		else
			foreignSelectedCount = foreignSelectedCount + 1
		end
	end

	local explicitLength = 3 + selectedCount * 2
	local teamExcludeCount = teamUnitCount - selectedTeamUnitCount
	local teamLength = 11 + (foreignSelectedCount + teamExcludeCount) * 2

	local selectedDefUsesBaseline = {}
	local baselineDefCount = 0
	local defIncludeCount = foreignSelectedCount
	local defExcludeCount = 0
	for i = 1, selectedDefCount do
		local unitDefID = selectedDefIDs[i]
		local selectedOfDef = selectedCountByDef[unitDefID]
		local totalOfDef = #normalizedUnitsByDef[unitDefID]
		local excludedOfDef = totalOfDef - selectedOfDef
		if 1 + excludedOfDef < selectedOfDef then
			selectedDefUsesBaseline[unitDefID] = true
			baselineDefCount = baselineDefCount + 1
			defExcludeCount = defExcludeCount + excludedOfDef
		else
			defIncludeCount = defIncludeCount + selectedOfDef
		end
	end
	local defsLength = 13 + (baselineDefCount + defIncludeCount + defExcludeCount) * 2

	if explicitLength <= teamLength and explicitLength <= defsLength then
		return {
			opcode = Protocol.OP_SET_EXPLICIT,
			units = selectedUnits,
			unitCount = selectedCount,
			byteLength = explicitLength,
		}
	end

	local includeUnits = {}
	local includeCount = 0
	local excludeUnits = {}
	local excludeCount = 0
	if teamLength <= defsLength then
		for i = 1, selectedCount do
			local unitID = selectedUnits[i]
			if not teamUnitDef[unitID] then
				includeCount = includeCount + 1
				includeUnits[includeCount] = unitID
			end
		end
		for unitDefID, units in pairs(normalizedUnitsByDef) do
			for i = 1, #units do
				local unitID = units[i]
				if not selectedSet[unitID] then
					excludeCount = excludeCount + 1
					excludeUnits[excludeCount] = unitID
				end
			end
		end
		return {
			opcode = Protocol.OP_SET_TEAM,
			baselineCount = teamUnitCount,
			baselineSum = teamUnitSum,
			baselineSumSquares = teamUnitSumSquares,
			includeUnits = includeUnits,
			includeCount = includeCount,
			excludeUnits = excludeUnits,
			excludeCount = excludeCount,
			byteLength = teamLength,
		}
	end

	local baselineDefIDs = {}
	local baselineDefIndex = 0
	local baselineCount = 0
	local baselineSum = 0
	local baselineSumSquares = 0
	for i = 1, selectedDefCount do
		local unitDefID = selectedDefIDs[i]
		if selectedDefUsesBaseline[unitDefID] then
			baselineDefIndex = baselineDefIndex + 1
			baselineDefIDs[baselineDefIndex] = unitDefID
			local units = normalizedUnitsByDef[unitDefID]
			for j = 1, #units do
				local unitID = units[j]
				baselineCount = baselineCount + 1
				baselineSum = (baselineSum + unitID) % U16_RANGE
				baselineSumSquares = (baselineSumSquares + unitID * unitID) % U16_RANGE
			end
		end
	end
	for i = 1, selectedCount do
		local unitID = selectedUnits[i]
		local unitDefID = teamUnitDef[unitID]
		if not unitDefID or not selectedDefUsesBaseline[unitDefID] then
			includeCount = includeCount + 1
			includeUnits[includeCount] = unitID
		end
	end
	for i = 1, baselineDefIndex do
		local units = normalizedUnitsByDef[baselineDefIDs[i]]
		for j = 1, #units do
			local unitID = units[j]
			if not selectedSet[unitID] then
				excludeCount = excludeCount + 1
				excludeUnits[excludeCount] = unitID
			end
		end
	end
	return {
		opcode = Protocol.OP_SET_DEFS,
		baselineCount = baselineCount,
		baselineSum = baselineSum,
		baselineSumSquares = baselineSumSquares,
		unitDefIDs = baselineDefIDs,
		unitDefCount = baselineDefIndex,
		includeUnits = includeUnits,
		includeCount = includeCount,
		excludeUnits = excludeUnits,
		excludeCount = excludeCount,
		byteLength = defsLength,
	}
end

function Protocol.EncodeSnapshot(plan, packValue)
	packValue = packValue or packU16
	if plan.opcode == Protocol.OP_SET_EXPLICIT then
		local parts = { strChar(plan.opcode), packU16(plan.unitCount) }
		local partCount = appendPackedList(parts, 2, plan.units, plan.unitCount, packValue)
		return tConcat(parts, "", 1, partCount)
	end

	local parts = {
		strChar(plan.opcode),
		packU16(plan.baselineCount),
		packU16(plan.baselineSum),
		packU16(plan.baselineSumSquares),
	}
	local partCount = 4
	if plan.opcode == Protocol.OP_SET_DEFS then
		partCount = partCount + 1
		parts[partCount] = packU16(plan.unitDefCount)
	end
	partCount = partCount + 1
	parts[partCount] = packU16(plan.includeCount)
	partCount = partCount + 1
	parts[partCount] = packU16(plan.excludeCount)
	if plan.opcode == Protocol.OP_SET_DEFS then
		partCount = appendPackedList(parts, partCount, plan.unitDefIDs, plan.unitDefCount, packValue)
	end
	partCount = appendPackedList(parts, partCount, plan.includeUnits, plan.includeCount, packValue)
	partCount = appendPackedList(parts, partCount, plan.excludeUnits, plan.excludeCount, packValue)
	return tConcat(parts, "", 1, partCount)
end

local function decodeExplicit(msg)
	local count = unpackU16(msg, 2)
	if not count or #msg ~= 3 + count * 2 then
		return nil
	end
	local units = unpackList(msg, 4, count)
	return { kind = "set", units = units, count = count }
end

local function buildExpandedSet(baseUnits, includeUnits, excludeUnits)
	local excluded = {}
	for i = 1, #excludeUnits do
		excluded[excludeUnits[i]] = true
	end
	local selected = {}
	local units = {}
	local count = 0
	for i = 1, #baseUnits do
		local unitID = baseUnits[i]
		if not excluded[unitID] and not selected[unitID] then
			selected[unitID] = true
			count = count + 1
			units[count] = unitID
		end
	end
	for i = 1, #includeUnits do
		local unitID = includeUnits[i]
		if not excluded[unitID] and not selected[unitID] then
			selected[unitID] = true
			count = count + 1
			units[count] = unitID
		end
	end
	return { kind = "set", units = units, count = count }
end

function Protocol.Decode(msg, teamID, getTeamUnits, getTeamUnitsByDefs)
	local opcode = strByte(msg, 1)
	if opcode == Protocol.OP_CLEAR and #msg == 1 then
		return { kind = "set", units = {}, count = 0 }
	elseif opcode == Protocol.OP_DELTA then
		local addCount = unpackU16(msg, 2)
		local removeCount = unpackU16(msg, 4)
		if not addCount or not removeCount or #msg ~= 5 + (addCount + removeCount) * 2 then
			return nil
		end
		local addUnits, pos = unpackList(msg, 6, addCount)
		local removeUnits = unpackList(msg, pos, removeCount)
		return {
			kind = "delta",
			addUnits = addUnits,
			addCount = addCount,
			removeUnits = removeUnits,
			removeCount = removeCount,
		}
	elseif opcode == Protocol.OP_SET_EXPLICIT then
		return decodeExplicit(msg)
	elseif opcode ~= Protocol.OP_SET_TEAM and opcode ~= Protocol.OP_SET_DEFS then
		return nil
	end

	local pos = 2
	local unitDefIDs = {}
	local baselineCount = unpackU16(msg, pos)
	local baselineSum = unpackU16(msg, pos + 2)
	local baselineSumSquares = unpackU16(msg, pos + 4)
	if not baselineCount or not baselineSum or not baselineSumSquares then
		return nil
	end
	if opcode == Protocol.OP_SET_DEFS then
		local unitDefCount = unpackU16(msg, 8)
		local includeCount = unpackU16(msg, 10)
		local excludeCount = unpackU16(msg, 12)
		if not unitDefCount or not includeCount or not excludeCount
			or #msg ~= 13 + (unitDefCount + includeCount + excludeCount) * 2
		then
			return nil
		end
		pos = 14
		unitDefIDs, pos = unpackList(msg, pos, unitDefCount)
		local includeUnits
		includeUnits, pos = unpackList(msg, pos, includeCount)
		local excludeUnits = unpackList(msg, pos, excludeCount)
		local baseUnits = getTeamUnitsByDefs(teamID, unitDefIDs) or {}
		return buildExpandedSet(baseUnits, includeUnits, excludeUnits)
	end

	local includeCount = unpackU16(msg, 8)
	local excludeCount = unpackU16(msg, 10)
	if not includeCount or not excludeCount or #msg ~= 11 + (includeCount + excludeCount) * 2 then
		return nil
	end
	local includeUnits
	pos = 12
	includeUnits, pos = unpackList(msg, pos, includeCount)
	local excludeUnits = unpackList(msg, pos, excludeCount)
	local baseUnits = getTeamUnits(teamID) or {}
	return buildExpandedSet(baseUnits, includeUnits, excludeUnits)
end

function Protocol.IsValidSpectatorMessage(msg, maxUnits)
	local opcode = strByte(msg, 1)
	if opcode == Protocol.OP_CLEAR then
		return #msg == 1
	end
	if opcode ~= Protocol.OP_SET_EXPLICIT then
		return false
	end
	local count = unpackU16(msg, 2)
	return count ~= nil and count <= maxUnits and #msg == 3 + count * 2
end

return Protocol
