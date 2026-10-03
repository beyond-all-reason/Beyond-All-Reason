local Modules = require("modules/enums").Modules
local ModuleHandler = require("modules/module_handler")
local TransferEnums = require("modules/transfer/enums")

---@param opts table
local function repo(opts)
	return {
		GetModOptions = function()
			return opts
		end,
	}
end

describe("a sender and a receiver", function()
	local Contract = ModuleHandler.Contract(Modules.Transfer)

	it(
		"are blocked by nothing, share by the modoption's mode and are taxed by its rate, unless a module says otherwise",
		function()
			local resolved = ModuleHandler.LoadEnrichers(Contract.TeamPairing)
			local lobby = {
				[TransferEnums.ModOptions.UnitSharingMode] = "resource",
				[TransferEnums.ModOptions.TaxResourceSharingAmount] = 0.2,
			}
			local facts = ModuleHandler.EnrichWith(resolved, {}, { modOptions = lobby }, repo(lobby), 1)
			assert.is_nil(facts[Contract.TeamPairing.TechBlocking])
			assert.are.same({ "resource" }, facts[Contract.TeamPairing.UnitSharingModes])
			assert.are.equal(0.2, facts[Contract.TeamPairing.TaxRate])
			assert.are.same(
				{ "none" },
				ModuleHandler.EnrichWith(resolved, {}, { modOptions = {} }, repo({}), 1)[Contract.TeamPairing.UnitSharingModes]
			)
		end
	)

	it("read no notes on their terms unless a module writes them", function()
		local unit = ModuleHandler.EnrichWith(ModuleHandler.LoadEnrichers(Contract.UnitTermsNotes), {}, {})
		assert.is_nil(unit[Contract.UnitTermsNotes.FutureUnlock])
		assert.is_nil(unit[Contract.UnitTermsNotes.TechData])
		local resource = ModuleHandler.EnrichWith(ModuleHandler.LoadEnrichers(Contract.ResourceTermsNotes), {}, {})
		assert.is_nil(resource[Contract.ResourceTermsNotes.TaxUnlock])
	end)
end)
