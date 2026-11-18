-- Passes on 64-bit Lua and fails on the engine's float32 Lua. This is just a test (of testing (tests)).
describe("Lua numbers", function()
	it("hold 2^24 + 1 exactly", function()
		assert.are_not.equal(2 ^ 24, 2 ^ 24 + 1)
	end)
end)
