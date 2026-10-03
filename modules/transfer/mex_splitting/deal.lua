
local Regions = require("modules/regions/api")

---@class MexRegionsDealLib
local Deal = {}

Deal.PARAM = "mex_splitting_deal"

---@class MexRegionsDealRecord
---@field regions MexRegion[]
---@field holders table<string, integer>

---@param regions MexRegion[]
---@param holders table<string, integer>
---@param mapSizeX number
---@param mapSizeZ number
---@return string
function Deal.Encode(regions, holders, mapSizeX, mapSizeZ)
	return Json.encode({ layout = Regions.ExportLayout(regions, mapSizeX, mapSizeZ), holders = holders }) --[[@as string]]
end

---@param raw string
---@param mapSizeX number
---@param mapSizeZ number
---@return MexRegionsDealRecord|nil
function Deal.Decode(raw, mapSizeX, mapSizeZ)
	if type(raw) ~= "string" or raw == "" then
		return nil
	end
	local ok, deal = pcall(Json.decode, raw)
	if not ok or type(deal) ~= "table" or type(deal.layout) ~= "table" or type(deal.holders) ~= "table" then
		return nil
	end
	local regions = Regions.ParseLayout(deal.layout, Regions.Enums.Types.MexRegion, mapSizeX, mapSizeZ)
	if not regions then
		return nil
	end
	return {
		regions = regions --[[@as MexRegion[] ]],
		holders = deal.holders,
	}
end

---@param mapSizeX number
---@param mapSizeZ number
---@return fun(springRepo: Spring): MexRegionsDealRecord|nil
function Deal.Reader(mapSizeX, mapSizeZ)
	local cachedRaw, cachedDeal ---@type string|nil,
	return function(springRepo)
		local raw = springRepo.GetGameRulesParam(Deal.PARAM)
		if raw ~= cachedRaw then
			cachedRaw = raw
			cachedDeal = Deal.Decode(raw, mapSizeX, mapSizeZ)
		end
		return cachedDeal
	end
end

return Deal
