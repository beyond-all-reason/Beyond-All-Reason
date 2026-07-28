--- Every unit hand-over arrives here so the policy is asked once. execute
--- re-checks per unit: a unit can stop qualifying between validate and execute.

local Shared = VFS.Include("modules/transfer/unit/shared.lua")

---@class TransferUnitsRequest
---@field from integer giving team
---@field to integer receiving team
---@field unitIDs integer[]
---@field share fun(from: integer, to: integer, unitIDs: integer[]): integer shared count

---@param request TransferUnitsRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.units expects a request table"
	end
	if type(request.from) ~= "number" or type(request.to) ~= "number" then
		return false, "transfer.units needs from and to team ids"
	end
	if request.from == request.to then
		return false, "a team cannot share with itself"
	end
	if type(request.unitIDs) ~= "table" or #request.unitIDs == 0 then
		return false, "transfer.units needs a non-empty unitIDs list"
	end
	if type(request.share) ~= "function" then
		return false, "the unit transfer controller has not initialized"
	end
	local policy = Shared.GetCachedPolicyResult(request.from, request.to, Spring)
	if not (policy and policy.canShare) then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	return true
end)

---@param request TransferUnitsRequest
---@return UnitTransferResult
Actions.RegisterExecute(function(request)
	return request.share(request.from, request.to, request.unitIDs)
end)
