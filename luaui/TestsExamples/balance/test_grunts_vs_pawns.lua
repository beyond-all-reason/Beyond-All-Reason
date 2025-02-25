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
		[0] = "armpw",
		[1] = "corak"
	}
	local n = 20

	local midX, midZ = Game.mapSizeX / 2, Game.mapSizeZ / 2
	local xOffset = 200
	local zStep = 30
	local startZ = midZ - zStep * n / 2

	-- make two lines of units facing each other
	SyncedRun(function(locals)
		do
			local x = locals.midX - locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ
				local y = Spring.GetGroundHeight(x, z)
				Spring.CreateUnit(locals.units[0], x, y, z + locals.zStep * i, "east", 0)
			end
		end

		do
			local x = locals.midX + locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ
				local y = Spring.GetGroundHeight(x, z)
				Spring.CreateUnit(locals.units[1], x, y, z + locals.zStep * i, "west", 1)
			end

		end
	end)

	Test.waitFrames(1)

	Spring.GiveOrderToUnitArray(Spring.GetTeamUnits(0), CMD.FIGHT, { midX, 0, midZ }, 0)
	Spring.GiveOrderToUnitArray(Spring.GetTeamUnits(1), CMD.FIGHT, { midX, 0, midZ }, 0)

	Spring.SendCommands("setspeed " .. 20)

	-- wait until one team has no units left
	Test.waitUntil(function()
		return #(Spring.GetTeamUnits(0)) == 0 or #(Spring.GetTeamUnits(1)) == 0
	end, 30 * 30)

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
		resultStr = resultStr .. "team " .. winner .. " wins"
		resultStr = resultStr .. " with " .. #(Spring.GetAllUnits()) .. " " .. unitName .. " left"
	else
		resultStr = resultStr .. "tie"
	end

	Spring.Echo(resultStr)

	-- pawns should win
	assert(winner == 0)
end
