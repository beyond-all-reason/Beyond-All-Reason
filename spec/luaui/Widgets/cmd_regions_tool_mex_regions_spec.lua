local Regions = require("modules/regions/api")
local Support = require("spec/luaui/Widgets/support/regions_tool")

describe("a mex region in the regions tool", function()
	local R = {} ---@type table
	local api = {} ---@type table

	before_each(function()
		Regions.Clear()
		R, api = Support.Tool()
		R.setType("mex_region")
	end)

	it("is made only once its form has its team and its group", function()
		R.openNew()
		Support.Draw(R, Support.Square(0))
		assert.is_false(api.submitForm())
		assert.are.same(
			{ "a mex region needs a team", "a mex region needs a group" },
			assert(api.getState().selected).problems
		)
		assert.are.same({}, Regions.All())
		assert.is_true(api.setFormField("team", "0"))
		assert.is_true(api.setFormField("group", "anti"))
		assert.is_true(api.submitForm())
		local held = assert(Regions.All("mex_region")[1]) --[[@as table]]
		assert.are.equal("anti", held.group)
		assert.are.equal(0, held.team)
	end)

	it("keeps a field typed wrong in the form, with what is wrong", function()
		assert.is_true(Support.Create(R, Support.Square(0), { team = "0", group = "anti" }))
		local held = assert(Regions.All("mex_region")[1]) --[[@as table]]
		api.openEdit(held.id)
		api.setFormField("team", "north")
		assert.is_false(api.submitForm())
		local selected = assert(api.getState().selected)
		assert.are.equal("north", selected.fields.team)
		assert.are.same({ "Team must be a number" }, selected.problems)
		assert.are.equal(0, assert(Regions.Get(held.id)).team)
	end)

	it("offers a team for every start drawn, named after the start", function()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
		assert.is_true(Support.Create(R, Support.Square(600), { team = "1", name = "N" }))
		R.setType("mex_region")
		R.openNew()
		assert.are.same({ { team = 0, label = "S" }, { team = 1, label = "N" } }, R.teamOptions())
	end)

	it("is checked against the map's starts only once a start is drawn", function()
		assert.is_true(Support.Create(R, Support.Square(0), { team = "3", group = "anti" }))
		local held = assert(Regions.All("mex_region")[1])
		assert.is_nil(R.validate().byRegion[held], "with no start drawn, the count is not the tool's to say")
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(500)))
		R.setType("mex_region")
		assert.are.same({ "bound to start 3; the map's starts are 0 to 0" }, R.validate().byRegion[held])
	end)
end)
