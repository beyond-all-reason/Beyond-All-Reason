local Income = require("modules/transfer/mex_splitting/income")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

---@type EconomyContract
local Economy = Policies.Contract(Modules.Economy)

-- Shared: what every team's mexes made this tick is the ally team's to split evenly
--
Policies.On(Economy.Extraction).Provide(Economy.Extraction.Income, function(ctx)
	if ctx.modOptions[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.Shared then
		return nil
	end
	return Income.Shared(ctx.teams, ctx.income)
end)
