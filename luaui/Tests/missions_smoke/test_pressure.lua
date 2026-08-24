---@diagnostic disable: undefined-field

-- Test.waitUntil counts FRAMES, not milliseconds: 3600 is two minutes of
-- game time, generous because placement probes cost a cadence on a bad map
-- corner.
local SPAWN_TIMEOUT = 3600

local function param(name)
	return Spring.GetGameRulesParam(name)
end

local function skip()
	if Spring.GetGameFrame() <= 0 then
		return true
	end
	local gaia = Spring.GetGaiaTeamID()
	local playerTeamID = Spring.GetLocalTeamID()
	local _, _, _, _, _, myAllyTeamID = Spring.GetTeamInfo(playerTeamID, false)
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= gaia and teamID ~= playerTeamID then
			local _, _, _, _, _, allyTeamID = Spring.GetTeamInfo(teamID, false)
			if allyTeamID ~= myAllyTeamID then
				return false
			end
		end
	end
	return true
end

local function setup()
	Test.clearMap()
end

local function cleanup()
	-- The director keeps running: stopping it needs the synced side, and this
	-- test runs last in its scenario by name.
	Test.clearMap()
end

local function test()
	local playerTeamID = Spring.GetLocalTeamID()

	Spring.SendCommands("luarules mission smoke_pressure")
	Test.waitUntil(function()
		return param("mission_active") == 1
	end)

	-- .After(30) holds the pressure back: nothing may exist before then, which is
	-- what catches a delay that silently does nothing.
	Test.waitFrames(20 * 30)
	assert(param("scavGracePeriod") == nil, "the director must not start before the trigger's .After(30) elapses")

	-- The director publishes its clocks at Start, so their existence IS
	-- "the pack resolved and the roster built".
	Test.waitUntil(function()
		return param("scavGracePeriod") ~= nil and param("scavTechAnger") ~= nil
	end, SPAWN_TIMEOUT)

	Test.waitUntil(function()
		return param("mission_trigger_fired_smoke_pressure/triggers/pressure.lua:1") == 1
	end, SPAWN_TIMEOUT)

	-- The mission's own dial, not the pack's default. Carried x1000, because
	-- a rules param is a number and the trigger file asks for 0.3.
	Test.waitUntil(function()
		return param("scavIntensity") ~= nil
	end, SPAWN_TIMEOUT)
	assert(
		param("scavIntensity") == 300,
		"the trigger file asks for 0.3, got " .. tostring((param("scavIntensity") or 0) / 1000)
	)

	Test.waitUntil(function()
		return (param("scav_hiveCount") or 0) > 0
	end, SPAWN_TIMEOUT)
	Test.waitUntil(function()
		return (param("scavWaveNumber") or 0) > 0
	end, SPAWN_TIMEOUT)

	-- Skirmish has no boss because the mission keeps its own win condition.
	assert(param("BossFightStarted") ~= 1, "the skirmish pack should never field a boss")

	local scavengers = 0
	for _, teamID in ipairs(Spring.GetTeamList()) do
		if teamID ~= playerTeamID then
			for _, unitID in ipairs(Spring.GetTeamUnits(teamID)) do
				local unitDef = UnitDefs[Spring.GetUnitDefID(unitID)]
				if unitDef and unitDef.customParams.isscavenger then
					scavengers = scavengers + 1
				end
			end
		end
	end
	assert(scavengers > 0, "expected scavenger units on the field, found none")
end

return { skip = skip, setup = setup, cleanup = cleanup, test = test }
