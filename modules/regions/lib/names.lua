---@class RegionNames
local Names = {}

---@param regions Region[]
---@param proposed string[]
---@return { name: string, derived: boolean }[]
function Names.Of(regions, proposed)
	local nameless = {} ---@type table<string, integer>
	for i, region in ipairs(regions) do
		if region.name == nil or region.name == "" then
			local proposal = tostring(proposed[i])
			nameless[proposal] = (nameless[proposal] or 0) + 1
		end
	end
	local seen = {} ---@type table<string, integer>
	local out = {} ---@type { name: string, derived: boolean }[]
	for i, region in ipairs(regions) do
		if region.name ~= nil and region.name ~= "" then
			out[i] = { name = region.name, derived = false }
		else
			local proposal = tostring(proposed[i])
			seen[proposal] = (seen[proposal] or 0) + 1
			out[i] =
				{ name = nameless[proposal] > 1 and (proposal .. "_" .. seen[proposal]) or proposal, derived = true }
		end
	end
	return out
end

return Names
