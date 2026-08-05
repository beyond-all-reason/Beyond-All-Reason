---@diagnostic disable: undefined-field, undefined-global

local Protocol = VFS.Include("common/selected_units_protocol.lua")

local function range(first, last)
	local values = {}
	for value = first, last do
		values[#values + 1] = value
	end
	return values
end

local function asSet(values)
	local result = {}
	for i = 1, #values do
		result[values[i]] = true
	end
	return result
end

local function assertSameUnits(expected, decoded)
	assert.equals(#expected, decoded.count)
	assert.same(asSet(expected), asSet(decoded.units))
end

local function teamReaders(teamUnitsByDef)
	local function getTeamUnits()
		local units = {}
		for _, defUnits in pairs(teamUnitsByDef) do
			for i = 1, #defUnits do
				units[#units + 1] = defUnits[i]
			end
		end
		return units
	end

	local function getTeamUnitsByDefs(_, defIDs)
		local units = {}
		for i = 1, #defIDs do
			local defUnits = teamUnitsByDef[defIDs[i]] or {}
			for j = 1, #defUnits do
				units[#units + 1] = defUnits[j]
			end
		end
		return units
	end

	return getTeamUnits, getTeamUnitsByDefs
end

local function roundTrip(selected, teamUnitsByDef)
	local plan = Protocol.BuildSnapshotPlan(selected, #selected, teamUnitsByDef)
	local msg = Protocol.EncodeSnapshot(plan)
	local getTeamUnits, getTeamUnitsByDefs = teamReaders(teamUnitsByDef)
	local decoded = Protocol.Decode(msg, 1, getTeamUnits, getTeamUnitsByDefs)
	return plan, msg, decoded
end

describe("selected units protocol", function()
	it("uses an explicit snapshot for a sparse mixed selection", function()
		local selected = { 1, 11, 999 }
		local plan, msg, decoded = roundTrip(selected, {
			[10] = range(1, 10),
			[20] = range(11, 20),
		})

		assert.equals(Protocol.OP_SET_EXPLICIT, plan.opcode)
		assert.equals(9, #msg)
		assertSameUnits(selected, decoded)
	end)

	it("normalizes sparse engine unit-definition lists", function()
		local sparseUnits = { n = 60 }
		local selected = range(1, 60)
		for unitID = 1, 60 do
			sparseUnits[unitID + 5] = unitID
		end
		local plan = Protocol.BuildSnapshotPlan(selected, #selected, {
			[10] = sparseUnits,
			n = 1,
		})

		assert.equals(Protocol.OP_SET_TEAM, plan.opcode)
		assert.equals(60, plan.baselineCount)
		assert.equals(11, plan.byteLength)
	end)

	it("uses all team units minus exceptions for a dense selection", function()
		local selected = range(1, 60)
		local plan, msg, decoded = roundTrip(selected, {
			[10] = range(1, 100),
		})

		assert.equals(Protocol.OP_SET_TEAM, plan.opcode)
		assert.equals(91, #msg)
		assertSameUnits(selected, decoded)
	end)

	it("encodes selecting an entire large team in five bytes", function()
		local selected = range(1, 1000)
		local plan, msg, decoded = roundTrip(selected, {
			[10] = range(1, 1000),
		})

		assert.equals(Protocol.OP_SET_TEAM, plan.opcode)
		assert.equals(11, #msg)
		assertSameUnits(selected, decoded)
	end)

	it("uses unit definition baselines with explicit exclusions", function()
		local selected = range(1, 95)
		selected[#selected + 1] = 101
		local plan, msg, decoded = roundTrip(selected, {
			[10] = range(1, 100),
			[20] = range(101, 200),
		})

		assert.equals(Protocol.OP_SET_DEFS, plan.opcode)
		assert.equals(27, #msg)
		assertSameUnits(selected, decoded)
	end)

	it("round-trips delta updates", function()
		local msg = Protocol.EncodeDelta({ 2, 4 }, 2, { 1 }, 1)
		local decoded = Protocol.Decode(msg, 1)

		assert.equals("delta", decoded.kind)
		assert.same({ 2, 4 }, decoded.addUnits)
		assert.same({ 1 }, decoded.removeUnits)
	end)

	it("limits spectators to exact explicit snapshots of 400 units", function()
		local fourHundred = range(1, 400)
		local valid = Protocol.EncodeSnapshot({
			opcode = Protocol.OP_SET_EXPLICIT,
			units = fourHundred,
			unitCount = #fourHundred,
		})
		local tooMany = range(1, 401)
		local invalid = Protocol.EncodeSnapshot({
			opcode = Protocol.OP_SET_EXPLICIT,
			units = tooMany,
			unitCount = #tooMany,
		})

		assert.is_true(Protocol.IsValidSpectatorMessage(valid, 400))
		assert.is_false(Protocol.IsValidSpectatorMessage(invalid, 400))
		assert.is_false(Protocol.IsValidSpectatorMessage(Protocol.EncodeDelta({ 1 }, 1, {}, 0), 400))
	end)

	it("rejects malformed category counts before expanding them", function()
		local malformed = string.char(Protocol.OP_SET_DEFS, 0, 0, 0, 0, 0, 0, 255, 255, 0, 0, 0, 0)
		local expansionCalled = false
		local decoded = Protocol.Decode(malformed, 1, function()
			return {}
		end, function()
			expansionCalled = true
			return {}
		end)

		assert.is_nil(decoded)
		assert.is_false(expansionCalled)
	end)

	it("expands a semantic snapshot against the receiver's current roster", function()
		local selected = range(1, 100)
		local plan = Protocol.BuildSnapshotPlan(selected, #selected, { [10] = range(1, 100) })
		local msg = Protocol.EncodeSnapshot(plan)
		local getTeamUnits, getTeamUnitsByDefs = teamReaders({ [10] = range(1, 101) })
		local decoded = Protocol.Decode(msg, 1, getTeamUnits, getTeamUnitsByDefs)

		assertSameUnits(range(1, 101), decoded)
	end)
end)
