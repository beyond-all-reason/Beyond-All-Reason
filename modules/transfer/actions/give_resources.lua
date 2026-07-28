--- Move a team's resources with no policy question asked.
---
--- The receiving side of a seat takeover: /take does not ask the sharing
--- mode whether it may, and must not pay its tax — the assets are not being
--- shared, they are changing hands with the seat. Take's own policy decides
--- whether the takeover happens at all; by the time this runs, it has.

--- A fiat resource grant: no tax, no policy, the game moving the economy.
---@class TransferGiveResourcesRequest
---@field from integer giving team
---@field to integer receiving team
---@field resource "metal"|"energy"
---@field amount number
---@field add fun(teamID: integer, resource: string, amount: number)
---@field take fun(teamID: integer, resource: string, amount: number)

---@param request TransferGiveResourcesRequest
---@return boolean allowed, string? reason
Actions.RegisterValidate(function(request)
	if type(request) ~= "table" then
		return false, "transfer.give_resources expects a request table"
	end
	if type(request.from) ~= "number" or type(request.to) ~= "number" then
		return false, "transfer.give_resources needs from and to team ids"
	end
	if request.from == request.to then
		return false, "a team cannot hand resources to itself"
	end
	if request.resource ~= "metal" and request.resource ~= "energy" then
		return false, 'transfer.give_resources needs resource = "metal" or "energy"'
	end
	if type(request.amount) ~= "number" or request.amount <= 0 then
		return false, "transfer.give_resources needs a positive amount"
	end
	if type(request.add) ~= "function" or type(request.take) ~= "function" then
		return false, "the resource transfer controller has not initialized"
	end
	return true
end)

---@param request TransferGiveResourcesRequest
---@return number moved
Actions.RegisterExecute(function(request)
	-- Whole amount, untaxed, both sides adjusted: no pipeline, because there
	-- is no policy to apply.
	request.take(request.from, request.resource, -request.amount)
	request.add(request.to, request.resource, request.amount)
	return request.amount
end)
