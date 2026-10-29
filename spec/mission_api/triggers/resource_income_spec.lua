local TeamBuilder = VFS.Include("spec/builders/team_builder.lua")
local SpringSyncedBuilder = VFS.Include("spec/builders/spring_synced_builder.lua")
local UnitDefsBuilder = VFS.Include("spec/builders/unit_defs_builder.lua")
local MissionApiBuilder = VFS.Include("spec/builders/mission_api_builder.lua")
local TriggerBuilder = VFS.Include("spec/builders/trigger_builder.lua")
local TriggerContextBuilder = VFS.Include("spec/builders/trigger_context_builder.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Game.gameSpeed / Spring.GetTeamResources / Spring.GetTeamUnits / UnitDefs inside its handler.
MissionApiBuilder.new():Install()

local resourceIncome = MissionSpecEnv.include(env, "luarules/mission_api/triggers/resource_income.lua")
local onGameFrame = resourceIncome.callins.GameFrame

describe("mission_api.triggers.resource_income", function()
	before_each(function()
		env.Spring.GetTeamUnits = function()
			return {}
		end
		env.Spring.GetUnitDefID = function()
			return 1
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 0
		end
	end)

	local function trigger(parameters)
		return TriggerBuilder.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = TriggerContextBuilder.new():Build()
		return context, context.timesFired
	end

	local triggerID = "t"

	-- Income and the resources received via sharing come from a built team, so the
	-- tuple GetTeamResources returns keeps the engine's field order.
	local function resources(income, received)
		local team = TeamBuilder.new()
			:WithID(0)
			:WithMetalIncome(income)
			:WithEnergyIncome(income)
			:WithMetalReceived(received or 0)
			:WithEnergyReceived(received or 0)
		return SpringSyncedBuilder.new():WithTeam(team):Build().GetTeamResources
	end

	-- The extractor-sourced tests need a def that extracts metal.
	local function extractorUnitDefs()
		return UnitDefsBuilder.new():WithUnitDef(1, { extractsMetal = 1 }):GetUnitDefsByID()
	end

	it("declares its type and parameters", function()
		assert.are.equal("ResourceIncome", resourceIncome.type)
		local names = {}
		for _, parameter in ipairs(resourceIncome.parameters) do
			names[parameter.name] = true
		end
		assert.is_true(names.teamID)
		assert.is_true(names.metal)
		assert.is_true(names.energy)
		assert.is_true(names.sources)
		assert.are.same({ "metal", "energy" }, resourceIncome.parameters.requiresOneOf)
	end)

	it("only evaluates once per second", function()
		local context, fired = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, 1)
		assert.are.equal(0, fired())
	end)

	it("fires when unfiltered income meets the metal threshold", function()
		local context, fired = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(1, fired())
	end)

	it("does not fire when unfiltered income is below the metal threshold", function()
		local context, fired = newContext()
		env.Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)

	it("does not fire when unfiltered income is below the energy threshold", function()
		local context, fired = newContext()
		env.Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, energy = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)

	it("filters by source: production only, excluding extractor income", function()
		local context, fired = newContext()
		-- Total income 10; extractor income should be subtracted from production.
		env.Spring.GetUnitDefID = function()
			return 1
		end
		env.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, metal = 1, sources = { production = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		-- production income = 10 (total) - 10 (extractor) - 0 (reclaim) = 0, below threshold 1.
		assert.are.equal(0, fired())
	end)

	it("filters by source: extractor income alone", function()
		local context, fired = newContext()
		env.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, metal = 5, sources = { extractor = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.equal(1, fired())
	end)

	it("filters by source: transfer income from GetTeamResources' received index", function()
		local context, fired = newContext()
		env.Spring.GetTeamResources = resources(10, 20)
		onGameFrame(
			trigger({ teamID = 0, metal = 15, sources = { transfer = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.equal(1, fired())
	end)

	it("filters by source: reclaim income from the context snapshot", function()
		local context, fired = newContext()
		context.GetReclaimIncomeSnapshot = function()
			return { metal = 7 }
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, metal = 5, sources = { reclaim = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.equal(1, fired())
	end)

	it("does not evaluate energy through extractor sources", function()
		-- Extractor income is metal-only per the trigger; requesting extractor-sourced
		-- energy income should never exceed a positive threshold.
		local context, fired = newContext()
		env.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, energy = 1, sources = { extractor = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.equal(0, fired())
	end)
end)
