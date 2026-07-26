
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

		it("exposes an ordinary game's dials, open, at their defaults", function()
			assert.are.equal("standard", standard.key)
			assert.are.equal("game", standard.category)
			assert.are.same({ value = "com", locked = false }, standard.modOptions.deathmode)
			assert.are.same({ value = 2000, locked = false }, standard.modOptions.maxunits)
			assert.are.same({ value = "random", locked = false }, standard.modOptions.draft_mode)
			assert.are.same({ value = false, locked = false }, standard.modOptions.unit_restrictions_noair)
		end)

		it("does not show what it does not speak: no TD config, no FFA manners", function()
			assert.is_nil(standard.modOptions.territorial_domination_config)
			assert.is_nil(standard.modOptions.ffa_wreckage)
			assert.is_nil(standard.modOptions.teamffa_start_boxes_shuffle)
		end)

		it("stays ranked and fields no bot", function()
			assert.is_true(standard.allowRanked)
			assert.is_nil(standard.bots)
		end)
	end)

	describe("the FFA preset", function()
		local ffa = VFS.Include("modules/modes/modes/ffa.lua")

		it("is Standard's dials with the FFA manners", function()
			assert.are.equal("ffa", ffa.key)
			assert.are.same({ value = "own_com", locked = false }, ffa.modOptions.deathmode)
			assert.are.same({ value = true, locked = true }, ffa.modOptions.ffa_wreckage)
			assert.are.same({ value = 2000, locked = false }, ffa.modOptions.maxunits)
			assert.is_true(ffa.allowRanked)
		end)
	end)

	describe("the Team FFA preset", function()
		local teamFfa = VFS.Include("modules/modes/modes/team_ffa.lua")

		it("shuffles the boxes, keeps the manners, opens the rest", function()
			assert.are.equal("team_ffa", teamFfa.key)
			assert.are.same({ value = true, locked = true }, teamFfa.modOptions.teamffa_start_boxes_shuffle)
			assert.are.same({ value = true, locked = true }, teamFfa.modOptions.ffa_wreckage)
			assert.are.same({ value = "com", locked = false }, teamFfa.modOptions.deathmode)
			assert.is_true(teamFfa.allowRanked)
		end)
	end)

	describe("the Territorial Domination preset", function()
		local td = VFS.Include("modules/modes/modes/territorial_domination.lua")

		it("locks the end rule, which brings its own dials along", function()
			assert.are.equal("territorial_domination", td.key)
			assert.are.same({ value = "territorial_domination", locked = true }, td.modOptions.deathmode)
			assert.are.same({ value = "25_minutes", locked = false }, td.modOptions.territorial_domination_config)
			assert.are.same(
				{ value = 1.2, locked = false },
				td.modOptions.territorial_domination_elimination_threshold_multiplier
			)
			assert.is_true(td.allowRanked)
		end)

		it("keeps the round dials to itself — Standard never shows them", function()
			local standard = VFS.Include("modules/modes/modes/standard.lua")
			assert.is_nil(standard.modOptions.territorial_domination_config)
		end)
	end)
end)
