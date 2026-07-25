local Roster = VFS.Include("modules/missions/lib/roster.lua")

describe("mission roster", function()
	it("parses entries with defaults applied", function()
		local entries = Roster.Parse({
			{ def = "corllt", team = "gaia", x = 100, z = 200 },
			{ name = "hub", def = "corlab", team = "gaia", x = 300, z = 400, facing = 2, group = "outpost_auto" },
		})
		assert.are.equal(2, #entries)
		assert.are.same(
			{ def = "corllt", team = "gaia", x = 100, z = 200, facing = 0 },
			entries[1]
		)
		assert.are.same(
			{ name = "hub", def = "corlab", team = "gaia", x = 300, z = 400, facing = 2, group = "outpost_auto" },
			entries[2]
		)
	end)

	it("rejects a non-table roster", function()
		assert.has_error(function()
			Roster.Parse("nope")
		end)
	end)

	it("rejects an entry without a def, naming the entry", function()
		local ok, err = pcall(Roster.Parse, { { team = "gaia", x = 1, z = 1 } })
		assert.is_false(ok)
		assert.is_truthy(tostring(err):find("entry 1", 1, true))
	end)

	it("rejects unknown team roles", function()
		assert.has_error(function()
			Roster.Parse({ { def = "corllt", team = "raptors", x = 1, z = 1 } })
		end)
	end)

	it("rejects missing coordinates", function()
		assert.has_error(function()
			Roster.Parse({ { def = "corllt", team = "gaia", x = 1 } })
		end)
	end)

	it("rejects duplicate unit names", function()
		assert.has_error(function()
			Roster.Parse({
				{ name = "hub", def = "corllt", team = "gaia", x = 1, z = 1 },
				{ name = "hub", def = "corllt", team = "gaia", x = 2, z = 2 },
			})
		end)
	end)

	it("rejects a non-numeric facing", function()
		assert.has_error(function()
			Roster.Parse({ { def = "corllt", team = "gaia", x = 1, z = 1, facing = "south" } })
		end)
	end)
end)
