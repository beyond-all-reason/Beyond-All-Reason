local gadget = gadget ---@type Gadget

function gadget:GetInfo()
	return {
		name = "Mex Income Shared",
		desc = "Says at the start that every team's extraction pools by ally team and splits back evenly",
		author = "BAR",
		layer = 0,
		enabled = true,
	}
end

if not gadgetHandler:IsSyncedCode() then
	return false
end

local TransferEnums = require("modules/transfer/enums")

if Spring.GetModOptions()[TransferEnums.ModOptions.MexSplitting] ~= TransferEnums.MexSplitting.Shared then
	return false
end

function gadget:GamePreload()
	for _, playerID in ipairs(Spring.GetPlayerList() or {}) do
		Spring.SendMessageToPlayer(
			playerID,
			"Mex Splitting: Shared. Every team's mex income pools with its allies' and is split back evenly."
		)
	end
end
