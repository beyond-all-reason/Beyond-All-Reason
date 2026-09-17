local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")

---@class MexRegionsRecords how a parsed region becomes a MexRegion: named. Its id comes from the layout codec
local Records = {}

---@param regions Region[] mex regions as the layout codec read them
---@return MexRegion[] the same tables, each carrying its display name
function Records.From(regions)
	local names = Regions.Names(Enums.Types.MexRegion, regions)
	---@cast regions MexRegion[]
	for i, region in ipairs(regions) do
		region.name = names[i].name
	end
	return regions
end

return Records
