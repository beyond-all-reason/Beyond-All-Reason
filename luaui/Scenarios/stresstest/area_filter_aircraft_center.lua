function skip()
	return select(1, Spring.GetTeamInfo(1, false)) == nil
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.restoreWidget("Area Command Filter")
	Spring.SelectUnitArray({})
	Test.clearMap()
end

local function createScenario(locals)
	local sourceID = assert(Spring.CreateUnit("armflak", locals.centerX - 600, 0, locals.centerZ, "east", 0))
	local bomberID = assert(Spring.CreateUnit("corhurc", locals.centerX, 500, locals.centerZ, "west", 1))
	local fighterID = assert(Spring.CreateUnit("corveng", locals.centerX + 300, 500, locals.centerZ, "west", 1))
	return sourceID, bomberID, fighterID
end

function test()
	local centerX = Game.mapSizeX / 2
	local centerZ = Game.mapSizeZ / 2
	local sourceID, bomberID = SyncedRun(createScenario)
	Spring.SelectUnitArray({ sourceID })
	Test.waitUntil(function()
		return #Spring.GetSelectedUnits() == 1
	end, 30)

	local areaCommandFilter = Test.prepareWidget("Area Command Filter")
	assert(areaCommandFilter, "Area Command Filter should load")
	areaCommandFilter.spTraceScreenRay = function()
		return "unit", bomberID
	end

	local issuedOrders = {}
	areaCommandFilter.spGiveOrderToUnitArray = function(unitIDs, commandID, params, options)
		issuedOrders[#issuedOrders + 1] = {
			unitIDs = unitIDs,
			commandID = commandID,
			params = params,
			options = options,
		}
	end

	local function assertBomberOnly(commandID, label, shift)
		issuedOrders = {}
		local handled = areaCommandFilter:CommandNotify(
			commandID,
			{ centerX, 0, centerZ, 600 },
			{ alt = true, shift = shift }
		)
		assertEqual(handled, true, label .. " should be handled")
		assertEqual(#issuedOrders, 1, label .. " issued order count")
		assertEqual(#issuedOrders[1].unitIDs, 1, label .. " source count")
		assertEqual(issuedOrders[1].unitIDs[1], sourceID, label .. " source")
		assertEqual(#issuedOrders[1].params, 1, label .. " target count")
		assertEqual(issuedOrders[1].params[1], bomberID, label .. " target")
		local issuedOptions = issuedOrders[1].options
		if type(issuedOptions) == "table" then
			local hasShift = false
			for index = 1, #issuedOptions do
				hasShift = hasShift or issuedOptions[index] == "shift"
			end
			assertEqual(hasShift, shift == true, label .. " legacy queue option")
		else
			assertEqual(issuedOptions, shift and CMD.OPT_SHIFT or 0, label .. " compact queue option")
		end
	end

	assertBomberOnly(GameCMD.UNIT_SET_TARGET, "S+Alt area", false)
	assertBomberOnly(CMD.ATTACK, "A+Alt area", false)
	assertBomberOnly(GameCMD.UNIT_SET_TARGET, "S+Alt+Shift area", true)
	assertBomberOnly(CMD.ATTACK, "A+Alt+Shift area", true)
end

return {
	skip = skip,
	setup = setup,
	test = test,
	cleanup = cleanup,
}
