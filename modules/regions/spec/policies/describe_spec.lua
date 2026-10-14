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

describe("what is said about a region", function()
	it("is nothing for a type nobody owns, and the owner's record for one somebody does", function()
		assert.is_nil(Regions.Describe({ id = "n", type = "nobody_knows", vertices = square }))
		local s = Regions.Describe(start({ team = 1, vertices = square }), {})
		assert.are.equal(1, s.team, "start answers for its own type")
	end)

	it("the shape is regions' own: area and centre, a point having no area", function()
		assert.are.same(
			{ area = 10000, centre = { x = 50, z = 50 } },
			Regions.Shape({ id = "n", type = "nobody_knows", vertices = square })
		)
		assert.are.same(
			{ area = 0, centre = { x = 7, z = 9 } },
			Regions.Shape({ id = "n", type = "nobody_knows", vertices = { { x = 7, z = 9 } } })
		)
	end)
end)
