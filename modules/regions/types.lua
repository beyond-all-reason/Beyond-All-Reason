local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class RegionField
---@field key string
---@field label string
---@field kind "string"|"integer"
---@field required boolean|nil
---@field unique boolean|string|nil true: unique among regions of this type; a field key: unique among those sharing that field's value
---@field picks "start"|nil what an editor offers as the values: the map's starts, by ordinal
---@field suggest boolean|nil an editor offers the values its siblings already carry

---@class RegionType
---@field key RegionTypeKey
---@field label string
---@field geometries RegionGeometryKey[] the shapes a region of this type may be drawn as
---@field fields RegionField[]
---@field module string|nil the module that contributed it, filled in here

local FRAGMENT = "region_types.lua"

local byKey = {} ---@type table<string, RegionType>
local claimedBy = {} ---@type table<string, string>
local manifests = ModuleHandler.Discover()
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

local order = {} ---@type string[]
for key in pairs(byKey) do
	order[#order + 1] = key
end
table.sort(order)

return {
	order = order,
	byKey = byKey,
}
