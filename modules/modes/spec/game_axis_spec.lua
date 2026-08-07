--- The game axis: one selector for how a match is played. Flavor modules
--- register their preset keys onto it in their own commits; these assertions
--- pin the axis itself — the wire key, the default, and the Standard preset
--- an ordinary game lands on.

local fragment = VFS.Include("modules/modes/modoptions.lua")

---@param key string
---@return table|nil
local function option(key)
	for _, entry in ipairs(fragment) do
		if entry.key == key then
			return entry
		end
	end
	return nil
end

describe("the game axis", function()
	it("ships the game section, weighted to lead", function()
		local section = option("game")
		assert.are.equal("section", section.type)
		assert.are.equal("Game", section.name)
		assert.are.equal(8, section.weight)
	end)

	it("ships the selector, defaulting to standard", function()
		local selector = option("game_mode")
		assert.are.equal("list", selector.type)
		assert.are.equal("standard", selector.def)
		assert.are.equal("game", selector.section)
		assert.are.equal("standard", selector.items[1].key)
	end)

	it("governs the Main options — the base rules belong to how the match is played", function()
		for _, entry in ipairs(VFS.Include("modoptions.lua")) do
			if entry.key == "options_main" and entry.type == "section" then
				assert.are.equal("game", entry.mode_category)
				return
			end
		end
		error("options_main section not found")
	end)

	describe("the Standard preset", function()
		local standard = VFS.Include("modules/modes/modes/standard.lua")

		it("is the default: nothing pinned, no bot", function()
			assert.are.equal("standard", standard.key)
			assert.are.equal("game", standard.category)
			assert.are.same({}, standard.modOptions)
			assert.is_nil(standard.bots)
		end)

		it("stays ranked — this preset IS standard multiplayer", function()
			assert.is_true(standard.allowRanked)
		end)
	end)

	describe("the FFA preset", function()
		local ffa = VFS.Include("modules/modes/modes/ffa.lua")

		it("sets the table manners over the same dials", function()
			assert.are.equal("ffa", ffa.key)
			assert.are.equal("game", ffa.category)
			assert.are.same({
				deathmode = { value = "own_com", locked = false },
				ffa_wreckage = { value = true, locked = true },
			}, ffa.modOptions)
		end)

		it("stays ranked and fields no bot", function()
			assert.is_true(ffa.allowRanked)
			assert.is_nil(ffa.bots)
		end)
	end)

	describe("the Team FFA preset", function()
		local teamFfa = VFS.Include("modules/modes/modes/team_ffa.lua")

		it("shuffles the boxes and keeps the FFA wreckage manners", function()
			assert.are.equal("team_ffa", teamFfa.key)
			assert.are.equal("game", teamFfa.category)
			assert.are.same({
				teamffa_start_boxes_shuffle = { value = true, locked = true },
				ffa_wreckage = { value = true, locked = true },
			}, teamFfa.modOptions)
			assert.is_true(teamFfa.allowRanked)
		end)
	end)

	describe("the Territorial Domination preset", function()
		local td = VFS.Include("modules/modes/modes/territorial_domination.lua")

		it("locks the end rule and leaves the round config to the host", function()
			assert.are.equal("territorial_domination", td.key)
			assert.are.equal("game", td.category)
			assert.are.same({
				deathmode = { value = "territorial_domination", locked = true },
			}, td.modOptions)
			assert.is_true(td.allowRanked)
		end)
	end)
end)
