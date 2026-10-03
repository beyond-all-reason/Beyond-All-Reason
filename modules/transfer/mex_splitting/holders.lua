local Deal = require("modules/transfer/mex_splitting/deal")
local Regions = require("modules/regions/api")

---@class MexRegionsHolders
local Holders = {}

local read = Deal.Reader(Game.mapSizeX, Game.mapSizeZ)

---@param springRepo Spring
---@param x number
---@param z number
---@return integer[]
function Holders.At(springRepo, x, z)
	local out = {} ---@type integer[]
	local deal = read(springRepo)
	if not deal then
		return out
	end
	for _, region in ipairs(deal.regions) do
		local holder = deal.holders[region.id]
		if holder ~= nil and not table.contains(out, holder) and Regions.Contains(x, z, region.vertices) then
			out[#out + 1] = holder
		end
	end
	return out
end

return Holders
