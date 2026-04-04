function skip()
	return SpringShared.GetGameFrame() <= 0
end

function setup()
	Test.clearMap()
end

function cleanup()
	Test.clearMap()

	SpringUnsynced.SendCommands("setspeed " .. 1)
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
				local y = SpringShared.GetGroundHeight(x, z)
				local unitID = SpringSynced.CreateUnit(locals.units[0], x, y, z, "east", 0)
			end
		end

		do
			local x = locals.midX + locals.xOffset
			for i = 1, locals.n do
				local z = locals.startZ + locals.zStep * i
				local y = SpringShared.GetGroundHeight(x, z)
				local unitID = SpringSynced.CreateUnit(locals.units[1], x, y, z, "west", 1)
			end
		end
	end)

	Test.waitFrames(1)

	if false then
		SpringSynced.GiveOrderToUnitArray(SpringShared.GetTeamUnits(0), CMD.FIGHT, { midX, 0, midZ }, 0)
		SpringSynced.GiveOrderToUnitArray(SpringShared.GetTeamUnits(1), CMD.FIGHT, { midX, 0, midZ }, 0)
	else
		for _, unitID in ipairs(SpringShared.GetAllUnits()) do
			local ux, uy, uz = SpringShared.GetUnitPosition(unitID)

			SpringSynced.GiveOrderToUnit(unitID, CMD.FIGHT, { 2 * midX - ux, 0, uz }, 0)
			SpringSynced.GiveOrderToUnit(unitID, CMD.FIGHT, { midX, 0, midZ }, { "shift" })
		end
	end

	SpringUnsynced.SendCommands("setspeed " .. 5)

	-- wait until one team has no units left
	Test.waitUntil(function()
		return #(SpringShared.GetTeamUnits(0)) == 0 or #(SpringShared.GetTeamUnits(1)) == 0
	end, 60 * 30)

	SpringUnsynced.SendCommands("setspeed " .. 1)

	if #(SpringShared.GetTeamUnits(0)) > #(SpringShared.GetTeamUnits(1)) then
		winner = 0
	elseif #(SpringShared.GetTeamUnits(1)) > #(SpringShared.GetTeamUnits(0)) then
		winner = 1
	end

	resultStr = "RESULT: "
	if winner ~= nil then
		unitName = units[winner]
		if UnitDefNames and units[winner] and UnitDefNames[units[winner]] then
			unitName = UnitDefNames[units[winner]].translatedHumanName or units[winner]
		end
		unitsLeft = #(SpringShared.GetAllUnits())
		resultStr = resultStr .. "team " .. winner .. " wins"
		resultStr = resultStr .. " with " .. unitsLeft
		resultStr = resultStr .. " (" .. string.format("%.f%%", 100 * unitsLeft / n) .. ")"
		resultStr = resultStr .. " " .. unitName .. " left"
	else
		resultStr = resultStr .. "tie"
	end

	SpringShared.Echo(resultStr)

	-- cor fighters should win
	assert(winner == 1)
end
