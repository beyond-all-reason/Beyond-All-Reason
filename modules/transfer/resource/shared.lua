local ModuleHandler = require("modules/module_handler")
local Modules = require("modules/enums").Modules
local TransferEnums = require("modules/transfer/enums")

local Shared = {}

---@param springRepo Recoil.Shared
---@param teamId integer
---@return boolean
function Shared.IsNonPlayerTeam(springRepo, teamId)
	if teamId == springRepo.GetGaiaTeamID() then
		return true
	end
	local _name, _active, _spec, isAiTeam = springRepo.GetTeamInfo(teamId, false)
	if isAiTeam and isAiTeam ~= 0 then -- the engine answers a boolean; the library says a number
		return true
	end
	local luaAI = springRepo.GetTeamLuaAI and springRepo.GetTeamLuaAI(teamId)
	return luaAI ~= nil and luaAI ~= ""
end

---@param terms ResourceTransferTerms
---@return integer TransferEnums.ResourceTermsCase: the one case the terms are in, for every reader to branch on
function Shared.CaseOf(terms)
	if terms.senderTeamId == terms.receiverTeamId then
		return TransferEnums.ResourceTermsCase.OnSelf
	end
	if not terms.canShare then
		return TransferEnums.ResourceTermsCase.OnDisabled
	end
	if terms.taxRate <= 0 then
		return TransferEnums.ResourceTermsCase.OnTaxFree
	end
	return TransferEnums.ResourceTermsCase.OnTaxed
end

---@param terms ResourceTransferTerms
---@param desired number
---@return number received, number sent
function Shared.CalculateSenderTaxedAmount(terms, desired)
	if desired <= 0 then
		return 0, 0
	end
	local r = terms.taxRate
	if r >= 1.0 then
		return 0, 0
	end
	local sent = desired / (1 - r)
	return desired, sent
end

-- The policy's terms for a pair and a resource, asked by key on whichever handle asks: formed and evaluated on the
-- frame's first ask, a lookup after. Always a record; a refusal is one that says so.
---@param senderId integer
---@param receiverId integer
---@param resourceType ResourceName
---@param springRepo Recoil.Shared the engine, or a spec's stand-in
---@return ResourceTransferTerms
function Shared.Terms(senderId, receiverId, resourceType, springRepo)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	return ModuleHandler.Ask(Transfer.ResourceTransfer, springRepo, senderId, receiverId, resourceType)
end

-- The frame's terms for a pair and a resource, dropped: the share that just moved them is the one writer.
---@param senderId integer
---@param receiverId integer
---@param resourceType ResourceName
---@param springRepo Recoil.Shared
function Shared.Forget(senderId, receiverId, resourceType, springRepo)
	---@type TransferContract
	local Transfer = ModuleHandler.Contract(Modules.Transfer)
	ModuleHandler.Forget(Transfer.ResourceTransfer, springRepo, senderId, receiverId, resourceType)
end

return Shared
