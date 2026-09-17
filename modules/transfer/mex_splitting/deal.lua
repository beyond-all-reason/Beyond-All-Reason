
---@class MexRegionsDealLib the deal on the wire: a game rules param the widgets read the regions and their holders back from
local Deal = {}

Deal.PARAM = "mex_splitting_deal"

---@class MexRegionsDealRecord
---@field regions MexRegion[]
---@field holders table<string, integer> region id -> the team that holds it

---@param regions MexRegion[]
---@param holders table<string, integer>
---@return string
function Deal.Encode(regions, holders)
	return Json.encode({ regions = regions, holders = holders })
end

---@param raw string
---@return MexRegionsDealRecord|nil
function Deal.Decode(raw)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, deal = pcall(Json.decode, raw)
	if not ok or type(deal) ~= "table" or type(deal.regions) ~= "table" or type(deal.holders) ~= "table" then
		return nil
	end
	return deal
end

---@return fun(springRepo: Spring): MexRegionsDealRecord|nil
function Deal.Reader()
	local cachedRaw, cachedDeal ---@type string|nil, MexRegionsDealRecord|nil
	return function(springRepo)
		local raw = springRepo.GetGameRulesParam(Deal.PARAM)
		if raw ~= cachedRaw then
			cachedRaw = raw
			cachedDeal = Deal.Decode(raw)
		end
		return cachedDeal
	end
end

return Deal
