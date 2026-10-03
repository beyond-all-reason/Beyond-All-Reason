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

describe("the region types", function()
	it("come by key, each saying what it may be drawn as and who contributed it", function()
		local order, byKey = Regions.Types()
		assert.is_true(table.contains(order, "start"))
		assert.are.same({ "point", "polygon" }, byKey.start.geometries)
		assert.are.equal("start", byKey.start.module)
	end)
end)
