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
		-- The requires list IS the whitelist of what a mission file may say,
		-- so adding to it is the entire authorization story for new
		-- vocabulary: waves brings the verbs, scavengers brings the packs.
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
