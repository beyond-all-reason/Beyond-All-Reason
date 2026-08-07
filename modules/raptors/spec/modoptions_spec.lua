--- The raptor_* options are WIRE VALUES: a lobby, a SPADS config and every
--- saved game setup address the raptors by these names. Moving them out of
--- the root modoptions.lua and into the module is allowed to change where
--- they live and nothing else — plus the governance pair handing the section
--- to the game axis, which is where the Raptors choice lives.

local fragment = VFS.Include("modules/raptors/modoptions.lua")

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

describe("raptors modoptions", function()
	it("ships its own section, at the weight it always had, governed by the game axis", function()
		local section = option("raptor_defense_options")
		assert.are.equal("section", section.type)
		assert.are.equal("Raptors", section.name)
		assert.are.equal(4, section.weight)
		assert.are.equal("game", section.mode_category)
	end)

	it("registers its preset on the game axis selector", function()
		local found = false
		for _, entry in ipairs(VFS.Include("modules/modes/modoptions.lua")) do
			if entry.key == "game_mode" then
				for _, item in ipairs(entry.items) do
					if item.key == "raptors" then
						found = true
					end
				end
			end
		end
		assert.is_true(found, "game_mode must list raptors or SPADS refuses the value")
	end)

	it("keeps every option key, type and default", function()
		local expected = {
			{ key = "raptor_difficulty", type = "list", def = "normal" },
			{ key = "raptor_raptorstart", type = "list", def = "initialbox" },
			{ key = "raptor_endless", type = "bool", def = false },
			{ key = "raptor_queentimemult", type = "number", def = 1, min = 0.1, max = 2, step = 0.1 },
			{ key = "raptor_queen_count", type = "number", def = 1, min = 1, max = 100, step = 1 },
			{ key = "raptor_spawncountmult", type = "number", def = 1, min = 1, max = 5, step = 1 },
			{ key = "raptor_firstwavesboost", type = "number", def = 1, min = 1, max = 10, step = 1 },
			{ key = "raptor_spawntimemult", type = "number", def = 1, min = 1, max = 5, step = 0.1 },
			{ key = "raptor_graceperiodmult", type = "number", def = 1, min = 0.1, max = 3, step = 0.1 },
		}
		for _, want in ipairs(expected) do
			local entry = option(want.key)
			assert.is_not_nil(entry, "missing option " .. want.key)
			for field, value in pairs(want) do
				assert.are.equal(value, entry[field], want.key .. "." .. field)
			end
			assert.are.equal("raptor_defense_options", entry.section, want.key .. ".section")
		end
	end)

	it("keeps the difficulty list's own keys, which the spawner indexes by", function()
		local keys = {}
		for _, item in ipairs(option("raptor_difficulty").items) do
			keys[#keys + 1] = item.key
		end
		assert.are.same({ "veryeasy", "easy", "normal", "hard", "veryhard", "epic" }, keys)
	end)

	it("keeps the placement list's keys, all three of them", function()
		local keys = {}
		for _, item in ipairs(option("raptor_raptorstart").items) do
			keys[#keys + 1] = item.key
		end
		assert.are.same({ "avoid", "initialbox", "alwaysbox" }, keys)
	end)

	it("no longer leaves raptor options in the root file", function()
		-- the merged list (root + module fragments) must carry the module's
		-- copy exactly once; a leftover root copy would double it
		local count = 0
		for _, entry in ipairs(VFS.Include("modoptions.lua")) do
			if entry.key == "raptor_difficulty" then
				count = count + 1
			end
		end
		assert.are.equal(1, count)
	end)

	it("adds nothing new — the mode is a serializer, not a wire key", function()
		for _, entry in ipairs(fragment) do
			if
				entry.key ~= "sub_header"
				and entry.key ~= "raptors_dev_channel_link"
				and entry.key ~= "raptor_defense_options"
			then
				assert.is_true(entry.key:find("^raptor_") ~= nil, "unexpected option key: " .. tostring(entry.key))
			end
		end
	end)
end)
