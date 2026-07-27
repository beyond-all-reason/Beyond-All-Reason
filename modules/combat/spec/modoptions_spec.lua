local ModuleHandler = VFS.Include("modules/module_handler.lua")

---Deterministic, byte-stable serialization: array part in order, then hash
---keys sorted; every leaf type-tagged.
---@param value any
---@return string
local function serialize(value)
	if type(value) ~= "table" then
		return type(value) .. ":" .. tostring(value)
	end
	local parts = {}
	local arrayLength = #value
	for _, item in ipairs(value) do
		parts[#parts + 1] = serialize(item)
	end
	local keys = {}
	for key in pairs(value) do
		if not (type(key) == "number" and key >= 1 and key <= arrayLength and key % 1 == 0) then
			keys[#keys + 1] = key
		end
	end
	table.sort(keys, function(a, b)
		return tostring(a) < tostring(b)
	end)
	for _, key in ipairs(keys) do
		parts[#parts + 1] = tostring(key) .. "=" .. serialize(value[key])
	end
	return "{" .. table.concat(parts, ",") .. "}"
end

describe("combat modoption neutrality", function()
	local options
	local baseline

	setup(function()
		ModuleHandler.ResetCaches()
		options = VFS.Include("modoptions.lua")
		baseline = serialize(options)
	end)

	it("the serializer is deterministic", function()
		assert.are.equal(baseline, serialize(options))
	end)

	it("the combat module is discovered", function()
		assert.is_table(ModuleHandler.Discover().combat)
	end)

	it("combat ships no modoptions fragment", function()
		assert.is_false(VFS.FileExists("modules/combat/modoptions.lua"))
	end)

	it("module-contributed options are the list's tail, exactly once", function()
		local contributed = ModuleHandler.ModOptions()
		assert.is_true(#contributed > 0)
		local rebuilt = {}
		for index = 1, #options - #contributed do
			rebuilt[index] = options[index]
		end
		for _, option in ipairs(contributed) do
			rebuilt[#rebuilt + 1] = option
		end
		assert.are.equal(baseline, serialize(rebuilt))
	end)
end)
