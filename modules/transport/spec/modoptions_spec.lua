local fragment = VFS.Include("modules/transport/modoptions.lua")

---@param key string
---@return table|nil
local function option(key)
	for _, entry in ipairs(fragment) do
		if entry.key == key and entry.type ~= "subheader" and entry.type ~= "separator" then
			return entry
		end
	end
	return nil
end

describe("transport modoptions", function()
	it("ships its own section, governed by the game axis", function()
		local section = option("transport")
		assert.are.equal("section", section.type)
		assert.are.equal("Transport", section.name)
		assert.are.equal("game", section.mode_category)
	end)

	it("keeps every moved option's key, type and default", function()
		local expected = {
			{ key = "transportenemy", type = "list", def = "notcoms" },
			{ key = "comm_trans_slow", type = "bool", def = false },
		}
		for _, want in ipairs(expected) do
			local entry = option(want.key)
			assert.is_not_nil(entry, want.key)
			assert.are.equal(want.type, entry.type, want.key)
			assert.are.equal(want.def, entry.def, want.key)
			assert.are.equal("transport", entry.section, want.key)
		end
	end)
end)
