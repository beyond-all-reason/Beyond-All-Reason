local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")

---@param rules table<string, any>
---@param opts table
local function repo(rules, opts)
	return {
		GetTeamRulesParam = function(_, key)
			return rules[key]
		end,
		GetModOptions = function()
			return opts
		end,
	}
end

describe("what tech tells transfer about a team", function()
	local Contract = ModuleHandler.Contract(Modules.Transfer)
	local opts = {
		unit_sharing_mode = "none",
		unit_sharing_mode_at_t2 = "resource",
		tax_resource_sharing_amount = 0.5,
		tax_resource_sharing_amount_at_t2 = 0.25,
	}

	it("the team's tax rate is the one for its tech level", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamTerms)
		local facts = ModuleHandler.EnrichWith(
			resolved,
			{ tech = true },
			{ teamId = 1, modOptions = opts, springRepo = repo({ tech_level = "2" }, opts) }
		)
		assert.are.equal(0.25, facts[Contract.TeamTerms.TaxRate])
	end)

	it("a pairing carries the sender's tier: what it blocks, its modes and its tax", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamPairing)
		local spring =
			repo({ tech_level = "1", tech_points = "3", tech_t2_threshold = "10", tech_t3_threshold = "20" }, opts)
		local facts = ModuleHandler.EnrichWith(resolved, { tech = true }, { modOptions = opts }, spring, 1)
		assert.are.same({ "none" }, facts[Contract.TeamPairing.UnitSharingModes])
		assert.are.equal(0.5, facts[Contract.TeamPairing.TaxRate])
		local blocking = facts[Contract.TeamPairing.TechBlocking]
		assert.are.equal(1, blocking.level)
		assert.are.equal(3, blocking.points)
		assert.are.equal(10, blocking.nextThreshold)
	end)

	it("the notes on a terms record say what the next tier unlocks, from the modoptions handed in", function()
		local blocking =
			{ level = 1, points = 3, t2Threshold = 10, t3Threshold = 20, nextLevel = 2, nextThreshold = 10 }
		local unit = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.UnitTermsNotes),
			{ tech = true },
			{ techBlocking = blocking },
			opts
		)
		assert.is_true(unit[Contract.UnitTermsNotes.FutureUnlock])
		assert.are.equal("resource", unit[Contract.UnitTermsNotes.TechData].nextUnitSharingMode)
		local resource = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.ResourceTermsNotes),
			{ tech = true },
			{ techBlocking = blocking },
			opts
		)
		assert.are.same(
			{ unlockLevel = 2, unlockThreshold = 10, unlockValue = 0.25 },
			resource[Contract.ResourceTermsNotes.TaxUnlock]
		)
	end)
end)
