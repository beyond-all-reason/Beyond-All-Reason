--- Hand units to another team.
---
--- The module's one effectful path for units changing hands: everything that
--- moves a unit between teams — a player dragging a selection onto an ally, a
--- mission handing over a garrison, /take emptying a seat — arrives here, so
--- the mode's policy is asked once and the announcement happens once.
---
--- validate is the precondition, pure: it answers whether this pair of teams
--- may share at all under the active mode. execute is the only code that
--- moves anything; it re-checks per unit, because a unit can stop qualifying
--- between the question and the answer.

local Shared = VFS.Include("modules/transfer/unit/shared.lua")

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
	local policy = Shared.GetCachedPolicyResult(request.from, request.to, Spring)
	if not (policy and policy.canShare) then
		return false, "the active mode does not allow unit transfer between these teams"
	end
	return true
end)

---@param request TransferUnitsRequest
---@return UnitTransferResult
Actions.RegisterExecute(function(request)
	return GG.ShareUnits(request.from, request.to, request.unitIDs)
end)
