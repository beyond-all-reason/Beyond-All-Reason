local ModuleHandler = require("modules/module_handler")
local Tax = require("modules/transfer/resource/tax")
local TransferEnums = require("modules/transfer/enums")

describe("the per-team tax rate cache", function()
	local opts = { [TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.3 }
	local repo = {
		GetModOptions = function()
			return opts
		end,
		GetTeamRulesParam = function()
			return nil
		end,
	}

	after_each(function()
		for k in pairs(require("modules/transfer/state").taxRateByTeam) do
			require("modules/transfer/state").taxRateByTeam[k] = nil
		end
	end)

	it("resolves a team nobody refreshed live, and does not remember it", function()
		assert.are.equal(0.3, Tax.RateOf(4, repo))
		assert.is_nil(require("modules/transfer/state").taxRateByTeam[4])
	end)

	it("serves the refreshed rate until the next refresh", function()
		Tax.Refresh({ 4 }, repo, opts)
		opts[TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.6
		assert.are.equal(0.3, Tax.RateOf(4, repo), "a dial turned between refreshes is not seen yet")
		Tax.Refresh({ 4 }, repo, opts)
		assert.are.equal(0.6, Tax.RateOf(4, repo))
		opts[TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.3
	end)

	it("is one table across include instances", function()
		Tax.Refresh({ 7 }, repo, opts)
		local other = require("modules/transfer/resource/tax")
		assert.are.equal(0.3, other.RateOf(7, repo))
	end)
end)
