local Spring = Spring --[[@as Recoil.Synced]]

local Comms = require("modules/transfer/resource/comms")
local ManualShareLedger = require("modules/transfer/economy/manual_share_ledger")
local Pairing = require("modules/transfer/lib/pairing")
local Shared = require("modules/transfer/resource/shared")

---@class TransferResourceResult
---@field success boolean
---@field sent number
---@field received number
---@field senderTeamId integer
---@field receiverTeamId integer
---@field terms ResourceTransferTerms? absent when the transfer was denied before a policy resolved

local Synced = {}

---@param ctx TransferResourceRequest
---@return TransferResourceResult
function Synced.Transfer(ctx)
	local terms = ctx.terms
	local desiredAmount = ctx.desiredAmount
	if terms and terms.canShare and desiredAmount then
		desiredAmount = math.min(desiredAmount, terms.amountSendable)
	end
	if (not terms or not terms.canShare) or (not desiredAmount or desiredAmount <= 0) then
		---@type TransferResourceResult
		return {
			success = false,
			sent = 0,
			received = 0,
			senderTeamId = ctx.senderTeamId,
			receiverTeamId = ctx.receiverTeamId,
			terms = terms,
		}
	end

	local received, sent = Shared.CalculateSenderTaxedAmount(terms, desiredAmount)

	local springRepo = ctx.springRepo --[[@as Recoil.Synced]] -- the move writes the balances: it runs in the synced handle
	local resourceType = terms.resourceType
	local senderCurrent = springRepo.GetTeamResources(ctx.senderTeamId, resourceType) or 0
	springRepo.SetTeamResource(ctx.senderTeamId, resourceType, math.max(0, senderCurrent - sent))
	springRepo.AddTeamResource(ctx.receiverTeamId, resourceType, received)

	---@type TransferResourceResult
	local result = {
		success = true,
		sent = sent,
		received = received,
		senderTeamId = ctx.senderTeamId,
		receiverTeamId = ctx.receiverTeamId,
		terms = terms,
	}

	return result
end

-- A resource shared under the policy: the pair's terms for that resource, the frame's one evaluation of the policy,
-- say whether, and tax and cap it; the ledger records what moved and both teams are told. A share the terms refuse is
-- a result that says so. The move is the one writer of what those terms read, so it drops the frame's terms after.
---@param resource ResourceName
---@param amount number
---@param toTeamID integer
---@param fromTeamID integer
---@return TransferResourceResult
function Synced.Share(resource, amount, toTeamID, fromTeamID)
	local terms = Shared.Terms(fromTeamID, toTeamID, resource, Spring)
	local ctx = Pairing.Request(Spring, fromTeamID, toTeamID, resource, amount, terms)
	local result = Synced.Transfer(ctx)
	local applied = result.terms
	if result.success and applied then
		Shared.Forget(fromTeamID, toTeamID, resource, Spring)
		ManualShareLedger.Record(fromTeamID, toTeamID, applied.resourceType, result.sent, result.received)
		Comms.SendTransferChatMessages(result, applied)
	end
	return result
end

---@param teamID integer
---@param resource ResourceName
---@param delta number
local function adjust(teamID, resource, delta)
	local current = Spring.GetTeamResources(teamID, resource) or 0
	Spring.SetTeamResource(teamID, resource, current + delta)
end

-- A resource handed over by fiat: the whole amount, both sides, untaxed, no policy asked.
---@param resource ResourceName
---@param amount number
---@param toTeamID integer
---@param fromTeamID integer
---@return number moved
function Synced.Give(resource, amount, toTeamID, fromTeamID)
	adjust(fromTeamID, resource, -amount)
	adjust(toTeamID, resource, amount)
	return amount
end

return Synced
