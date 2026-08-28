
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
	it("ships its own section, at the weight it always had, governed by the game axis", function()
		local section = option("scav_defense_options")
		assert.are.equal("section", section.type)
		assert.are.equal("Scavengers", section.name)
		assert.are.equal(3, section.weight)
		assert.are.equal("game", section.mode_category)
	end)

	it("registers its preset on the game axis selector", function()
		local found = false
		for _, entry in ipairs(VFS.Include("modules/modes/modoptions.lua")) do
			if entry.key == "game_mode" then
				for _, item in ipairs(entry.items) do
					if item.key == "scavengers" then
						found = true
					end
				end
			end
		end
		assert.is_true(found, "game_mode must list scavengers or SPADS refuses the value")
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
			if
				entry.key ~= "sub_header"
				and entry.key ~= "scavengers_dev_channel_link"
				and entry.key ~= "scav_defense_options"
			then
				assert.is_true(entry.key:find("^scav_") ~= nil, "unexpected option key: " .. tostring(entry.key))
			end
		end
	end)
end)
