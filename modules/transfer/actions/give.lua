---@class TransferGiveRequest
---@field to integer receiving team
---@field unitIDs integer[]

---@param request table unvalidated; validate is what makes it a TransferGiveRequest
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
	return true
end)

---@param request TransferGiveRequest
---@return integer transferred
Actions.RegisterExecute(function(request)
	-- Spring.TransferUnit fires AllowUnitTransfer, and a policy that does not know
	-- this is fiat would refuse a hand-over from a team nobody is allied with.
	Spring.SetGameRulesParam("isGiveInProgress", 1)
	local moved = 0
	for _, unitID in ipairs(request.unitIDs) do
		if Spring.TransferUnit(unitID, request.to, true) then
			moved = moved + 1
		end
	end
	Spring.SetGameRulesParam("isGiveInProgress", 0)
	return moved
end)
