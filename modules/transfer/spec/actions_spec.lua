
local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("transfer actions", function()
	local registry

	setup(function()
		ModuleHandler.ResetCaches()
		registry = ModuleHandler.LoadActions("transfer")
	end)

	it("declares units and resources", function()
		assert.is_table(registry.byName.units)
		assert.is_table(registry.byName.resources)
	end)

	it("declares give and give_resources, the two that skip policy", function()
		assert.is_table(registry.byName.give)
		assert.is_table(registry.byName.give_resources)
	end)

	it("every action registers an execute", function()
		for _, action in ipairs(registry.list) do
			assert.is_function(action.execute, action.name .. " must register execute")
		end
	end)

	it("validate refuses a team sharing with itself", function()
		local allowed, reason = registry.byName.units.validate({ from = 1, to = 1, unitIDs = { 7 } })
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("itself", 1, true))
	end)

	it("validate refuses an empty unit list", function()
		assert.is_false(registry.byName.units.validate({ from = 0, to = 1, unitIDs = {} }))
	end)

	it("validate refuses when the controller has not handed its pipeline over", function()
		local allowed, reason = registry.byName.units.validate({ from = 0, to = 1, unitIDs = { 7 } })
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("initialized", 1, true))
	end)

	it("give_resources refuses a team handing to itself", function()
		local allowed, reason = registry.byName.give_resources.validate({
			from = 2,
			to = 2,
			resource = "metal",
			amount = 5,
			add = function() end,
			take = function() end,
		})
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("itself", 1, true))
	end)

	it("give_resources moves the whole amount, both sides, untaxed", function()
		local moves = {}
		local record = function(team, resource, delta)
			moves[#moves + 1] = { team = team, resource = resource, delta = delta }
		end
		local moved = registry.byName.give_resources.execute({
			from = 1,
			to = 2,
			resource = "metal",
			amount = 40,
			add = record,
			take = record,
		})
		assert.are.equal(40, moved)
		assert.are.same({
			{ team = 1, resource = "metal", delta = -40 },
			{ team = 2, resource = "metal", delta = 40 },
		}, moves)
	end)

	it("resources validate refuses without a send function", function()
		local allowed, reason = registry.byName.resources.validate({
			from = 0,
			to = 1,
			resource = "metal",
			amount = 5,
		})
		assert.is_false(allowed)
		assert.is_truthy(tostring(reason):find("initialized", 1, true))
	end)

	it("validate refuses a resource that is not metal or energy", function()
		local allowed = registry.byName.resources.validate({ from = 0, to = 1, resource = "ore", amount = 5 })
		assert.is_false(allowed)
	end)

	it("validate refuses a non-positive amount", function()
		assert.is_false(registry.byName.resources.validate({ from = 0, to = 1, resource = "metal", amount = 0 }))
	end)
end)
