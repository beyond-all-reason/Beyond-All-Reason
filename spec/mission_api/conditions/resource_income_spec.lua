local Builders = VFS.Include("spec/builders/index.lua")
local MissionSpecEnv = require("mission_api.spec_helper")

local env = MissionSpecEnv.new()

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Game.gameSpeed / Spring.GetTeamResources / Spring.GetTeamUnits / UnitDefs inside its handler.
Builders.MissionApi.new():Install()

local resourceIncome = MissionSpecEnv.include(env, "luarules/mission_api/conditions/resource_income.lua")
local onGameFrame = resourceIncome.callins.GameFrame

describe("mission_api.conditions.resource_income", function()
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
		return Builders.Trigger.new():WithParameters(parameters):Build()
	end

	local function newContext()
		local context = Builders.TriggerContext.new():Build()
		return context, context.sampledValues
	end

	local triggerID = "t"

	-- Income and the resources received via sharing come from a built team, so the
	-- tuple GetTeamResources returns keeps the engine's field order.
	local function resources(income, received)
		local team = Builders.Team
			.new()
			:WithID(0)
			:WithMetalIncome(income)
			:WithEnergyIncome(income)
			:WithMetalReceived(received or 0)
			:WithEnergyReceived(received or 0)
		return Builders.Spring.new():WithTeam(team):Build().GetTeamResources
	end

	-- The extractor-sourced tests need a def that extracts metal.
	local function extractorUnitDefs()
		return Builders.UnitDefs.new():WithUnitDef(1, { extractsMetal = 1 }):GetUnitDefsByID()
	end

	it("declares its type, kind and parameters", function()
		assert.are.equal("ResourceIncome", resourceIncome.type)
		assert.are.equal("metric", resourceIncome.kind)
		local required = {}
		for _, parameter in ipairs(resourceIncome.parameters) do
			required[parameter.name] = parameter.required
		end
		assert.are.same({ teamID = true, resource = true, sources = false }, required)
	end)

	it("only samples once per second", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context, 1)
		assert.are.same({}, sampled())
	end)

	it("samples the engine's total income for the named resource when no sources are given", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, resource = "metal" }), triggerID, context, Game.gameSpeed)
		onGameFrame(trigger({ teamID = 0, resource = "energy" }), triggerID, context, Game.gameSpeed)
		assert.are.same({ 10, 10 }, sampled())
	end)

	it("filters by source: production only, excluding extractor income", function()
		local context, sampled = newContext()
		-- Total income 10; extractor income should be subtracted from production.
		env.Spring.GetUnitDefID = function()
			return 1
		end
		_G.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, resource = "metal", sources = { production = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		-- production income = 10 (total) - 10 (extractor) - 0 (reclaim) = 0
		assert.are.same({ 0 }, sampled())
	end)

	it("filters by source: extractor income alone", function()
		local context, sampled = newContext()
		_G.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, resource = "metal", sources = { extractor = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.same({ 10 }, sampled())
	end)

	it("filters by source: transfer income from GetTeamResources' received index", function()
		local context, sampled = newContext()
		env.Spring.GetTeamResources = resources(10, 20)
		onGameFrame(
			trigger({ teamID = 0, resource = "metal", sources = { transfer = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.same({ 20 }, sampled())
	end)

	it("filters by source: reclaim income from the context snapshot", function()
		local context, sampled = newContext()
		context.GetReclaimIncomeSnapshot = function()
			return { metal = 7 }
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, resource = "metal", sources = { reclaim = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.same({ 7 }, sampled())
	end)

	it("samples no energy through extractor sources", function()
		-- Extractor income is metal-only, so extractor-sourced energy income is always zero.
		local context, sampled = newContext()
		_G.UnitDefs = extractorUnitDefs()
		env.Spring.GetTeamUnits = function()
			return { 1 }
		end
		env.Spring.GetUnitMetalExtraction = function()
			return 10
		end
		env.Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, resource = "energy", sources = { extractor = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.same({ 0 }, sampled())
	end)
end)
