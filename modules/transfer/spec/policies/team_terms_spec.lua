local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

describe("one team's terms", function()
	it("tax it by the modoption, clamped to 0..1, unless a module says otherwise", function()
		local Contract = ModuleHandler.Contract(Modules.Transfer)
		local resolved = ModuleHandler.LoadEnrichers(Contract.TeamTerms)
		local function tax(raw)
			return ModuleHandler.EnrichWith(
				resolved,
				{},
				{ modOptions = { [TransferEnums.ModOptions.TaxResourceSharingAmount] = raw } }
			)[Contract.TeamTerms.TaxRate]
		end
		assert.are.equal(0.3, tax("0.3"))
		assert.are.equal(0, tax(-1))
		assert.are.equal(1, tax(7))
		assert.are.equal(0, tax(nil))
	end)
end)
