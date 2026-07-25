local ModuleHandler = VFS.Include("modules/module_handler.lua")

describe("mission module manifests", function()
	local manifests

	setup(function()
		ModuleHandler.ResetCaches()
		manifests = ModuleHandler.Discover()
	end)

	it("discovers missions, matchflow and combat", function()
		assert.is_table(manifests.missions)
		assert.is_table(manifests.matchflow)
		assert.is_table(manifests.combat)
	end)

	it("missions declares its matchflow and combat dependencies", function()
		assert.are.same({ "matchflow", "combat" }, manifests.missions.requires)
	end)

	it("every declared requirement resolves to a discovered module", function()
		for name, manifest in pairs(manifests) do
			for _, required in ipairs(manifest.requires or {}) do
				assert.is_table(manifests[required],
					name .. " requires missing module " .. required)
			end
		end
	end)
end)
