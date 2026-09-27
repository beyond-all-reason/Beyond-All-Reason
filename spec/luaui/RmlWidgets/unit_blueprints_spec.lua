-- Unit blueprints (refactor plan, U9): the file format, pure.
local Blueprints = VFS.Include("luaui/RmlWidgets/gui_unit_library/blueprints.lua")

local SAMPLE = {
	name = "Forward base",
	units = {
		{ unitDefName = "armllt", dx = -32, dz = 0, facing = 1, extra = { neutral = true } },
		{ unitDefName = "armsolar", dx = 32.5, dz = -16, facing = 0, extra = { orders = { { "MOVE", { 1, 2, 3 } } } } },
	},
}

describe("unit blueprints", function()
	it("round-trips through its file text", function()
		local text = Blueprints.serialise(SAMPLE)
		local back = assert(Blueprints.parse(text))
		assert.are.equal("Forward base", back.name)
		assert.are.equal(1, back.version)
		assert.are.same(SAMPLE.units, back.units)
	end)

	it("writes the same text for the same blueprint", function()
		assert.are.equal(Blueprints.serialise(SAMPLE), Blueprints.serialise(SAMPLE))
	end)

	it("reads a file in an empty sandbox: it cannot reach anything", function()
		local blueprint, why = Blueprints.parse("os.exit(1) return { units = { { unitDefName = 'armpw' } } }")
		assert.is_nil(blueprint)
		assert.is_truthy(tostring(why):find("not a blueprint", 1, true))
	end)

	it("refuses what is not a blueprint, and fills in what a unit left out", function()
		assert.is_nil((Blueprints.parse("return {}")))
		assert.is_nil((Blueprints.parse("return { units = { { dx = 1 } } }")))
		assert.is_nil((Blueprints.parse("this is not lua")))
		local minimal = assert(Blueprints.parse("return { units = { { unitDefName = 'armpw' } } }"))
		assert.are.same({ unitDefName = "armpw", dx = 0, dz = 0, facing = 0, extra = {} }, minimal.units[1])
	end)

	it("drops what plain data cannot carry", function()
		local text =
			Blueprints.serialise({ name = "f", units = { { unitDefName = "armpw", extra = { f = function() end } } } })
		local back = assert(Blueprints.parse(text))
		assert.is_nil(back.units[1].extra.f)
	end)

	it("turns a name into a safe file name", function()
		assert.are.equal("forward_base.lua", Blueprints.fileName("Forward base!"))
		assert.are.equal("blueprint.lua", Blueprints.fileName("  ../  "))
	end)
end)
