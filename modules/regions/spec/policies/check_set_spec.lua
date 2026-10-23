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

describe("a set of regions", function()
	it("is checked region by region, every problem naming its region", function()
		local regions = {
			start({ team = 1, vertices = square }),
			start({ team = 1, name = "twin", vertices = far }),
			start({ team = 2, vertices = { { x = 900, z = 900 } } }),
		}
		local problems = Regions.CheckSet(Regions.Enums.Types.Start, regions)
		assert.are.same({
			{ region = regions[1], name = "1", message = "a start with team 1 already exists" },
			{ region = regions[2], name = "twin", message = "a start with team 1 already exists" },
		}, problems)
		local first = assert(problems[1])
		assert.is_true(rawequal(regions[1], first.region), "the problem points at the caller's own table")
		assert.are.equal("1: a start with team 1 already exists", Regions.ProblemLine(first))
		assert.are.equal("about the set", Regions.ProblemLine({ message = "about the set" }))
	end)
end)
