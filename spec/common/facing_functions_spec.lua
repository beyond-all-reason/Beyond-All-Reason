local SpecEnv = VFS.Include("spec/support/spec_env.lua")

local env = SpecEnv.new({
	Spring = {
		GetHeadingFromFacing = function(facing)
			return ({ [0] = 0, [1] = 16384, [2] = 32767, [3] = -16384 })[facing]
		end,
	},
})
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

	describe("CompassAngleToHeading", function()
		it("turns a compass angle into the engine's heading", function()
			assert.are.equal(32768, facingFunctions.CompassAngleToHeading(0))
			assert.are.equal(16384, facingFunctions.CompassAngleToHeading(90))
			assert.are.equal(0, facingFunctions.CompassAngleToHeading(180))
			assert.are.equal(-16384, facingFunctions.CompassAngleToHeading(270))
		end)

		it("turns a compass angle into radians", function()
			assert.are.equal(math.pi, facingFunctions.CompassAngleToHeading(0, true))
			assert.are.equal(math.pi / 2, facingFunctions.CompassAngleToHeading(90, true))
		end)
	end)

	describe("DirectionToHeading", function()
		it("takes a compass angle as it is", function()
			assert.are.equal(16384, facingFunctions.DirectionToHeading(100, 100, { angle = 90 }))
		end)

		it("faces a point, east and north of the start", function()
			assert.are.equal(16384, facingFunctions.DirectionToHeading(100, 100, { x = 200, z = 100 }))
			assert.are.equal(32768, facingFunctions.DirectionToHeading(100, 100, { x = 100, z = 0 }))
		end)

		it("faces south when the point is the start point", function()
			assert.are.equal(0, facingFunctions.DirectionToHeading(100, 100, { x = 100, z = 100 }))
		end)
	end)
end)
