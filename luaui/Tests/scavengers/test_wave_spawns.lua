---@diagnostic disable: undefined-field

-- Needs a ScavengersAI team and a short grace (tools/headless_testing/startscript_scav_smoke.txt);
-- the devtools compose file pins one startscript, so this self-skips everywhere else.

-- Test.waitUntil counts FRAMES, not milliseconds.
local WAVE_TIMEOUT = 3600
local BOSS_TIMEOUT = 5400

-- The director's early-boss hatch opens a minute past grace. One second of
-- slack, because the hatch is checked on the once-a-second slow tick.
local BOSS_HATCH_DELAY = 61

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	return Spring.GetGameRulesParam("scavGracePeriod") == nil
end

local function test()
	local scavTeamID = BAR.Utilities.GetScavTeamID()
	assert(scavTeamID, "no scavengers team; startscript_scav_smoke.txt sets one up")

	local difficulty = Spring.GetGameRulesParam("scavDifficulty")
	assert(difficulty and difficulty >= 1, "scavDifficulty should be a resolved rung, got " .. tostring(difficulty))
	assert((Spring.GetGameRulesParam("scavBossTime") or 0) > 0, "scavBossTime should be the absolute boss second")
	assert(Spring.GetGameRulesParam("scavTechAnger") ~= nil, "the director should publish its roster clock")

	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("scav_hiveCount") or 0) > 0
	end, WAVE_TIMEOUT)

	-- Grace is dialled down to a tenth in the startscript, so this is a wave and not the AI's starting commander.
	Test.waitUntil(function()
		return (Spring.GetTeamUnitCount(scavTeamID) or 0) > 5
	end, WAVE_TIMEOUT)

	local scavengerUnits = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(scavTeamID)) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.customParams.isscavenger then
			scavengerUnits = scavengerUnits + 1
		end
	end
	assert(scavengerUnits > 0, "expected scavenger units on the field, found none")

	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("scavTechAnger") or 0) > 0
	end, WAVE_TIMEOUT)

	local grace = Spring.GetGameRulesParam("scavGracePeriod") or 0
	Test.waitUntil(function()
		return Spring.GetGameSeconds() > grace + BOSS_HATCH_DELAY
	end, BOSS_TIMEOUT)

	SyncedRun(function(locals)
		for _, unitID in ipairs(Spring.GetTeamUnits(locals.scavTeamID)) do
			local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
			if unitDef and unitDef.name:find("scavbeacon", 1, true) then
				Spring.DestroyUnit(unitID, false, true)
			end
		end
	end)

	Test.waitUntil(function()
		return Spring.GetGameRulesParam("BossFightStarted") == 1
	end, BOSS_TIMEOUT)

	Test.waitUntil(function()
		return Spring.GetGameRulesParam("scavBossHealth") ~= nil
			and Spring.GetGameRulesParam("scavBossStaggerPercentage") ~= nil
	end, BOSS_TIMEOUT)

	local health = Spring.GetGameRulesParam("scavBossHealth")
	assert(health > 0 and health <= 100, "the shared boss health bar should read 1-100, got " .. tostring(health))
	assert((Spring.GetGameRulesParam("pveBossInfo") or "") ~= "", "the boss roster should be published for the UI")
end

return { skip = skip, test = test }
