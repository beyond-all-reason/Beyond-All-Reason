local Roster = VFS.Include("modules/missions/lib/roster.lua")
local Verbs = VFS.Include("modules/missions/lib/verbs.lua")

describe("mission roster DSL", function()
	local Spawn
	local Finalize

	before_each(function()
		local file = Roster.ForFile("cm8/units.lua")
		Spawn = file.Spawn
		Finalize = file.Finalize
	end)

	it("builds entries from Spawn chains at Finalize", function()
		Spawn(Verbs.UnitDef("corlab"), "gaia").At(0.42, 0.42).Named("hub").Grouped("outpost_auto")
		Spawn(Verbs.UnitDef("armcom"), "enemy").At(0.77, 0.77)
		local entries = Finalize()
		assert.are.same({
			{ def = "corlab", team = "gaia", fx = 0.42, fz = 0.42, name = "hub", group = "outpost_auto" },
			{ def = "armcom", team = "enemy", fx = 0.77, fz = 0.77 },
		}, entries)
	end)

	it("a spawn without an At fails the load, naming the statement", function()
		Spawn(Verbs.UnitDef("corlab"), "gaia").Named("hub")
		local ok, err = pcall(Finalize)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("Spawn 1", 1, true))
	end)

	it("rejects duplicate unit names at Finalize", function()
		Spawn(Verbs.UnitDef("corlab"), "gaia").At(0.1, 0.1).Named("hub")
		Spawn(Verbs.UnitDef("corllt"), "gaia").At(0.2, 0.2).Named("hub")
		assert.has_error(function()
			Finalize()
		end)
	end)

	it("rejects a plain string where a UnitDef reference belongs", function()
		assert.has_error(function()
			Spawn("corlab", "gaia")
		end)
	end)

	it("rejects an unknown team role", function()
		assert.has_error(function()
			Spawn(Verbs.UnitDef("corlab"), "raptors")
		end)
	end)

	it("rejects positions outside map fractions", function()
		assert.has_error(function()
			Spawn(Verbs.UnitDef("corlab"), "gaia").At(512, 512)
		end)
	end)

	it("rejects chain calls after Finalize", function()
		local chain = Spawn(Verbs.UnitDef("corlab"), "gaia").At(0.1, 0.1)
		Finalize()
		assert.has_error(function()
			chain.Named("late")
		end)
		assert.has_error(function()
			Spawn(Verbs.UnitDef("corllt"), "gaia")
		end)
	end)

	it("rejects Finalize twice", function()
		Finalize()
		assert.has_error(function()
			Finalize()
		end)
	end)
end)

describe("Claim", function()
	local function forFile()
		return Roster.ForFile("m/units.lua")
	end
	local function def(name)
		return { name = name }
	end

	it("records the intent to take an existing unit rather than add one", function()
		local file = forFile()
		file.Claim(def("armcom"), "enemy").Named("boss").OrSpawnAt(0.5, 0.5)
		local entries = file.Finalize()
		assert.are.equal(1, #entries)
		assert.is_true(entries[1].claim)
		assert.are.equal("armcom", entries[1].def)
		assert.are.equal("enemy", entries[1].team)
		assert.are.equal("boss", entries[1].name)
	end)

	it("still carries a position, for the case where there is nothing to claim", function()
		local file = forFile()
		file.Claim(def("armcom"), "enemy").OrSpawnAt(0.25, 0.75)
		local entries = file.Finalize()
		assert.are.equal(0.25, entries[1].fx)
		assert.are.equal(0.75, entries[1].fz)
	end)

	it("a claim with no OrSpawnAt fails the load, and says which verb is missing", function()
		-- A mission that cannot say what to do with an empty seat cannot arm in
		-- its own single-player game, so this is a load error rather than a
		-- silent no-op.
		local file = forFile()
		file.Claim(def("armcom"), "enemy").Named("boss")
		local ok, err = pcall(file.Finalize)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("OrSpawnAt", 1, true))
		assert.is_truthy(tostring(err):find("Claim 1", 1, true))
	end)

	it("Spawn keeps its own message when it is the one missing a position", function()
		local file = forFile()
		file.Spawn(def("armcom"), "enemy").Named("boss")
		local ok, err = pcall(file.Finalize)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("has no At", 1, true))
	end)

	it("Neutral is a Spawn thing, and off unless asked for", function()
		local file = Roster.ForFile("m/units.lua")
		file.Spawn({ name = "corllt" }, "gaia").At(0.5, 0.5).Neutral()
		file.Spawn({ name = "corllt" }, "gaia").At(0.6, 0.6)
		local entries = file.Finalize()
		assert.is_true(entries[1].neutral)
		assert.is_nil(entries[2].neutral, "a spawn is hostile unless the roster says otherwise")
	end)

	it("rejects a bad team role and a bad def, same as Spawn", function()
		assert.has_error(function()
			forFile().Claim(def("armcom"), "nobody")
		end)
		assert.has_error(function()
			forFile().Claim("armcom", "enemy")
		end)
	end)

	it("claimed and spawned names share one namespace", function()
		local file = forFile()
		file.Spawn(def("armcom"), "player").At(0, 0).Named("dup")
		file.Claim(def("armcom"), "enemy").Named("dup").OrSpawnAt(1, 1)
		local ok, err = pcall(file.Finalize)
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("duplicate unit name dup", 1, true))
	end)
end)
