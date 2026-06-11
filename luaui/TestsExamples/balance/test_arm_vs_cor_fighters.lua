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
		[0] = "armfig",
		[1] = "corveng",
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
				local y = Engine.Shared.GetGroundHeight(x, z)
				local unitID = Engine.Synced.CreateUnit(locals.units[0], x, y, z, "east", 0)
			end
		end

		do
			local x = locals.midX + locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ + locals.zStep * i
				local y = Engine.Shared.GetGroundHeight(x, z)
				local unitID = Engine.Synced.CreateUnit(locals.units[1], x, y, z, "west", 1)
			end
		end
	end)

	Test.waitFrames(1)

	if false then
		Engine.Shared.GiveOrderToUnitArray(Engine.Shared.GetTeamUnits(0), CMD.FIGHT, { midX, 0, midZ }, 0)
		Engine.Shared.GiveOrderToUnitArray(Engine.Shared.GetTeamUnits(1), CMD.FIGHT, { midX, 0, midZ }, 0)
	else
		for _, unitID in ipairs(Engine.Shared.GetAllUnits()) do
			local ux, uy, uz = Engine.Shared.GetUnitPosition(unitID)

			Engine.Shared.GiveOrderToUnit(unitID, CMD.FIGHT, { 2 * midX - ux, 0, uz }, 0)
			Engine.Shared.GiveOrderToUnit(unitID, CMD.FIGHT, { midX, 0, midZ }, { "shift" })
		end
	end

	Engine.Unsynced.SendCommands("setspeed " .. 5)

	-- wait until one team has no units left
	Test.waitUntil(function()
		return #(Engine.Shared.GetTeamUnits(0)) == 0 or #(Engine.Shared.GetTeamUnits(1)) == 0
	end, 60 * 30)

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
		unitsLeft = #(Engine.Shared.GetAllUnits())
		resultStr = resultStr .. "team " .. winner .. " wins"
		resultStr = resultStr .. " with " .. unitsLeft
		resultStr = resultStr .. " (" .. string.format("%.f%%", 100 * unitsLeft / n) .. ")"
		resultStr = resultStr .. " " .. unitName .. " left"
	else
		resultStr = resultStr .. "tie"
	end

	Engine.Shared.Echo(resultStr)

	-- cor fighters should win
	assert(winner == 1)
end
