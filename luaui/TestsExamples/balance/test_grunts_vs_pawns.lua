function skip()
	return Engine.Shared.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()

	Engine.Unsynced.SendCommands("setspeed " .. 1)
end

function test()
	local units = {
		[0] = "armpw",
		[1] = "corak",
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
				local y = Engine.Shared.GetGroundHeight(x, z)
				Engine.Synced.CreateUnit(locals.units[0], x, y, z + locals.zStep * i, "east", 0)
			end
		end

		do
			local x = locals.midX + locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ
				local y = Engine.Shared.GetGroundHeight(x, z)
				Engine.Synced.CreateUnit(locals.units[1], x, y, z + locals.zStep * i, "west", 1)
			end
		end
	end)

	Test.waitFrames(1)

	Engine.Shared.GiveOrderToUnitArray(Engine.Shared.GetTeamUnits(0), CMD.FIGHT, { midX, 0, midZ }, 0)
	Engine.Shared.GiveOrderToUnitArray(Engine.Shared.GetTeamUnits(1), CMD.FIGHT, { midX, 0, midZ }, 0)

	Engine.Unsynced.SendCommands("setspeed " .. 20)

	-- wait until one team has no units left
	Test.waitUntil(function()
		return #(Engine.Shared.GetTeamUnits(0)) == 0 or #(Engine.Shared.GetTeamUnits(1)) == 0
	end, 30 * 30)

	Engine.Unsynced.SendCommands("setspeed " .. 1)

	if #(Engine.Shared.GetTeamUnits(0)) > #(Engine.Shared.GetTeamUnits(1)) then
		winner = 0
	elseif #(Engine.Shared.GetTeamUnits(1)) > #(Engine.Shared.GetTeamUnits(0)) then
		winner = 1
	end

	resultStr = "RESULT: "
	if winner ~= nil then
		unitName = units[winner]
		if UnitDefNames and units[winner] and UnitDefNames[units[winner]] then
			unitName = UnitDefNames[units[winner]].translatedHumanName or units[winner]
		end
		resultStr = resultStr .. "team " .. winner .. " wins"
		resultStr = resultStr .. " with " .. #(Engine.Shared.GetAllUnits()) .. " " .. unitName .. " left"
	else
		resultStr = resultStr .. "tie"
	end

	Engine.Shared.Echo(resultStr)

	-- pawns should win
	assert(winner == 0)
end
