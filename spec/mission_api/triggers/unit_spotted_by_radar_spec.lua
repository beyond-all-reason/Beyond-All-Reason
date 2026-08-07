require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time,
-- and UnitDefs inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitSpottedByRadar = VFS.Include('luarules/mission_api/triggers/unit_spotted_by_radar.lua')
local onEnteredRadar = unitSpottedByRadar.callins.UnitEnteredRadar

describe("mission_api.triggers.unit_spotted_by_radar", function()
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

	it("declares its type and parameters", function()
		assert.are.equal('UnitSpottedByRadar', unitSpottedByRadar.type)
		local names = {}
		for _, parameter in ipairs(unitSpottedByRadar.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.owningTeamID)
		assert.is_true(names.spottingAllyTeamID)
		assert.are.same({ 'unitName', 'unitDefName' }, unitSpottedByRadar.parameters.requiresOneOf)
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		onEnteredRadar(trigger({ unitName = 'scouts' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onEnteredRadar(trigger({ unitDefName = 'corfast' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by owningTeamID", function()
		local context, fired = newContext()
		onEnteredRadar(trigger({ unitDefName = 'armpw', owningTeamID = 9 }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by spottingAllyTeamID", function()
		local context, fired = newContext()
		onEnteredRadar(trigger({ unitDefName = 'armpw', spottingAllyTeamID = 5 }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("fires when a matching unit enters radar", function()
		local context, fired = newContext()
		onEnteredRadar(trigger({ unitDefName = 'armpw' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it("re-fires on every radar entry, with no deduplication", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		onEnteredRadar(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(3, fired())
	end)
end)
