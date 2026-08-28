local ModeBuilder = VFS.Include("modules/mode_builder.lua")
local Pve = VFS.Include("modules/waves/mode_dsl.lua")

--- A pretend flavor: the grammar is generic, the keys are not. These are the
--- scav keys because they are the ones with a wire contract to keep, but the
--- same verbs bound to raptor_* would produce raptor options.
local KEYS = {
	difficulty = "flavor_difficulty",
	bossCount = "flavor_boss_count",
	bossTime = "flavor_bosstimemult",
	grace = "flavor_graceperiodmult",
	waveTime = "flavor_spawntimemult",
	waveCount = "flavor_spawncountmult",
	placement = "flavor_start",
	endless = "flavor_endless",
}

local Pack = { Horde = { domain = "waves" } }

local function grammar(keys)
	return ModeBuilder.Grammar({
		category = "flavor_options",
		serializers = Pve.SerializersFor(keys or KEYS),
		verbs = Pve.Verbs,
	})
end

describe("waves mode grammar", function()
	it("serializes each dial to the flavor's own wire key", function()
		local Mode = grammar()
		local mode = Mode("Flavor")
			.Difficulty(Pack.Horde, "normal")
			.Boss(Pack.Horde, 2, 1.5)
			.Grace(Pack.Horde, 1.0)
			.Pace(Pack.Horde, 1.0, 2.0)
			.Placement(Pack.Horde, "initialbox")
			.Endless(Pack.Horde, false)

		assert.are.equal("normal", mode.modOptions.flavor_difficulty.value)
		assert.are.equal(2, mode.modOptions.flavor_boss_count.value)
		assert.are.equal(1.5, mode.modOptions.flavor_bosstimemult.value)
		assert.are.equal(1.0, mode.modOptions.flavor_graceperiodmult.value)
		assert.are.equal(1.0, mode.modOptions.flavor_spawntimemult.value)
		assert.are.equal(2.0, mode.modOptions.flavor_spawncountmult.value)
		assert.are.equal("initialbox", mode.modOptions.flavor_start.value)
		assert.are.equal(false, mode.modOptions.flavor_endless.value)
	end)

	it("a bare policy is a suggestion: nothing locked", function()
		local Mode = grammar()
		local mode = Mode("Flavor").Difficulty(Pack.Horde, "normal").Pace(Pack.Horde, 1.0, 1.0)
		assert.is_false(mode.modOptions.flavor_difficulty.locked)
		assert.is_false(mode.modOptions.flavor_spawntimemult.locked)
	end)

	it("Locked pins a structural choice; Sealed pins a dial", function()
		local Mode = grammar()
		local mode = Mode("Flavor").Difficulty(Pack.Horde, "normal").Locked().Pace(Pack.Horde, 1, 1).Sealed()
		assert.is_true(mode.modOptions.flavor_difficulty.locked)
		assert.is_true(mode.modOptions.flavor_spawntimemult.locked)
		assert.is_false(
			Mode("Flavor").Pace(Pack.Horde, 1, 1).Locked().modOptions.flavor_spawntimemult.locked,
			"Locked leaves a dial open"
		)
	end)

	it("defaults the boss countdown to the host's own pace", function()
		local Mode = grammar()
		local mode = Mode("Flavor").Boss(Pack.Horde, 1)
		assert.are.equal(1, mode.modOptions.flavor_bosstimemult.value)
	end)

	it("serializes nothing for a dial the flavor does not have a key for", function()
		local Mode = grammar({ difficulty = "flavor_difficulty" })
		local mode = Mode("Flavor").Difficulty(Pack.Horde, "normal").Endless(Pack.Horde, true)
		assert.are.equal("normal", mode.modOptions.flavor_difficulty.value)
		assert.are.equal(
			1,
			(function()
				local n = 0
				for _ in pairs(mode.modOptions) do
					n = n + 1
				end
				return n
			end)()
		)
	end)

	it("refuses a verb applied to something that is not a wave pack", function()
		local Mode = grammar()
		assert.has_error(function()
			Mode("Flavor").Difficulty({ domain = "resource" }, "normal")
		end)
		assert.has_error(function()
			Mode("Flavor").Endless("Horde", true)
		end)
	end)

	it("keys the preset off its own name and carries the flavor's category", function()
		local Mode = grammar()
		local mode = Mode("Big Waves").Desc("lots of them")
		assert.are.equal("big_waves", mode.key)
		assert.are.equal("flavor_options", mode.category)
		assert.are.equal("lots of them", mode.desc)
	end)
end)
