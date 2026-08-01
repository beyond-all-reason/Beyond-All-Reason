---@diagnostic disable: lowercase-global, undefined-field

-- The multiplayer path, end to end: a scavengers AI is on the field, the
-- flavor gadget discovers its team, builds the roster, hands a spec to the
-- wave director, and waves come out of the ground.
--
-- Needs a game set up for it — a ScavengersAI team and a short grace period.
-- tools/headless_testing/startscript_scav_smoke.txt is that game:
--
--   spring-headless --isolation \
--     tools/headless_testing/startscript_scav_smoke.txt
--
-- Wiring that scenario into `just bar::integrations` is a BAR-Devtools
-- change (the compose file pins one startscript); until then this self-skips
-- everywhere else, so it costs the standard suite nothing.

-- Test.waitUntil counts FRAMES, not milliseconds.
local WAVE_TIMEOUT = 3600
local BOSS_TIMEOUT = 5400

-- The director's early-boss hatch opens a minute past grace. One second of
-- slack, because the hatch is checked on the once-a-second slow tick.
local BOSS_HATCH_DELAY = 61

function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	-- The director publishes its grace period at Start. No param, no
	-- scavengers game.
	return Spring.GetGameRulesParam("scavGracePeriod") == nil
end

function test()
	local scavTeamID = Spring.Utilities.GetScavTeamID()
	assert(scavTeamID, "no scavengers team; startscript_scav_smoke.txt sets one up")

	-- The roster resolved: a difficulty index, a grace period and a boss hour
	-- are what defs_build produces and spec_build hands over.
	local difficulty = Spring.GetGameRulesParam("scavDifficulty")
	assert(difficulty and difficulty >= 1, "scavDifficulty should be a resolved rung, got " .. tostring(difficulty))
	assert((Spring.GetGameRulesParam("scavBossTime") or 0) > 0, "scavBossTime should be the absolute boss second")
	assert(Spring.GetGameRulesParam("scavTechAnger") ~= nil, "the director should publish its roster clock")

	-- Beacons first: nothing can spawn until the director has somewhere to
	-- spawn from, and the burrow count is its own rulesparam.
	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("scav_hiveCount") or 0) > 0
	end, WAVE_TIMEOUT)

	-- Then units. The grace period is dialled down to a tenth in the
	-- startscript, so this is a wave and not the AI's starting commander.
	Test.waitUntil(function()
		return (Spring.GetTeamUnitCount(scavTeamID) or 0) > 5
	end, WAVE_TIMEOUT)

	-- And they are scavengers, not whatever the AI would have built.
	local scavengerUnits = 0
	for _, unitID in ipairs(Spring.GetTeamUnits(scavTeamID)) do
		local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
		if unitDef and unitDef.customParams.isscavenger then
			scavengerUnits = scavengerUnits + 1
		end
	end
	assert(scavengerUnits > 0, "expected scavenger units on the field, found none")

	-- The clock is running, which is what makes the roster climb.
	Test.waitUntil(function()
		return (Spring.GetGameRulesParam("scavTechAnger") or 0) > 0
	end, WAVE_TIMEOUT)

	--------------------------------------------------------------------------
	-- The boss, through the director's early hatch.
	--
	-- Waiting out the boss clock would take the better part of an hour. The
	-- hatch is the honest shortcut AND a mechanic worth testing on its own:
	-- a map the players have cleared of beacons, well past grace, means the
	-- director has no way left to spend its clock, so the boss comes early
	-- rather than never.
	--------------------------------------------------------------------------

	local grace = Spring.GetGameRulesParam("scavGracePeriod") or 0
	Test.waitUntil(function()
		return Spring.GetGameSeconds() > grace + BOSS_HATCH_DELAY
	end, BOSS_TIMEOUT)

	-- Raze every beacon. The next slow tick finds nowhere to spawn from.
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

	-- And the boss gadget woke up with it: the shared health bar and the
	-- stagger bank are both published, which is the whole of what a UI panel
	-- and a player read during the fight.
	Test.waitUntil(function()
		return Spring.GetGameRulesParam("scavBossHealth") ~= nil
			and Spring.GetGameRulesParam("scavBossStaggerPercentage") ~= nil
	end, BOSS_TIMEOUT)

	local health = Spring.GetGameRulesParam("scavBossHealth")
	assert(health > 0 and health <= 100, "the shared boss health bar should read 1-100, got " .. tostring(health))
	assert((Spring.GetGameRulesParam("pveBossInfo") or "") ~= "", "the boss roster should be published for the UI")
end
