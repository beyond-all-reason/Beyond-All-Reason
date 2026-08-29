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

	it("missions declares its matchflow dependency, and the transport rules it speaks", function()
		assert.are.same({ "matchflow", "transport" }, manifests.missions.requires)
	end)
end)
