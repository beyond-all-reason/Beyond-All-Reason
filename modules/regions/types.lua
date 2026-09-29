local ModuleHandler = require("modules/module_handler")

---@class Region
---@field id string
---@field type RegionTypeKey
---@field vertices { x: number, z: number }[]
---@field kind "point"|"polygon"|"box"|"spline"|nil
---@field controls { x: number, z: number, strength: number|nil }[]|nil
---@field name string|nil

---@class RegionField
---@field key string
---@field label string
---@field kind "string"|"integer"|"points"
---@field required boolean|nil
---@field unique boolean|nil
---@field picks string|nil
---@field suggest boolean|nil

---@class RegionType
---@field key RegionTypeKey
---@field label string
---@field geometries RegionGeometryKey[]
---@field fields RegionField[]
---@field module string|nil

local FRAGMENT = "region_types.lua"

local byKey = {} ---@type table<string, RegionType>
local claimedBy = {} ---@type table<string, string|nil>
local manifests = ModuleHandler.Manifests()
local names = {}
for name in pairs(manifests) do
	names[#names + 1] = name
end
table.sort(names)
for _, name in ipairs(names) do
	local path = manifests[name].dir .. FRAGMENT
	if VFS.FileExists(path) then
		local fragment = VFS.Include(path)
		if type(fragment) ~= "table" then
			error(path .. ": region_types.lua must return { <key> = RegionType, ... }")
		end
		for key, kind in pairs(fragment) do
			if claimedBy[key] then
				error(path .. ": region type " .. key .. " is already contributed by " .. claimedBy[key])
			end
			if
				type(kind) ~= "table"
				or kind.key ~= key
				or type(kind.label) ~= "string"
				or type(kind.geometries) ~= "table"
			then
				error(path .. ": region type " .. tostring(key) .. " needs key, label and geometries")
			end
			kind.fields = kind.fields or {}
			kind.module = name
			claimedBy[key] = name
			byKey[key] = kind
		end
	end
end

-- The list order: the more basal the owning module, the earlier its types; start before what is built on it.
local depths = {} ---@type table<string, integer>
---@param name string
---@return integer
local function depth(name)
	if depths[name] == nil then
		depths[name] = 0
		local deepest = 0
		for _, required in ipairs(manifests[name] and manifests[name].requires or {}) do
			deepest = math.max(deepest, depth(required) + 1)
		end
		depths[name] = deepest
	end
	return depths[name]
end

local order = {} ---@type RegionTypeKey[]
for _, kind in pairs(byKey) do
	order[#order + 1] = kind.key
end
table.sort(order, function(a, b)
	local ma, mb = byKey[a].module or "", byKey[b].module or ""
	if depth(ma) ~= depth(mb) then
		return depth(ma) < depth(mb)
	end
	if ma ~= mb then
		return ma < mb
	end
	return a < b
end)

---@param key RegionTypeKey
---@return string the key as a name: two_words is TwoWords
local function nameOf(key)
	return (key:gsub("(%a)([%w]*)_?", function(first, rest)
		return first:upper() .. rest
	end))
end

local keys = {} ---@type table<string, RegionTypeKey>
for _, key in ipairs(order) do
	keys[nameOf(key)] = key
end

return {
	order = order,
	byKey = byKey,
	keys = keys --[[@as RegionTypeFields]],
}
