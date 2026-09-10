---@diagnostic disable: need-check-nil, undefined-field, unnecessary-assert

function cleanup()
	Test.restoreWidget("Area Command Filter")
end

local function packetSize(order)
	return 17 + 2 * #order.unitIDs + 4 * #order.params
end

function test()
	local sourceIDs = {}
	for index = 1, 300 do
		sourceIDs[index] = index
	end
	local targetIDs = {}
	local issuedOrders = {}

	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	areaCommandFilter.spGetSelectedUnits = function()
		return sourceIDs
	end
	areaCommandFilter.spGetUnitsInCylinder = function()
		return targetIDs
	end
	areaCommandFilter.spGetUnitDefID = function()
		return 1
	end
	areaCommandFilter.spGetUnitAllyTeam = function(unitID)
		return unitID >= 10000 and 1 or 0
	end
	areaCommandFilter.spGetUnitTeam = areaCommandFilter.spGetUnitAllyTeam
	areaCommandFilter.spGetUnitArrayCentroid = function()
		return 0, 0, 0
	end
	areaCommandFilter.spGetUnitPosition = function(unitID)
		return unitID, 0, 0
	end
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", targetIDs[1]
	end
	areaCommandFilter.spGiveOrderToUnitArray = function(unitIDs, commandID, params, options)
		issuedOrders[#issuedOrders + 1] = {
			unitIDs = unitIDs,
			commandID = commandID,
			params = params,
			options = options,
		}
	end

	local function runCase(case)
		targetIDs = {}
		for index = 1, case.targetCount do
			targetIDs[index] = 10000 + index
		end
		issuedOrders = {}
		assertEqual(
			areaCommandFilter:CommandNotify(case.commandID, { 0, 0, 0, 1000 }, { alt = true, meta = case.prepend }),
			true,
			case.label .. " should be handled"
		)

		assertEqual(#issuedOrders, 4, case.label .. " should use two target chunks and two source batches")
		local firstChunkTargets = case.targetCount - case.secondChunkTargets
		local chunkStarts = case.prepend and { firstChunkTargets + 1, 1 } or { 1, firstChunkTargets + 1 }
		for orderIndex = 1, #issuedOrders do
			local order = issuedOrders[orderIndex]
			local sentChunk = math.floor((orderIndex - 1) / 2) + 1
			local sourceBatch = (orderIndex - 1) % 2 + 1
			assert(packetSize(order) <= 8192, case.label .. " packet exceeds NETMSG_AICOMMANDS")
			assertEqual(#order.unitIDs, sourceBatch == 1 and 256 or 44, case.label .. " source batch size")

			local paramOffset = 0
			if case.prepend then
				assertEqual(order.commandID, CMD.INSERT, case.label .. " should prepend with INSERT")
				assertEqual(order.params[1], 0, case.label .. " insert position")
				assertEqual(order.params[2], case.listCommandID, case.label .. " inserted command")
				assertEqual(order.params[3], CMD.OPT_META, case.label .. " inserted Set Target should retain Meta")
				paramOffset = 3
			else
				assertEqual(order.commandID, case.listCommandID, case.label .. " compact command")
			end

			local targetStart = chunkStarts[sentChunk]
			for paramIndex = paramOffset + 1, #order.params do
				assertEqual(
					order.params[paramIndex],
					targetIDs[targetStart + paramIndex - paramOffset - 1],
					case.label .. " target order"
				)
			end
		end
	end

	runCase({
		label = "Attack across packet boundary",
		commandID = CMD.ATTACK,
		listCommandID = GameCMD.ATTACK_TARGETS,
		targetCount = 1916,
		secondChunkTargets = 1,
	})
	runCase({
		label = "Space+Set Target across packet boundary",
		commandID = GameCMD.UNIT_SET_TARGET,
		listCommandID = GameCMD.UNIT_SET_TARGETS,
		targetCount = 1913,
		secondChunkTargets = 1,
		prepend = true,
	})
end

return {
	skip = skip,
	test = test,
	cleanup = cleanup,
}
