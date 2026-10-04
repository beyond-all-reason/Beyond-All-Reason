function skip()
	return Spring.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()

	Spring.SendCommands("setspeed " .. 1)
end

function test()
	local units = {
		[0] = "armfig",
		[1] = "corveng"
	}
	local n = 200

	local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local xOffset = 1000
	local zStep = 10
	local startZ = midZ - zStep * n / 2

	-- make two lines of units facing each other
	SyncedRun(function(locals)
		do
			local x = locals.midX - locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ + locals.zStep * i
				local y = Spring.GetGroundHeight(x, z)
				local unitID = Spring.CreateUnit(locals.units[0], x, y, z, "east", 0)
			end
		end

		do
			local x = locals.midX + locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ + locals.zStep * i
				local y = Spring.GetGroundHeight(x, z)
				local unitID = Spring.CreateUnit(locals.units[1], x, y, z, "west", 1)
			end

		end
	end)

	Test.waitFrames(1)

	if false then
		Spring.GiveOrderToUnitArray(Spring.GetTeamUnits(0), CMD.FIGHT, { midX, 0, midZ }, 0)
		Spring.GiveOrderToUnitArray(Spring.GetTeamUnits(1), CMD.FIGHT, { midX, 0, midZ }, 0)
	else
		for _, unitID in ipairs(Spring.GetAllUnits()) do
			local ux, uy, uz = Spring.GetUnitPosition(unitID)

			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { 2 * midX - ux, 0, uz }, 0)
			Spring.GiveOrderToUnit(unitID, CMD.FIGHT, { midX, 0, midZ }, { "shift" })
		end
	end

	Spring.SendCommands("setspeed " .. 5)

	-- wait until one team has no units left
	Test.waitUntil(function()
		return #(Spring.GetTeamUnits(0)) == 0 or #(Spring.GetTeamUnits(1)) == 0
	end, 60 * 30)

	Spring.SendCommands("setspeed " .. 1)

	if #(Spring.GetTeamUnits(0)) > #(Spring.GetTeamUnits(1)) then
		winner = 0
	elseif #(Spring.GetTeamUnits(1)) > #(Spring.GetTeamUnits(0)) then
		winner = 1
	end

	resultStr = "RESULT: "
	if winner ~= nil then
		unitName = units[winner]
		if UnitDefNames and units[winner] and UnitDefNames[units[winner]] then
			unitName = UnitDefNames[units[winner]].translatedHumanName or units[winner]
		end
		unitsLeft = #(Spring.GetAllUnits())
		resultStr = resultStr .. "team " .. winner .. " wins"
		resultStr = resultStr .. " with " .. unitsLeft
		resultStr = resultStr .. " (" .. string.format("%.f%%", 100 * unitsLeft / n) .. ")"
		resultStr = resultStr .. " " .. unitName .. " left"
	else
		resultStr = resultStr .. "tie"
	end

	Spring.Echo(resultStr)

	-- cor fighters should win
	assert(winner == 1)
end
