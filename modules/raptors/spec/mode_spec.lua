local ModeDSL = VFS.Include("modules/raptors/mode_dsl.lua")

--- The mode is a serializer and a lobby instruction, never a new wire key.
--- The queen is the flavor's boss; everything else reads exactly like the
--- scavengers preset, which is the point of the shared PvE grammar.

local preset = VFS.Include("modules/raptors/modes/raptors.lua")

local RAPTOR_OPTIONS = {
	raptor_difficulty = true,
	raptor_queen_count = true,
	raptor_queentimemult = true,
	raptor_graceperiodmult = true,
	raptor_spawntimemult = true,
	raptor_spawncountmult = true,
	raptor_raptorstart = true,
	raptor_endless = true,
}

describe("the Raptors mode", function()
	it("keys off its own name and lives on the game axis", function()
		assert.are.equal("raptors", preset.key)
		assert.are.equal("game", preset.category)
		assert.is_true(#preset.desc > 0)
	end)

	it("emits only option keys that already exist", function()
		for key in pairs(preset.modOptions) do
			assert.is_true(RAPTOR_OPTIONS[key], "mode invented a modoption: " .. key)
		end
	end)

	it("touches every dial the mode is about — the boost dial stays unclaimed and open", function()
		for key in pairs(RAPTOR_OPTIONS) do
			assert.is_not_nil(preset.modOptions[key], "mode leaves " .. key .. " unset")
		end
		assert.is_nil(preset.modOptions.raptor_firstwavesboost)
	end)

	it("serializes the lobby's own defaults — the mode names a shape, it does not retune", function()
		assert.are.equal("normal", preset.modOptions.raptor_difficulty.value)
		assert.are.equal(1, preset.modOptions.raptor_queen_count.value)
		assert.are.equal(1.0, preset.modOptions.raptor_graceperiodmult.value)
		assert.are.equal(1.0, preset.modOptions.raptor_spawntimemult.value)
		assert.are.equal(1.0, preset.modOptions.raptor_spawncountmult.value)
		assert.are.equal("initialbox", preset.modOptions.raptor_raptorstart.value)
		assert.are.equal(false, preset.modOptions.raptor_endless.value)
	end)

	it("leaves difficulty and endless open — the two choices a lobby is there to make", function()
		assert.is_false(preset.modOptions.raptor_difficulty.locked)
		assert.is_false(preset.modOptions.raptor_endless.locked)
	end)

	it("pins the placement, because the mode IS the growing box", function()
		assert.is_true(preset.modOptions.raptor_raptorstart.locked)
	end)

	it("asks the lobby for the bot, because activation is bot presence and no option says so", function()
		assert.are.same({ "RaptorsAI" }, preset.bots)
	end)

	it("is not a ranked mode", function()
		assert.is_false(preset.allowRanked)
	end)

	describe("the grammar", function()
		it("exposes the swarm as its noun, addressed ahead of its pack", function()
			assert.are.equal("waves", ModeDSL.Raptors.Swarm.domain)
			assert.are.equal("raptors.swarm", ModeDSL.Raptors.Swarm.name)
		end)

		it("keeps chaining after a chain verb", function()
			local mode = ModeDSL.Mode("X").Bot("SomeAI").Difficulty(ModeDSL.Raptors.Swarm, "hard")
			assert.are.equal("hard", mode.modOptions.raptor_difficulty.value)
			assert.are.same({ "SomeAI" }, mode.bots)
		end)
	end)
end)
