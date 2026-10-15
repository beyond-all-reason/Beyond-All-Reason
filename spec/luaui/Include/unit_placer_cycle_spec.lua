-- The shared unit placer's pick set (PtaQ's N2): several types picked with Shift, cycled
-- through on each placement, in order or at random.
local Cycle = VFS.Include("luaui/Include/unit_placer/cycle.lua")

describe("unit_placer.cycle", function()
	describe("toggle", function()
		it("a plain click picks that one alone", function()
			assert.are.same({ "c" }, Cycle.toggle({ "a", "b" }, "c", false))
		end)

		it("Shift adds to the end, in the order picked", function()
			assert.are.same({ "a", "b", "c" }, Cycle.toggle({ "a", "b" }, "c", true))
		end)

		it("Shift on a member takes it back out", function()
			assert.are.same({ "a", "c" }, Cycle.toggle({ "a", "b", "c" }, "b", true))
		end)

		it("Shift on the last member keeps it rather than emptying the set", function()
			assert.are.same({ "a" }, Cycle.toggle({ "a" }, "a", true))
		end)

		it("does not change the set it was handed", function()
			local names = { "a" }
			Cycle.toggle(names, "b", true)
			assert.are.same({ "a" }, names)
		end)
	end)

	describe("mode", function()
		it("reads anything unknown as ORDER, and flips between the two", function()
			assert.are.equal("abc", Cycle.mode(nil))
			assert.are.equal("abc", Cycle.mode("sideways"))
			assert.are.equal("random", Cycle.mode("random"))
			assert.are.equal("random", Cycle.other("abc"))
			assert.are.equal("abc", Cycle.other("random"))
		end)
	end)

	describe("ORDER", function()
		it("walks the set a b c and wraps", function()
			local set = Cycle.new({ "a", "b", "c" }, "abc")
			local seen = { set.current() }
			for _ = 1, 4 do
				seen[#seen + 1] = set.advance()
			end
			assert.are.same({ "a", "b", "c", "a", "b" }, seen)
		end)

		it("a single pick stays that pick", function()
			local set = Cycle.new({ "a" }, "abc")
			assert.are.equal("a", set.advance())
			assert.is_false(set.cycles())
		end)

		it("copies the list it was given", function()
			local names = { "a", "b" }
			local set = Cycle.new(names, "abc")
			names[1] = "z"
			assert.are.equal("a", set.current())
		end)
	end)

	describe("RANDOM", function()
		it("draws every placement from the whole set", function()
			local draws = { 3, 1, 3, 2 }
			local n = 0
			local set = Cycle.new({ "a", "b", "c" }, "random", function(size)
				assert.are.equal(3, size)
				n = n + 1
				return draws[n]
			end)
			assert.are.same({ "c", "a", "c", "b" }, { set.current(), set.advance(), set.advance(), set.advance() })
		end)

		it("keeps a bad draw inside the set", function()
			local set = Cycle.new({ "a", "b" }, "random", function()
				return 9
			end)
			assert.are.equal("b", set.current())
		end)

		it("never leaves the set with the real random source", function()
			local set = Cycle.new({ "a", "b", "c" }, "random")
			local members = { a = true, b = true, c = true }
			for _ = 1, 50 do
				assert.is_true(members[set.advance()] == true)
			end
		end)
	end)

	it("an empty set has nothing to arm with", function()
		local set = Cycle.new({}, "abc")
		assert.is_nil(set.current())
		assert.is_nil(set.advance())
	end)
end)
