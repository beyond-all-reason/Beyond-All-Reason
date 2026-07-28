
---@class TransferGiveRequest
---@field to integer receiving team
---@field unitIDs integer[]
---@field move fun(unitIDs: integer[], to: integer, fiat: boolean): integer moved count

---@param request TransferGiveRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.give expects a request table"
	end
	if type(request.to) ~= "number" then
		return false, "transfer.give needs a receiving team id"
	end
	if type(request.unitIDs) ~= "table" or #request.unitIDs == 0 then
		return false, "transfer.give needs a non-empty unitIDs list"
	end
	if type(request.move) ~= "function" then
		return false, "the unit transfer controller has not initialized"
	end
	return true
end)

---@param request TransferGiveRequest
---@return integer transferred
Actions.RegisterExecute(function(request)
	-- Spring.TransferUnit fires AllowUnitTransfer, and a policy that does not know
	-- this is fiat would refuse a hand-over from a team nobody is allied with.
	Spring.SetGameRulesParam("isGiveInProgress", 1)
	local moved = request.move(request.unitIDs, request.to, true)
	Spring.SetGameRulesParam("isGiveInProgress", 0)
	return moved
end)
