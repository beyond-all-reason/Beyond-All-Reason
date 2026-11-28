local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local env = SpecEnv.new({
	Game = { textColorCodes = { Color = "\255", ColorAndOutline = "\254" } },
})
local color = SpecEnv.include(env, "common/springUtilities/color.lua")

describe("common.color", function()
	describe("ToInt", function()
		it("packs 0-1 channels into one integer", function()
			assert.are.equal(0xFF8000, color.ToInt(1, 128 / 255, 0))
		end)

		it("clamps channels outside 0-1", function()
			assert.are.equal(0xFF00FF, color.ToInt(1.4, -2, 3))
		end)
	end)

	describe("FromInt", function()
		it("unpacks an integer into 0-1 channels", function()
			assert.are.same({ 1, 128 / 255, 0 }, { color.FromInt(0xFF8000) })
		end)

		it("gives back what ToInt packed", function()
			assert.are.equal(0x336699, color.ToInt(color.FromInt(0x336699)))
		end)
	end)
end)
