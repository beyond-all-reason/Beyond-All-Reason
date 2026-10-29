local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time (so, here),
-- Game.envDamageTypes from the harness, and Spring / UnitDefs inside its handlers.
MissionApiBuilder.new():Install()

local unitDefs = UnitDefsBuilder.new():WithUnitDefs({
	[1] = { name = "armsolar" },
	[2] = { name = "armwin" },
})
_G.UnitDefs = unitDefs:GetUnitDefsByID()

local productionCanceled = MissionSpecEnv.include(env, "luarules/mission_api/triggers/production_canceled.lua")
local onUnitDestroyed = productionCanceled.callins.UnitDestroyed
local onUnitTaken = productionCanceled.callins.UnitTaken

describe("mission_api.triggers.production_canceled", function()
	before_each(function()
		-- Default: the unit was still under construction (a nanoframe).
		env.Spring.GetUnitIsBeingBuilt = function()
			return true
		end
	end)

	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = TriggerContextBuilder.new():WithInFactory(true):Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	local function canceled(trigger, context, unitDefID, unitTeam, weaponDefID)
		weaponDefID = weaponDefID or Game.envDamageTypes.FactoryCancel
		onUnitDestroyed(trigger, triggerID, context, 100, unitDefID, unitTeam, nil, nil, nil, weaponDefID)
	end

	local function taken(trigger, context, unitDefID, oldTeam, newTeam)
		onUnitTaken(trigger, triggerID, context, 100, unitDefID, oldTeam, newTeam)
	end

	it("declares its type and parameters", function()
		assert.are.equal("ProductionCanceled", productionCanceled.type)
		local names = {}
		for _, parameter in ipairs(productionCanceled.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.unitName)
		assert.is_true(names.unitDefName)
		assert.is_true(names.teamID)
		assert.is_true(names.factoryName)
		assert.is_true(names.factoryDefName)
		assert.are.same({ "unitName", "unitDefName" }, productionCanceled.parameters.requiresOneOf)
	end)

	it("filters by unitDefName", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = "armsolar" }), context, 2, 0) -- unitDefID 2 = armwin
		assert.are.equal(0, fired())
	end)

	it("filters by teamID", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 9)
		assert.are.equal(0, fired())
	end)

	it("fires when a unit in production is canceled", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a nanoframe shot down in the factory", function()
		local context, fired = newContext()
		canceled(trigger({ unitDefName = "armsolar" }), context, 1, 0, 42) -- a real weaponDefID
		assert.are.equal(0, fired())
	end)

	it("defers factory filtering to context.IsBuildFrameOwner", function()
		local context, fired = newContext()
		context.IsBuildFrameOwner = function()
			return false
		end
		canceled(trigger({ unitDefName = "armsolar", factoryDefName = "armlab" }), context, 1, 0)
		assert.are.equal(0, fired())
	end)

	it("fires for a buildee taken by an enemy team, for the team it was taken from", function()
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armsolar", teamID = 0 }), context, 1, 0, 9)
		assert.are.equal(1, fired())
	end)

	it("does not fire for a finished unit that is taken", function()
		env.Spring.GetUnitIsBeingBuilt = function()
			return false
		end
		local context, fired = newContext()
		taken(trigger({ unitDefName = "armsolar" }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)

	it("does not fire for a nanoframe taken outside a factory", function()
		local context, fired = newContext()
		context.InFactory = function()
			return false
		end
		taken(trigger({ unitDefName = "armsolar" }), context, 1, 0, 9)
		assert.are.equal(0, fired())
	end)
end)
