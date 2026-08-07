--- Send resources to another team.
---
--- The module's one effectful path for metal and energy changing hands. The
--- tax a mode levies, the share level that triggers an automatic send and the
--- ledger that records it all hang off this one execute.
---
--- validate is the precondition, pure. execute prices and sends.

---@param request TransferResourcesRequest
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
	if type(request.send) ~= "function" then
		return false, "the resource transfer controller has not initialized"
	end
	return true
end)

---@param request TransferResourcesRequest
---@return ResourceTransferResult
Actions.RegisterExecute(function(request)
	return request.send(request.from, request.to, request.resource, request.amount)
end)
