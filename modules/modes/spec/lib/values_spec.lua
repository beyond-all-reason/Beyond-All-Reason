local Values = VFS.Include("modules/modes/lib/values.lua") ---@type ModeValues

describe("mode values on the wire", function()
	it("writes booleans as the engine reads them", function()
		assert.are.equal("1", Values.ToModOption(true))
		assert.are.equal("0", Values.ToModOption(false))
	end)

	it("rounds numbers at float32 precision and trims what %g would keep", function()
		assert.are.equal("0.6", Values.ToModOption(0.6))
		assert.are.equal("0.6", Values.ToModOption(0.60000002))
		assert.are.equal("30", Values.ToModOption(30))
		assert.are.equal("-1", Values.ToModOption(-1))
		assert.are.equal("0", Values.ToModOption(0))
		assert.are.equal("1.5", Values.ToModOption(1.5))
	end)

	it("passes strings through", function()
		assert.are.equal("notcoms", Values.ToModOption("notcoms"))
	end)
end)
