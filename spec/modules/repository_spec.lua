local Repository = require("modules/repository")

---@class SpecThing
---@field id string|nil
---@field name string
---@field colour string|nil

describe("a repository", function()
	local things = Repository.New() ---@type Repository<SpecThing>

	before_each(function()
		things = Repository.New()
	end)

	it("holds what it creates, in order, each under an id that counts up", function()
		local given = { name = "a" }
		local a = things.Create(given)
		local b = things.Create({ name = "b" })
		assert.is_true(rawequal(a, given), "the entity itself, not a copy")
		assert.are.equal("1", a.id)
		assert.are.equal("2", b.id)
		assert.are.same({ a, b }, things.All())
		assert.is_true(rawequal(a, things.Get("1")))
	end)

	it("gives every entity it creates its id, and takes none from the caller", function()
		assert.has_error(function()
			things.Create({ id = "7", name = "a" })
		end, "Repository: an entity is given its id on creation")
	end)

	it(
		"loads what was saved: exactly those, in order, under their ids, and never gives one of those ids again",
		function()
			things.Create({ name = "gone" })
			local b, a = { id = "9", name = "b" }, { id = "3", name = "a" }
			assert.are.same({ b, a }, things.Load({ b, a }))
			assert.are.same({ b, a }, things.All())
			assert.is_nil(things.Get("1"))
			assert.is_true(rawequal(a, things.Get("3")))
			things.Delete("9")
			assert.are.equal("10", things.Create({ name = "drawn" }).id, "an id once seen is not given again")
		end
	)

	it("will not load an entity without its id, or two under one", function()
		assert.has_error(function()
			things.Load({ { name = "a" } })
		end, "Repository: a loaded entity brings its id")
		assert.has_error(function()
			things.Load({ { id = "1", name = "a" }, { id = "1", name = "b" } })
		end, "Repository: two entities under id 1")
	end)

	it("updates an entity where the one under its id stood", function()
		local a = things.Create({ name = "a" })
		local b = things.Create({ name = "b" })
		local renamed = things.Update({ id = a.id, name = "first" })
		assert.are.same({ renamed, b }, things.All())
		assert.is_true(rawequal(renamed, things.Get("1")))
	end)

	it("will not update what it does not hold", function()
		assert.has_error(function()
			things.Update({ id = "7", name = "nobody" })
		end, "Repository: no entity under id 7")
	end)

	it("lists only what is asked for", function()
		local a = things.Create({ name = "a", colour = "red" })
		things.Create({ name = "b", colour = "blue" })
		local c = things.Create({ name = "c", colour = "red" })
		assert.are.same(
			{ a, c },
			things.All(function(thing)
				return thing.colour == "red"
			end)
		)
	end)

	it("deletes by id, clears what is asked for, and counts every change", function()
		local before = things.Revision()
		local a = things.Create({ name = "a", colour = "red" })
		local b = things.Create({ name = "b", colour = "blue" })
		assert.is_true(rawequal(a, things.Delete("1")))
		assert.is_nil(things.Delete("1"))
		assert.are.same(
			{ b },
			things.Clear(function(thing)
				return thing.colour == "blue"
			end)
		)
		assert.are.same({}, things.All())
		assert.are.equal(before + 4, things.Revision())
	end)
end)
