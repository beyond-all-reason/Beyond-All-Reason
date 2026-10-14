local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")
local state = require("modules/transfer/state")

-- the ledger is module state, shared by every instance: empty it around the case that writes it
local function clearLedger()
	for teamId in pairs(state.manualShareLedger) do
		state.manualShareLedger[teamId] = nil
	end
end

describe("what transfer tells economy", function()
	it("a team's tax rate is transfer's, from the modoption", function()
		local resolved = ModuleHandler.LoadEnrichers(ModuleHandler.Contract(Modules.Economy).Distribution)
		local spring = {
			GetModOptions = function()
				return { [TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.4 }
			end,
			GetTeamRulesParam = function()
				return nil
			end,
		}
		local facts = ModuleHandler.EnrichWith(resolved, { transfer = true }, { teamId = 1, springRepo = spring })
		assert.are.equal(0.4, facts[ModuleHandler.Contract(Modules.Economy).Distribution.TaxRate])
	end)

	it("a mode that denies resource sharing denies the team's overflow too", function()
		local resolved = ModuleHandler.LoadEnrichers(ModuleHandler.Contract(Modules.Economy).Distribution)
		local spring = {
			GetModOptions = function()
				return { [TransferEnums.ModOptions.ResourceSharingEnabled] = "0" }
			end,
			GetTeamRulesParam = function()
				return nil
			end,
		}
		local facts = ModuleHandler.EnrichWith(resolved, { transfer = true }, { teamId = 1, springRepo = spring })
		assert.is_false(facts[ModuleHandler.Contract(Modules.Economy).Distribution.Shares])
	end)

	it("the redistribution results carry what was shared by hand since the last tick", function()
		clearLedger()
		ManualShareLedger.Record(1, 2, "metal", 100, 90)
		local resolved = ModuleHandler.LoadEnrichers(ModuleHandler.Contract(Modules.Economy).Redistribution)
		local results = {
			{ teamId = 1, resourceType = "metal", sent = 5, received = 0 },
			{ teamId = 2, resourceType = "metal", sent = 0, received = 0 },
		}
		local folded =
			ModuleHandler.EnrichWith(resolved, { transfer = true }, { results = results })[ModuleHandler.Contract(
				Modules.Economy
			).Redistribution.Results]
		assert.are.equal(105, assert(folded[1]).sent)
		assert.are.equal(90, assert(folded[2]).received)
		clearLedger()
	end)
end)
