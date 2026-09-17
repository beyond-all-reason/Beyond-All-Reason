---@class RegionNames derives display names for regions with none set: the base name from the type's owner, numbered when siblings share it
local Names = {}

---@param regions Region[]
---@param bases string[] base name per region, by index, from the Names pipeline
---@return { name: string, derived: boolean }[] by index
function Names.Of(regions, bases)
	local nameless = {} ---@type table<string, integer>
	for i, region in ipairs(regions) do
		if region.name == nil or region.name == "" then
			local base = tostring(bases[i])
			nameless[base] = (nameless[base] or 0) + 1
		end
	end
	local seen = {} ---@type table<string, integer>
	local out = {} ---@type { name: string, derived: boolean }[]
	for i, region in ipairs(regions) do
		if region.name ~= nil and region.name ~= "" then
			out[i] = { name = region.name, derived = false }
		else
			local base = tostring(bases[i])
			seen[base] = (seen[base] or 0) + 1
			out[i] = { name = nameless[base] > 1 and (base .. "_" .. seen[base]) or base, derived = true }
		end
	end
	return out
end

return Names
