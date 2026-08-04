---@diagnostic disable: lowercase-global, undefined-field

-- CM8 Ashfall's pressure, end to end, with no bot on the field.
--
-- That last part is the point. Scavengers in a multiplayer game are activated
-- by a ScavengersAI being present; a mission is not a lobby and has no bot to
-- add. This proves the mission path is bot-free: the trigger file names a
-- pack, the missions module resolves it through the scavengers module, and
-- the same wave director a multiplayer game runs starts spawning.
--
-- Fails if the DSL loses the Waves verbs or the Scavengers nouns, if the ctx
-- facet is disconnected, if the pack cannot build a spec, or if the director
-- starts but never puts anything on the map.
--
-- Needs a game with an enemy team for the mission's enclave to spawn on:
-- tools/headless_testing/startscript_cm8_waves.txt is that game.
--
--   spring-headless --isolation \
--     tools/headless_testing/startscript_cm8_waves.txt
--
-- Everywhere else it self-skips, so the standard suite pays nothing for it.
-- Wiring extra scenarios into the integration runner is a BAR-Devtools
-- change; the same follow-up covers the scavengers smoke.

-- Grace on the skirmish pack is a tenth of the easy rung's 240s, so beacons
-- are due around 24s and the first wave ten seconds after that. Test.waitUntil
-- counts FRAMES, not milliseconds: 3600 is two minutes of game time, generous
-- because placement probes are random and a bad map corner costs a cadence.
local SPAWN_TIMEOUT = 3600

---Everything below reads GameRulesParams. They are readable unsynced, they
---are what a UI panel would use, and they keep this test out of the synced
---state entirely.
local function param(name)
	return Spring.GetGameRulesParam(name)
end

function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	-- CM8's enclave spawns for an enemy team. Without one the mission cannot
	-- arm at all, and this is not the game to run it in.
	local gaia = Spring.GetGaiaTeamID()
	local playerTeamID = Spring.GetLocalTeamID()
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= playerTeamID then
			return false
		end
	end
	return true
end

function setup()
	Test.clearMap()
end

function cleanup()
	-- The director keeps running: stopping it needs the synced side, and this
	-- scenario is single-test by design — its startscript names one test, and
	-- in the standard suite the skip above means none of this ever started.
	Test.clearMap()
end

function test()
	local playerTeamID = Spring.GetLocalTeamID()

	Spring.SendCommands("luarules mission cm8_ashfall")
	Test.waitUntil(function()
		return param("mission_active") == 1
	end)

	-- The opening beat waits. .After(30) holds the pressure back half a
	-- minute, so nothing may exist before then — this is the assertion that
	-- would catch a delay that silently does nothing.
	Test.waitFrames(20 * 30)
	assert(param("scavGracePeriod") == nil, "the director must not start before the trigger's .After(30) elapses")

	-- MatchFlow.Started fires on the first cadence after arming, and its Do
	-- is what asks for the pressure. The director publishes its clocks at
	-- Start, so their existence IS "the pack resolved and the roster built".
	Test.waitUntil(function()
		return param("scavGracePeriod") ~= nil and param("scavTechAnger") ~= nil
	end, SPAWN_TIMEOUT)

	-- That trigger is published as FIRED, which is what lets the editor shade
	-- a card once the engine has actually run it. The key is the runtime's own
	-- trigger identity, mission prefix included.
	Test.waitUntil(function()
		return param("mission_trigger_fired_cm8_ashfall/triggers/waves.lua:1") == 1
	end, SPAWN_TIMEOUT)
	-- A trigger that has not fired publishes nothing rather than zero: the
	-- Armada commander is alive, so the pressure has not been called off.
	assert(
		param("mission_trigger_fired_cm8_ashfall/triggers/waves.lua:4") == nil,
		"an unfired trigger should publish nothing"
	)

	-- The mission's own dial, not the pack's default. Carried x1000, because
	-- a rules param is a number and the trigger file asks for 0.3.
	Test.waitUntil(function()
		return param("scavIntensity") ~= nil
	end, SPAWN_TIMEOUT)
	assert(
		param("scavIntensity") == 300,
		"the trigger file asks for 0.3, got " .. tostring((param("scavIntensity") or 0) / 1000)
	)

	-- Beacons, then units, then the director's own account of it.
	Test.waitUntil(function()
		return (param("scav_hiveCount") or 0) > 0
	end, SPAWN_TIMEOUT)

	Test.waitUntil(function()
		return (param("scavWaveNumber") or 0) > 0
	end, SPAWN_TIMEOUT)

	-- Skirmish is pressure with no ending of its own. The boss count is zero,
	-- so this flag can never be raised — and the mission keeps its own win
	-- condition, which is the whole reason the pack exists.
	assert(param("BossFightStarted") ~= 1, "the skirmish pack should never field a boss")

	-- And what is on the map is hostile to the player and is a scavenger,
	-- neither of which needed a bot.
	local scavengers = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= playerTeamID then
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
				-- The mission's own roster sits on these teams too; count only
				-- what the director put there.
				if unitDef and unitDef.customParams.isscavenger then
					scavengers = scavengers + 1
				end
			end
		end
	end
	assert(scavengers > 0, "expected scavenger units on the field, found none")
end
