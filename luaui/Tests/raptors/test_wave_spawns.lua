---@diagnostic disable: undefined-field

-- Needs a RaptorsAI team and short clocks: tools/headless_testing/startscript_raptor_smoke.txt.
-- Self-skips everywhere else.

-- Test.waitUntil counts FRAMES, not milliseconds.
local WAVE_TIMEOUT = 3600
local BOSS_TIMEOUT = 5400
local BOSS_HATCH_DELAY = 61

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	return Spring.GetGameRulesParam("raptorGracePeriod") == nil
end

local function test()
	local raptorTeamID = BAR.Utilities.GetRaptorTeamID()
	assert(raptorTeamID, "no raptors team; startscript_raptor_smoke.txt sets one up")

	local difficulty = Spring.GetGameRulesParam("raptorDifficulty")
	assert(difficulty and difficulty >= 1, "raptorDifficulty should be a resolved rung, got " .. tostring(difficulty))
	assert(
		(Spring.GetGameRulesParam("raptorQueenTime") or 0) > 0,
		"raptorQueenTime should be the absolute queen second"
	)
	assert(Spring.GetGameRulesParam("raptorTechAnger") ~= nil, "the director should publish its roster clock")
	assert(
		(Spring.GetGameRulesParam("RaptorQueenAngerGain_Base") or 0) > 0,
		"the panel's gain line should be published"
	)

	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("raptor_hiveCount") or 0) > 0
	end, WAVE_TIMEOUT)

	Test.waitUntil(function()
		return (Spring.GetTeamUnitCount(raptorTeamID) or 0) > 5
	end, WAVE_TIMEOUT)

	for _, unitID in ipairs(Spring.GetTeamUnits(raptorTeamID)) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		assert(
			unitDef and unitDef.name:find("^raptor_"),
			"a non-raptor on the raptor team: " .. tostring(unitDef and unitDef.name)
		)
	end

	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("raptorTechAnger") or 0) > 0
	end, WAVE_TIMEOUT)

	local grace = Spring.GetGameRulesParam("raptorGracePeriod") or 0
	Test.waitUntil(function()
		return Spring.GetGameSeconds() > grace + BOSS_HATCH_DELAY
	end, BOSS_TIMEOUT)

	-- Raze every hive. The next slow tick finds nowhere to spawn from and
	-- the queen comes early.
	SyncedRun(function(locals)
		for _, unitID in ipairs(Spring.GetTeamUnits(locals.raptorTeamID)) do
			local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
			if unitDef and unitDef.name == "raptor_hive" then
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end)

	Test.waitUntil(function()
		return Spring.GetGameRulesParam("BossFightStarted") == 1
	end, BOSS_TIMEOUT)

	Test.waitUntil(function()
		return Spring.GetGameRulesParam("raptorQueenHealth") ~= nil
			and Spring.GetGameRulesParam("raptorQueenStaggerPercentage") ~= nil
	end, BOSS_TIMEOUT)

	local health = Spring.GetGameRulesParam("raptorQueenHealth")
	assert(health > 0 and health <= 100, "the shared queen health bar should read 1-100, got " .. tostring(health))
	assert((Spring.GetGameRulesParam("pveBossInfo") or "") ~= "", "the queen roster should be published for the UI")

	local queen
	for _, unitID in ipairs(Spring.GetTeamUnits(raptorTeamID)) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.name:find("^raptor_queen_") then
			queen = unitID
		end
	end
	assert(queen, "a queen should be on the field")
	assert(Spring.GetUnitExperience(queen) == 0, "a queen arrives fresh")

	-- A dead raptor leaves an egg.
	local eggsBefore = #Spring.GetAllFeatures()
	SyncedRun(function(locals)
		for _, unitID in ipairs(Spring.GetTeamUnits(locals.raptorTeamID)) do
			if unitID ~= locals.queen then
				Spring.DestroyUnit(unitID, false, false)
				break
			end
		end
	end)
	Test.waitUntil(function()
		return #Spring.GetAllFeatures() > eggsBefore
	end, 300)
end

return { skip = skip, test = test }
