local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local env = SpecEnv.new()
local facingFunctions = SpecEnv.include(env, "common/springUtilities/facingFunctions.lua")

describe("common.facingFunctions", function()
	describe("FacingToNumber", function()
		it("turns a facing name or letter into the engine's number", function()
			assert.are.equal(1, facingFunctions.FacingToNumber("east"))
			assert.are.equal(3, facingFunctions.FacingToNumber("w"))
		end)

		it("keeps a facing that is already a number", function()
			assert.are.equal(2, facingFunctions.FacingToNumber(2))
		end)

		it("faces south when no facing is given", function()
			assert.are.equal(0, facingFunctions.FacingToNumber(nil))
		end)
	end)
end)
