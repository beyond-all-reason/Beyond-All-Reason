require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time,
-- and UnitDefs inside its handler.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armpw' }, [2] = { name = 'corfast' } }

local unitUnspottedByRadar = VFS.Include('mission_api/triggers/unit_unspotted_by_radar')
local onLeftRadar = unitUnspottedByRadar.callins.UnitLeftRadar

describe("mission_api.triggers.unit_unspotted_by_radar", function()
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
		assert.are.equal('UnitUnspottedByRadar', unitUnspottedByRadar.type)
		local names = {}
		for _, parameter in ipairs(unitUnspottedByRadar.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.owningTeamID)
		assert.is_true(names.spottingAllyTeamID)
		assert.are.same({ 'unitName', 'unitDefName' }, unitUnspottedByRadar.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		onLeftRadar(trigger({ unitDefName = 'corfast' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by owningTeamID", function()
		local context, fired = newContext()
		onLeftRadar(trigger({ unitDefName = 'armpw', owningTeamID = 9 }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by spottingAllyTeamID", function()
		local context, fired = newContext()
		onLeftRadar(trigger({ unitDefName = 'armpw', spottingAllyTeamID = 5 }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("filters by unitName", function()
		local context, fired = newContext()
		context.DoesUnitHaveName = function() return false end
		onLeftRadar(trigger({ unitName = 'scouts' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(0, fired())
	end)

	it("fires when a matching unit leaves radar", function()
		local context, fired = newContext()
		onLeftRadar(trigger({ unitDefName = 'armpw' }), triggerID, context, 100, 3, 0, 1)
		assert.are.equal(1, fired())
	end)

	it("re-fires on every radar-loss event, with no deduplication", function()
		local context, fired = newContext()
		local t = trigger({ unitDefName = 'armpw' })
		onLeftRadar(t, triggerID, context, 100, 3, 0, 1)
		onLeftRadar(t, triggerID, context, 100, 3, 0, 1)
		onLeftRadar(t, triggerID, context, 100, 3, 0, 1)
		assert.are.equal(3, fired())
	end)
end)
