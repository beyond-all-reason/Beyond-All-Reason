local ModuleHandler = VFS.Include("modules/module_handler.lua")

---@class RegionField
---@field key string
---@field label string
---@field kind "string"|"integer"
---@field required boolean|nil
---@field unique boolean|nil the value must be unique among regions of this type
---@field picks string|nil name of a pick list an editor offers for the value; the type's owner and the editor agree on the name
---@field suggest boolean|nil an editor offers the values already used by siblings

---@class RegionType
---@field key RegionTypeKey
---@field label string
---@field geometries RegionGeometryKey[] the geometry kinds allowed for this type
---@field fields RegionField[]
---@field module string|nil the module that contributed the type; set by the registry

local FRAGMENT = "region_types.lua"

local byKey = {} ---@type table<string, RegionType>
local claimedBy = {} ---@type table<string, string>
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
---@return integer how many modules deep the module's requires go
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

local order = {} ---@type string[]
for key in pairs(byKey) do
	order[#order + 1] = key
end
table.sort(order, function(a, b)
	local ma, mb = byKey[a].module, byKey[b].module
	if depth(ma) ~= depth(mb) then
		return depth(ma) < depth(mb)
	end
	if ma ~= mb then
		return ma < mb
	end
	return a < b
end)

return {
	order = order,
	byKey = byKey,
}
