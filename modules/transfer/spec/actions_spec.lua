--- transfer publishes its capabilities as declared actions: the framework's
--- actions/ slot, loaded by ModuleHandler, validate before execute. Until
--- these files existed the loader had no callers at all.

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

	it("validate refuses a resource that is not metal or energy", function()
		local allowed = registry.byName.resources.validate({ from = 0, to = 1, resource = "ore", amount = 5 })
		assert.is_false(allowed)
	end)

	it("validate refuses a non-positive amount", function()
		assert.is_false(registry.byName.resources.validate({ from = 0, to = 1, resource = "metal", amount = 0 }))
	end)
end)
