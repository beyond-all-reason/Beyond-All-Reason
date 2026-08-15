--- Hand units over with no policy question asked.
---
--- The giver is the game itself, not a team choosing to share: a mission
--- handing a garrison to the player, a seat being taken over. A mode has no
--- say, which is why this is a separate action rather than a flag on units —
--- bypassing policy should be something you can see in the call.

--- The give, with its movement injected: fiat transfer, no policy asked.
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
	-- Announce the fiat for the duration of the move. Spring.TransferUnit
	-- fires AllowUnitTransfer, which asks the sharing policy — and a policy
	-- that has no idea this is fiat will refuse a hand-over from a team
	-- nobody is allied with. Same shape as isTakeInProgress.
	Spring.SetGameRulesParam("isGiveInProgress", 1)
	local moved = request.move(request.unitIDs, request.to, true)
	Spring.SetGameRulesParam("isGiveInProgress", 0)
	return moved
end)
