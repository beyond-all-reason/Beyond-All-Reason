local Regions = VFS.Include("modules/regions/api.lua") ---@type RegionsApi
local Enums = VFS.Include("modules/regions/enums.lua")

---@class MexRegionsRecords how a parsed region becomes a MexRegion: named, and given the id the deal is keyed by
local Records = {}

---@param name string
---@param team integer
---@return string
function Records.Id(name, team)
	return name .. "@" .. team
end

---@param regions Region[] mex regions as the layout codec read them
---@return MexRegion[] the same tables, each carrying its name and id
function Records.From(regions)
	local names = Regions.Names(Enums.Types.MexRegion, regions)
	---@cast regions MexRegion[]
	for i, region in ipairs(regions) do
		region.name = names[i].name
		if type(region.team) == "number" then
			region.id = Records.Id(region.name, region.team)
		end
	end
	return regions
end

return Records
