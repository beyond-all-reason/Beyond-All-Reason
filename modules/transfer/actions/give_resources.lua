---@class TransferGiveResourcesRequest
---@field from integer giving team
---@field to integer receiving team
---@field resource "metal"|"energy"
---@field amount number

---@param request table unvalidated; validate is what makes it a TransferGiveResourcesRequest
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
	return true
end)

-- Spring.AddTeamResource clamps its amount to >= 0, so the deduction goes through Set.
---@param teamID integer
---@param resource ResourceName
---@param delta number
local function adjust(teamID, resource, delta)
	local current = Spring.GetTeamResources(teamID, resource) or 0
	Spring.SetTeamResource(teamID, resource, current + delta)
end

---@param request TransferGiveResourcesRequest
---@return number moved
Actions.RegisterExecute(function(request)
	adjust(request.from, request.resource, -request.amount)
	adjust(request.to, request.resource, request.amount)
	return request.amount
end)
