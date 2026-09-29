local Regions = require("modules/regions/api")

local square = { { x = 0, z = 0 }, { x = 100, z = 0 }, { x = 100, z = 100 }, { x = 0, z = 100 } }
local far = { { x = 500, z = 500 }, { x = 600, z = 500 }, { x = 600, z = 600 } }

local made = 0

---@param fields table
---@return Region
local function start(fields)
	made = made + 1
	fields.id = fields.id or ("r" .. made)
	return Regions.New(Regions.Enums.Types.Start, fields)
end

describe("checking a region", function()
	it("passes a whole polygon or a point with its required fields", function()
		assert.are.same({}, Regions.Check(Regions.Enums.Types.Start, start({ team = 1, vertices = square }), {}))
		assert.are.same(
			{},
			Regions.Check(Regions.Enums.Types.Start, start({ team = 1, vertices = { { x = 5, z = 5 } } }), {})
		)
	end)

	it("collects every problem rather than stopping at the first", function()
		local problems =
			Regions.Check(Regions.Enums.Types.Start, start({ vertices = { { x = 0, z = 0 }, { x = 1, z = 1 } } }), {})
		assert.are.same({
			{ message = "two vertices make neither a point nor a polygon", at = { x = 1, z = 1 } },
			{ message = "a start needs a team" },
		}, problems)
		assert.are.same(
			{ { message = "a region is a point or a polygon" } },
			Regions.Check(Regions.Enums.Types.Start, start({ team = 1 }), {})
		)
	end)

	it("refuses a value a sibling already has where the type says it is unique", function()
		assert.are.same(
			{ { message = "a start with team 1 already exists" } },
			Regions.Check(
				Regions.Enums.Types.Start,
				start({ team = 1, vertices = square }),
				{ start({ team = 1, vertices = far }) }
			)
		)
		assert.are.same(
			{ { message = "Team must be a number" } },
			Regions.Check(Regions.Enums.Types.Start, start({ team = "north", vertices = square }), {})
		)
	end)

	it("checks only the fields when the region has no shape yet", function()
		assert.are.same({}, Regions.Check(Regions.Enums.Types.Start, start({ team = 1 }), {}, true))
		assert.are.same(
			{ { message = "a start needs a team" } },
			Regions.Check(Regions.Enums.Types.Start, start({}), {}, true)
		)
	end)
end)
