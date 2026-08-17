require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so, here),
-- Game.envDamageTypes from the harness, and Spring / UnitDefs inside its handlers.
GG['MissionAPI'] = GG['MissionAPI'] or {}
GG['MissionAPI'].Modules = GG['MissionAPI'].Modules or {}
GG['MissionAPI'].Modules.ParameterTypes = VFS.Include('luarules/mission_api/parameter_types.lua')

_G.UnitDefs = { [1] = { name = 'armsolar' }, [2] = { name = 'armwin' } }

local productionCanceled = VFS.Include('luarules/mission_api/triggers/production_canceled.lua')
local onUnitDestroyed = productionCanceled.callins.UnitDestroyed
local onUnitTaken = productionCanceled.callins.UnitTaken

describe("mission_api.triggers.production_canceled", function()
	before_each(function()
		-- Default: the unit was still under construction (a nanoframe).
		Spring.GetUnitIsBeingBuilt = function() return true end
		-- Default: Teams are only allied with themselves. SOME TESTS WIDEN THIS.
		Spring.AreTeamsAllied = function(teamA, teamB) return teamA == teamB end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			ActivateTrigger = function() fired = fired + 1 end,
			DoesUnitHaveName = function() return true end,
			isBuildFrameOwner = function() return true end,
			InFactory = function() return true end,
		}
		return context, function() return fired end
	end

	local triggerID = 't'

	local function canceled(trigger, context, unitDefID, unitTeam, weaponDefID)
		weaponDefID = weaponDefID or Game.envDamageTypes.FactoryCancel
		onUnitDestroyed(trigger, triggerID, context, 100, unitDefID, unitTeam, nil, nil, nil, weaponDefID)
	end

	local function taken(trigger, context, unitDefID, oldTeam, newTeam)
		onUnitTaken(trigger, triggerID, context, 100, unitDefID, oldTeam, newTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal('ProductionCanceled', productionCanceled.type)
		local names = {}
		for _, parameter in ipairs(productionCanceled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.factoryName)
		assert.is_true(names.factoryDefName)
		assert.are.same({ 'unitName', 'unitDefName' }, productionCanceled.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = 'armsolar' }), context, 2, 0) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 9)
		assert.are.equal(0, fired())
	end)

	it("fires when a unit in production is canceled", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a buildee killed by its factory dying", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = 'armsolar' }), context, 1, 0, Game.envDamageTypes.FactoryKilled)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a nanoframe shot down in the factory", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 42) -- a real weaponDefID
		assert.are.equal(0, fired())
	end)

	it("defers factory filtering to context.isBuildFrameOwner", function()
		local context, fired = newContext()
		context.isBuildFrameOwner = function() return false end
		canceled(trigger({ unitDefName = 'armsolar', factoryDefName = 'armlab' }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a buildee taken by an enemy team, for the team it was taken from", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0, 9)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a buildee given to an allied team (production continues)", function()
		local context, fired = newContext()
		Spring.AreTeamsAllied = function(teamA, teamB)
			return teamA == teamB or (teamA == 0 and teamB == 2) or (teamA == 2 and teamB == 0)
		end
		taken(trigger({ unitDefName = 'armsolar', teamID = 0 }), context, 1, 0, 2)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a finished unit that is taken", function()
		Spring.GetUnitIsBeingBuilt = function() return false end
		local context, fired = newContext()
		taken(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a nanoframe taken outside a factory", function()
		local context, fired = newContext()
		context.InFactory = function() return false end
		taken(trigger({ unitDefName = 'armsolar' }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)
end)
