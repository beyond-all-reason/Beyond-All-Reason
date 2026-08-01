--- The scav_* options are WIRE VALUES: a lobby, a SPADS config and every
--- saved game setup address the scavengers by these names. Moving them out of
--- the root modoptions.lua and into the module is allowed to change where
--- they live and nothing else.

local fragment = VFS.Include("modules/scavengers/modoptions.lua")

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

describe("scavengers modoptions", function()
	it("ships its own section, at the weight it always had", function()
		local section = option("scav_defense_options")
		assert.are.equal("section", section.type)
		assert.are.equal("Scavengers", section.name)
		assert.are.equal(3, section.weight)
	end)

	it("keeps every option key, type and default", function()
		local expected = {
			{ key = "scav_difficulty", type = "list", def = "normal" },
			{ key = "scav_scavstart", type = "list", def = "initialbox" },
			{ key = "scav_endless", type = "bool", def = false },
			{ key = "scav_bosstimemult", type = "number", def = 1, min = 0.1, max = 2, step = 0.1 },
			{ key = "scav_boss_count", type = "number", def = 1, min = 1, max = 20, step = 1 },
			{ key = "scav_spawncountmult", type = "number", def = 1, min = 1, max = 5, step = 1 },
			{ key = "scav_spawntimemult", type = "number", def = 1, min = 1, max = 5, step = 0.1 },
			{ key = "scav_graceperiodmult", type = "number", def = 1, min = 0.1, max = 3, step = 0.1 },
		}
		for _, want in ipairs(expected) do
			local entry = option(want.key)
			assert.is_not_nil(entry, "missing option " .. want.key)
			for field, value in pairs(want) do
				assert.are.equal(value, entry[field], want.key .. "." .. field)
			end
			assert.are.equal("scav_defense_options", entry.section, want.key .. ".section")
		end
	end)

	it("keeps the difficulty list's own keys, which are what the roster indexes by", function()
		local keys = {}
		for _, item in ipairs(option("scav_difficulty").items) do
			keys[#keys + 1] = item.key
		end
		assert.are.same({ "veryeasy", "easy", "normal", "hard", "veryhard", "epic" }, keys)
	end)

	it("keeps the placement list's keys, which the director reads directly", function()
		local keys = {}
		for _, item in ipairs(option("scav_scavstart").items) do
			keys[#keys + 1] = item.key
		end
		assert.are.same({ "avoid", "initialbox" }, keys)
	end)

	it("adds nothing new — the mode is a serializer, not a wire key", function()
		for _, entry in ipairs(fragment) do
			if entry.key ~= "sub_header" and entry.key ~= "scavengers_dev_channel_link" then
				assert.is_true(entry.key:find("^scav_") ~= nil, "unexpected option key: " .. tostring(entry.key))
			end
		end
	end)
end)
