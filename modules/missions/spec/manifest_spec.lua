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
		assert.are.same(
			{ "matchflow", "combat", "transfer", "waves", "scavengers", "placement" },
			manifests.missions.requires
		)
	end)

	it("every module it requires exists and contributes vocabulary or an api", function()
		for _, name in ipairs(manifests.missions.requires) do
			assert.is_table(manifests[name], "missions requires a module that was not discovered: " .. name)
		end
	end)
end)
