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

describe("a region's name", function()
	it("is what the map gave it, or what its type's owner calls it, numbered once siblings share it", function()
		local names = Regions.Names(Regions.Enums.Types.Start, {
			start({ team = 1 }),
			start({ team = 2, name = "N" }),
			start({}),
			start({}),
		})
		assert.are.same({ name = "1", derived = true }, names[1], "a start is called after its team")
		assert.are.same({ name = "N", derived = false }, names[2])
		assert.are.same({ name = "start_1", derived = true }, names[3], "no team, so the type's label, numbered")
		assert.are.same({ name = "start_2", derived = true }, names[4])
	end)
end)
