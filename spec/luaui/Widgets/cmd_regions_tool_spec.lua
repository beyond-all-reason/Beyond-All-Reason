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
		Support.Draw(R, Support.Square(500))
		R.setFormField("team", "")
		assert.is_false(api.submitForm())
		local selected = assert(api.getState().selected)
		assert.are.same({ "a start needs a team" }, selected.problems)
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

	it("offers a start every team, naming the start seated there; picking a seated one opens that start", function()
		local R, api = Support.Tool()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
		assert.is_true(Support.Create(R, Support.Square(600), { team = "1", name = "N" }))
		local south, north = R.start(0), R.start(1)
		R.openEdit(north.id)
		assert.are.same(
			{ { team = 0, label = "Team 1 · S" }, { team = 1, label = "Team 2 · N" } },
			R.teamOptions(),
			"two ally teams, both seated"
		)
		R.setFormField("name", "North")
		assert.is_false(R.setFormField("team", "0"))
		assert.are.equal(north.id, R.form.id, "unsaved edits keep the form here")
		assert.are.equal("Save or cancel the edits here first, then pick Team 1 to move there", R.error)
		R.cancelForm()
		R.openEdit(north.id)
		assert.is_true(R.setFormField("team", "0"))
		assert.are.equal(south.id, R.form.id, "with nothing to save, the form moved to the south start")
		R.cancelForm()
		api.setNumAllyTeams(3)
		R.openEdit(south.id)
		assert.are.same(
			{ { team = 0, label = "Team 1 · S" }, { team = 1, label = "Team 2 · N" }, { team = 2, label = "Team 3" } },
			R.teamOptions(),
			"a third ally team on the slider is a free seat"
		)
		R.setFormField("team", "2")
		assert.are.equal(south.id, R.form.id, "a free team stays an edit of this start")
		assert.are.equal(2, R.form.region.team)
	end)

	it("a click on the map inside another region opens it, unless the form has edits to save or drop first", function()
		local R, api = Support.Tool()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
		assert.is_true(Support.Create(R, Support.Square(600), { team = "1", name = "N" }))
		local south, north = R.start(0), R.start(1)
		R.openEdit(north.id)
		assert.is_false(R.pick(2), "the form's own region is not a move")
		assert.is_true(R.pick(1))
		assert.are.equal(south.id, R.form.id)
		R.setFormField("name", "South")
		assert.is_false(R.pick(2))
		assert.are.equal(south.id, R.form.id, "unsaved edits keep the form here")
		assert.are.equal("Save or cancel the edits here first, then click the other region to open it", R.error)
		assert.are.equal("South", R.form.region.name, "and keep the edit")
		assert.is_not_nil(api.getState().regionError:find("Save or cancel", 1, true))
	end)

	it("places positions for the starts seated, counting teams the way the starts do", function()
		local R, api = Support.Tool()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
		assert.is_true(Support.Create(R, Support.Square(600), { team = "1", name = "N" }))
		api.placeRandomPositions(1000, 1000)
		assert.are.equal(2, #R.held("start"), "no third start was seated")
		local counts = {}
		for _, start in ipairs(R.held("start")) do
			counts[start.team] = #(start.positions or {})
		end
		assert.is_true((counts[0] or 0) > 0 and (counts[1] or 0) > 0, "both seated starts got positions")
	end)

	it("closes spots gathered with the Mexes tool into the shape when the form is submitted", function()
		local R = Support.Tool()
		R.setType("start")
		R.openNew()
		R.setFormField("team", "0")
		R.radialPending = { { x = 100, z = 100 }, { x = 400, z = 100 }, { x = 250, z = 400 } }
		assert.is_true(R.submitForm())
		local held = R.held("start")
		assert.are.equal(1, #held)
		assert.is_true(#held[1].vertices >= 3, "the hull around the spots is its shape")
		assert.are.same({}, R.radialPending)
	end)

	it(
		"switching to Positions closes a clean form and places from the list; a form with edits stays and says so",
		function()
			local R, api = Support.Tool()
			R.setType("start")
			assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
			R.openEdit(R.start(0).id)
			assert.is_true(R.setEditMode("create"))
			assert.is_nil(R.form)
			assert.are.equal("points", api.getState().placing)
			R.setEditMode("select")
			R.openEdit(R.start(0).id)
			R.setFormField("name", "South")
			assert.is_false(R.setEditMode("create"))
			assert.is_not_nil(R.form, "the form with edits stays")
			assert.are.equal("Save or cancel the edits here first, then switch to Positions", R.error)
		end
	)

	it("a draw tool picked from the list begins a new region with that tool armed", function()
		local R, api = Support.Tool()
		R.setType("start")
		local offered = api.getState().newGeometries
		assert.is_true(#offered > 0)
		for _, g in ipairs(offered) do
			assert.are_not.equal("point", g, "points are placed, not drawn")
		end
		assert.is_true(api.openNewWith(offered[1]))
		assert.is_not_nil(R.form)
		assert.is_true(R.form.isNew == nil or R.form.id == nil)
		assert.are.equal(offered[1], api.getState().geometry)
		assert.are.equal("form", api.getState().view)
		assert.is_false(api.openNewWith("point"))
	end)

	it("Point on a held start with an area removes the area as a commit; pending field edits stay pending", function()
		local R, api = Support.Tool()
		R.setType("start")
		assert.is_true(Support.Create(R, Support.Square(100), { team = "0", name = "S" }))
		local south = R.start(0)
		R.openEdit(south.id)
		local offered = table.concat(api.getState().geometries, ",")
		assert.is_not_nil(offered:find("point", 1, true), "a start's form offers Point")
		assert.is_false(api.setGeometry("point"), "no positions: nothing would be left")
		assert.is_not_nil(R.error:find("no positions to stand at", 1, true))
		assert.is_true(#R.start(0).vertices >= 3, "the area stayed")
		R.cancelForm()
		api.addPosition(150, 150, 0, 1)
		R.openEdit(south.id)
		R.setFormField("name", "South")
		assert.is_true(api.setGeometry("point"))
		assert.are.equal("point", api.getState().geometry)
		assert.are.equal("point", R.start(0).kind, "regions holds the start as a point now")
		assert.are.equal(1, #R.start(0).vertices)
		assert.are.equal("S", R.start(0).name, "the pending name edit was not saved by it")
		assert.is_true(R.form.changed, "and is still pending in the form")
		assert.are.equal("South", R.form.region.name)
		assert.are.equal(1, #R.form.region.vertices, "the form shows the shape regions holds")
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
