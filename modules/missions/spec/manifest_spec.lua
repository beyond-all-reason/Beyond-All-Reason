local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("the missions manifest", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("discovers missions and matchflow", function()
		assert.is_table(manifests.missions)
		assert.is_table(manifests.matchflow)
	end)

	it("missions declares the modules it draws vocabulary from", function()
		assert.are.same({ "matchflow", "transport", "combat", "transfer" }, manifests.missions.requires)
	end)
end)
