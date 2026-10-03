-- What is under test is the boundary: the list is what regions holds, a form edits its own copy of one region, and a
-- region changes only when its form is submitted and regions takes it whole.
local Regions = require("modules/regions/api")
local Support = require("spec/luaui/Widgets/support/regions_tool")

describe("the regions tool", function()
	local R = {} ---@type table
	local api = {} ---@type table

	before_each(function()
		Regions.Clear()
		R, api = Support.Tool()
		R.setType("start")
	end)

	it("creates what a new form holds when it is submitted, and goes back to the list", function()
		R.openNew()
		local drawn = Support.Draw(R, Support.Square(0))
		assert.are.same({}, Regions.All(), "drawing alone offers regions nothing")
		assert.are.equal("form", api.getState().view)
		assert.is_true(api.submitForm())
		assert.are.equal("list", api.getState().view)
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.is_false(rawequal(held, drawn))
		assert.are.equal(0, held.team)
		assert.are.same({ held }, api.getState().regions)
	end)

	it("keeps a form regions refuses open, with what is wrong, until it is fixed", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		R.openNew()
		R.setFormField("team", "0")
		Support.Draw(R, Support.Square(500))
		assert.is_false(api.submitForm())
		local selected = assert(api.getState().selected)
		assert.are.same({ "a start with team 0 already exists" }, selected.problems)
		assert.is_true(selected.isNew)
		assert.are.equal(1, #Regions.All())
		R.setFormField("team", "1")
		assert.are.same({}, assert(api.getState().selected).problems, "an edit leaves what was said behind")
		assert.is_true(api.submitForm())
		assert.are.equal(2, #Regions.All())
	end)

	it("edits its own copy of a region; regions' changes only when the form is saved", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.is_true(api.openEdit(held.id))
		local copy = R.form.region
		assert.is_false(rawequal(copy, held))
		copy.vertices[1].x = 25
		R.touched()
		assert.is_true(assert(api.getState().selected).changed)
		assert.are.equal(0, assert(assert(Regions.Get(held.id)).vertices[1]).x)
		api.cancelForm()
		assert.are.equal(0, assert(assert(Regions.Get(held.id)).vertices[1]).x, "cancel leaves it as it was")
		api.openEdit(held.id)
		R.form.region.vertices[1].x = 25
		R.setFormField("name", "north")
		assert.is_true(api.submitForm())
		local saved = assert(Regions.Get(held.id))
		assert.are.equal(25, assert(saved.vertices[1]).x)
		assert.are.equal("north", saved.name)
		assert.are.equal(1, #Regions.All(), "the same region, under the same id")
	end)

	it("keeps an edit regions refuses in the form, and says where", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		api.openEdit(held.id)
		R.form.region.vertices = { { x = 0, z = 0 }, { x = 40, z = 0 } }
		assert.is_false(api.submitForm())
		assert.are.same(
			{ { message = "two vertices make neither a point nor a polygon", at = { x = 40, z = 0 } } },
			R.form.problems
		)
		assert.are.equal(4, #assert(Regions.Get(held.id)).vertices)
	end)

	it("deletes the region its form is on", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		api.openEdit(assert(Regions.All()[1]).id)
		assert.is_true(api.deleteForm())
		assert.are.same({}, Regions.All())
		assert.are.same({}, api.getState().regions)
	end)

	it("keeps a start that is only its positions as a point, one commit per position", function()
		assert.is_true(api.addPosition(300, 400, 0, 1))
		assert.is_true(api.addPosition(350, 400, 0, 2))
		assert.are.same({}, R.validate().lines)
		assert.are.equal(1, #Regions.All("start"))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.are.equal(0, held.team)
		assert.are.same({ { x = 300, z = 400 } }, held.vertices)
		assert.are.same({ { x = 300, z = 400 }, { x = 350, z = 400 } }, held.positions)
		api.clearAllPositions()
		assert.are.same({}, Regions.All("start"))
	end)

	it("makes a new start's area the area of the start already seated at its team", function()
		assert.is_true(api.addPosition(300, 400, 0, 1))
		assert.is_true(Support.Create(R, Support.Square(0), { team = "0" }))
		assert.are.equal(1, #Regions.All("start"))
		local held = assert(Regions.All("start")[1]) --[[@as table]]
		assert.are.equal(4, #held.vertices)
		assert.are.same({ { x = 300, z = 400 } }, held.positions)
	end)

	it("undoes a commit with another", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		local id = assert(Regions.All()[1]).id
		api.openEdit(id)
		R.setFormField("name", "north")
		assert.is_true(api.submitForm())
		R.undo()
		assert.is_nil(assert(Regions.Get(id)).name)
		R.undo()
		assert.are.same({}, Regions.All())
		R.redo()
		assert.are.equal(1, #Regions.All(), "made again, under the id regions gives it")
		R.undo()
		assert.are.same({}, Regions.All(), "and that one is the one undone")
	end)

	it("undoes past a delete: the region made again is the one the earlier steps go on to change", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		local id = assert(Regions.All()[1]).id
		api.openEdit(id)
		R.setFormField("name", "north")
		assert.is_true(api.submitForm())
		api.openEdit(id)
		assert.is_true(api.deleteForm())
		assert.are.same({}, Regions.All())
		R.undo()
		local again = assert(Regions.All()[1])
		assert.are.equal("north", again.name, "back, as it was when deleted")
		R.undo()
		assert.are.equal(1, #Regions.All())
		assert.is_nil(assert(Regions.All()[1]).name, "and the rename before the delete is undone on that region")
		R.redo()
		assert.are.equal("north", assert(Regions.All()[1]).name)
	end)

	it("moves later starts down a team when one goes", function()
		assert.is_true(Support.Create(R, Support.Square(0)))
		assert.is_true(Support.Create(R, Support.Square(500)))
		assert.is_true(Support.Create(R, Support.Square(1000)))
		api.openEdit(assert(R.start(0)).id)
		api.deleteForm()
		local teams = {}
		for _, region in ipairs(Regions.All("start")) do
			teams[#teams + 1] = (region --[[@as StartRegion]]).team
		end
		table.sort(teams)
		assert.are.same({ 0, 1 }, teams)
	end)

	it("saves what regions holds, and loads a file back leaving out what does not check out", function()
		local path = os.tmpname()
		assert.is_true(Support.Create(R, Support.Square(0)))
		local id = assert(Regions.All()[1]).id
		assert.is_true(api.saveRegions(path))
		local saved = assert(assert(io.open(path, "r")):read("*a")) --[[@as string]]
		assert.matches("team = 0", saved)
		assert.is_true(api.loadRegions(path))
		os.remove(path)
		assert.are.equal(id, assert(Regions.All()[1]).id)

		local brokenPath = os.tmpname()
		local broken = assert(io.open(brokenPath, "w"))
		broken:write(
			"return { regions = { start = { { id = 'a', team = 0, x = 1, y = 1 }, { id = 'b', x = 2, y = 2 } } } }"
		)
		broken:close()
		assert.is_true(api.loadRegions(brokenPath))
		os.remove(brokenPath)
		assert.are.equal(1, #Regions.All(), "the start with no team is left out")
		assert.are.equal("a", assert(Regions.All()[1]).id)
	end)
end)
