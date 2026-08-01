require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- UnitDefs / Spring.GetUnitTeam inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitSpottedBySeismic = VFS.Include('luarules/mission_api/triggers/unit_spotted_by_seismic.lua')
local onSeismicPing = unitSpottedBySeismic.callins.UnitSeismicPing

describe("mission_api.triggers.unit_spotted_by_seismic", function()
	before_each(function()
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

	local triggerID = 't'

	local function ping(t, context, seismicAllyTeamID, unitID, unitDefID)
		onSeismicPing(t, triggerID, context, 0, 0, 0, 1, seismicAllyTeamID, unitID, unitDefID)
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
		ping(trigger({ unitName = 'scouts' }), context, 0, 100, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		ping(trigger({ unitDefName = 'corfast' }), context, 0, 100, 1) -- unitDefID 1 = armpw
		assert.are.equal(0, fired())
	end)

	it("filters by owningTeamID via the unit's current team", function()
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

	-- This includes both SlowUpdate/automatic pings from the engine and any extra scripted pings.
	it("fires on every ping, with no deduplication", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		for _ = 1, 10 do
			ping(t, context, 0, 100, 1)
		end
		assert.are.equal(10, fired())
	end)
end)
