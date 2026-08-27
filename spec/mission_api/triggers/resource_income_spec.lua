require("spec_helper")

-- The trigger file reads GG['MissionAPI'].Modules.ParameterTypes at load time, and
-- Game.gameSpeed / Spring.GetTeamResources / Spring.GetTeamUnits / UnitDefs inside its handler.
GG["MissionAPI"] = GG["MissionAPI"] or {}
GG["MissionAPI"].Modules = GG["MissionAPI"].Modules or {}
GG["MissionAPI"].Modules.ParameterTypes = VFS.Include("luarules/mission_api/parameter_types.lua")

local resourceIncome = VFS.Include("luarules/mission_api/triggers/resource_income.lua")
local onGameFrame = resourceIncome.callins.GameFrame

describe("mission_api.triggers.resource_income", function()
	before_each(function()
		Spring.GetTeamUnits = function()
			return {}
		end
		Spring.GetUnitDefID = function()
			return 1
		end
		Spring.GetUnitMetalExtraction = function()
			return 0
		end
	end)

	local function trigger(parameters)
		return { parameters = parameters or {}, settings = {} }
	end

	local function newContext()
		local fired = 0
		local context = {
			GetReclaimIncomeSnapshot = function()
				return nil
			end,
			ActivateTrigger = function()
				fired = fired + 1
			end,
		}
		return context, function()
			return fired
		end
	end

	local triggerID = "t"

	-- select(4, ...) is total income; select(8, ...) is resources received via sharing.
	local function resources(income, received)
		return function()
			return 0, 0, 0, income, 0, 0, 0, received or 0
		end
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
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, 1)
		assert.are.equal(0, fired())
	end)

	it("fires when unfiltered income meets the metal threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(10)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(1, fired())
	end)

	it("does not fire when unfiltered income is below the metal threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, metal = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)

	it("does not fire when unfiltered income is below the energy threshold", function()
		local context, fired = newContext()
		Spring.GetTeamResources = resources(1)
		onGameFrame(trigger({ teamID = 0, energy = 5 }), triggerID, context, Game.gameSpeed)
		assert.are.equal(0, fired())
	end)

	it("filters by source: production only, excluding extractor income", function()
		local context, fired = newContext()
		-- Total income 10; extractor income should be subtracted from production.
		Spring.GetUnitDefID = function()
			return 1
		end
		_G.UnitDefs = { [1] = { extractsMetal = 1 } }
		Spring.GetTeamUnits = function()
			return { 1 }
		end
		Spring.GetUnitMetalExtraction = function()
			return 10
		end
		Spring.GetTeamResources = resources(10)
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
		_G.UnitDefs = { [1] = { extractsMetal = 1 } }
		Spring.GetTeamUnits = function()
			return { 1 }
		end
		Spring.GetUnitMetalExtraction = function()
			return 10
		end
		Spring.GetTeamResources = resources(10)
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
		Spring.GetTeamResources = resources(10, 20)
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
		Spring.GetTeamResources = resources(10)
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
		_G.UnitDefs = { [1] = { extractsMetal = 1 } }
		Spring.GetTeamUnits = function()
			return { 1 }
		end
		Spring.GetUnitMetalExtraction = function()
			return 10
		end
		Spring.GetTeamResources = resources(10)
		onGameFrame(
			trigger({ teamID = 0, energy = 1, sources = { extractor = true } }),
			triggerID,
			context,
			Game.gameSpeed
		)
		assert.are.equal(0, fired())
	end)
end)
