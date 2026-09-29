local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

---@param mode string
local function lobby(mode)
	return { [TransferEnums.ModOptions.MexSplitting] = mode }
end

local teams = {
	[0] = { allyTeam = 0, isDead = false },
	[1] = { allyTeam = 0, isDead = false },
}
local made = { [0] = { metal = 6, energy = 0 }, [1] = { metal = 2, energy = 0 } }

describe("what extraction pays, under shared mex splitting", function()
	local resolved = ModuleHandler.LoadEnrichers(ModuleHandler.Contract(Modules.Economy).Extraction)

	it("is the ally team's mex metal, split evenly", function()
		local ctx = { modOptions = lobby(TransferEnums.MexSplitting.Shared), teams = teams, seconds = 2, income = made }
		local income = ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[ModuleHandler.Contract(
			Modules.Economy
		).Extraction.Income]
		assert.are.same({ [0] = { metal = 4, energy = 0 }, [1] = { metal = 4, energy = 0 } }, income)
	end)

	it("is what the engine paid under any other mex splitting", function()
		local ctx =
			{ modOptions = lobby(TransferEnums.MexSplitting.MapAssigned), teams = teams, seconds = 2, income = made }
		assert.is_true(
			rawequal(
				made,
				ModuleHandler.EnrichWith(resolved, { transfer = true }, ctx)[ModuleHandler.Contract(Modules.Economy).Extraction.Income]
			)
		)
	end)
end)
