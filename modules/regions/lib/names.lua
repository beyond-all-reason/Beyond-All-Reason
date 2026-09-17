---@class RegionNames what a region is called when it carries no name: the base its type's owner gave it, with an ordinal once siblings share it
local Names = {}

---@param kind RegionType
---@return string|nil the field whose value scopes the name's uniqueness, when the type declares one
local function scopeOf(kind)
	for _, field in ipairs(kind.fields) do
		if field.key == "name" and type(field.unique) == "string" then
			return field.unique
		end
	end
	return nil
end

---@param kind RegionType
---@param regions Region[]
---@param bases string[] what each region is called before numbering, by index, from the Names pipeline
---@return { name: string, derived: boolean }[] by index
function Names.Of(kind, regions, bases)
	local scopeKey = scopeOf(kind)
	---@param i integer
	---@param region Region
	---@return string
	local function scope(i, region)
		return tostring(bases[i]) .. "|" .. tostring(scopeKey and region[scopeKey] or "")
	end
	local nameless = {} ---@type table<string, integer>
	for i, region in ipairs(regions) do
		if region.name == nil or region.name == "" then
			local key = scope(i, region)
			nameless[key] = (nameless[key] or 0) + 1
		end
	end
	local seen = {} ---@type table<string, integer>
	local out = {} ---@type { name: string, derived: boolean }[]
	for i, region in ipairs(regions) do
		if region.name ~= nil and region.name ~= "" then
			out[i] = { name = region.name, derived = false }
		else
			local key = scope(i, region)
			seen[key] = (seen[key] or 0) + 1
			local name = tostring(bases[i])
			if nameless[key] > 1 then
				name = name .. "_" .. seen[key]
			end
			out[i] = { name = name, derived = true }
		end
	end
	return out
end

return Names
