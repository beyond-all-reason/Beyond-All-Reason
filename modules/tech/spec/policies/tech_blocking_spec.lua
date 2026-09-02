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
	local atTier1 = { tech_level = "1", tech_points = "3", tech_t2_threshold = "10", tech_t3_threshold = "20" }

	local i18n
	before_each(function()
		i18n = BAR.I18N
		-- the clause as its key and data, so the spec reads what tech says without the strings
		BAR.I18N = function(key, data)
			if data == nil then
				return key
			end
			local parts = {}
			for k, v in pairs(data) do
				parts[#parts + 1] = k .. "=" .. tostring(v)
			end
			table.sort(parts)
			return key .. "{" .. table.concat(parts, ",") .. "}"
		end
	end)
	after_each(function()
		BAR.I18N = i18n
	end)

	it("the team's tax rate is the one for its tech level", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamTerms)
		local facts = ModuleHandler.EnrichWith(
			resolved,
			{ tech = true },
			{ teamId = 1, modOptions = opts, springRepo = repo({ tech_level = "2" }, opts) }
		)
		assert.are.equal(0.25, facts[Contract.TeamTerms.TaxRate])
	end)

	it("a pairing carries the sender's tier: its modes and its tax", function()
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamPairing)
		local facts = ModuleHandler.EnrichWith(
			resolved,
			{ tech = true },
			{ modOptions = opts, springRepo = repo(atTier1, opts), senderTeamId = 1 }
		)
		assert.are.same({ "none" }, facts[Contract.TeamPairing.UnitSharingModes])
		assert.are.equal(0.5, facts[Contract.TeamPairing.TaxRate])
		local atTier2 = ModuleHandler.EnrichWith(resolved, { tech = true }, {
			modOptions = opts,
			springRepo = repo(
				{ tech_level = "2", tech_points = "10", tech_t2_threshold = "10", tech_t3_threshold = "20" },
				opts
			),
			senderTeamId = 1,
		})
		assert.are.same({ "resource" }, atTier2[Contract.TeamPairing.UnitSharingModes])
		assert.are.equal(0.25, atTier2[Contract.TeamPairing.TaxRate])
	end)

	it("the notes on a terms record say, in the player's words, what the next tier opens", function()
		local terms = { senderTeamId = 1, receiverTeamId = 2 }
		local unit = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.UnitTermsNotes),
			{ tech = true },
			{ terms = terms, modOptions = opts, springRepo = repo(atTier1, opts) }
		)
		assert.are.equal(
			"ui.techBlocking.opening.units{level=2,points=3,threshold=10,unitSharingMode=ui.unitSharingMode.resource}",
			unit[Contract.UnitTermsNotes.Opening]
		)
		local resource = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.ResourceTermsNotes),
			{ tech = true },
			{ terms = terms, modOptions = opts, springRepo = repo(atTier1, opts) }
		)
		assert.are.equal(
			"ui.techBlocking.opening.tax{level=2,points=3,rate=25,threshold=10}",
			resource[Contract.ResourceTermsNotes.Opening]
		)
	end)

	it("the notes say nothing for a team tech keeps no level for, or past the last opening", function()
		local terms = { senderTeamId = 1, receiverTeamId = 2 }
		local none = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.UnitTermsNotes),
			{ tech = true },
			{ terms = terms, modOptions = opts, springRepo = repo({}, opts) }
		)
		assert.is_nil(none[Contract.UnitTermsNotes.Opening])
		local top = ModuleHandler.EnrichWith(
			ModuleHandler.LoadEnrichers(Contract.ResourceTermsNotes),
			{ tech = true },
			{
				terms = terms,
				modOptions = opts,
				springRepo = repo(
					{ tech_level = "3", tech_points = "20", tech_t2_threshold = "10", tech_t3_threshold = "20" },
					opts
				),
			}
		)
		assert.is_nil(top[Contract.ResourceTermsNotes.Opening])
	end)
end)
