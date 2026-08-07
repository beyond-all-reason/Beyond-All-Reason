---@diagnostic disable: undefined-field

-- Plays hello_pawns end to end: `runtestsheadless hello_pawns`.
-- This test really ends the game (Spring.GameOver); scope the run if it
-- disturbs later tests in a full suite.

local PAWN = "armpw"
local PAWN_COUNT = 3

local function skip()
	return Spring.GetGameFrame() <= 0
end

local function setup()
	Test.clearMap()
	-- The victory below is a real GameOver, and Autoquit answers one with a
	-- 12s countdown that would end the run before later tests finish.
	widgetHandler:DisableWidget("Autoquit")
end

local function cleanup()
	Test.clearMap()
end

local function test()
	-- SyncedRun ships the caller's stack locals (not upvalues), so copy the
	-- file-level config into locals for the spawn block below.
	local pawnName = PAWN
	local pawnCount = PAWN_COUNT
	local teamID = Spring.GetLocalTeamID()
	local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
	local pawnDefID = UnitDefNames[PAWN].id

	Spring.SendCommands("luarules mission hello_pawns")
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("mission_active") == 1
	end)

	Test.expectCallin("GameOver")

	-- Has() means COMPLETED units: the nanoframe must not win the mission
	-- (the factory-blueprint bug).
	local x = Game.mapSizeX / 2
	local z = Game.mapSizeZ / 2
	local frameUnitID = SyncedRun(function(locals)
		for i = 1, locals.pawnCount - 1 do
			Spring.CreateUnit(
				locals.pawnName,
				locals.x + i * 32,
				Spring.GetGroundHeight(locals.x + i * 32, locals.z),
				locals.z,
				0,
				locals.teamID
			)
		end
		-- The nanoframe needs a live builder: unit_prevent_lab_hax2 destroys
		-- fresh under-construction units whose builder is dead/absent.
		local builderID = Spring.CreateUnit(
			"armck",
			locals.x - 64,
			Spring.GetGroundHeight(locals.x - 64, locals.z),
			locals.z,
			0,
			locals.teamID
		)
		local unitID = Spring.CreateUnit(
			locals.pawnName,
			locals.x,
			Spring.GetGroundHeight(locals.x, locals.z),
			locals.z,
			0,
			locals.teamID,
			true,
			true,
			nil,
			builderID
		)
		if unitID ~= nil then
			-- Give it real progress so abandoned-nanoframe decay stays far away.
			Spring.SetUnitHealth(unitID, { build = 0.8 })
		end
		return unitID
	end)
	assert(frameUnitID ~= nil, "failed to spawn the nanoframe Pawn")

	Test.waitUntil(function()
		return Spring.GetTeamUnitDefCount(teamID, pawnDefID) >= PAWN_COUNT
	end)

	Test.waitFrames(2 * 15 + 2)
	assert(
		Spring.GetGameRulesParam("objective_build_pawns") ~= 1,
		"mission must not complete while the third Pawn is a nanoframe"
	)

	SyncedRun(function(locals)
		Spring.SetUnitHealth(locals.frameUnitID, { build = 1 })
	end)

	-- The verdict rides the full gameover ceremony (GG.maxDeathFrame-or-250 + 70
	-- frame delay), hence the long timeout.
	Test.waitUntilCallin("GameOver", function(winningAllyTeams)
		if type(winningAllyTeams) ~= "table" then
			return false
		end
		for _, winner in ipairs(winningAllyTeams) do
			if winner == allyTeamID then
				return true
			end
		end
		return false
	end, 20 * 30)

	assert(
		Spring.GetGameRulesParam("objective_build_pawns") == 1,
		"objective build_pawns should be complete before victory"
	)
end

return { skip = skip, setup = setup, cleanup = cleanup, test = test }
