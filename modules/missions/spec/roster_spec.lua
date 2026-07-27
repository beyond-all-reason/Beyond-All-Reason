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
		Spawn(Verbs.UnitDef("corlab"), "gaia")
			.At(0.42, 0.42)
			.Named("hub")
			.Grouped("outpost_auto")
		Spawn(Verbs.UnitDef("armcom"), "enemy")
			.At(0.77, 0.77)
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
