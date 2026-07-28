local ContextFactory = VFS.Include("modules/transfer/context_factory.lua")
local ResourceTransfer = VFS.Include("modules/transfer/resource/synced.lua")
local Comms = VFS.Include("modules/transfer/resource/comms.lua")
local ManualShareLedger = VFS.Include("modules/transfer/economy/manual_share_ledger.lua")

---@class TransferResourcesRequest
---@field from integer giving team
---@field to integer receiving team
---@field resource "metal"|"energy"
---@field amount number
---@field grant ResourcePolicyResult the pair's policy result for this resource, as the api resolved it

---@param request table unvalidated; validate is what makes it a TransferResourcesRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.resources expects a request table"
	end
	if type(request.from) ~= "number" or type(request.to) ~= "number" then
		return false, "transfer.resources needs from and to team ids"
	end
	if request.from == request.to then
		return false, "a team cannot send resources to itself"
	end
	if request.resource ~= "metal" and request.resource ~= "energy" then
		return false, 'transfer.resources needs resource = "metal" or "energy"'
	end
	if type(request.amount) ~= "number" or request.amount <= 0 then
		return false, "transfer.resources needs a positive amount"
	end
	if type(request.grant) ~= "table" then
		return false, "transfer.resources needs the grant the api resolves"
	end
	return true
end)

---@param request TransferResourcesRequest
---@return ResourceTransferResult
Actions.RegisterExecute(function(request)
	local from, to, resource, amount = request.from, request.to, request.resource, request.amount
	local springRepo = Spring
	local policyResult = request.grant
	-- A factory per call: it memoises team resources, and a transfer reads the currents as they are now.
	local ctx = ContextFactory.create(springRepo).resourceTransfer(from, to, resource, amount, policyResult)
	local result = ResourceTransfer.ResourceTransfer(ctx)

	local applied = result.policyResult
	if result.success and applied then
		ManualShareLedger.Record(from, to, applied.resourceType, result.sent, result.received)
		Comms.SendTransferChatMessages(result, applied)
	end

	return result
end)
