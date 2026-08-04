local ModeDSL = VFS.Include("modules/scavengers/mode_dsl.lua")

--- The mode is a serializer and a lobby instruction, never a new wire key.
--- These are the assertions that keep it that way: the option names it emits
--- are exactly the eight that already exist, and the bot it asks for is
--- carried outside the option set because no option can express it.

local preset = VFS.Include("modules/scavengers/modes/scavengers.lua")

local SCAV_OPTIONS = {
	ranked_game = true,
	scav_difficulty = true,
	scav_boss_count = true,
	scav_bosstimemult = true,
	scav_graceperiodmult = true,
	scav_spawntimemult = true,
	scav_spawncountmult = true,
	scav_scavstart = true,
	scav_endless = true,
}

describe("the Scavengers mode", function()
	it("keys off its own name and lives on the game axis", function()
		assert.are.equal("scavengers", preset.key)
		assert.are.equal("game", preset.category)
		assert.is_true(#preset.desc > 0)
	end)

	it("emits only option keys that already exist", function()
		for key in pairs(preset.modOptions) do
			assert.is_true(SCAV_OPTIONS[key], "mode invented a modoption: " .. key)
		end
	end)

	it("touches every dial the mode is about", function()
		for key in pairs(SCAV_OPTIONS) do
			assert.is_not_nil(preset.modOptions[key], "mode leaves " .. key .. " unset")
		end
	end)

	it("serializes the lobby's own defaults — the mode names a shape, it does not retune", function()
		assert.are.equal("normal", preset.modOptions.scav_difficulty.value)
		assert.are.equal(1, preset.modOptions.scav_boss_count.value)
		assert.are.equal(1.0, preset.modOptions.scav_graceperiodmult.value)
		assert.are.equal(1.0, preset.modOptions.scav_spawntimemult.value)
		assert.are.equal(1.0, preset.modOptions.scav_spawncountmult.value)
		assert.are.equal("initialbox", preset.modOptions.scav_scavstart.value)
		assert.are.equal(false, preset.modOptions.scav_endless.value)
	end)

	it("leaves difficulty and endless open — the two choices a lobby is there to make", function()
		assert.is_false(preset.modOptions.scav_difficulty.locked)
		assert.is_false(preset.modOptions.scav_endless.locked)
	end)

	it("pins the placement, because the mode IS the growing box", function()
		assert.is_true(preset.modOptions.scav_scavstart.locked)
	end)

	it("asks the lobby for the bot, because activation is bot presence and no option says so", function()
		assert.are.same({ "ScavengersAI" }, preset.bots)
	end)

	it("is not a ranked mode, and the pin says so where the badge used to", function()
		assert.is_false(preset.allowRanked)
		assert.are.same({ value = false, locked = true }, preset.modOptions.ranked_game)
	end)

	describe("the grammar", function()
		it("exposes the packs as its nouns", function()
			assert.are.equal("waves", ModeDSL.Scavengers.Horde.domain)
			assert.are.equal("scavengers.horde", ModeDSL.Scavengers.Horde.name)
		end)

		it("refuses a bot name that is not a name", function()
			assert.has_error(function()
				ModeDSL.Mode("X").Bot(42)
			end)
		end)

		it("keeps chaining after a chain verb", function()
			local mode = ModeDSL.Mode("X").Bot("SomeAI").Difficulty(ModeDSL.Scavengers.Horde, "hard")
			assert.are.equal("hard", mode.modOptions.scav_difficulty.value)
			assert.are.same({ "SomeAI" }, mode.bots)
		end)
	end)
end)
