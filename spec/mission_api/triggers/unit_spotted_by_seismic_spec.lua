require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- UnitDefs / Spring.GetUnitTeam inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitSpottedBySeismic = VFS.Include('luarules/mission_api/triggers/unit_spotted_by_seismic.lua')
local onSeismicPing = unitSpottedBySeismic.callins.UnitSeismicPing
local onSeismicInterval = unitSpottedBySeismic.callins.SeismicInterval

-- The first sweep banks the ping as a score of 2, which drains in two more sweeps. The dwell
-- floor then holds the drained contact until it has been tracked for eight sweeps in total.
local SWEEPS_TO_FALLOFF_AFTER_ONE_PING = 9

describe("mission_api.triggers.unit_spotted_by_seismic", function()
	-- Each test below takes a fresh triggerID, rather than risk sharing state across triggers.
	local triggerID
	local triggerCount = 0

	before_each(function()
		triggerCount = triggerCount + 1
		triggerID = 'spotted-' .. triggerCount -- Safe.
		Spring.GetUnitTeam = function(_unitID) return 3 end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			DoesUnitHaveName = function() return true end,
			ActivateTrigger = function() fired = fired + 1 end,
		}
		return context, function() return fired end
	end

	local function ping(t, context, seismicAllyTeamID, unitID, unitDefID)
		onSeismicPing(t, triggerID, context, 0, 0, 0, 1, seismicAllyTeamID, unitID, unitDefID)
	end

	local function tickSilent(t, context, intervals)
		for _ = 1, intervals do -- NB: Always from 1
			onSeismicInterval(t, triggerID, context)
		end
	end

	it("declares its type and parameters", function()
		assert.are.equal('UnitSpottedBySeismic', unitSpottedBySeismic.type)
		local names = {}
		for _, parameter in ipairs(unitSpottedBySeismic.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.owningTeamID)
		assert.is_true(names.spottingAllyTeamID)
		assert.are.same({ 'unitName', 'unitDefName' }, unitSpottedBySeismic.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		local t = trigger({ unitName = 'scouts' })
		context.DoesUnitHaveName = function() return false end
		ping(t, context, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		ping(trigger({ unitDefName = 'corfast' }), context, 0, 100, 1) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by owningTeamID", function()
		local context, fired = newContext()
		ping(trigger({ unitDefName = 'armpw', owningTeamID = 9 }), context, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by spottingAllyTeamID", function()
		local context, fired = newContext()
		ping(trigger({ unitDefName = 'armpw', spottingAllyTeamID = 5 }), context, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("fires on a matching seismic ping", function()
		local context, fired = newContext()
		ping(trigger({ unitDefName = 'armpw' }), context, 0, 100, 1)
		assert.are.equal(1, fired())
	end)

	it("fires only on the leading edge, and stays locked while pings continue", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 10 do
			ping(t, context, 0, 100, 1)
		end
		assert.are.equal(1, fired())
	end)

	it("stays locked across intervals while the unit keeps pinging", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 20 do
			ping(t, context, 0, 100, 1)
			tickSilent(t, context, 1)
		end
		assert.are.equal(1, fired())
	end)

	-- Need some concrete behaviors that are not statistical:
	it("stays locked for a unit pinging every other interval", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 50 do
			ping(t, context, 0, 100, 1)
			tickSilent(t, context, 1)
			tickSilent(t, context, 1)
		end
		assert.are.equal(1, fired())
	end)

	it("stays locked while the contact is still draining", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 0, 100, 1)
		tickSilent(t, context, SWEEPS_TO_FALLOFF_AFTER_ONE_PING - 1)
		ping(t, context, 0, 100, 1)
		assert.are.equal(1, fired())
	end)

	it("re-arms once the contact falls off, and fires again on the next ping", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 0, 100, 1)
		tickSilent(t, context, SWEEPS_TO_FALLOFF_AFTER_ONE_PING)
		ping(t, context, 0, 100, 1)
		assert.are.equal(2, fired())
	end)

	it("locks each unit independently", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		ping(t, context, 0, 100, 1)
		ping(t, context, 0, 101, 1)
		ping(t, context, 0, 100, 1)
		assert.are.equal(2, fired())
	end)
end)
